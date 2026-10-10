// SPDX-License-Identifier: GPL-3.0-or-later
import { MatchError } from "./match.js";
import { avatarNameAllowed } from './content-policy.js';

const actions = [
  "move",
  "resign",
  "offer_draw",
  "respond_draw",
  "rematch",
  "use_lifeline",
];
export const isAction = (type) => actions.includes(type);
const fields = {
  ping: [],
  set_push_device: ['deviceId', 'token', 'enabled', 'active'],
  register_player: ["commandId", "name", "avatarId", "level", "playerToken"],
  update_player: ["commandId", "name", "avatarId", "level"],
  leaderboard: [],
  points_history: [],
  find_player: ["query"],
  list_available_players: ['requestId', 'after'],
  list_games: [],
  presence: ["names"],
  send_invite: ["commandId", "opponentName", "scheduledAt", "timed", "baseMs", "tossForColors"],
  list_invites: [],
  create_shared_invite: ['commandId', 'baseMs', 'tossForColors'],
  list_shared_invites: [],
  delete_shared_invite: ['commandId', 'inviteId'],
  open_shared_invite: ['commandId', 'inviteId'],
  delete_invite: ["commandId", "inviteId"],
  respond_invite: ["commandId", "inviteId", "accept"],
  propose_invite_time: [
    "commandId",
    "inviteId",
    "scheduledAt",
    "timed",
    "baseMs",
  ],
  create_game: ["commandId", "baseMs", "incrementMs", "tossForColors"],
  quick_match: ["commandId", "baseMs", "incrementMs", "tossForColors"],
  start_computer_game: [
    "commandId",
    "opponentId",
    "tossForColors",
    "baseMs",
    "incrementMs",
  ],
  cancel_matchmaking: ["commandId", "gameId"],
  join_game: ["commandId", "gameId"],
  resume_game: ["gameId", "seatToken"],
  sync: ["gameId"],
  move: ["commandId", "gameId", "round", "ply", "move"],
  resign: ["commandId", "gameId", "round"],
  offer_draw: ["commandId", "gameId", "round"],
  respond_draw: ["commandId", "gameId", "round", "offerId", "accept"],
  rematch: ["commandId", "gameId", "round"],
  use_lifeline: ["commandId", "gameId", "round"],
};
const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const identifier = (value) =>
  typeof value === "string" && /^[a-zA-Z0-9_-]{1,80}$/.test(value);
const legacyAvatarIds = new Set([
  "crown",
  "knight",
  "mage",
  "dragon",
  "robot",
  "ranger",
  "sun",
  "moon",
]);
// Must match the immutable CustomAvatarDesign v1 wire order in the app:
// presentation, age, face, skin, hair style/color, moustache, beard, eyewear,
// outfit, outfit color, background. Portrait IDs contain no paths or user text.
const customAvatarMaxima = [1, 3, 3, 7, 11, 9, 4, 5, 5, 5, 7, 7];
const customAvatarId = (value) =>
  value.length === 22 &&
  /^custom-v1-[0-9a-z]{12}$/.test(value) &&
  [...value.slice(10)].every((digit, index) =>
    Number.parseInt(digit, 36) <= customAvatarMaxima[index]);
