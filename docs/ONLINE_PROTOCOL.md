# Online Game Protocol v4

## Clock extensions (capability-gated)

`invite_clocks` enables `incrementMs` and `clockMode` on `send_invite`,
`propose_invite_time`, and `create_shared_invite`. Only a durable-storage-enabled
server advertises `daily_games`. Clients must not send these new fields to an
older server or silently substitute a different clock.

- Rapid: `clockMode: "live", baseMs: 900000, incrementMs: 10000`.
- Classical: `clockMode: "live", baseMs: 1800000` (or `3600000`), `incrementMs: 0`.
- Daily: `clockMode: "daily", baseMs: 86400000, incrementMs: 0`, timed enabled.
  Daily is valid only for friend invitations, not quick-match or bot queues.

Invitation payloads carry the agreed clock rules. State snapshots additionally
contain `clockMode`, `baseMs`, `incrementMs`, and `turnDeadlineEpochMs` (null
outside an active Daily turn). Both clients receive the same absolute deadline;
the existing remaining-clock fields remain available for local interpolation.
Each legal Daily move resets the per-turn allowance. Invalid/replayed commands,
reconnect, and server restart do not extend it. Moves at expiry lose on time.
Old invitations without these fields retain live/no-increment semantics.

See [clock rollout and durability](GAME_CLOCKS.md) for storage configuration,
private checkpoints, write-before-ack semantics and operational limits.

## Transport

Human portrait avatars and authoritative computer opponents require v4 on both
ends. Earlier clients are incompatible.
The development endpoint is `ws://localhost:8080`; production must use `wss://`.
Every message is a JSON text frame. The server sends `connected` with
`protocolVersion: 4` after the WebSocket handshake.

### Optional custom avatar extension

Updated servers advertise `custom_avatars` in `connected.capabilities`. This
does not change protocol v4. `register_player` and `update_player` accept a
custom design in the existing `avatarId` field: `custom-v1-` followed by exactly
12 lowercase base-36 digits. The positional fields and inclusive ranges are:

| Field | Range |
| --- | --- |
| Presentation | 0–1 |
| Age | 0–3 |
| Face shape | 0–3 |
| Skin tone | 0–7 |
| Hairstyle | 0–11 |
| Hair colour | 0–9 |
| Moustache | 0–4 |
| Beard | 0–5 |
| Eyewear | 0–5 |
| Outfit | 0–5 |
| Outfit colour | 0–7 |
| Background | 0–7 |

The default is `custom-v1-020321000000`. Unknown versions, extra characters,
uppercase digits and out-of-range values are rejected. Preset and legacy IDs
remain valid; human profiles cannot impersonate reserved bot portraits. Custom
IDs flow unchanged through search, invitations, game snapshots, rankings and
history. Artwork is rendered locally, with no external image URL or photo upload.
The version freezes the meaning/order of parts as well as their bounds.

On older services, the new app sends `avatar-01` on the wire but retains the
chosen custom ID in its local saved profile after a successful acknowledgement.
A visible lobby notice explains that other players see a preset. Reconnecting
to an updated service automatically sends the retained custom ID. Old apps do
not understand this format and display their existing fallback portrait; both
players need the updated app to see custom artwork.

### Optional colour toss extension

Updated servers advertise `capabilities: ["color_toss"]` in `connected`.
Only after receiving this capability may clients send `tossForColors: true`
on `create_game`, `quick_match`, `start_computer_game`, or `send_invite`.
Omitting the flag retains the creator/sender-White behaviour. Older v4
servers remain usable without the optional extension; deploy the updated
server before enabling this feature in a release.

The server makes one random assignment when creating the match. Seat tokens
are issued for the resulting colours, including a Black creator and White
joiner. Invitation acceptance never assumes the sender is White. Snapshots
and invitations contain `tossForColors`; the normal `seat` and `players`
fields describe the outcome. Quick matches pair the same toss preference.
Setup retries and reconnects keep the assignment; rematches retain seats.
Start a new match for a new toss. Built-in opponents can play either colour
without changing their fixed levels.

WhatsApp shares an HTTPS invitation link with Avatar-name search/invite
fallback instructions. Sharing creates an invitation, not a room. Existing
custom-scheme game links still parse for backwards compatibility.

