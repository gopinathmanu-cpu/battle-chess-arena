# Battle Chess Arena Beta 34 testing handoff

Version: `0.9.0-beta.34+49` · expected ARM64 split APK version code: `2049`.

## Included changes

- Durable Firebase/Firestore-backed online profiles, games, credits and leaderboard.
- Server anti-abuse limits and a one-instance Cloud Run cost ceiling.
- Fantasy v5 artwork with clear White mounts and vivid dark-side accents.
- Historical and Legendary v3 artwork across all 27 kingdoms: ivory-white
  elephants/horses, stronger crimson/gold Black details, preserved orientation,
  and existing theme-specific Queen weapons.
- Latest credit, online invitation, leaderboard, Conquest, customization,
  notification, accessibility and presentation updates in the current source.

## Automated verification

- Focused themed-art and board rendering tests: 29 passed.
- Flutter analysis: no issues.
- Server suite: 60 passed before the artwork-only update.
- Music lifecycle suite: all 8 tests passed; switching apps pauses background
  music/effects and foreground resume obeys the saved mute setting.
- Full Flutter suite completed 378 passes, 3 skips and 7 known stale UI-test
  failures (missing legacy scroll targets, animation settle timeouts, and one
  outdated move expectation). The affected tests also fail serially; none touch
  the v3 artwork, audio lifecycle controller, signing, or APK compilation.

## APK verification

- [x] Signed ARM64 APK built: 197,858,243 bytes.
- [x] Package `com.manugopinath.battlechessarena.mobiletest`, label
  `Battle Chess Arena Beta`, min API 24, target API 36, version code `2049`,
  and version name `0.9.0-beta.34` verified.
- [x] APK signature verified. Certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] Static 16 KB ZIP alignment verified.
- [x] APK SHA-256:
  `81d0067505418ba07968dde6ad26c5a1c8185f5aa7135e265ce96fec6cc46056`.

## Testing limitations

Physical-device installation and final artwork legibility remain pending. Install
over the preceding mobile-test Beta package to preserve that package's local
saves. Online play requires network access to the deployed Firebase service.
