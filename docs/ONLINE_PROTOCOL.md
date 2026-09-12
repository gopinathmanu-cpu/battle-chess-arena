# Online Game Protocol v2

Milestone 4 requires v2 on both ends. v1 clients are incompatible.
The development endpoint is `ws://localhost:8080`; production must use `wss://`.
Every message is a JSON text frame. The server sends `connected` with
`protocolVersion: 2` after the WebSocket handshake.

Clients send `{"type":"ping"}` while connected. The server replies with
`{"type":"pong"}`. This heartbeat applies in the lobby as well as during a game.

## Player identity

Before creating, joining, resuming, or listing games, send:

```json
{"type":"register_player","commandId":"profile-1","name":"Nova Knight","avatarId":"mage"}
```

Avatar IDs contain 3–20 ASCII letters, numbers, spaces, underscores, or hyphens and
are unique after trimming, whitespace folding, and case normalization. The
server returns `player_registered` with a private `playerToken`. Save this token
and include it in later registrations to reclaim the same name. Never display or
share player or seat tokens.

Available avatar IDs are `crown`, `knight`, `mage`, `dragon`, `robot`, `ranger`,
`sun`, and `moon`. Every game state includes public `players.w` and `players.b`
objects containing only `name`, `avatarId`, and current `points`.

The server rejects a second non-completed manual or quick game between the same
two identities. A scheduled invitation may still be created for that opponent
and becomes its own game after both players agree to the proposed time.

## Leaderboard

Send `{"type":"leaderboard"}` after profile registration. The server returns up
to fifty entries ordered by points, wins, and Avatar Name. A completed round
awards 3 points to its winner or 1 point to each player for a draw, and records
the corresponding win, draw, or loss exactly once.

`points_history` returns the authenticated player's completed matches with the
opponent identity, result, completion timestamp, and awarded points. `list_games`
returns all non-completed server games for that player with only their own private
seat credential. `find_player` performs a case-insensitive exact Avatar ID lookup
and returns the public avatar icon and current online status.

## Favourites, presence, and invitations

Favourites are private device data and are never uploaded as a list. To refresh
their status, an authenticated client sends `presence` with up to fifty Avatar
Names. The response reports whether each identity currently has an authenticated
WebSocket connection.

`send_invite` contains an opponent Avatar ID and an optional `scheduledAt`
Unix timestamp in milliseconds. The server rejects self-invites, unknown names,
duplicate pending invitations, and past schedules. An immediate invitation is
rejected when the pair already has an open game, while a future invitation is
allowed. `invite_updated` is delivered
to every live connection belonging to either player. `list_invites` returns the
current user's sent and received invitations with `pending`, `accepted`,
`declined`, or `blocked` status.

The invitation payload identifies `awaitingResponseFromName`. That player can
send `respond_invite` to accept or decline, or `propose_invite_time` with a new
future timestamp. A proposal transfers the response turn to the other player,
who can accept, decline, or counter again. Accepting an immediate invitation
creates the game at once. Accepting a scheduled invitation creates it when its
scheduled time arrives. Each player's invitation payload then contains only that
player's seat and private seat token. Clients save this as a normal history entry
and can open it from the lobby. Reminder selections are stored on the device and
shown while the app is running; background operating-system notifications are
not part of this version.

## Commands

| Type | Fields besides `type` | Meaning |
| --- | --- | --- |
| `create_game` | `commandId`; optional `baseMs`, `incrementMs` | Create room, claim White; defaults 600000 ms, zero increment. |
| `quick_match` | `commandId`; optional `baseMs`, `incrementMs` | Join a waiting quick match with the same clock, or reserve a new White seat. |
| `cancel_matchmaking` | `commandId`, `gameId` | Delete the caller's still-waiting quick-match room and release its seat. |
| `join_game` | `commandId`, `gameId` | Claim the vacant Black seat and start White's clock. |
| `resume_game` | `gameId`, `seatToken` | Authenticate this connection as the existing seat. |
| `sync` | `gameId` | Authenticated full-state request; reply has `synced: true`. |
| `move` | `commandId`, `gameId`, `round`, `ply`, `move` | Request a legal move at this round and history length. |
| `resign` | `commandId`, `gameId`, `round` | Concede the active game. |
| `offer_draw` | `commandId`, `gameId`, `round` | Offer a draw; only one offer may be outstanding. |
| `respond_draw` | `commandId`, `gameId`, `round`, `offerId`, `accept` | Opponent accepts/declines the identified offer; `accept` is a boolean. |
| `rematch` | `commandId`, `gameId`, `round` | Consent to another round after completion. |

Example move:

```json
{"type":"move","commandId":"client_a_1","gameId":"room-id","round":1,"ply":0,"move":{"from":"e2","to":"e4","promotion":"q"}}
```

`move.from`/`to` are squares `a1`–`h8`. Promotion is `q`, `r`, `b`, or `n`
(default `q`); castling uses king destinations `g1`, `c1`, `g8`, or `c8`.
IDs/tokens use 1–80 ASCII letters, digits, underscores or hyphens.
`round` is a positive safe integer; `ply` is a nonnegative safe integer.
`baseMs` is an integer from 10000 to 10800000; increment 0 to 60000.
Unknown fields/types, malformed JSON, arrays, binary frames, invalid field types,
and invalid squares are rejected. Payload limit is 16 KiB; oversized messages
close the socket with code 1009. Compression is disabled.

