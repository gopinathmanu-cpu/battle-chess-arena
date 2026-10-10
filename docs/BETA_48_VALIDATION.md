# Battle Chess Arena Beta 48 testing handoff

Version: `0.9.0-beta.48+63` · verified ARM64 split APK version code: `2063`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Uses the existing beta identity and signing key.

## Included changes

- Continuous selection-to-move presentation for all four Animated worlds:
  short selection entrance, stable viewer-relative lane/facing, anchored motion
  and board source-to-destination travel synchronized with the strike.
- Neon ready and attack pose atlases for all twelve roles, blended into recovery
  in live captures and cinematic encounters. Original cast assets stay intact.
- Keep the board visible during Animated captures and retain capture Skip.
- Cool blue Suggest move/Threat scan buttons with readable text, prices and
  loading/disabled states. Slate tiles make captured White/Black pieces visible.
- Capture sounds follow the stage's impact and lifecycle; restored captures and
  returning from selection to an already shown move do not repeat the strike.
- Victors and defeated figures use the same body scale in live play and films;
  fading and outcome labels convey defeat without shrinking the character.
- Suggest move places its credit cost in the label, keeping the icon centered.
- Home and Settings no longer offer new custom-theme creation. Existing saved
  themes remain usable and editable without reopening creation controls.
- Preserve legal game state, accepted online moves, credit charging, autoplay,
  reply gaps, checkmate-before-result, Classic swipes and saved games.

## Verification

- [x] Focused motion, board, actual-screen, online and contrast regressions:
  81 stage/arena, 143 board/integration/layout, 54 domain/home/game and 7 capture
  sound cases passed in their final focused runs.
- [x] Full Flutter regression: **937 passed, 10 opt-in previews skipped**.
  Full analysis is clean. No server changes require a new server test run.
- [x] Actual-art inspection: Neon role pose contact sheets, **52** equal-scale
  live/film/finale frames and **8** final real-screen assist/capture previews.
- [x] Signed ARM64 APK, version/certificate and asset checks. Minimum Android
  API 24, target API 36. All **16** artwork/music assets match source byte-for-byte;
  compiled app differs from Beta 47 and intermediate pose sheets are excluded.
- [x] Static 16 KB ZIP alignment and the ELF load segments in all **5** native
  libraries pass.
- [x] Corresponding-source packaging and handoff checksums; release audit verifies
  archive files against the frozen workspace and retains all 67 Stockfish source
  and header files. Local configuration, signing files and build caches are excluded.
- [ ] Physical Android installation/upgrade, smoothness and two-device acceptance.
  No Android device is attached.

## Artifacts

- `build/beta-0.9.0-beta.48+63/battle-chess-arena-0.9.0-beta.48+63-arm64-v8a.apk`
- APK size: **233,730,631 bytes** (222.90 MiB).
- APK SHA-256: `923fedc8e4e8af055ffd6541479535719f4cdea922c06070a3b911cba11786f8`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Matching source, release instructions, device checklist and checksums accompany
  the APK. No server changes or deployment are required for this update.
- Artwork and exact prompts: `docs/NEON_LIVE_POSE_ARTWORK.md` and
  `docs/NEON_LIVE_POSE_PROMPTS.json`.
