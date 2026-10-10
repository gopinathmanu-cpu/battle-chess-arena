# Battle Chess Arena Beta 50 testing handoff

Version: `0.9.0-beta.50+65` · expected ARM64 split APK version code: `2065`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. The release targets the existing beta identity and
signing key. Automated, APK and corresponding-source checks are recorded below;
physical-device acceptance remains pending.

## Included changes

- Home's Animated family icon grows from 52 to 64 pixels within the existing
  84-pixel card, preserving the labels and Classic icon.
- Online games and regular Tournaments replace the top animation with a
  prominent opponent profile. Both Classic and Animated choices show it above
  the portrait board, or beside the landscape board with the existing swap.
  No duplicate profile appears in match details. World boards/backgrounds,
  accepted move/capture handling and cinematic summaries remain; ordinary
  practice and Conquests retain their illustrated arenas.
- Accepted Animated captures retain their attack and impact sounds when the
  opponent profile replaces the stage. A nonvisual clock preserves mute,
  reduced-motion, background pause, duplicate-event and restored-game behaviour;
  Classic capture overlays and practice/Conquest arenas keep their existing owner.
- Live Animated moves settle after landing without the actor retreating toward
  its starting position. Primary movement and attacks, defeated reactions,
  castling choreography and cinematic motion are retained.
- Each Animated board piece fits nearly 98% of its available square content
  along one axis at native proportions, including weapons and mounts. The board
  uses each role's own resting crop; live and film keep their shared body scale.
- Black characters have brighter exposed faces/hands and strongly contrasting
  army accessories in Manga Vanguard, Epic Guardians, Olympian Legion and Neon
  Dominion. The Neon update covers resting, ready and attack artwork.
- Both Olympian Queens receive visible long flowing hair. The other six Queens
  retain their existing flowing hair and character identities.
- Both Neon Rooks become tall upright heroic chariot commanders with recognizable
  energy cannons across resting, ready and attack artwork. Four edited atlases
  cover White rest, Black rest and the shared ready/attack sheets; crop and body
  metrics follow the revised silhouettes.
- Existing Classic/Animated page switching, saved audio preferences, history
  filters, replay piece toggles, castling and custom-colour choices are preserved.

The nine selected runtime cast paths and preserved originals are recorded in
[Beta 50 cast artwork](BRIGHT_ANIMATED_CAST_ARTWORK.md), with full submitted edits
in [the prompt manifest](BRIGHT_ANIMATED_CAST_PROMPTS.json).
Neon uses the revised ready/attack sheets only for Rooks; other roles retain the
earlier bright pose sheets to avoid overlapping Rook flags/capes in their crops.

## Verification

- [x] `flutter analyze --no-pub`: no issues found. Final log:
  `/private/tmp/bca-beta50-final-analysis-2.log`.
- [x] Final Flutter regression: **1,116 passed, 14 optional visual tests skipped,
  no failures**, using `--no-pub --concurrency=1 --reporter expanded`.
  Final log: `/private/tmp/bca-beta50-final-regression.log`.
- [x] Focused live landing checks: accepted moves, attacks, defeated reaction,
  castling, reduced motion, lifecycle and restored-action behaviour. The 69
  focused arena cases and final regression passed.
- [x] Per-piece board fitting: all 48 role/side/world figures at small square
  sizes, native atlas aspect, mirrored containment and unchanged film/live scale.
- [x] Actual-art review: 36 four-army cast/live/film frames, 56 Neon pose/avatar/
  castling frames and the eight-panel board palette preview rendered with decoded
  source assets. All eight Queens and both tall Neon Rooks reviewed, including
  resting/ready/attack poses and mirrored Black figures.
- [x] Home Animated icon: 64-pixel icon, unchanged labels/84-pixel card/Classic
  icon, narrow screens and enlarged text verified.
- [x] Eight shared opponent/board component previews rendered with actual human
  and bot portraits, covering Online/Tournament, Classic/Animated and both
  orientations. These illustrate the shared layout rather than full live sessions.
- [x] Online/Tournament opponent panels: both page families, correct human/bot
  identity, no duplicate profile, compact portrait, landscape swap and large text.
  Server acceptance, clocks, captures, results, Settings and saved styles verified.
- [x] Accepted-capture audio: 14 direct cue tests and 25 integrated capture/
  Tournament cases passed, followed by the full regression. Attack occurs once,
  impact at 391 ms (immediately with reduced motion); background pause, mute,
  Skip, ACK/clock revisions and silent restore covered. Classic/practice/Conquest
  sound ownership is retained. Logs:
  `/private/tmp/bca-beta50-cue-direct-tests.log` and
  `/private/tmp/bca-beta50-cue-integrated-tests.log`.
- [x] Release compilation/signing produced a complete ARM64 APK from the tested
  source. Gradle's final copy to Flutter output failed because the disk filled;
  its automatic retry also failed from insufficient space. The completed Gradle
  APK passed ZIP CRC, package/version and signature checks. After removing only
  generated native packaging caches and the incomplete output copy, the complete
  signed APK was copied intact and its SHA-256 matched. No source changed and no
  prior beta handoff was removed. Build log: `/private/tmp/bca-beta50-build.log`.
- [x] `aapt`: beta package, version `0.9.0-beta.50`, ARM64 code `2065`, minimum
  SDK 24, target SDK 36 and ARM64-only native code. Permissions: Internet,
  notifications and the package's non-exported dynamic receiver permission.
- [x] `apksigner verify --verbose --print-certs`: APK Signature Scheme v2 verifies
  with the existing beta certificate SHA-256
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
  Public verification log: `/private/tmp/bca-beta50-apk-signature.log`.
- [x] `zipalign -c -P 16 4` and all five ARM64 ELF load alignments verified.
  ZIP CRC and compiled-app change from Beta 49 also verified. Static checks
  alone do not certify compatibility on a 16 KB device.
- [x] All 18 runtime artwork/music assets match workspace sources; intermediate artwork
  is excluded from the APK and source prompts/provenance are included as intended.
- [x] Corresponding source archive matches the working tree, includes GPL and
  Stockfish sources, and excludes signing files, credentials, local configuration,
  caches and generated builds. All 67 Stockfish source/header files and nine
  selected atlas records verified. All five supplied checksums and copied handoff
  documents verified after packaging; no signing files were read by the audit.
  Final audit log: `/private/tmp/bca-beta50-source-audit.log`.
- [ ] Physical Android installation/upgrade, motion smoothness, character
  visibility and two-device acceptance. Automated checks do not replace these.

## Artifacts

- APK:
  `build/beta-0.9.0-beta.50+65/battle-chess-arena-0.9.0-beta.50+65-arm64-v8a.apk`
- APK size: **238,728,282 bytes** (227.67 MiB).
- APK SHA-256:
  `21df2e674864338066d97c55c78a87fc7e3797dab76ebef518016d7255f8ba10`.
- Matching source: `corresponding-source.tar.gz` in the same handoff directory,
  with release instructions, device checklist and `SHA256SUMS`.
  No server change or deployment is
  required for this presentation update.

See the [device checklist](DEVICE_VALIDATION_CHECKLIST.md) and
[Android beta guide](ANDROID_BETA_RELEASE.md).
