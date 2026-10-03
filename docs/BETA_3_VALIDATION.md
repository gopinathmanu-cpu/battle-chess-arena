# Android beta 3 handoff · 2026-09-20

Release: **0.9.0-beta.3+18**. Package: `com.manugopinath.battlechessarena`.
This is a testing build; physical-device acceptance is still required.

## Changes since beta 2

- Free immediate-capture threat scan: legal attacker/victim pairs flash red for
  three seconds each, without spending lifelines or stopping clocks. Reduced
  motion uses steady highlights. Board input, position changes, settings,
  backgrounding, disconnects and disposal cancel active scans.
- Captured-pieces box for both sides, respecting selected character/standard
  pieces, actual captures, en passant, promotions, undo, saved games, online
  full-history reconnect and rematches. Show/hide is saved on this device.
- Gameplay settings moved into a single dismissible, scrollable gear-menu
  sheet. The gear remains available with the top bar hidden. Gameplay actions
  stay outside the settings sheet; timed games continue while it is open.
- Large, bright Manga Vanguard White Knight launcher artwork over a faint
  golden standard chess set and board, using the user's selected sunny image.
  The final master and native exports are opaque RGB.
- All beta-2 tournaments, points, diagnostics and save-preservation changes
  remain included. No new application dependency, Firebase SDK or permission.

## Verification

- Flutter analysis: no issues.
- Flutter suite: **143 passed**, including actual game-screen threat sequencing,
  clocks/lifelines, capture history, preference persistence, online snapshots,
  settings access/dismissal, portrait/landscape, and large-text layouts.
- Node server suite: **23 passed**, including real WebSocket integration.
- Source whitespace checks and packaging-script syntax: passed.
- Native launcher exports: dimensions, Android RGB/RGBA, iOS opaque RGB and
  SHA-256 consistency with the current master are checked by
  `node tool/update_launcher_icons.mjs --check`.
- Final signed APK verification: all three release builds passed signature and
  `zipalign -c -P 16 4` checks. All 15 native libraries match the inspected
  binaries with 16 KB or 64 KB LOAD alignment. API minimum 24, target 36;
  permissions remain INTERNET and the app-scoped receiver permission.
- Extracted ARM64 launcher icon visually checked against the selected golden
  White Knight with faint standard chess set; all 20 native icon sizes validate.

| Architecture | Installed version code | APK size (decimal MB) |
| --- | ---: | ---: |
| ARM64 | 2018 | 150.3 |
| ARMv7 | 1018 | 147.3 |
| x86-64 | 4018 | 151.8 |

Signing certificate SHA-256 (same key as earlier betas):
`1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
This is a public certificate fingerprint, not signing-key material. The larger
ABI version codes allow upgrades, but install-over-old retention still needs
device testing.

## Remaining device acceptance

Install/update without uninstalling, check launcher masks/caches, native engine
loading, physical-device performance, 16 KB runtime compatibility, two-phone
online play and background recovery using [the checklist](DEVICE_VALIDATION_CHECKLIST.md).
No device installation or iOS build is claimed by automated checks.

Threat scans describe the current position, not a prediction after your next
move. Check is handled separately; no listed capture is a promise of safety.
The captured box never guesses from missing material when online history does
not match the authoritative position; it shows history unavailable instead.

Existing beta limitations remain: backend data is in memory, tournament points
are device-local, and cloud Crashlytics/automatic feedback upload are not
configured. No backend deployment or external distribution was performed.

## Handoff

After final APK verification, `bash tool/package_android_beta.sh` creates
`build/beta-0.9.0-beta.3+18/` with three ABI-labelled APKs, these notes, the device
checklist, release guide, matching working-tree source archive and SHA-256 sums.
The script excludes signing keys/local secrets and refuses to overwrite an
existing handoff. Prior beta-2 artifacts are retained. Do not distribute the
stale unlabelled `app-release.apk` from the Flutter output directory.
