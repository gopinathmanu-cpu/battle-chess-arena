# Battle Chess Arena Beta 49 testing handoff

Version: `0.9.0-beta.49+64` · ARM64 split APK version code: `2064`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Uses the existing beta identity and signing key.

## Included changes

- Stationary selection avatars with short varied role/board-aware replies; only
  legal accepted moves begin motion. Existing Neon poses and all four worlds retained.
- Classic starts use the original page and no startup piece-type popup appears
  in local, computer, online, tournament, retry or rematch flows.
- Settings offers exactly four Classic and four Animated sets and switches the
  page during a game while preserving position, captures, turns and clocks.
- Page mode is saved independently from board-piece swipes; old offline saves
  and five-slot online appearance records retain their previous presentation.
- Coordinated King-and-Rook castling, with a theme-specific protective effect
  and correct board targets for either side and either castling wing.
- Replay controls toggle Classic/Animated pieces on the permanent board, zoom
  overview and enlarged recorded board while preserving story and playback.
- Animated board pieces use the matching animation cast, including correct
  Black facing, complete weapons/mounts, role badges and a common body scale.
  Classic/custom/legacy art remains compatible.
- Game History filters Show All, Completed and Unfinished without changing
  stored records, ordering or replay/cinematic access.
- Classic-page swipes cycle only the four Classic styles and retain the page;
  Animated-page swipes keep their existing Classic/Animated icon toggle.
- Compact credit counters retain fixed bounds during deductions; Home uses Exp
  when there is too little space for the full Experience label.
- Four matching Animated board palettes in gameplay, Home previews and replay
  zoom/overview: Neon cyan/violet, Manga blue/rose, Epic ivory/forest and Olympian
  marble/bronze. Both icon types remain legible, with custom colour overrides kept.
- Commentary and music remember their last switches across games and replay
  routes; muted film speech/music are restored before playback starts.
- Preserve credit charging, autoplay pacing, highest-strength assistance,
  checkmate-before-result ordering, saved history and equal figure body scale.

## Verification

- `flutter analyze --no-pub`: no issues after the final changes.
- Final regression coverage: **1,060 cases verified**. The complete run passed
  1,057 cases and skipped 13 opt-in previews. Three new History accessibility
  fixtures needed in-body semantics cleanup and a fresh visibility check after
  filter reflow; the corrected entire 25-case History file passed on rerun.
  Production code did not change after that complete run.
- Matching board-art checks: 25 focused cases passed, comparing all 48 role,
  side and world identities directly with the animation renderer, including
  asset source, crop masks, native fitting and Black mirroring.
- Actual-art eight-panel board preview passed and was visually reviewed with
  role badges: four Animated armies and four Classic-icon alternatives. Weapons,
  mounts and feet fit the squares; both armies remain readable on both colours.
- Live avatar/impact and castling landing/settled frames were reviewed across
  all four worlds and both sides. Selection stays stationary and castling uses
  equal King/Rook body scale with the appropriate protective effect.
- Startup/custom compatibility: 57 focused cases passed for saved custom art,
  Classic/Animated launches, swipe fixtures and immediate online matchmaking.
- The signed release APK compiled successfully. The Flutter wrapper's final
  copy ran out of disk space; after removing incomplete output and generated
  caches, the complete Gradle APK was copied byte-for-byte and verified below.
  Versioned APK/source handoffs and the existing production AAB were preserved.
- `aapt`: beta package, version `0.9.0-beta.49`, ARM64 code `2064`, Android
  minimum API 24 and target API 36 confirmed.
- `apksigner verify --verbose --print-certs`: valid APK v2 signature, using the
  existing beta public certificate SHA-256
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- `zipalign -c -P 16 4`: passed. All five ARM64 ELF libraries have compatible
  static 16 KB load alignment; this does not certify runtime device behaviour.
- All 16 artwork/music assets match the source byte-for-byte. Intermediate pose
  sheets are excluded. Compiled app content differs from Beta 48 and includes
  the matching-board, replay toggle, saved audio, history filter and swipe controls.
- Packaging provides the exact working-tree source, including all 67 Stockfish
  C++ source/header files, with signing/local-environment/build caches excluded.
  Verify the five supplied files with `shasum -a 256 -c SHA256SUMS`.

- [ ] Physical Android installation/upgrade, smoothness and two-device acceptance.
  No physical-device result is claimed by automated tests.

## Artifacts

- `build/beta-0.9.0-beta.49+64/battle-chess-arena-0.9.0-beta.49+64-arm64-v8a.apk`
- APK size: **233,730,751 bytes** (222.90 MiB).
- APK SHA-256:
  `ec5a15c13d04c5b3d086be95546da6d7f822c0efc35acb4ef4a662f8cf629851`.
- Matching source, release instructions, device checklist and checksums accompany
  the APK. No server changes or deployment are required for this update.
