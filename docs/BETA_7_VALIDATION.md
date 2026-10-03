# Android beta 7 handoff · 2026-09-20

Release: **0.9.0-beta.7+22**. Package: `com.manugopinath.battlechessarena`.
This is a testing build; physical-device acceptance is still required.

## Changes since beta 6

- Home now shows the white and black piece previews on separate rows and keeps
  primary play actions visible on compact phones.
- Added direct Themed/Classic selection on Home. Classic offers Magnetic 3D,
  Wooden 3D, Flat Club, and Flat Teaching sets; the latter two follow the
  supplied flat chess-piece reference.
- The selected Classic set carries into local, computer, online, tournament,
  promotion, capture, and saved-game rendering.
- Re-isolated all 48 themed sprites in centered 256 × 256 cells, eliminating
  adjacent-piece fragments around elephant Bishops.

## Automated verification

- Both final atlases are idempotent through the alignment pipeline: rebuilt
  files are byte-for-byte identical, confirming uniform centering and pawn
  baselines.
- `flutter analyze`: passed with no issues.
- `flutter test`: 152 tests passed.
- `npm --prefix server test`: 23 tests passed.
- All three release APKs passed signing verification and 16 KiB page-alignment
  validation with the established Battle Chess Arena Beta certificate
  (`SHA-256 1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`).

## Android artifacts

| ABI | Version code | SHA-256 |
| --- | ---: | --- |
| armeabi-v7a | 1022 | `1c92ea038f79f5e956fe1c1c20fc7c6912b93c7c2fda88e8ba6bf45b5e9ccacf` |
| arm64-v8a | 2022 | `58ac00823b58b8440689dbc5e0a7eff7a1dd429fcf4a7223021d350e2f6d1028` |
| x86_64 | 4022 | `96b5cf3be82ce11076d5adb4b2db6712660cf78570bd4586d2384d69528587dc` |

All artifacts must report package `com.manugopinath.battlechessarena` and
version name `0.9.0-beta.7`.

## Remaining device acceptance

On a narrow physical phone, switch through all four Classic sets and every
themed army. Confirm both Home preview rows remain isolated and that pawns,
elephant Bishops, promotions, captured-piece panels, and capture animations are
centered without neighboring fragments. Verify an existing beta installation
updates without uninstalling so saved games and tournament points are retained.
