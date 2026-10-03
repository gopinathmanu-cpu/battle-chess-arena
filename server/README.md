# Authoritative Match Server · 0.9.0 Beta 1

Node 22+ reference server for Battle Chess Arena protocol v4. Owns legal position,
turns, clocks, results, command receipts, draw offers and mutual rematches.
GPL-3.0-or-later; chess.js is BSD-2-Clause and ws is MIT.

```bash
npm ci
npm test
npm audit --omit=dev
npm start
```

Listens on `0.0.0.0:8080`; override with `PORT=8081 npm start`. `GET /health`
returns a small JSON readiness response. WebSocket clients exchange application
`ping`/`pong` heartbeats so idle lobby connections remain healthy.

Players register a case-insensitively unique 3–20 character Avatar ID and one
of 50 preset portraits or a validated custom avatar design before entering
matchmaking (legacy icon IDs remain accepted). A private player token permits
the same identity to reconnect from multiple game sessions. Players can search
exact IDs, list all their active games, and negotiate scheduled invitations with
alternating date/time and timed/untimed proposals. Profiles can change their
public ID and portrait without losing their private identity. Completed rounds award three points for a win,
one for a draw, and zero for a loss; the leaderboard and personal match ledger
explain every awarded point.
The online lobby also offers twenty clearly labelled, fictional computer
profiles spanning Beginner, Intermediate, and Advanced. Their moves are chosen
and committed on the server, so clocks, reconnects, results, and history use the
same authoritative path as human matches.
Tests bind an ephemeral loopback port and do not require a separately running server.

The optional `custom_avatars` capability allows updated clients to share layered
avatar designs in the existing `avatarId` field. Deploy the updated service and
app together; an APK build alone does not enable the server extension.

The optional `credits` capability enables the server-owned Arena Credits beta
wallet. New and legacy profiles receive 300 welcome credits; activation of a
server-backed round and accepted online Move suggestions deduct credits, while
meaningful completions plus a capped daily refill add bonus credits. The service exposes no client-callable purchase
or grant command. Real-money packs remain disabled until authenticated accounts,
per-user transactional storage and server-verified store receipts are available.
See [`docs/ARENA_CREDITS.md`](../docs/ARENA_CREDITS.md).

See [protocol v4](../docs/ONLINE_PROTOCOL.md) for field validation, replay rules,
clock sequencing, rematches, recovery and production requirements. The server
exports `createMatchServer` for tests; `src/index.js` is the command-line entry.

Without `FIRESTORE_PROJECT_ID`, this runs as a local in-memory reference
implementation and room state and credentials vanish on process restart. With a
configured Firestore state store, profiles, rooms, invitations, result awards and
credit ledgers are checkpointed atomically; startup fails rather than silently
resetting state when the checkpoint cannot be loaded. The service still has beta
capacity limits and is not ready for unrestricted public hosting without stronger
account authentication, cleanup, abuse controls, backpressure and multi-instance
room routing.
For the supported Firebase-project Cloud Run deployment, see
[`docs/FIREBASE_NETWORK_DEPLOYMENT.md`](../docs/FIREBASE_NETWORK_DEPLOYMENT.md).