Clients never supply FEN, clock values, colour, SAN, or results as game authority.
The connection must have claimed/resumed a seat in the addressed game before
sync or actions. A token from one game cannot authenticate another game.

## Replies and replay protection

`game_created` / `seat_joined` return `gameId`, `seat`, private `seatToken`,
`commandId`, and `state`. `seat_resumed` returns `gameId`, `seat`, and `state`.
Only the seat's own socket receives its token. It is absent from broadcasts,
logs, copy actions, and status labels.

Quick matchmaking returns `matchmaking_waiting` when the caller reserves the
first seat, or `match_found` when it immediately claims a matching second seat.
Both contain the same private seat fields and authoritative state as room setup.
The waiting player receives an active `game_state` when paired.
`matchmaking_cancelled` confirms removal of a still-waiting search.

An action receives a `command_result`:

```json
{"type":"command_result","commandId":"client_a_1","accepted":true,"duplicate":false}
```

Rejected receipts also include `code` and `message`. Transport/validation errors
use `error` with `code`, `message`, and `commandId` when available. Errors may
still be followed by a state: settling the clock can finish the game even when
the submitted command is rejected.

For actions, receipts are retained per seat and command ID for the room's entire
in-memory lifetime, across reconnects and rematches. Identical retransmissions
return the original outcome with `duplicate: true`, plus a fresh state, without
repeating the action. A changed request with the same ID fails with
`COMMAND_ID_REUSED`. Rejected outcomes are retained too. The room accepts at most
4096 distinct action IDs, then rejects new commands instead of evicting receipts
and permitting old replays. Create a new room at that development limit.

The server normalizes message key order before receipt comparison. Round and ply
checks reject delayed new commands targeting old positions. Responses to obsolete
draw offers are rejected by offer ID. Create/join retries are deduplicated on the
same connection. A lost create/join response before the client receives a token
cannot be recovered on a new connection: create or join again. The mobile client
does not automatically retransmit unauthenticated setup requests.

## Authoritative state

Every emitted snapshot has a strictly increasing `sequence`, including sync,
clock-only updates, and rejected/duplicate commands. A broadcast shares one
snapshot and sequence across all connected room members. Sequence does not reset
on rematch. Gaps are normal: a snapshot may be sent to only one client.

State fields:

- `gameId`, `sequence`, `round`
- `status`: `waiting`, `active`, `complete`
- legal `fen`, `turn` (`w`/`b`), full `san` history
- `clocks.w`, `clocks.b`: nonnegative remaining milliseconds
- `result`: null, or `{reason, winner}`; winner is `w`, `b`, or null
- `drawOffer`: null, or `{side, offerId}`
- `rematchOffers`: array of consenting sides

Reasons: `checkmate`, `timeout`, `resignation`, `agreement`, `stalemate`,
`insufficient_material`, `repetition`, `fifty_move`.
The reference server automatically adjudicates threefold repetition and the
fifty-move rule; it does not implement a separate tournament draw-claim workflow.
Moving declines an opponent's outstanding offer. An offer survives the offering
player's own move. Both rematch consents reset the position/history/clocks,
increment `round`, and start White's clock. Room ID, tokens, and colours stay the
same. Active-game actions are rejected after completion; rematch is the exception.

## Clocks, recovery, and capture presentation

The server uses a monotonic clock, settles it before processing commands, applies
increments only on legal moves, and broadcasts active-room snapshots every second.
Timeout is delivered without either player sending a request. Disconnects and
capture animations do not stop the clock.

1. Client highlights locally legal candidates for its own seat and turn.
2. It sends one pending command, leaving its canonical board unchanged.
3. It applies a server state only if its room matches and its sequence is newer.
   Duplicate/older states do not rewind the board or reset the clock baseline.
4. For a single new move, it verifies the SAN transition against the old and new
   normalized FEN positions. Only a verified capture starts the optional renderer.
5. Capture presentation is skippable, supports fast/fade-only modes, and never
   changes the server clock. Reconnect/sync gaps do not replay old battles.

Display clocks interpolate from each accepted snapshot using a local monotonic
stopwatch. Reaching zero locally does not declare a winner; only a server result
can finish the game. Latency compensation is not implemented.

On transport failure the client disables actions and retries every two seconds.
It resumes with the in-memory game ID/token, explicitly requests full sync, then
retries its exact pending command ID. A five-second heartbeat requests sync;
missing responses for three heartbeat intervals triggers reconnect. App resume
also requests synchronization. Invalid resume credentials or a missing room stop
automatic retries and show the server error.

Tokens survive temporary network loss while the lobby remains mounted. Returning
home, terminating the app, or restarting the server loses recovery state. Durable
secure credential storage is outside this milestone.

## Production boundary

This remains a single-process, in-memory development server (1000-room cap).
Before public hosting: authenticated short-lived seat credentials, TLS, persistent
state and command receipts committed atomically, room ownership/routing across
workers, scheduled clock recovery, expiration/cleanup, request/connection rate
limits, backpressure, origin policy, metrics and credential-safe logging are
required. Room IDs alone do not authenticate actions. No accounts, matchmaking,
ratings, tournaments, or production deployment were added in Milestone 4.
