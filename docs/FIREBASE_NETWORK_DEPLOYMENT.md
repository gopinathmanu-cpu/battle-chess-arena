# Firebase online-play deployment

Online play runs the existing authoritative match server on
Cloud Run inside the Google Cloud project associated with a Firebase project.
This keeps legal-move validation, clocks, matchmaking and reconnect handling on
the server while allowing the service to scale to zero when unused.

Direct Firebase Hosting rewrites are not used for the game socket because
Firebase Hosting has a 60-second dynamic request timeout. Cloud Run supports
WebSockets directly for up to 60 minutes per request, and the app already
reconnects and restores a seat after a timeout or network change.

## Simple setup

### 1. Prepare the Firebase project

In Firebase Console, open **Project settings → General** and copy the
**Project ID**. This can be different from the display name `BattleChessArena`.

Upgrade the project to the **Blaze** plan and attach a billing account. Configure
a small billing budget alert before deploying.

### 2. Install Google Cloud CLI and deploy

Install the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install), then
run these commands from the repository root:

```sh
gcloud init
./tool/deploy_firebase_network.sh YOUR_FIREBASE_PROJECT_ID
```

The script enables the required services, creates the default Firestore
database when needed, grants the Cloud Run runtime identity access, deploys the
server, and prints the service address. It then calls `/health` and fails unless
the live service reports protocol version 4 with durable storage enabled.
Durable storage keeps player profiles and leaderboard results across Cloud Run
restarts. Firebase CLI and local Docker are not required.

### 3. Build and test

This repository is already configured for the `battechessarena` deployment, so
build normally:

```sh
flutter build apk --release --split-per-abi
```

Choose the matching ABI-labelled APK (usually ARM64; see
[the beta guide](ANDROID_BETA_RELEASE.md)). Install it on both phones, open
**Play Online**, and create a
different Avatar ID on each device.

That is the complete integration path. The remaining sections explain the
deployment choices and manual commands for troubleshooting.

## Manual deployment

1. Create or select a Firebase project, then use the same project ID with the
   Google Cloud CLI. Billing must be enabled for Cloud Run, although its free
   usage allowance may cover a small test deployment.
2. Install and authenticate the Google Cloud CLI. The Firebase project ID is
   shown in **Firebase Console → Project settings → General**.
3. From the repository root, run:

```sh
gcloud config set project YOUR_FIREBASE_PROJECT_ID
gcloud run deploy battle-chess-arena-firebase \
  --source server \
  --region asia-south1 \
  --allow-unauthenticated \
  --timeout 3600 \
  --concurrency 1000 \
  --min-instances 0 \
  --max-instances 1 \
  --session-affinity
```

`max-instances=1` remains required by the single-authority server. Without
`FIRESTORE_PROJECT_ID`, rooms and profiles are process-local and Daily is disabled.
For the new durable Daily mode, follow the IAM, rules, configuration, capacity
and restart checks in [Game clocks](GAME_CLOCKS.md) before enabling it. The simple
deployment command above does not provision a database or grant storage access.

Verify the returned service URL:

```sh
curl https://YOUR_CLOUD_RUN_SERVICE_URL/health
```

For another Firebase project, convert its URL from `https://` to `wss://` and
override the bundled endpoint while building:

```sh
flutter build apk --release --split-per-abi \
  --dart-define=ONLINE_SERVER_URL=wss://YOUR_CLOUD_RUN_SERVICE_URL
```

The home screen exposes one **Play Online** entry. Each server deployment
maintains its own rooms, profiles, and leaderboard.

There is no Render fallback or secondary online endpoint. `render.yaml` has
been removed; production online play uses only the Firebase project's Cloud Run
service configured by `ONLINE_SERVER_URL`.

## HTTPS invitation links: release checklist

Deploy the updated server before distributing an APK with WhatsApp direct links.
`/health` and the socket handshake must advertise `shared_invites`. Until then,
the app shares Avatar-name instructions only. No live deployment is performed
by editing these files.

- The server serves `/invite/ID` and `/.well-known/assetlinks.json` on the same
  HTTPS domain as the game service. Link previews are read-only.
- The Android manifest verifies the bundled `battle-chess-arena-firebase-jdth6ggixa-el.a.run.app`
  domain for `/invite/` paths. For a different endpoint, update the manifest host
  as well as `ONLINE_SERVER_URL`; a Dart define alone cannot change Android's filter.
- The association contains the public certificate fingerprint of the existing
  directly distributed beta APK. Add the Play App Signing certificate before
  distributing through Google Play. Never publish private signing keys.
- Install the newly built APK after deploying the association. Check Android's
  domain verification and test WhatsApp on a physical phone, both with the app
  installed and with only the browser fallback. See the official
  [Android verification guide](https://developer.android.com/training/app-links/verify-applinks).
- Verify deletion and the 24-hour expiry message in both the browser and app.
  Scheduled named invitations expire no earlier than 15 minutes after their
  scheduled start. Already-started games remain intact.
- The current process-local server can invalidate links earlier if it restarts.
  A missing record is treated as unavailable and never recreated by opening a URL.

## Cost and connectivity choices

- `--min-instances 0` minimizes idle cost but the first connection after an idle
  period can experience a cold start.
- Change to `--min-instances 1` for consistently warm connections at additional
  cost.
- WebSocket requests keep a Cloud Run instance active and billable while players
  remain connected.
- The client heartbeat, retry and seat-resume logic requires no Firebase-specific
  application permissions or embedded service-account credentials.

References:

- <https://cloud.google.com/run/docs/triggering/websockets>
- <https://firebase.google.com/docs/hosting/serverless-overview>
