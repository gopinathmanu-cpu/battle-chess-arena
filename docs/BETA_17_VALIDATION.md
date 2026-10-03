# Android beta 17 testing handoff

Version: `0.9.0-beta.17+32` · verified ARM64 split APK version code: `2032`.

## Included changes

- Lift face-scale midtones for both armies while retaining dark Black costumes,
  bright accessories, equal-height pieces and lean pawns.
- Add a chessboard/paintbrush action to visible and compact offline/online
  toolbars. It toggles only the board square colours.
- Add separate light- and dark-square colour pickers in Game settings, with vivid
  presets, HSL/hex controls, a live board preview and a contrast safety gate.
- Persist the selected palette and enabled state device-wide across restarts;
  pieces, world scenery, music and game state remain independent.

## Automated verification

- `flutter analyze`: no issues.
- `flutter test`: all 351 tests passed.
- `npm --prefix server test`: all 58 tests passed with localhost integration enabled.
- `git diff --check`: no whitespace errors.
- The 31-set, two-army 48 px contact sheet was regenerated and visually reviewed.

## APK verification

- [x] Signed ARM64 APK built successfully: 196,192,523 bytes (about 196.2 MB).
- [x] Package `com.manugopinath.battlechessarena`, minimum API 24, target API 36.
- [x] Version code 2032 and version name `0.9.0-beta.17` verified with `aapt`.
- [x] Signing certificate matches beta 16, SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] APK v2 signature verification passed with Android build-tools 36.0.0.
- [x] Static 16 KB ZIP alignment verification passed.
- [x] APK SHA-256:
  `cceb9f4a125f79cc41c11ea9d2b937dcd847debf2cd9dca312f39bd86a8f7b12`.

## Testing limitations

Physical-device installation and on-device colour/brightness review remain pending.
Install over the earlier ARM64 beta without uninstalling to preserve local saves.
Online features still require the matching server revision to be deployed.
