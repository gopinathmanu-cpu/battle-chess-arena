# Battle Chess Arena Beta 37 testing handoff

Version: `0.9.0-beta.37+52` · expected ARM64 split APK version code: `2052`.

Intended package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. This beta updates Beta 36 mobiletest installations
when signed with the same key and installs alongside the production Play app.

## Included changes

- Computer-match header includes an auto-play toggle. Automatic player turns
  wait five seconds before the move preview begins.
- Both automatically played sides blink the source square for three seconds,
  then the target square for three seconds before moving. The move squares stay
  highlighted until the opponent moves.
- Completed games with both armies using Neon Dominion offer **Watch cinematic
  summary**. The movie replays the full game with a neon-city opening, chapter
  titles, animated characters, capture scenes, and the actual game result.
- Movie controls include pause, speed selection, timeline seeking, scene
  navigation, and replay. Reduced-motion viewing is supported.
- Local, computer, tournament, and online result screens provide the movie
  action; the completed board also retains it. Returning from the movie restores
  the result screen without awarding points or XP again.
- Classic pieces, custom sets, and mixed armies do not offer a Neon movie.
  Online history must replay legally and match the authoritative final position.
- Includes Beta 36 launcher-icon choices and persistence.

## Verification

- [x] Flutter analysis passed with no issues.
- [x] Focused Flutter verification passed: 78 tests covering cinematic replay,
  player controls, result actions, auto-play, and relevant regressions.
- [x] Six Flutter-rendered frames reviewed in `build/cinematic-preview/`: opening,
  mid-game, capture, and finale in landscape, plus opening and capture in
  portrait. Layout coverage includes 320×568 at 1.5× text, 390×844 at 1× text,
  650×360 at 1× text, and 844×390 at 1.5× text.

These checks validate the source and rendered UI; physical Android acceptance
remains pending.

## APK verification

- [x] Signed ARM64 release APK built: 200,429,891 bytes.
- [x] Packaged manifest verified: package
  `com.manugopinath.battlechessarena.mobiletest`, label `Battle Chess Arena Beta`,
  min API 24, target API 36, version `0.9.0-beta.37`, version code `2052`,
  ARM64 ABI, and both launcher aliases.
- [x] APK signature verified; matches the Beta 36 signing certificate. SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] Static 16 KB ZIP alignment verified.
- [x] APK SHA-256:
  `942a696d302fbe28b0f8437d9f94c5ea5e42ce5d7a7a8870a078bee21e838f2b`.
- [x] Exact matching `corresponding-source.tar.gz` packaged with release notes,
  device checklist, and `SHA256SUMS`; archive file list reviewed for exclusions.

## Device acceptance still pending

- [ ] Upgrade an installed Beta 36 mobiletest APK without uninstalling and
  confirm saved games, settings, profile, points, and trophies remain available.
- [ ] Check native Stockfish moves and the five-second auto-play gap on Android.
  Confirm both three-second square previews and cancellation when auto-play stops.
- [ ] Watch a complete Neon Dominion movie in portrait and landscape; exercise
  pause, seeking, speed, replay, Back, reduced motion, and background/resume.
- [ ] Confirm replay does not submit moves or grant duplicate rewards, including
  online games and final tournament rounds.
- [ ] Check real-device rendering, audio lifecycle, performance, and native
  library loading, including a 16 KB Android device where available.

See [the Android release guide](ANDROID_BETA_RELEASE.md) for build and packaging
commands, and [the device checklist](DEVICE_VALIDATION_CHECKLIST.md) for broader
acceptance. No native-device test or Play Store upload is recorded by this handoff.