### Revocable WhatsApp invitations

Servers advertise `shared_invites` in `connected.capabilities`. Supported clients
use `create_shared_invite` (`commandId`, optional `baseMs`, `tossForColors`).
The `shared_invite_created` response contains a public invitation with `inviteId`,
`avatarName`, `status`, `createdAt`, and `expiresAt`. No seat or identity credentials
are put in shared URLs. An older server gets the Avatar-name-only fallback.

The HTTPS path `/invite/ID` serves a read-only fallback page;
WhatsApp link previews never claim a seat. Android HTTPS App Links and the page's
`battlechessarena://invite?invite=ID` button open the app. The authenticated app
sends `open_shared_invite` (`commandId`, `inviteId`), which atomically admits one
opponent and returns `seat_joined`. Reopening by a participant returns the same
seat; another player cannot take it. The creator receives `shared_invite_updated`
and can open the started game from Active games.

`list_shared_invites` lists the owner's links. `delete_shared_invite` revokes a
link for everyone, publishes its deleted status, and retains a tombstone. Only
the creator may revoke it. Deleting a used link does not delete the started game.

Links expire **24 hours after creation**. Resharing/retrying does not extend that
deadline. HTTP returns 410 with a deleted/expired message and no app-launch
button; in-app opens return `INVITE_DELETED` or `INVITE_EXPIRED`. Unknown links
return HTTP 404 / `INVITE_UNAVAILABLE`. All invitation pages use `no-store`.
These reference stores are process-local: server restarts invalidate outstanding
links, rather than silently recreating them. Durable storage remains separate.

Clients send `{"type":"ping"}` while connected. The server replies with
`{"type":"pong"}`. This heartbeat applies in the lobby as well as during a game.

## Player identity

Before creating, joining, resuming, or listing games, send:

```json
{"type":"register_player","commandId":"profile-1","name":"Nova Knight","avatarId":"avatar-17","level":"intermediate"}
```

