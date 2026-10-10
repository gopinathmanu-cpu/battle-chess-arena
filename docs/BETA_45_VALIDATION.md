# Battle Chess Arena Beta 45 testing handoff

Version: `0.9.0-beta.45+60` · expected ARM64 split APK version code: `2060`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Updates same-key mobiletest builds and installs
alongside the production Play app, with separate device-local data.

## Included changes

- Give manual computer replies a full two-second pause after the move animation
  finishes. Quiet Neon moves wait for the 850 ms arena animation first; fast or
  skipped captures also wait for its remaining animation. Background/resume
  restarts the visible reply pause, and stale/reset requests cannot move.
- Finish a dedicated 2.6-second CHECKMATE presentation before the result window
  or tournament championship. It identifies the checkmated king without treating
  a king as a captured piece, blocks dismissal and pauses in background. Reduced
  motion uses a static 650 ms presentation.
- Reuse the active Animated world's backdrop in results, draws/timeouts and
  tournament victories. Neon retains its city even with Classic board pieces.
  Preserve result actions, game history, progression and cinematic summaries.
- Charge exactly one credit for each successfully committed automatic player
  move. Computer replies and manual moves remain free; cancelled, stale, illegal
  or unavailable moves incur no fee. Insufficient funds stop auto-play without
  advancing the position. Show the price in the toggle tooltip, speed panel and
  credits guide. Retain the user's 0.5×–3× auto-play pacing control.
- Generate automatic player moves and offline/online suggestions with the
  maximum assistance profile: Skill 20, depth 18, 2625 ms and Elo limiting off.
  Ordinary opponents retain selected difficulty/persona. A degraded engine uses
  the strongest available fallback, without an intentional mistake probability.
- Update server computer replies to a two-second default and invalidate queued
  replies on position/round/completion changes. Server source is included; this
  handoff does not deploy the running server.

## Verification

- [x] Final full Flutter regression run: all 760 tests passed. Five skips are
  the three development-only credit-refill cases and two opt-in preview harnesses.
  Full Flutter analysis reports no issues.
- [x] Focused animation/credit/online regression rerun: all 64 tests passed,
  including all 20 credit/timing cases and fast/Skip/background/resume checks.
- [x] Strongest assistance service tests passed in the initial focused run.
- [x] Presentation: all 12 opt-in tests passed; scoped analysis clean. Four
  actual-art frames reviewed in `build/checkmate-preview/`, including portrait
  and landscape checkmate impact and Neon results with Classic board pieces.
- [x] Server Node suite: all 63 tests passed, including full default reply delay,
  cancellation and a fresh rematch delay. No server deployment performed.
- [x] Signed ARM64 APK: beta package/label, version `0.9.0-beta.45`, code
  `2060`, minimum API 24 and target API 36 verified. Certificate matches prior
  betas. Four cinematic assets and the Fantasy atlas match workspace bytes;
  intermediate pose sheets are excluded and compiled app code differs from Beta 44.
- [x] Static 16 KB ZIP alignment passes. All five ARM64 libraries have ELF
  PT_LOAD alignment of at least 16 KB, with congruent offsets/virtual addresses.
- [x] Exact corresponding-source archive audited: all 927 regular files match
  the workspace, including 67 Stockfish C++ sources/headers and licensing/art
  provenance. Signing/local files, caches and build outputs are excluded.
  All five handoff checksums verify.
- [ ] Physical Android installation/upgrade, animation smoothness and real
  two-device acceptance. No physical device is attached.

## Suggested device checks

1. Make a quiet player move with Animated or Classic board pieces. Let the upper
   Neon action finish, then verify the full two-second pause before the computer
   preview. Capture a piece, use Fast battles and Skip, and check the same pause.
   Background/resume during the pause; no reply should jump ahead while returning.
2. Enable auto-play with a known wallet balance. Each successful player move
   subtracts exactly one credit; computer moves never subtract that fee. Stop
   before/after a move and test zero funds. Manual chess remains available.
3. Try auto-play and Suggest move against an Easy opponent or a tournament
   persona: player assistance should use the maximum profile while the opponent
   remains at the selected strength. Adjust auto-play speed and commentary.
4. Win and lose by checkmate. Watch the entire mate presentation before result
   buttons appear. Check reduced motion, large text, portrait and landscape.
5. With Neon armies, switch the board to Classic and finish a game. The result
   background must still show the Neon city. Check all four Fantasy worlds,
   tournament rounds/finals, Review Board, New Game and cinematic summaries.
6. Test online checkmate, repeated completed state messages, reconnect/rematch
   and queued captures. Use the updated server source to verify the online bot
   delay and fresh rematch timing on two devices.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.45+60-arm64-v8a.apk`.
- Handoff folder: `build/beta-0.9.0-beta.45+60/`.
- APK size: 208,171,752 bytes (208.2 MB).
- APK SHA-256: `f9037689a2395a42795a5e1e4738d651b72353e4fb0954bfb9c3c25f617e90d6`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical device acceptance remains pending.
