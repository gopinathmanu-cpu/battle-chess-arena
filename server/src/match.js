// SPDX-License-Identifier: GPL-3.0-or-later
// Modified 2026-09-05: sequenced online actions and replay protection.
import { randomUUID } from "node:crypto";
import { performance } from "node:perf_hooks";
import { Chess } from "chess.js";

export class MatchError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

export class Match {
  constructor({
    id = randomUUID(),
    baseMs = 600_000,
    incrementMs = 0,
    whitePlayer = null,
  } = {}) {
    if (!Number.isInteger(baseMs) || baseMs < 10_000 || baseMs > 10_800_000) {
      throw new MatchError(
        "INVALID_CLOCK",
        "baseMs must be between 10 seconds and 3 hours",
      );
    }
    if (
      !Number.isInteger(incrementMs) ||
      incrementMs < 0 ||
      incrementMs > 60_000
    ) {
      throw new MatchError(
        "INVALID_CLOCK",
        "incrementMs must be between 0 and 60 seconds",
      );
    }
    this.id = id;
    this.chess = new Chess();
    this.baseMs = baseMs;
    this.incrementMs = incrementMs;
    this.remaining = { w: baseMs, b: baseMs };
    this.tokens = { w: randomUUID(), b: null };
    this.players = {
      w: whitePlayer ?? {
        id: `guest-${randomUUID()}`,
        name: "White player",
        avatarId: "crown",
      },
      b: null,
    };
    this.status = "waiting";
    this.result = null;
    this.activeSince = null;
    this.sequence = 0;
    this.round = 1;
    this.drawOffer = null;
    this.rematchOffers = new Set();
    // Retain receipts across rematches; never evict and permit old replay.
    this.commands = new Map();
  }

  get whiteToken() {
    return this.tokens.w;
  }

  joinBlack(now = performance.now(), blackPlayer = null) {
    this.settleClock(now);
    if (this.tokens.b)
      throw new MatchError("GAME_FULL", "Both seats are already claimed");
    this.tokens.b = randomUUID();
    this.players.b = blackPlayer ?? {
      id: `guest-${randomUUID()}`,
      name: "Black player",
      avatarId: "knight",
    };
    this.status = "active";
    this.activeSince = now;
    return this.tokens.b;
  }

  hasPlayer(playerId) {
    return this.players.w?.id === playerId || this.players.b?.id === playerId;
  }

  isPair(firstId, secondId) {
    return (
      (this.players.w?.id === firstId && this.players.b?.id === secondId) ||
      (this.players.w?.id === secondId && this.players.b?.id === firstId)
    );
  }

  playerIdForSide(side) {
    return this.players[side]?.id ?? null;
  }

  sideForToken(token) {
    if (typeof token !== "string" || token.length === 0) return null;
    if (token === this.tokens.w) return "w";
    if (token === this.tokens.b) return "b";
    return null;
  }

  requireSeat(token) {
    const side = this.sideForToken(token);
    if (!side)
      throw new MatchError("UNAUTHORIZED_SEAT", "Seat token is invalid");
    return side;
  }

  // Pure domain entry point. Transport validation runs before this method.
  command(token, command, now = performance.now()) {
    this.settleClock(now);
    const side = this.requireSeat(token);
    const { commandId } = command;
    if (
      typeof commandId !== "string" ||
      !/^[a-zA-Z0-9_-]{1,80}$/.test(commandId)
    ) {
      throw new MatchError("INVALID_COMMAND", "A valid commandId is required");
    }
    const key = `${side}:${commandId}`;
    const fingerprint = JSON.stringify(command);
    const previous = this.commands.get(key);
    if (previous) {
      if (previous.fingerprint !== fingerprint) {
        throw new MatchError(
          "COMMAND_ID_REUSED",
          "Command ID was already used for a different request",
        );
      }
      return { ...previous.receipt, duplicate: true };
    }
    if (this.commands.size >= 4096) {
      throw new MatchError(
        "COMMAND_LIMIT",
        "Room command limit reached; create a new room",
      );
    }
    let receipt;
    try {
      if (command.round !== this.round)
        throw new MatchError(
          "STALE_ROUND",
          "This request belongs to an earlier round",
        );
      this.#act(side, command, now);
      receipt = { commandId, accepted: true };
    } catch (error) {
      if (!(error instanceof MatchError)) throw error;
      receipt = {
        commandId,
        accepted: false,
        code: error.code,
        message: error.message,
      };
    }
    this.commands.set(key, { fingerprint, receipt });
    return { ...receipt, duplicate: false };
  }

