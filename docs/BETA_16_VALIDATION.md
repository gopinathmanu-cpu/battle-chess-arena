# Android beta 16 testing handoff

Version: `0.9.0-beta.16+31` · verified ARM64 split APK version code: `2031`.

## Included changes

- Retain all beta 15 discovery, notifications, conquests, credits, progression,
  badges and optional preferred-name behavior.
- Render every built-in themed role at one common 94%-of-square height and shared
  baseline; keep pawns deliberately narrow for quick identification.
- Keep Black costumes dark while enhancing existing metallic/colour details and
  adding a restrained gold silhouette edge; use a dark edge for light armies.
- Give all 31 themed sets unique complementary board palettes with regression-
  tested light/dark luminance separation.

## Automated verification

- `flutter analyze`: no issues.
- `flutter test`: all 346 tests passed.
- `npm --prefix server test`: all 58 tests passed with localhost integration enabled.
- `git diff --check`: no whitespace errors.
- The 31-set, two-army 48 px contact sheet rendered successfully and was
  visually reviewed against each set's light and dark square colours.

## APK verification

- [x] Signed ARM64 APK built successfully: 196,192,283 bytes (about 196.2 MB).
- [x] Package `com.manugopinath.battlechessarena`, minimum API 24, target API 36.
- [x] Version code 2031 and version name `0.9.0-beta.16` verified with `aapt`.
- [x] Signing certificate matches beta 15, SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] APK v2 signature verification passed with Android build-tools 36.0.0.
- [x] Static 16 KB ZIP alignment verification passed.
- [x] APK SHA-256:
  `9b8c27fb92b7783d532d127777bd5e36382fed995395a8683d2b3dc3ab248c48`.

## Testing limitations

Physical-device installation and on-device visual review remain pending; automated
pixel checks and the desktop contact-sheet review do not replace phone acceptance.
Install over the earlier ARM64 beta without uninstalling to preserve local saves.
Online features still require the matching server revision to be deployed.
