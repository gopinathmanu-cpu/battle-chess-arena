# Battle Chess Arena Beta 43 testing handoff

Version: `0.9.0-beta.43+58` · expected ARM64 split APK version code: `2058`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Updates same-key mobiletest builds and installs
alongside the production Play app, with separate device-local data.

## Included changes

- Add a live illustrated battlefield when Themed pieces are selected and both
  built-in armies are Neon Dominion. The board-world choice is independent.
  Classic, other themed armies, mixed armies and custom sets retain their
  existing play screen.
- Put the player's selected figure on the left facing right, with only its
  legal capture victims in round bubbles on the right. Put an accepted
  opponent move on the right facing left, with its legal attack targets on the
  left. Lanes follow the player even when their seat is Black.
- Give king bubbles a distinct aura and priority in the vertical three-per-page
  threat list. Label a legal checking opportunity POSSIBLE CHECK and an actual
  checked king CHECK; never depict the king as a capture victim. Account for
  pins, en passant, promotions, castling and discovered checks.
- Keep the top arena and compact clocks/status visible above the existing
  interactive board. Portrait Board/Match controls shortcuts scroll the lower
  pane; landscape uses a controls sidebar. Animation does not delay input or
  pause clocks. Reduced motion uses static emphasis. Role badges scale down to
  fit small squares so they leave the themed artwork visible.
- Preserve existing move previews, captures, assists, autoplay/commentary,
  result handling, device-local history and cinematic replay. Online actions
  follow validated accepted positions, not outgoing move requests; gaps,
  disconnects, changed rounds/seats and appearance changes clear stale action.

## Verification

- [x] Final Flutter analysis: no issues found.
- [x] Full Flutter regression run: all 686 tests passed. Three development-only
  credit-refill tests and the opt-in screenshot harness are skipped in the
  ordinary release run. Includes 63 new live-action, arena and offline/online
  integration checks, plus existing autoplay, history, cinematics, screens and
  real Node multiplayer integration. Additional themed-art/layout regression
  after the final small-square badge adjustment: all 53 focused tests passed.
- [x] Twelve actual-asset live-screen frames reviewed: timed White selection,
  Black human and local Black selection, both capture lanes, possible/actual
  king check, four-threat pagination, small portrait, 2× text, short landscape,
  reduced motion and timed online accepted moves. Every board sprite must
  resolve its atlas painter before capture. Preview: `build/neon-live-preview-v1/`.
  The compact 2× and landscape boards retain visible artwork after badge sizing.
- [x] Signed ARM64 APK: beta package/label, version `0.9.0-beta.43`, code
  `2058`, min API 24 and target API 36 verified. Certificate matches prior
  betas. All four cinematic runtime assets match source bytes; intermediate
  pose sheets are excluded. Compiled app code differs from Beta 42.
- [x] Static 16 KB ZIP alignment passes; all five ARM64 libraries have ELF
  PT_LOAD alignment of 16 KB or greater.
- [x] Exact corresponding-source archive audited: all 919 regular files match
  the workspace, including 67 Stockfish C++/header files, licences and artwork
  provenance. Signing material, local configuration, caches and build products
  are excluded. All five handoff checksums verify.
- [ ] Physical Android installation, upgrade, animation performance and real
  two-device acceptance. No physical device is attached.

## Suggested device checks

1. Choose Themed and both Neon Dominion armies. Select a piece with legal
   captures: its figure should appear on the left, and the victims on the right
   should match the board. Try a pinned piece and en passant.
2. Play Black against the computer or online. Your selections stay left-facing
   right and opponent moves appear right-facing left. Confirm source/target
   coordinates, attack bubbles and the board agree.
3. Select a piece that can give check, then play a checking move. The king bubble
   should change from POSSIBLE CHECK to CHECK and remain visually prominent.
   Browse both pages when more than three threats exist.
4. Move, capture, undo, restart, resume and change appearances. Check online
   reconnect/rematch and rejected requests. Stale figures and threats must clear;
   pending requests must not advance the live board or show an accepted move.
5. Try small portrait, short landscape, large text and reduced motion. Scroll
   Match controls and return to Board; confirm the arena remains visible, board
   taps work, clocks continue, and assists/autoplay/results/history still work.
6. Choose Classic, another theme, mixed armies or a custom set. These should
   keep the original play layout. Changing only the board world should retain
   the Neon live screen when both armies remain Neon.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.43+58-arm64-v8a.apk`.
- Handoff folder: `build/beta-0.9.0-beta.43+58/`.
- APK size: 208,171,752 bytes (208.2 MB).
- APK SHA-256: `c08351110a8e97f30d4fe183c39e3dbedf9024f7d9c30c883d85c0daa4632cb1`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical device acceptance remains pending.
