# Battle Chess Arena Beta 38 testing handoff

Version: `0.9.0-beta.38+53` · expected ARM64 split APK version code: `2053`.

Intended package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. With the same signing key, this beta updates earlier
mobiletest installations and installs alongside the production Play app.

## Included changes

- With auto-play enabled, both player and computer turns wait two seconds at
  the default 1× speed before previewing a move.
- The source square blinks three times before the move: 200 ms on and 200 ms
  off per cycle, totaling 1.2 seconds at 1×. The target stays steadily highlighted
  during this preview.
- After the move commits, the target square blinks three times using the same
  timing. Captures finish their battle animation before these target blinks;
  terminal moves finish blinking before the result opens. Both move squares
  retain their highlights until the opponent moves.
- Auto-play shows a speed slider below the board, from 0.5× to 3×. It scales the
  turn gap and both blink phases. Changing speed takes effect immediately while
  preserving the elapsed fraction of the current phase.
- A header commentary icon appears during auto-play and starts enabled. It
  adds a caption for the actual committed move and speaks it using Android
  TextToSpeech when an English voice is available. Other platforms show captions;
  unavailable Android voices leave caption playback usable. Disabling commentary
  stops speech and hides its caption.
- Source and target timing pauses when the app is backgrounded. Castling
  highlights the king's destination, and reset/cancellation checks prevent
  overlapping engine requests from committing stale moves.
- All Beta 37 Neon Dominion cinematic summaries remain available: full-game
  movies, scene captions and capture effects, pause, speed, seeking, scene
  navigation, replay, and reduced-motion viewing. Result screens and completed
  boards offer the movie when both armies use Neon Dominion; replay preserves
  the game result and does not grant additional rewards.
- Classic pieces, custom sets, and mixed armies do not offer a Neon movie.
  Online replay must match the authoritative final position.

## Verification

- [x] Beta 38 Flutter analysis: no issues found.
- [x] Updated focused Flutter tests: all 102 passed, including timing, speed
  changes, special moves, lifecycle/cancellation, commentary, and cinematic
  regressions.
- [x] Android native TextToSpeech integration compiled in the signed release
  build.

Beta 37's earlier checks are recorded in
[its historical handoff](BETA_37_VALIDATION.md). They do not replace validation
of the new timing and commentary changes. Physical Android acceptance remains
pending.

## APK verification

- [x] Signed ARM64 release APK built. Size: 200,430,235 bytes (200.4 MB).
- [x] Packaged manifest verified: mobiletest package, Beta label, min API 24,
  target API 36, version name `0.9.0-beta.38`, version code `2053`, ARM64 ABI,
  launcher aliases, and the TextToSpeech service visibility query.
- [x] APK signature verified against the previous beta. Certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] Static 16 KB ZIP alignment verified.
- [x] APK SHA-256 recorded:
  `77f8ede088f943b585b616b061b697289b355f206fc2cb5d9fd2b352209c6239`.
- [x] Exact matching `corresponding-source.tar.gz` packaged with release notes,
  device checklist, and `SHA256SUMS`; archive file list reviewed for exclusions.
  All five handoff checksums verify; 205 text source/test/tool/server files,
  pubspec, and Android native files match the working tree byte for byte.

## Device acceptance still pending

- [ ] Upgrade an earlier mobiletest beta without uninstalling; confirm saved
  games, settings, profile, points, and trophies remain available.
- [ ] At 1×, verify the two-second gap on both sides, three source blinks before
  moving, steady target preview, three target blinks after moving, and retained
  move highlights. Repeat for captures, castling, promotion, and a terminal move.
- [ ] Try 0.5× and 3× speeds and change speed during each active phase. Confirm
  the remaining timing adjusts immediately and the slider appears only during
  auto-play.
- [ ] Check captions and Android English speech, disable/re-enable commentary,
  and test a device without an available English voice. Confirm stopping,
  resetting, leaving, and backgrounding do not leave unwanted speech playing.
- [ ] Background/resume during source and target phases; stop auto-play and
  reset while the engine is thinking. Confirm no stale move or blink appears.
- [ ] Watch a complete Neon Dominion movie in portrait and landscape; exercise
  pause, seeking, speed, replay, Back, reduced motion, and background/resume.
- [ ] Confirm movies do not submit moves or grant duplicate rewards, including
  online games and final tournament rounds.
- [ ] Check native Stockfish operation, real-device rendering, audio lifecycle,
  performance, and native library loading, including a 16 KB Android device
  where available.

See [the Android release guide](ANDROID_BETA_RELEASE.md) for build and packaging
commands, and [the device checklist](DEVICE_VALIDATION_CHECKLIST.md) for broader
acceptance. No physical-device test or Play Store upload is recorded here.