  #act(side, command, now) {
    if (command.type === "rematch") {
      if (this.status !== "complete")
        throw new MatchError(
          "GAME_NOT_COMPLETE",
          "Finish this game before a rematch",
        );
      this.rematchOffers.add(side);
      if (this.rematchOffers.size === 2) {
        this.chess.reset();
        this.round += 1;
        this.remaining = { w: this.baseMs, b: this.baseMs };
        this.status = "active";
        this.result = null;
        this.drawOffer = null;
        this.rematchOffers.clear();
        this.activeSince = now;
      }
      return;
    }
    if (this.status !== "active")
      throw new MatchError("GAME_NOT_ACTIVE", "The game is not active");
    switch (command.type) {
      case "move":
        if (command.ply !== this.chess.history().length)
          throw new MatchError(
            "STALE_POSITION",
            "The position has changed; sync before moving",
          );
        this.#move(side, command.move, now);
        break;
      case "resign":
        this.#finish("resignation", side === "w" ? "b" : "w");
        break;
      case "offer_draw":
        if (this.drawOffer)
          throw new MatchError(
            "DRAW_PENDING",
            "A draw offer is already pending",
          );
        this.drawOffer = { side, offerId: command.commandId };
        break;
      case "respond_draw":
        if (
          !this.drawOffer ||
          this.drawOffer.side === side ||
          this.drawOffer.offerId !== command.offerId
        ) {
          throw new MatchError(
            "NO_DRAW_OFFER",
            "No matching opponent draw offer",
          );
        }
        if (command.accept) this.#finish("agreement", null);
        this.drawOffer = null;
        break;
      default:
        throw new MatchError("UNKNOWN_TYPE", "Unsupported action");
    }
  }

  // Retained for existing rules tests and local domain callers.
  play(token, move, now = performance.now()) {
    this.settleClock(now);
    const side = this.requireSeat(token);
    if (this.status === "complete" && this.result?.reason === "timeout")
      return this.snapshot(now);
    if (this.status !== "active")
      throw new MatchError("GAME_NOT_ACTIVE", "The game is not active");
    this.#move(side, move, now);
    return this.snapshot(now);
  }

  #move(side, { from, to, promotion = "q" }, now) {
    if (side !== this.chess.turn())
      throw new MatchError("NOT_YOUR_TURN", "It is not your turn");
    let move;
    try {
      move = this.chess.move({ from, to, promotion });
    } catch {
      move = null;
    }
    if (!move)
      throw new MatchError(
        "ILLEGAL_MOVE",
        "Move is not legal in the authoritative position",
      );
    this.remaining[side] += this.incrementMs;
    this.activeSince = now;
    // Moving declines an opponent's offer. Your offer survives your own move.
    if (this.drawOffer?.side !== side) this.drawOffer = null;
    if (this.chess.isCheckmate()) this.#finish("checkmate", side);
    else if (this.chess.isStalemate()) this.#finish("stalemate", null);
    else if (this.chess.isInsufficientMaterial())
      this.#finish("insufficient_material", null);
    else if (this.chess.isThreefoldRepetition())
      this.#finish("repetition", null);
    else if (this.chess.isDraw()) this.#finish("fifty_move", null);
  }

  #finish(reason, winner) {
    this.status = "complete";
    this.result = { reason, winner };
    this.drawOffer = null;
    this.activeSince = null;
  }

  // Every emitted snapshot has a fresh sequence, including clock-only updates.
  snapshot(now = performance.now()) {
    this.settleClock(now);
    return {
      gameId: this.id,
      sequence: ++this.sequence,
      round: this.round,
      status: this.status,
      fen: this.chess.fen(),
      turn: this.chess.turn(),
      san: this.chess.history(),
      clocks: { ...this.remaining },
      result: this.result ? { ...this.result } : null,
      drawOffer: this.drawOffer ? { ...this.drawOffer } : null,
      rematchOffers: [...this.rematchOffers],
      players: {
        w: this.#publicPlayer(this.players.w),
        b: this.#publicPlayer(this.players.b),
      },
    };
  }

  #publicPlayer(player) {
    return player
      ? {
          name: player.name,
          avatarId: player.avatarId,
          points: player.points ?? 0,
        }
      : null;
  }

  settleClock(now = performance.now()) {
    if (this.activeSince === null) return;
    const active = this.chess.turn();
    this.remaining[active] = Math.max(
      0,
      this.remaining[active] - Math.max(0, now - this.activeSince),
    );
    this.activeSince = Math.max(now, this.activeSince);
    if (this.remaining[active] === 0)
      this.#finish("timeout", active === "w" ? "b" : "w");
  }
}
