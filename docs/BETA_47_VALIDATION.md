# Battle Chess Arena Beta 47 testing handoff

Version: `0.9.0-beta.47+62` · expected ARM64 split APK version code: `2062`.

Package: `com.manugopinath.battlechessarena.mobiletest` · launcher label:
`Battle Chess Arena Beta`. Updates same-key mobiletest builds and installs
alongside the production Play app, with separate device-local data.

## Included changes

- Extend live arenas and cinematic replay to Manga Vanguard, Epic Guardians and
  Olympian Legion, alongside Neon Dominion. Each army gets its own battlefield,
  full-body White/Black cast, action effects, story and original soundtrack.
- Preserve selection-to-move continuity, facing, factual threats, real captures,
  checkmate/victory, reduced motion, Classic swipes and landscape swapping.
- Use the recorded Animated theme for saved-game movies even with Classic icons;
  retain clearly labeled Neon interpretation for legacy/mixed/custom recordings.
- Match online accepted moves and themed result backgrounds to all four armies.
  Existing reply delay, autoplay confirmation/credits and strongest assistance
  remain in place. No server deployment or save format migration is required.

## Verification

- [x] Final full Flutter regression: all 863 tests passed with seven intentional
  skips (three development-only credit-refill cases and four opt-in previews).
  Full analysis reports no issues.
- [x] Focused all-theme live, accepted online, mate, history, cinematic/audio
  tests. All four armies restore their last move safely after inherited scopes
  initialize. Exact two-second reply boundaries and fast autoplay respect the
  full Animated move; credits and authoritative online moves remain covered.
- [x] 36 actual-art review frames in `build/animated-armies-preview-v1/`
  include all 48 figures, captures, threats/check/mate, victory, short landscape
  and reduced motion. Three new twelve-role galleries were visually reviewed
  after removing neighboring atlas fragments. Harness text uses test fonts;
  shipping typography and smoothness remain physical-device checks.
- [x] All 63 server Node tests passed; no server deployment.
- [x] Signed ARM64 APK: beta package/label, version `0.9.0-beta.47`, code2062,
  minimum API24/target36, and the same certificate as prior betas. All 14 checked
  artwork/music assets match source; intermediate pose sheets are excluded.
  Compiled app code differs from Beta46.
- [x] Static 16 KB ZIP alignment passes; all five ARM64 libraries have ELF load
  segments aligned to at least16KB with congruent offsets/virtual addresses.
- [x] Exact corresponding-source archive and five handoff checksums verified.
  App, original artwork/music, provenance and complete Stockfish source included;
  signing/local files, caches and build outputs excluded.
- [ ] Physical Android installation/upgrade, smoothness and two-device acceptance.
  No Android device is attached.

## Artifact details

- APK: `battle-chess-arena-0.9.0-beta.47+62-arm64-v8a.apk`.
- Handoff folder: `build/beta-0.9.0-beta.47+62/`.
- APK size: 228,983,080 bytes (229.0 MB).
- APK SHA-256: `9d737c00d68afedee27ef7ccee369464c7c565649fb5c19ae88f825478aa911c`.
- Original artwork/prompts: `docs/ANIMATED_ARMIES_ARTWORK.md` and
  `docs/ANIMATED_ARMIES_ART_PROMPTS.json`.
- Signing certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- Corresponding source, release instructions, device checklist and checksums
  accompany the APK. Physical device acceptance remains pending.
