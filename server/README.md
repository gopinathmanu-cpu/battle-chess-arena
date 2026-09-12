# Authoritative Match Server · 0.5.0

Node 22+ reference server for Battle Chess Arena protocol v2. Owns legal position,
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

Players register a case-insensitively unique 3–20 character Avatar Name and one
of eight icon IDs before entering matchmaking. A private player token permits
the same identity to reconnect from multiple game sessions. The server prevents
two open games between the same pair of identities while allowing either player
to keep games open against other opponents. Completed rounds award three points
for a win, one for a draw, and zero for a loss; the leaderboard includes each
profile's win/draw/loss record.
Tests bind an ephemeral loopback port and do not require a separately running server.

See [protocol v2](../docs/ONLINE_PROTOCOL.md) for field validation, replay rules,
clock sequencing, rematches, recovery and production requirements. The server
exports `createMatchServer` for tests; `src/index.js` is the command-line entry.

This is a local in-memory reference implementation. Room state and credentials
vanish on process restart. It has a 1000-room cap and a 4096-action receipt cap per
room, with no automatic expiration. It is not ready for public hosting. Add durable
atomic state/receipts, authenticated credentials, TLS, cleanup, abuse controls,
backpressure, clock recovery and room routing before production deployment.
For a cost-free multiplayer test deployment, see
[`docs/RENDER_DEPLOYMENT.md`](../docs/RENDER_DEPLOYMENT.md).
