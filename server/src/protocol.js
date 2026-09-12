// SPDX-License-Identifier: GPL-3.0-or-later
import { MatchError } from "./match.js";

const actions = ["move", "resign", "offer_draw", "respond_draw", "rematch"];
export const isAction = (type) => actions.includes(type);
const fields = {
  ping: [],
  create_game: ["commandId", "baseMs", "incrementMs"],
  quick_match: ["commandId", "baseMs", "incrementMs"],
  cancel_matchmaking: ["commandId", "gameId"],
  join_game: ["commandId", "gameId"],
  resume_game: ["gameId", "seatToken"],
  sync: ["gameId"],
  move: ["commandId", "gameId", "round", "ply", "move"],
  resign: ["commandId", "gameId", "round"],
  offer_draw: ["commandId", "gameId", "round"],
  respond_draw: ["commandId", "gameId", "round", "offerId", "accept"],
  rematch: ["commandId", "gameId", "round"],
};
const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const identifier = (value) =>
  typeof value === "string" && /^[a-zA-Z0-9_-]{1,80}$/.test(value);
const integer = (value, min = 0) => Number.isSafeInteger(value) && value >= min;
function require(valid) {
  if (!valid)
    throw new MatchError(
      "INVALID_MESSAGE",
      "Invalid or unexpected protocol fields",
    );
}

export function validateMessage(message) {
  require(
    object(message) &&
      typeof message.type === "string" &&
      Object.hasOwn(fields, message.type),
  );
  const allowed = fields[message.type];
  require(
    Object.keys(message).every(
      (key) => key === "type" || allowed.includes(key),
    ),
  );
  if (allowed.includes("commandId")) require(identifier(message.commandId));
  if (allowed.includes("gameId")) require(identifier(message.gameId));
  if (allowed.includes("round")) require(integer(message.round, 1));
  if (message.type === "create_game" || message.type === "quick_match") {
    require(
      message.baseMs === undefined ||
        (integer(message.baseMs, 10_000) && message.baseMs <= 10_800_000),
    );
    require(
      message.incrementMs === undefined ||
        (integer(message.incrementMs) && message.incrementMs <= 60_000),
    );
  }
  if (message.type === "resume_game") require(identifier(message.seatToken));
  if (message.type === "respond_draw")
    require(identifier(message.offerId) && typeof message.accept === "boolean");
  if (message.type === "move") {
    require(integer(message.ply));
    const move = message.move;
    require(
      object(move) &&
        Object.keys(move).every((key) =>
          ["from", "to", "promotion"].includes(key),
        ),
    );
    require(typeof move.from === "string" && /^[a-h][1-8]$/.test(move.from));
    require(typeof move.to === "string" && /^[a-h][1-8]$/.test(move.to));
    require(
      move.promotion === undefined ||
        ["q", "r", "b", "n"].includes(move.promotion),
    );
  }
  // Canonical ordering makes receipt matching independent of JSON key order.
  return Object.fromEntries(
    ["type", ...allowed]
      .filter((key) => message[key] !== undefined)
      .map((key) => [
        key,
        key === "move"
          ? {
              from: message.move.from,
              to: message.move.to,
              promotion: message.move.promotion ?? "q",
            }
          : message[key],
      ]),
  );
}