Avatar IDs contain 3–20 printable ASCII keyboard characters (including @, # and other punctuation) and
are unique after trimming, whitespace folding, and case normalization. The
server returns `player_registered` with a private `playerToken`. Save this token
and include it in later registrations to reclaim the same name. Never display or
share player or seat tokens.

Available portrait IDs are `avatar-01` through `avatar-50`. Legacy icon IDs are
accepted only so existing saved profiles and history continue to render. Every
game state includes public `players.w` and `players.b`
objects containing `name`, `avatarId`, `level`, current `points`, and a
`computer` boolean. Built-in opponents always set `computer: true` so clients
never present them as people.

An authenticated player can send `update_player` with a new unique `name` and
`avatarId`. The server preserves the private identity, scores, invitations, and
game seats and returns `player_updated`.

The server rejects a second non-completed manual or quick game between the same
two identities. A scheduled invitation may still be created for that opponent
and becomes its own game after both players agree to the proposed time.

## Leaderboard

Send `{"type":"leaderboard"}` after profile registration. The server returns up
to fifty entries ordered by points, wins, and Avatar Name. A completed round
awards 3 points to its winner or 1 point to each player for a draw, and records
the corresponding win, draw, or loss exactly once.

`points_history` returns the authenticated player's completed matches with the
opponent identity, result, completion timestamp, and awarded points. Completed
history cannot be deleted. `list_games`
returns all non-completed server games for that player with only their own private
seat credential. `find_player` performs a case-insensitive exact Avatar ID lookup
and returns the public avatar icon and current online status.

## Saved player circles, presence, and invitations

Family, Friends and Professionals classifications are private device data and
are never uploaded as a list. Legacy favourites are treated as Friends. To
refresh saved players' status, an authenticated client sends `presence` with up
to fifty Avatar Names. The response reports whether each identity currently has
an authenticated WebSocket connection.

`send_invite` contains an opponent Avatar ID, an optional `scheduledAt`, a
`timed` boolean, and `baseMs` for timed play. `propose_invite_time` can revise
the date, time, and timer format together. An untimed game retains clock values
for protocol compatibility but never decrements them. The optional `scheduledAt` is a
Unix timestamp in milliseconds. The server rejects self-invites, unknown names,
duplicate pending invitations, and past schedules. An immediate invitation is
rejected when the pair already has an open game, while a future invitation is
allowed. `invite_updated` is delivered
to every live connection belonging to either player. `list_invites` returns the
current user's sent and received invitations with `pending`, `accepted`,
`declined`, `deleted`, `expired`, or `blocked` status. Invitations carry an
`expiresAt` timestamp: 24 hours after creation, or 15 minutes after the scheduled
start, whichever is later. Counter-proposals recalculate the deadline. Expiry is
enforced both on requests and on server ticks, and never terminates a started game.

Deleting an unanswered or accepted-but-not-started invitation cancels it for
both players. Deleting an invitation to an already-started game hides that
invitation for the caller only and preserves the match and completed history.

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
| `start_computer_game` | `commandId`, `opponentId`; optional `baseMs`, `incrementMs` | Start an authoritative game as White against one of the 20 built-in computer profiles. Replaces the caller's waiting quick match, if any. |
| `cancel_matchmaking` | `commandId`, `gameId` | Delete the caller's still-waiting quick-match room and release its seat. |
| `join_game` | `commandId`, `gameId` | Claim the vacant Black seat and start White's clock. |
| `resume_game` | `gameId`, `seatToken` | Authenticate this connection as the existing seat. |
| `sync` | `gameId` | Authenticated full-state request; reply has `synced: true`. |
| `move` | `commandId`, `gameId`, `round`, `ply`, `move` | Request a legal move at this round and history length. |
| `resign` | `commandId`, `gameId`, `round` | Concede the active game. |
| `offer_draw` | `commandId`, `gameId`, `round` | Offer a draw; only one offer may be outstanding. |
| `respond_draw` | `commandId`, `gameId`, `round`, `offerId`, `accept` | Opponent accepts/declines the identified offer; `accept` is a boolean. |
| `rematch` | `commandId`, `gameId`, `round` | Consent to another round after completion. |
| `use_lifeline` | `commandId`, `gameId`, `round` | Request a move suggestion on your turn. With the `credits` capability, each accepted nonduplicate request costs one credit. The legacy command name is retained for v4 compatibility. |

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
`computer_match_found` confirms a built-in opponent game and carries the same
private seat fields and authoritative state. Computer moves, clocks, results,
draw declines, and rematch consent are all processed by the server.

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

## Arena Credits extension

Servers advertising the optional `credits` capability own the Arena Credit
balance and policy. `player_registered`, `player_updated`, setup replies, and
action receipts may include `credits`, `bonusCredits`, `purchasedCredits`, and
`creditPolicy`. Private
`credit_balance` frames include the authoritative `account`, its recent ledger
entries, and the same policy. Clients display these fields but never submit a
balance, grant, charge, refund, or purchase result.

All games and rematches are free. The round-cost fields remain in the protocol
for compatibility and are zero for live human, Daily human and server-computer
rounds. Round creation and activation append no spending transactions and do not
require a credit balance. Legacy `credit_required` scheduled invitations can
activate under the free-game policy.

Only an accepted, nonduplicate `use_lifeline` Suggest Move request costs one
credit, using its command-derived idempotency key. Invalid, duplicate, stale or
wrong-turn requests are free. An unfunded suggestion is rejected with
`INSUFFICIENT_CREDITS` before its counter changes. Suggestions are unavailable
against real players. On-device suggestions also cost one credit only after a
valid result is produced. Auto-play, retries, threat scans and normal moves are
free.

New and migrated beta profiles receive one idempotent 300-credit welcome grant.
On later UTC days, registration can receive a Top-up of up to three bonus credits without
exceeding the 300-credit welcome ceiling. A completed round with at least two
legal half-moves earns one credit, capped at five per player per UTC day. All
mutations are server-generated and keyed by profile, game and round. See
[Arena Credits](ARENA_CREDITS.md) for the product policy and the production
billing boundary.

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
- `lifelines.w`, `lifelines.b`: legacy compatibility fields, reset to three each round; no longer decremented or used to limit suggestions
- `lifelineRequests.w`, `lifelineRequests.b`: accepted request counters used to trigger or restore a suggestion

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
6. Consecutive capture presentations are queued with at least two seconds of
   unobstructed board time between them.

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
