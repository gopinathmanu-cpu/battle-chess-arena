# Battle Chess Arena Beta 40 testing handoff

Version: `0.9.0-beta.40+55` · expected ARM64 split APK version code: `2055`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. This build updates earlier mobiletest installations
with the same signing key and installs alongside the production Play app.

## Included changes

- Neon Dominion summaries keep illustrated piece action in the upper half and
  the actual recorded chessboard in the lower half throughout the film.
- A board camera zooms and follows the moving piece from its highlighted source
  to its highlighted destination. A full-board overview and coordinates retain
  battlefield context during zoom. Both panes land the move together.
- Castling moves both king and rook; en passant removes the actual pawn victim;
  promotions use the selected role. Opening and finale show the correct snapshots.
- After a move lands, right-side bubbles show threatened opponent pieces with
  their role and square; matching board squares highlight. Bubbles group multiple
  attackers of one victim and include discovered attacks and checked kings.
  The scan uses the moving army's immediate legal captures on the recorded board,
  rather than predicting future play. New threats receive a distinct accent.
- On a capture, the actual defeated figure stays full-length on the right.
  WINNER and DEFEATED stamps identify that encounter's mover and victim.
  A checked king remains a threatened king and is never depicted as captured.
- Short landscape places captions beside the lower board so the upper half
  retains the figures and stamps even with larger text and system insets.
  When controls hide, both panes expand to use the available screen.
- The narrated Aurora-versus-Void story, original instrumental music, separate
  voice/music toggles, speed, pause, scene navigation, timeline and replay remain.
  Narration completion gates chapter advance; lifecycle and route coverage pause
  audio and movement. Enlarge recorded board pauses the film for inspection.
- Reduced motion keeps the board unzoomed and uses position snapshots while
  retaining route highlights, threat bubbles, capture stamps and readable controls.
- Prior auto-play timing, speed controls and move commentary remain included.
  The film uses immutable history and preserves the finished result and rewards.

## Verification

- [x] Final Flutter analysis: no issues found.
- [x] Broad regression run: all 184 tests passed, covering chess replay, threats,
  board camera, action stage, player/audio, autoplay, results, tournament, online
  and responsive layouts. After final visual refinements, all 54 focused cinematic
  tests passed, including overview route clearance and synchronized capture sound.
- [x] Twelve rendered portrait/tablet/phone-landscape frames reviewed, including
  in-flight movement, threats, capture, finale, larger text with system insets,
  and hidden controls. The optional review harness writes to
  `build/cinematic-preview-v3/`.
- [x] Signed ARM64 release APK built; metadata confirms beta package, label,
  version name `0.9.0-beta.40`, version code `2055`, ARM64, min API 24 and target API 36.
- [x] Signature matches the prior beta certificate and static 16 KB ZIP
  alignment verification passes. All five ARM64 native libraries also pass
  static ELF PT_LOAD alignment checks (16 KB or greater).
- [x] All four cinematic runtime assets match workspace bytes. Intermediate
  pose inputs are excluded from the APK.
- [x] Corresponding source archive audited: all 899 regular archived files match
  workspace bytes. Required source/artwork provenance and 67 Stockfish C++/header
  files are included. Signing material, local config, caches, build products and
  pyc are excluded; all five handoff checksums verify.
- [ ] Physical Android install/upgrade, speech quality, music balance, camera
  smoothness and native 16 KB loading acceptance. No physical device is attached.

## Suggested device checks

1. Finish a game with both armies set to Neon Dominion and open its summary.
   Check that both pieces in action and the battlefield remain visible.
2. Follow quiet moves, a capture, castling, en passant and promotion. Check the
   source/destination coordinates, continuous movement and exact resulting board.
3. Look for opponent threat bubbles after landing, including a discovered threat,
   a checked king and a victim with several attackers. Scroll the bubble strip if
   there are more threats than fit. Match their squares to the board highlights.
4. On a capture, check that the captured figure appears on the right with DEFEATED
   and that the moving figure bears WINNER. A capture with check should keep both
   the captured victim and a separate checked-king bubble.
5. Pause, seek, change speed and reopen the board inspection sheet. Verify that
   the two panes remain synchronized and that obsolete narration stops.
6. Test a small phone, landscape, larger text and reduced motion. Confirm all
   controls remain reachable and that the full-board overview preserves context.
7. Background and return, cover the route, mute voice/music separately, then exit.
   Check that the film respects prior pause state and ordinary game music returns.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.40+55-arm64-v8a.apk`
- Size: 207,974,692 bytes (208.0 MB).
- APK SHA-256: `61c8efda2b8363304ba465ede6ab91a2fdc341608d48ca96133c10c47621e175`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Handoff folder: `build/beta-0.9.0-beta.40+55/`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical installation and audio/camera acceptance remain
  pending; automated and static verification do not replace those checks.
