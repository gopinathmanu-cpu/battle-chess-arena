# Battle Chess Arena Beta 42 testing handoff

Version: `0.9.0-beta.42+57` · expected ARM64 split APK version code: `2057`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Updates same-key mobiletest builds and installs
alongside the production Play app, with separate device-local data.

## Included changes

- Correct the native-facing assumption: both source cast sheets face right.
  Mirror Black's cropped artwork to face left for every actor and portrait;
  preserve fixed faction lanes and movement directions.
- Stack larger round threatened-piece portraits vertically, three per page,
  on the opponent's side. Keep role/square labels and all legal board highlights.
- Simplify narration to White/Black moves, captures, checks, legal threats
  against either side, forks and material changes. Remove repetitive scenery
  filler. Tactical facts are calculated from immutable positions, not engine
  quality ratings; all scene captions are prepared once before playback.
- Add magic/laser capture effects synchronized with the board landing, clear
  check emphasis and a celebration for the verified winning side. Draws,
  cancellation and unfinished recordings do not receive a victory celebration.
  Reduced motion uses static emphasis instead of animated effects.
- Retain player perspective in computer, tournament, online and historical
  films. A confirmed player loss ends with encouragement to fight another day;
  local two-player replays stay neutral. Results and recorded moves are preserved.
- Retain existing board zoom, full captured figures and encounter stamps,
  narration/music controls, playback navigation, speed and device-local history.

## Verification

- [x] Final Flutter analysis: no issues found.
- [x] Full Flutter regression run: all 623 tests passed; three development-only
  credit-refill tests remain disabled in release configuration. Coverage includes
  facing and faction lanes, vertical threat pagination, true capture/check
  effects, legal threats/replies, pins, en passant, forks, material accounting,
  viewer perspective, neutral endings, narration completion and finale sound,
  history, autoplay, existing screens and real Node multiplayer integration.
- [x] Eighteen actual-asset review frames: Black pawn/knight/queen facing left,
  vertical three-item threats and both pages of a four-threat scene, capture
  strike/stamps, check, both winner finales and loss encouragement. Includes
  small portrait, short landscape, large text, hidden controls and reduced motion.
  Preview harness: `build/cinematic-preview-v5/`.
- [x] Signed ARM64 APK: beta package/label, version `0.9.0-beta.42`, code `2057`,
  min API 24 and target API 36 verified. Signing certificate matches prior betas.
- [x] Static 16 KB ZIP alignment passes; all five ARM64 libraries have ELF
  PT_LOAD alignment of 16 KB or greater. All four cinematic runtime assets match
  source bytes; intermediate pose sheets are excluded from the APK.
- [x] Exact corresponding-source archive audited: all 910 regular files match
  the workspace, including 67 Stockfish C++/header files, licences and artwork
  provenance. Signing material, local configuration, caches and build products
  are excluded. All five handoff checksums verify.
- [ ] Physical Android install/upgrade, speech quality, soundtrack balance,
  animation smoothness and native loading. No physical device is attached.

## Suggested device checks

1. Watch Black pawn, knight, bishop, rook, queen and king scenes. Faces, mounts
   and weapons should point left; White should point right. Include captures,
   castling, promotion, threat portraits, prologue and finale.
2. Browse a scene with more than three threats. Portraits should stack vertically
   on the opponent's side, remain readable and agree with the highlighted board.
3. Listen to moves with threats, a capture, a new fork, check, promotion and
   checkmate. Match every named role/square and material fact to the position.
4. Watch winning and losing computer/online games and their saved replays.
   Verify the actual winning side receives the celebration and player losses
   receive an encouraging ending. Draws and unfinished games must stay neutral.
5. Try small portrait, short landscape, larger text and reduced motion. Pause,
   seek, change speed, mute voice/music, background and reopen. Capture effects
   must land with the move and audio; replay must not alter the live game.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.42+57-arm64-v8a.apk`.
- Handoff folder: `build/beta-0.9.0-beta.42+57/`.
- APK size: 208,040,608 bytes (208.0 MB).
- APK SHA-256: `b7187c651fbcd03bc6708e232b094ddd553d2bddc7c0b24b56e0bbe03494fadc`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical device acceptance remains pending.
