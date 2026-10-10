# Battle Chess Arena Beta 39 testing handoff

Version: `0.9.0-beta.39+54` · expected ARM64 split APK version code: `2054`.

Intended package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. With the same signing key, this beta updates earlier
mobiletest installations and installs alongside the production Play app.

## Included changes

- Neon Dominion game summaries now use an illustrated film presentation with
  layered city scenery, new battle poses without chess bases, camera cuts,
  parallax and distinct actions for the moving roles. Captures, castling,
  promotions, checks and checkmate follow the recorded game.
- The film fills the screen. Playback controls fade after four seconds and
  return when the scene is tapped. Pause, previous/next, timeline seeking,
  1×/2×/4× speed and replay remain available. Reduced motion keeps controls
  visible and limits camera and action movement.
- **View recorded board** opens the actual position in a separate sheet.
  The film pauses while the board is open and resumes according to the prior
  playback state after it closes.
- A deterministic story casts White as cyan **Aurora** and Black as magenta
  **Void**. Narration and captions describe every recorded move, the opening
  and the supplied outcome. They preserve routes, victims, castling,
  en passant, promotions, checks and the game's ending reason.
- Android narration uses the installed English speech engine. A chapter waits
  for its spoken line to finish before advancing. Missing voice support leaves
  captions and timed playback available. The header voice icon independently
  enables or disables storytelling.
- An original 40-second instrumental score accompanies the film. It lowers its
  volume during narration; quieter impact cues accompany captures and checkmate.
  The header music icon controls this soundtrack independently from narration.
  The score is synthesized from oscillators, deterministic noise and envelopes;
  its editable source is `tool/generate_neon_film_score.py`.
- Pause, seeking, speed changes, backgrounding, route coverage and exit cancel
  obsolete narration safely. Voice ownership prevents an older film route from
  stopping a newer film's narrator. The final automatic move's voice yields to
  the film storyteller.
- The app's ordinary background music and effects stay suspended while a film
  owns audio. Overlapping film routes hold separate leases; lifecycle resumes
  and late route cleanup respect those leases and the saved mute preference.
- Movies remain available after local, computer, tournament and validated
  online games when both armies use Neon Dominion. Viewing them preserves
  match history and rewards. Classic, custom and mixed armies keep their
  existing result presentation.
- Beta 38 auto-play timing, the 0.5×–3× speed slider, source/target blinks,
  spoken move commentary and captions remain included.

## Verification

- [x] Targeted cinematic audio and theme music tests: all 29 passed, including
  narration completion/cancellation, instance ownership, score ducking,
  loading/disposal races, overlapping background leases, lifecycle resumes and
  cancelled delayed victory cues.
- [x] Targeted Dart analysis of the audio service and audio/music tests:
  no issues found.
- [x] Final Beta 39 Flutter analysis: no issues found.
- [x] Final focused Beta 39 Flutter regressions: all 158 passed, including
  story accuracy, illustrated stage, audio, player lifecycle, autoplay,
  online/tournament integration, result entry and layouts.
- [x] Illustrated film rendering verified with actual assets in portrait and
  landscape; seven review frames in `build/cinematic-preview-v2/`.
  Narrow screen bounds and reduced-motion behavior passed widget tests.
  [Artwork, prompts and original score provenance](NEON_CINEMATIC_ARTWORK.md)
  are included in the corresponding source.
- [x] Android narration ownership and TextToSpeech integration compiled in the
  final signed release build.

Beta 38's earlier checks are recorded in
[its historical handoff](BETA_38_VALIDATION.md). Physical Android acceptance
remains pending.

## APK verification

- [x] Signed ARM64 release APK built. Size: 207,843,620 bytes (207.8 MB).
- [x] Packaged manifest verified: mobiletest package, Beta label, min API 24,
  target API 36, version name `0.9.0-beta.39`, version code `2054`, ARM64 ABI,
  launcher aliases and the TextToSpeech service visibility query.
- [x] APK signature verified against the previous beta. Certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] Static 16 KB ZIP alignment verified.
- [x] APK SHA-256 recorded:
  `52c4d952da8bfbec163bf5ea6cda191f0aeb66afa410c3ae16117a9c81d1294f`.
- [x] The packaged city, both alpha character sheets and original score are
  present as runtime Flutter assets; intermediate source sheets are excluded.
- [x] Exact matching `corresponding-source.tar.gz` packaged with release notes,
  device checklist and `SHA256SUMS`; all 894 regular archived files match
  the workspace byte for byte and all five checksums verify. Archive exclusions
  are clean. Input pose sheets, full prompts, provenance and score generator
  are included; all four new runtime assets match the signed APK exactly.

## Device acceptance still pending

- [ ] Upgrade an earlier mobiletest beta without uninstalling; confirm saved
  games, settings, profile, points and trophies remain available.
- [ ] Watch a complete Neon Dominion game in portrait and landscape. Judge the
  new battle poses, role actions, city layers, camera cuts and finale on a phone.
- [ ] Check storytelling voice quality, cadence and speech completion against
  captions. Try captures, checks, castling, en passant and promotion; verify the
  supplied resignation, timeout or draw ending remains accurate.
- [ ] Hear the original soundtrack beneath narration and check its ducking,
  loop seam and impact levels. Toggle voice and music independently; test an
  unavailable English voice and confirm captions and playback continue.
- [ ] Pause/resume, seek, change speed, open/close the recorded board, cover the
  film with another route, replay and exit during speech. Confirm old speech or
  music never returns and the ordinary soundtrack resumes only when appropriate.
- [ ] Background/resume while playing and while paused. Verify speech and score
  stop in the background; exercise reduced motion and large text.
- [ ] Verify controls fade after four seconds, tapping restores them, and the
  recorded board corresponds to the displayed move without changing the game.
- [ ] Confirm movies do not submit moves or grant duplicate rewards, including
  online games and final tournament rounds.
- [ ] Recheck Beta 38 auto-play timing, speed and move commentary, native
  Stockfish operation, performance and native library loading, including a
  16 KB Android device where available.

See [the Android release guide](ANDROID_BETA_RELEASE.md) for build and packaging
commands, and [the device checklist](DEVICE_VALIDATION_CHECKLIST.md) for broader
acceptance. No physical-device test or Play Store upload is recorded here.
