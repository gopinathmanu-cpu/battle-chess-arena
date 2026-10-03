# Android beta 12 testing handoff

Version: `0.9.0-beta.12+27` · ARM64 APK version code: `2027`.

## Verified locally

- Release build: `flutter build apk --release --target-platform android-arm64 --split-per-abi`.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: all 180 tests passed.
- `npm test` in `server`: all 35 tests passed.
- APK signature verifies with the established beta signing certificate:
  SHA-256 `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Static 16 KB ZIP alignment check passed. Package ID is
  `com.manugopinath.battlechessarena`; minimum Android API is 24.
- Packaged Android manifest contains the verified HTTPS `/invite/` route and
  the `battlechessarena://invite` fallback route.

## Changes to test

- Choose White or Black for computer games; board orientation, opening moves,
  hints, undo, results, and saved-game colour follow the choice.
- Optional tournament colour toss, preserved when resuming a round.
- Optional server-authoritative online colour toss.
- HTTPS WhatsApp invitations with Avatar-name search/invite fallback, link
  deletion, and explicit deleted/expired messages in the browser and app.
- Automatic 24-hour link expiry. Unstarted named invitations expire after
  24 hours or 15 minutes after their scheduled start, whichever is later.
  Games already started are preserved.
- Earlier avatar crop fixes, enlarged picker, fixed bot levels, music choices,
  and settings improvements remain included.

## Live service limitation — important for testers

The read-only live health check during packaging reported protocol 4 and server
version `0.9.0-beta.6`, without `color_toss` or `shared_invites` capabilities.
The updated server has **not been deployed**. Against that service this APK
shares Avatar-name-only WhatsApp instructions and disables online colour toss.
Direct links, revocation, and expiry require a separate server deployment before
end-to-end phone testing. See [deployment checklist](FIREBASE_NETWORK_DEPLOYMENT.md).

No connected Android device was available. Installation over the old beta,
Android App Link domain verification, actual WhatsApp launching, and two-phone
play remain pending. Current server storage is process-local: restarting it can
invalidate invitations and online data earlier than their normal expiry.

Install this ARM64 APK over the previous ARM64 beta without uninstalling to
retain local data. Keep the matching source archive and checksums with any copy
shared with friends. No external upload or tester invitation was performed.
