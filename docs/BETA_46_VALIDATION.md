# Battle Chess Arena Beta 46 testing handoff

Version: `0.9.0-beta.46+61` · expected ARM64 split APK version code: `2061`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Updates same-key mobiletest builds and installs
alongside the production Play app, with separate device-local data.

## Included changes

- Continue a selected Neon actor's current visible pose into distinct accepted
  move motion and follow-through. Preserve both sides' facing, capture effects,
  threat bubbles and reduced-motion behavior.
- Show Suggest move and Threat scan immediately below the portrait board.
  In Neon landscape keep them beneath the animation, keep the full board visible
  and provide a central swap icon that preserves the user's preferred side.
  Remove the Board and Match controls shortcut buttons; details remain scrollable.
- Ask Classic pieces or Animated pieces before new games, resets and retries,
  with the note that swiping either way toggles between them. Preserve the selected
  world and army, saved-game appearance on resume, and old-game history on reset.
  Online setup and charged retries follow the accepted piece choice.
- Hold the credit counter's exact bounds through deductions, digit changes and
  connection-state changes. Confirm the one-credit fee on every autoplay enable;
  stop immediately without an extra prompt. Prior per-commit charging remains.
- Distinguish CHECKMATE from check in the live arena, name the victorious side
  and show CHECKMATED king emphasis. Existing full mate/result sequence remains.

## Verification

- [x] Final full Flutter regression: all 803 tests passed; six intentional skips
  are three development-only credit-refill tests and three opt-in preview cases.
  Full Flutter analysis reports no issues.
- [x] Focused live-motion, quick-action, startup-choice, autoplay-confirmation,
  credit geometry and online lifecycle regressions. All 42 autoplay/credit cases,
  20 arena cases, 87 launch/reset/retry fixtures and 24 clock/settings/typography
  cases pass. Online delayed acceptance and terminal-during-choice guards are
  covered by the full integration run.
- [x] Server Node suite: all 63 tests passed. No server deployment performed.
- [x] Final opt-in actual-art motion review passed. Eleven portrait/landscape
  frames in `build/neon-live-preview-v3/` show selected-pose continuity, distinct
  strike/follow-through, fixed fully visible credits, swapped panels and factual
  CHECKMATE/VICTORY labels. Harness assist-label glyphs use the test font; button
  font parity and bounds are verified separately. Physical fonts/smoothness remain
  part of the pending device checks.
- [x] Signed ARM64 APK: beta package/label, version `0.9.0-beta.46`, code
  `2061`, minimum API 24 and target API 36 verified. Signing certificate matches
  prior betas. All five artwork/music assets match source, intermediate pose
  sheets are excluded, and compiled app code differs from Beta 45.
- [x] Static 16 KB ZIP alignment passes. All five ARM64 libraries have ELF
  PT_LOAD alignment of at least 16 KB with congruent offsets/virtual addresses.
- [x] Exact corresponding-source archive audited: all 932 regular files match
  the workspace, including 67 Stockfish C++ sources/headers, licensing and artwork
  provenance. Signing/local files, caches and build outputs are excluded.
  All five handoff checksums verify.
- [ ] Physical Android installation/upgrade, animation smoothness and real
  two-device acceptance. No physical device is attached.

## Suggested device checks

Follow the Beta 46 section in `DEVICE_VALIDATION_CHECKLIST.md`, including new-game
cancel/resume, live move follow-through, enlarged text, swapped landscape panels,
fee confirmation, fixed counter geometry and final checkmate scene. Prior reply
delay, maximum assistance, history and cinematic checks remain relevant.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.46+61-arm64-v8a.apk`.
- Handoff folder: `build/beta-0.9.0-beta.46+61/`.
- APK size: 208,237,220 bytes (208.2 MB).
- APK SHA-256: `44cee3f17e017736e0248767313a6ac323b9c5d519f4ea2e6d84514a58a9e22d`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical device acceptance remains pending.
