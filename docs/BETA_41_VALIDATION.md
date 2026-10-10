# Battle Chess Arena Beta 41 testing handoff

Version: `0.9.0-beta.41+56` · expected ARM64 split APK version code: `2056`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Updates previous mobiletest builds with the same key
and installs alongside the production Play app.

## Included changes

- White illustrated figures stay left facing right and Black figures stay right
  facing left throughout the Neon Dominion film. Black approaches travel leftward.
  Captures, castling, promotions, opening and finale preserve faction lanes.
- Larger round threat portraits appear on the opponent's side. Each page shows
  up to three, with previous/next controls and a page count. Check remains first;
  all legal threats and corresponding board highlights remain available.
- Home's Game history lists completed and unfinished local, computer, tournament
  and received online games, with players, date, result and chess set metadata.
  Played moves remain when leaving a game, replacing the resume slot or resetting.
  Each received online round has its own ID; full SAN histories are verified
  against the authoritative final board before offline archiving.
- History offers read-only board stepping, a move list and Watch cinematic summary
  for every verified recording. Neon Dominion is the implemented movie style;
  other set, Classic and custom recordings clearly use a Neon interpretation.
  Unfinished recordings keep their unfinished label and do not invent an ending.
  Viewing history and films does not alter the live game or award extra rewards.
- Retained legacy resume/tournament snapshots migrate without deleting their
  source. Previously discarded move lists cannot be reconstructed. Unreadable
  archive entries remain preserved with replay marked unavailable; no automatic
  record eviction occurs.
- Archive writes are serialized and completed records are immutable. Failed
  saves offer retry; pending terminal sources are retained for recovery. Delayed
  archive cleanup cannot erase a newer resume slot. Undo after completion creates
  a separate continuation recording while retaining the original reward ID.
- Previous battlefield zoom, capture stamps, narration/music, film controls,
  reduced motion, autoplay timing/speed and optional move commentary remain.

## Verification

- [x] Final Flutter analysis: no issues found.
- [x] Full Flutter regression run: all 584 tests passed; three development-only
  credit-refill tests are disabled in release configuration. Coverage includes
  faction lanes/threat paging, archive/migration/corruption/write failures,
  history UI, offline and online recording, resume/reset/Undo, tournament pending
  completion recovery, rewards, autoplay, existing screens and Node multiplayer.
  A timed draw test gates storage and verifies blocked moves and stopped clocks.
- [x] Fourteen cinematic portrait/landscape review frames, including White and
  Black captures, large text with insets and hidden controls, plus six rendered
  history list/detail frames reviewed with the shipping theme and piece art.
  Review harnesses: `build/cinematic-preview-v4/`, `build/history-preview-v1/`.
- [x] Signed ARM64 release APK; beta package/label, version `0.9.0-beta.41`,
  code `2056`, min API 24, target API 36 and ARM64 architecture verified.
- [x] Prior beta signing certificate matches; static 16 KB ZIP alignment passes.
  All five ARM64 libraries have ELF PT_LOAD alignment of 16 KB or greater.
- [x] All four cinematic runtime assets match workspace source bytes.
- [x] Exact corresponding source audited: all 907 archived regular files match
  the workspace, including 67 Stockfish C++/header files and artwork provenance.
  Signing material, local config, caches, build products and pyc are excluded;
  all five handoff checksums verify.
- [ ] Physical Android install/upgrade, speech quality, soundtrack balance,
  smooth animation and native 16 KB loading. No physical device is attached.

## Suggested device checks

1. Watch White and Black quiet moves and captures. Check lane, direction and
   facing; the actual victor and victim retain their correct faction positions.
   Include castling, promotion, intro and finale.
2. Find a move with more than three threats. Browse pages on the opponent's side
   and match portrait role/square labels to the highlighted board squares. Check
   that a new scene starts on the first page and that playback keeps the selected
   page stable within a scene.
3. Play and finish local/computer/tournament games, and complete online rounds.
   Open Home → Game history, inspect player/result/set metadata, step the board
   and open each cinematic. Ensure the recorded result remains unchanged.
4. Leave an unfinished game, start another and restart the app. Confirm its
   played moves remain in history. Upgrade over an existing beta and check retained
   legacy saves migrate. Device-local records do not survive clearing app data.
5. Undo a completed local game and finish the continuation. Check that the first
   ending remains separately available and that rewards are not granted twice.
6. Test received online games without keeping the game screen open, sync after
   reconnect and rematch. Check round separation and absence of duplicate clock
   updates; verify the archive can be replayed offline.
7. Try small portrait, short landscape, larger text and reduced motion. Pause,
   seek, change speed, enlarge the recorded board, mute narration/music separately,
   background, return and exit. Ordinary game audio should return correctly.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.41+56-arm64-v8a.apk`.
- Handoff folder: `build/beta-0.9.0-beta.41+56/`.
- APK size: 208,040,604 bytes (208.0 MB).
- APK SHA-256: `abc807a1a0b254eb4cb794e9d86b749af1b1e5f9b5cc330413cfd246f5bdb6ab`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical device acceptance remains pending.
