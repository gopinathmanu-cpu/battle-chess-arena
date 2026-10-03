# Android beta 6 handoff · 2026-09-20

Release: **0.9.0-beta.6+21**. Package: `com.manugopinath.battlechessarena`.
This is a testing build; physical-device acceptance is still required.

## Changes since beta 5

- Replaced the eight chess-character profile icons with 50 dedicated illustrated
  human face avatars in a scrollable five-column picker.
- The catalog includes children, teenagers, and adults; varied skin tones,
  facial features, hairstyles, facial hair, glasses, and a head covering.
- Built-in computer opponents now display human portraits instead of chess
  pieces. Legacy profile IDs still map to faces so saved history remains usable.
- Protocol v4 validates `avatar-01` through `avatar-50` and identifies stale
  backend deployments clearly. It retains legacy IDs for upgrade compatibility.

## Automated verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 147 tests passed.
- `npm --prefix server test`: 23 tests passed.
- Avatar coverage verifies all 50 unique IDs, exact atlas-cell selection,
  scrolling to avatar 50, legacy-ID migration, and server rejection of IDs
  outside the catalog.
- All three release APKs passed `apksigner verify` and 16 KiB page-alignment
  validation with the established Battle Chess Arena Beta certificate
  (`SHA-256 1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`).

## Android artifacts

| ABI | Version code | SHA-256 |
| --- | ---: | --- |
| armeabi-v7a | 1021 | `7d7de0b0c9fc6168da3d5d57b66ebb056fadff30774cf6d76125e21b618e36e9` |
| arm64-v8a | 2021 | `dff3b365c088f7148b2d8fe2f42a3fa46f0ddd20543b02657797a95184e9e0a3` |
| x86_64 | 4021 | `e2ad7c3ae930ebc33edb4e66238d62bf246bd7d37e528b05a1e892f8cb5e32f3` |

All report package `com.manugopinath.battlechessarena` and version name
`0.9.0-beta.6`.

## Remaining device acceptance

Inspect and select all 50 portraits on a narrow phone and with large text. Check
the profile editor, lobby, invitations, rankings, game screen, history, built-in
opponents, and tournaments. Confirm every circular crop shows only its intended
face and that scrolling never changes the selection unexpectedly. Online play
requires the matching protocol-v4 Cloud Run server deployment.
