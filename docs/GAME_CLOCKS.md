# Game clocks

| Entry point | New-game default | Alternatives |
| --- | --- | --- |
| Computer | Rapid 15+10 | Untimed Practice |
| Friends / WhatsApp invitation | Daily, 24 hours per move | Rapid 15+10, Classical 30 or 60 minutes without increment |
| Tournament | Rapid 15+10 | Existing saved round keeps its original clock |
| Quick live matchmaking / online bots | Rapid 15+10 | Classical 30 or 60 minutes |

15+10 means each player begins with 15 minutes and receives 10 seconds after
each legal move. Undo in local practice revokes the increment without refunding
thinking time. Illegal moves, retries, hints and reconnects do not earn time.
Local clocks use monotonic elapsed time rather than counting timer callbacks.
Tournament clocks retain the existing pause-on-background/leave behaviour.
Untimed Practice neither counts down nor earns increments and is resumable.

Daily is **not** a 24-hour total clock: every legal move gives the next player a
fresh 24 hours. The deadline continues while both players are offline. A move at
or after the deadline is rejected and the server records a timeout. Clock
display interpolation is cosmetic; only the server decides the result.
Invitation-link expiry and the game's per-turn deadline are separate clocks.

## Deployment gate — not enabled on the live service by this source change

The app requires `invite_clocks` for increment-bearing friend invitations and
`daily_games` for Daily. Older services show an availability message instead of
silently creating a different clock. Rapid quick matches remain compatible with
the existing protocol. Version 4 is retained; the extensions are capability-gated.

Daily is advertised only when a durable store is configured. The Node entrypoint
loads Firestore before listening; failed loads abort startup. Register/profile
changes, invitations, game moves, seats, receipt deduplication and result awards
are checkpointed **before** success frames are delivered. Failed writes close
connections and make health return 503; restart reloads the last committed state.
Do not automatically retry against empty in-memory state.

Deployment preparation (requires project-owner approval; not performed here):

1. Create a Firestore Native database in the existing Firebase project and enable
   its API. Give the server runtime service account the needed Firestore data
   permissions (for example `roles/datastore.user`, scoped appropriately).
2. Deny all mobile/web client access to `serverState/**` in Firestore rules.
   Checkpoints include private player/seat tokens. Server access uses IAM and
   short-lived metadata-service credentials; no credentials belong in the APK.
3. Set `FIRESTORE_PROJECT_ID` on the server, and optionally `FIRESTORE_DATABASE`
   (defaults to `(default)`). Deploy the updated source with one active authority,
   `max-instances=1`, and no traffic split between revisions. Drain old revisions
   during rollout. No deployment or IAM changes are made by editing this repo.
4. Check `/health` for both capabilities. On two test devices, create a Daily
   invitation, accept it, move, disconnect both, restart the server and reconnect.
   Verify names, seats, history and the unchanged current deadline.

This is a **small-deployment checkpoint store**, not a horizontally scalable
match database. Firestore update-time preconditions prevent stale containers
from overwriting a newer checkpoint; a conflict fails closed and needs a restart.
The compressed checkpoint is capped at 900,000 bytes below the document limit.
Capacity exhaustion fails closed without deleting any data. Monitor capacity and
storage errors; partitioned room storage is required before a larger rollout.
Active live games write clock snapshots; Daily games avoid per-second writes
when only the countdown changes. Include Firestore operation/storage costs in
the deployment budget.

At scale-to-zero, an overdue Daily result is settled on the next server wake or
request. The deadline is not extended. No background push reminders are added.
The old process-local service cannot export its state through a public endpoint;
plan any migration of existing live data before replacing that deployment.

Implementation references:

- [Firestore REST authentication](https://firebase.google.com/docs/firestore/use-rest-api)
- [Atomic commit endpoint](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/projects.databases.documents/commit)
- [Write preconditions](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/Write)
- [Firestore limits](https://firebase.google.com/docs/firestore/quotas)
- [Service-account metadata authentication](https://docs.cloud.google.com/compute/docs/access/authenticate-workloads)

## Checks

- `flutter analyze`
- `flutter test`
- `cd server && npm test`

The new tests cover presets, legacy saves, untimed clocks, increments/undo,
Daily legal/illegal/retried moves, exact expiry, rematch, protocol validation,
restart recovery, result awards, capability gating, write failures, and the
Firestore adapter using a stub transport. A real Firestore deployment and
physical-device overnight test remain release checks.

Validation for this change: static analysis passed, all 307 Flutter tests passed,
all 47 server tests passed, and `git diff --check` passed. No cloud resources were
changed and no production deployment was performed.
