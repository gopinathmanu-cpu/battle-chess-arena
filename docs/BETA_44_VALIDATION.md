# Battle Chess Arena Beta 44 testing handoff

Version: `0.9.0-beta.44+59` · expected ARM64 split APK version code: `2059`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Updates same-key mobiletest builds and installs
alongside the production Play app, with separate device-local data.

## Included changes

- Rename the player-facing character-set choice Animated. Offer only Manga
  Vanguard, Epic Guardians, Olympian Legion and Neon Dominion for new Fantasy
  selections, plus the four Classic sets. Hide unavailable catalog categories.
  Preserve full catalog IDs and artwork for saved games/history/custom designs;
  optional new Studio formation metadata does not remap older costume values.
- Remove placeholder king figures from the live Neon arena. Show only relevant
  selected/moved actors and actual captured victims. Actual checks retain a
  prominent king bubble; checking opportunities remain distinct from captures.
- Animate the actual captured victim into a recoiling, tilted/faded DEFEATED
  pose, alongside the encounter winner. Reduced motion uses static emphasis;
  king checks do not receive defeated/winner capture stamps.
- Put A–H labels above/below and 1–8 on both sides in orientation-aware gutters
  outside the 64 playable squares. Keep input and capture flight aligned with
  the inset board, including Black orientation.
- Swipe either direction inside the Neon screen to toggle Animated/Classic
  board pieces without changing armies, selection, legal position, or current
  illustrated action. Classic style/settings controls and cinematic summaries
  remain available without leaving the animated game screen.
- In landscape, show animation in the left half and the board in the right.
  Put clocks/status and other match controls below on one scrollable page.
  Portrait keeps the arena above the board and its Board/Match controls shortcuts.
- Preserve online authority, clocks, existing capture overlays, move previews,
  autoplay/commentary, assists, results and device-local history.

## Verification

- [x] Final Flutter analysis: no issues found.
- [x] Full Flutter regression run: all 726 tests passed. Three development-only
  credit-refill cases and the opt-in preview harness are skipped in the normal
  release run. Includes coordinates/input/overlay geometry, Classic swipes and
  action retention, defeat/check behavior, landscape scrolling, curated choices,
  old saved/custom compatibility, autoplay, cinematics/history and real Node
  multiplayer integration.
- [x] Twenty-one actual-asset live-screen frames reviewed, with viewport and
  artwork-decoder readiness checks. Includes blank idle, Classic/Animated swipes,
  both player perspectives, landscape action/board and scrolled controls, true
  capture before impact/impact/settled defeat, check/potential check, threat pages,
  large text, reduced motion and online accepted moves.
  Preview: `build/neon-live-preview-v2/`.
- [x] Signed ARM64 APK: beta package/label, version `0.9.0-beta.44`, code
  `2059`, min API 24 and target API 36 verified. Certificate matches prior betas.
  Four cinematic assets and the Fantasy atlas match source bytes; intermediate
  pose sheets are excluded. Compiled app code differs from Beta 43.
- [x] Static 16 KB ZIP alignment passes; all five ARM64 libraries have ELF
  PT_LOAD alignment of 16 KB or greater.
- [x] Exact corresponding-source archive audited: all 923 regular files match
  the workspace, including 67 Stockfish C++ sources/headers, licenses and art
  provenance. Signing files, local configuration, caches and build outputs are
  excluded. All five handoff checksums verify.
- [ ] Physical Android installation/upgrade, animation smoothness, and real
  two-device acceptance. No physical device is attached.

## Suggested device checks

1. Confirm Home, settings and Studio call the character choice Animated and
   offer only the four Fantasy sets. The four Classic choices remain available.
   Reopen an old saved/history/custom set and verify its original artwork.
2. Start Neon with no move/selection: no placeholder kings should appear.
   Select a piece and inspect its legal capture/check bubbles. Clear/undo/restart
   and verify figures never invent a selected actor or capture victim.
3. Swipe left/right, or use the Classic switch, while a piece is selected or
   after an opponent move. Only board styling should change; animation, threats,
   selection, legal moves and game position should remain. Resume the game and
   verify the selected board style is retained.
4. Inspect A–H and 1–8 along all board edges for White and Black seats. Play a
   capture and en passant: the victim, flight and target square must align. The
   actual captured figure should end as DEFEATED; checked kings remain alive.
5. Rotate to landscape. Animation should be left, board right, both initially
   visible. Scroll down for clocks and controls. Test small portrait, short
   landscape, large text, reduced motion, zoom and ordinary square taps/swipes.
6. Try offline/computer/online captures with Classic pieces, a promotion,
   a checking move, rejected online requests, reconnect/rematch and a completed
   game. Confirm authority, clocks, history and cinematic summaries are retained.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.44+59-arm64-v8a.apk`.
- Handoff folder: `build/beta-0.9.0-beta.44+59/`.
- APK size: 208,171,752 bytes (208.2 MB).
- APK SHA-256: `4537e05fe85b9251664c52e3167620912ae1c35fee30b51801eb81133a584399`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical device acceptance remains pending.
