# Android beta 13 testing handoff

Version: `0.9.0-beta.13+28` · ARM64 APK version code: `2028`.

## Included fix

Suggest Move and Threat Scan now share the same 14-point font and weight in
computer and online games. Longer labels wrap instead of shrinking. Both buttons
have equal heights and stay side by side, including at larger text settings.
All earlier beta 12 changes remain included.

## Verification

- Release ARM64 APK build completed successfully (approximately 174 MB).
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: all 186 tests passed, including six typography checks
  for computer/online play at 320/390-pixel widths and up to 1.5× text scale.
- APK signature and static 16 KB ZIP alignment checks passed.
- Same established signing certificate as previous betas, SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Package: `com.manugopinath.battlechessarena`; minimum Android API: 24.

## Testing limitations

No Android device was connected; physical installation and visual testing remain
pending. Install over the previous ARM64 beta without uninstalling to retain data.

The live health check still reports protocol 4 / server `0.9.0-beta.6` without
`shared_invites` or `color_toss` capabilities. No server deployment was performed.
WhatsApp therefore uses Avatar-name-only fallback instructions until the server
is updated. Direct invite links, revocation, expiry, and online colour toss need
that separate deployment. This typography fix itself requires no server change.

Matching source and checksums are included in this handoff. Older handoffs are
preserved. No external upload or tester invitation was performed.
