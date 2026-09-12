// SPDX-License-Identifier: GPL-3.0-or-later
import { WebSocketServer, WebSocket } from "ws";
import { createServer } from "node:http";
import { performance } from "node:perf_hooks";
import { Match, MatchError } from "./match.js";
import { isAction, validateMessage } from "./protocol.js";

export function createMatchServer({
  port = 8080,
  host = "0.0.0.0",
  tickMs = 1000,
  now = () => performance.now(),
} = {}) {
  const games = new Map();
  const peers = new Map();
  const matchmaking = new Map();
  const httpServer = createServer((request, response) => {
    if (request.method === "GET" && request.url === "/health") {
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({ status: "ok", protocolVersion: 2 }));
      return;
    }
    response.writeHead(404, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: "not_found" }));
  });
  const server = new WebSocketServer({
    server: httpServer,
    maxPayload: 16 * 1024,
    perMessageDeflate: false,
  });
  httpServer.listen(port, host);
  const send = (socket, type, payload = {}) => {
    if (socket.readyState === WebSocket.OPEN)
      socket.send(JSON.stringify({ type, ...payload }));
  };
  const broadcast = (gameId, state) => {
    for (const [socket, peer] of peers) {
      if (peer.gameId === gameId) send(socket, "game_state", { state });
    }
  };
  const tick = () => {
    for (const game of games.values()) {
      if (game.status === "active") broadcast(game.id, game.snapshot(now()));
    }
  };
  const timer = setInterval(tick, tickMs);
  timer.unref();
  server.on("close", () => clearInterval(timer));

  server.on("connection", (socket) => {
    const peer = { setupReceipts: new Map() };
    peers.set(socket, peer);
    socket.on("error", () => {}); // A transport failure must not crash other rooms.
    send(socket, "connected", { protocolVersion: 2 });
    socket.on("message", (raw, binary) => {
      let message;
      let game;
      try {
        games.get(peer.gameId)?.settleClock(now());
        if (binary)
          throw new MatchError("INVALID_MESSAGE", "Use JSON text frames");
        let parsed;
        try {
          parsed = JSON.parse(raw.toString());
        } catch {
          throw new MatchError(
            "INVALID_MESSAGE",
            "Expected a JSON protocol message",
          );
        }
        message = validateMessage(parsed);
        if (message.type === "ping") {
          send(socket, "pong");
          return;
        }
        if (
          message.type === "create_game" ||
          message.type === "join_game" ||
          message.type === "quick_match"
        ) {
          const fingerprint = JSON.stringify(message);
          const previous = peer.setupReceipts.get(message.commandId);
          if (previous) {
            if (previous.fingerprint !== fingerprint)
              throw new MatchError(
                "COMMAND_ID_REUSED",
                "Command ID was already used",
              );
            send(socket, previous.type, previous.payload);
            const current = games.get(peer.gameId);
            if (current)
              send(socket, "game_state", { state: current.snapshot(now()) });
            return;
          }
          if (peer.gameId)
            throw new MatchError(
              "ALREADY_SEATED",
              "Reconnect to a new lobby connection before joining another room",
            );
          if (message.type === "create_game") {
            if (games.size >= 1000)
              throw new MatchError(
                "ROOM_LIMIT",
                "Development server room limit reached",
              );
            game = new Match({
              baseMs: message.baseMs,
              incrementMs: message.incrementMs,
            });
            games.set(game.id, game);
            peer.gameId = game.id;
            peer.token = game.whiteToken;
          } else if (message.type === "join_game") {
            game = games.get(message.gameId);
            if (!game)
              throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
            peer.token = game.joinBlack(now());
            peer.gameId = game.id;
          } else {
            const baseMs = message.baseMs ?? 600_000;
            const incrementMs = message.incrementMs ?? 0;
            const queueKey = `${baseMs}:${incrementMs}`;
            const waitingId = matchmaking.get(queueKey);
            const waiting = games.get(waitingId);
            if (waiting?.status === "waiting") {
              game = waiting;
              matchmaking.delete(queueKey);
              peer.token = game.joinBlack(now());
              peer.gameId = game.id;
            } else {
              matchmaking.delete(queueKey);
              if (games.size >= 1000)
                throw new MatchError(
                  "ROOM_LIMIT",
                  "Development server room limit reached",
                );
              game = new Match({ baseMs, incrementMs });
              games.set(game.id, game);
              matchmaking.set(queueKey, game.id);
              peer.gameId = game.id;
              peer.token = game.whiteToken;
              peer.queueKey = queueKey;
            }
          }
          const type = message.type === "create_game"
            ? "game_created"
            : message.type === "join_game"
              ? "seat_joined"
              : game.status === "waiting"
                ? "matchmaking_waiting"
                : "match_found";
          const state = game.snapshot(now());
          const payload = {
            commandId: message.commandId,
            gameId: game.id,
            seat: game.sideForToken(peer.token),
            seatToken: peer.token,
            state,
          };
          peer.setupReceipts.set(message.commandId, {
            fingerprint,
            type,
            payload,
          });
          send(socket, type, payload);
          broadcast(game.id, state);
          return;
        }
        if (message.type === "cancel_matchmaking") {
          game = games.get(message.gameId);
          if (!game)
            throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
          if (peer.gameId !== game.id || game.sideForToken(peer.token) !== "w")
            throw new MatchError(
              "UNAUTHORIZED_SEAT",
              "Only the waiting player can cancel matchmaking",
            );
          if (game.status !== "waiting")
            throw new MatchError("MATCH_FOUND", "An opponent has already joined");
          if (peer.queueKey && matchmaking.get(peer.queueKey) === game.id)
            matchmaking.delete(peer.queueKey);
          games.delete(game.id);
          peer.gameId = null;
          peer.token = null;
          peer.queueKey = null;
          send(socket, "matchmaking_cancelled", {
            commandId: message.commandId,
            gameId: game.id,
          });
          return;
        }
        game = games.get(message.gameId);
        if (!game)
          throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
        game.settleClock(now());
        if (message.type === "resume_game") {
          const side = game.requireSeat(message.seatToken);
          if (
            peer.gameId &&
            (peer.gameId !== game.id || peer.token !== message.seatToken)
          ) {
            throw new MatchError(
              "ALREADY_SEATED",
              "This connection already holds a different seat",
            );
          }
          peer.gameId = game.id;
          peer.token = message.seatToken;
          send(socket, "seat_resumed", {
            gameId: game.id,
            seat: side,
            state: game.snapshot(now()),
          });
          return;
        }
        if (peer.gameId !== game.id)
          throw new MatchError(
            "UNAUTHORIZED_SEAT",
            "Join or resume the game first",
          );
        game.requireSeat(peer.token);
        if (message.type === "sync") {
          send(socket, "game_state", {
            state: game.snapshot(now()),
            synced: true,
          });
        } else if (isAction(message.type)) {
          const receipt = game.command(peer.token, message, now());
          broadcast(game.id, game.snapshot(now()));
          send(socket, "command_result", receipt);
        }
      } catch (error) {
        const known = error instanceof MatchError;
        send(socket, "error", {
          ...(message?.commandId ? { commandId: message.commandId } : {}),
          code: known ? error.code : "SERVER_ERROR",
          message: known
            ? error.message
            : "The server could not process the request",
        });
        // A rejected request can still have settled a timeout.
        const seatedGame = games.get(peer.gameId);
        if (seatedGame) broadcast(seatedGame.id, seatedGame.snapshot(now()));
      }
    });
    socket.on("close", () => {
      if (peer.queueKey && matchmaking.get(peer.queueKey) === peer.gameId) {
        const waiting = games.get(peer.gameId);
        if (waiting?.status === "waiting") {
          matchmaking.delete(peer.queueKey);
          games.delete(peer.gameId);
        }
      }
      peers.delete(socket);
    });
  });
  return {
    server,
    httpServer,
    games,
    matchmaking,
    tick,
    async close() {
      clearInterval(timer);
      for (const socket of server.clients) socket.terminate();
      await new Promise((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
      await new Promise((resolve, reject) =>
        httpServer.close((error) => (error ? reject(error) : resolve())),
      );
    },
  };
}
