# Android beta 14 testing handoff

Version: `0.9.0-beta.14+29` · verified ARM64 APK version code: `2029`.

## Included changes

- Full starting-board previews for all four themed and four classic chess sets.
- Swipe browsing and left/right arrows, with wraparound arrow navigation.
- Themed/Classic artwork cards using actual knight sprites, colour-matched
  gradients, selection borders, glow and a selected checkmark.
- Both families' choices are remembered across launches and passed into new games.
- Compact Home play actions, side-by-side landscape layout and a scrolling
  fallback for short screens and enlarged text.
- All earlier beta 13 changes remain included.

## Verification

- `flutter analyze --no-pub`: no issues.
- `npm --prefix server test`: all 35 tests passed.
- `flutter test --no-pub`: all 196 tests passed, including artwork selection,
  full-board previews, saved selections, accessibility and responsive layouts.
- Release ARM64 APK built successfully (approximately 177 MB).
- APK signature and static 16 KB ZIP alignment checks passed.
- Same signing certificate as previous betas, SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Package: `com.manugopinath.battlechessarena`; minimum Android API: 24;
  target API: 36; architecture: `arm64-v8a`.

## Testing limitations

Physical-device installation and two-phone acceptance remain pending. Install
over the previous ARM64 beta without uninstalling to retain local data.

These Home changes need no server update. No server deployment was performed.
Direct WhatsApp links, invitation revocation/expiry and online colour toss still
require the matching server capabilities described in the Android beta guide;
this build does not establish that those capabilities are live.

Matching source and checksums accompany the APK. Older handoffs are preserved.
No external upload or tester invitation was performed.