const avatarId = (value) =>
  typeof value === "string" &&
  (legacyAvatarIds.has(value) || /^avatar-(0[1-9]|[1-4][0-9]|50)$/.test(value) || customAvatarId(value));
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
  if (message.type === 'set_push_device') {
    require(identifier(message.deviceId) && typeof message.token === 'string' &&
      /^[A-Za-z0-9_:\-]{20,4096}$/.test(message.token) &&
      typeof message.enabled === 'boolean' && typeof message.active === 'boolean');
  }
  const allowed = fields[message.type];
  const friendClock = ['send_invite', 'propose_invite_time', 'create_shared_invite'].includes(message.type);
  const clockFields = friendClock ? ['clockMode', 'incrementMs'] : [];
  require(
    Object.keys(message).every(
      (key) => key === "type" || allowed.includes(key) || clockFields.includes(key),
    ),
  );
  if (allowed.includes("commandId")) require(identifier(message.commandId));
  if (friendClock) {
    require(message.clockMode === undefined || ['live', 'daily'].includes(message.clockMode));
    require(message.incrementMs === undefined ||
      (integer(message.incrementMs) && message.incrementMs <= 60000));
    if (message.clockMode === 'daily') {
      require(message.baseMs === 86400000 && message.incrementMs === 0 && message.timed !== false);
    }
  }
  if (allowed.includes('tossForColors')) require(message.tossForColors === undefined || typeof message.tossForColors === 'boolean');
  if (allowed.includes("gameId")) require(identifier(message.gameId));
  if (allowed.includes("round")) require(integer(message.round, 1));
  if (
    message.type === 'create_shared_invite' ||
    message.type === "create_game" ||
    message.type === "quick_match" ||
    message.type === "start_computer_game"
  ) {
    require(
      message.baseMs === undefined ||
        (integer(message.baseMs, 10_000) && message.baseMs <= (friendClock && message.clockMode === 'daily' ? 86400000 : 10_800_000)),
    );
    require(
      message.incrementMs === undefined ||
        (integer(message.incrementMs) && message.incrementMs <= 60_000),
    );
  }
  if (message.type === "start_computer_game")
    require(identifier(message.opponentId));
  if (message.type === "register_player" || message.type === "update_player") {
    require(
      typeof message.name === "string" &&
        message.name === message.name.trim() &&
        /^[\x20-\x7E]{3,20}(?![\s\S])/.test(message.name) &&
        avatarNameAllowed(message.name),
    );
    require(avatarId(message.avatarId));
    require(
      message.level === undefined ||
        ["beginner", "intermediate", "advanced"].includes(message.level),
    );
    if (message.type === "register_player") {
      require(
        message.playerToken === undefined || identifier(message.playerToken),
      );
    }
  }
  if (message.type === "presence") {
    require(
      Array.isArray(message.names) &&
        message.names.length <= 50 &&
        message.names.every(
          (name) =>
            typeof name === "string" &&
            /^[\x20-\x7E]{3,20}(?![\s\S])/.test(name),
        ),
    );
  }
  if (message.type === "find_player") {
    require(
      typeof message.query === "string" &&
        message.query === message.query.trim() &&
        /^[\x20-\x7E]{3,20}(?![\s\S])/.test(message.query),
    );
  }
  if (message.type === 'list_available_players') {
    require(typeof message.requestId === 'string' && message.requestId.length > 0 && message.requestId.length <= 64);
    require(message.after === undefined || (typeof message.after === 'string' && message.after.length <= 64));
  }
  if (message.type === "send_invite") {
    require(
      typeof message.opponentName === "string" &&
        /^[\x20-\x7E]{3,20}(?![\s\S])/.test(message.opponentName),
    );
    require(message.scheduledAt === undefined || integer(message.scheduledAt));
    require(message.timed === undefined || typeof message.timed === "boolean");
    require(
      message.baseMs === undefined ||
        (integer(message.baseMs, 10_000) && message.baseMs <= (message.clockMode === 'daily' ? 86400000 : 10_800_000)),
    );
  }
  if (message.type === "respond_invite") {
    require(identifier(message.inviteId));
    require(typeof message.accept === "boolean");
  }
  if (message.type === "delete_invite") require(identifier(message.inviteId));
  if (['delete_shared_invite', 'open_shared_invite'].includes(message.type)) require(identifier(message.inviteId));
  if (message.type === "propose_invite_time") {
    require(identifier(message.inviteId));
    require(integer(message.scheduledAt));
    require(message.timed === undefined || typeof message.timed === "boolean");
    require(
      message.baseMs === undefined ||
        (integer(message.baseMs, 10_000) && message.baseMs <= (message.clockMode === 'daily' ? 86400000 : 10_800_000)),
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
    ["type", ...allowed, ...clockFields]
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
