# Battle Chess Arena Beta 35 testing handoff

Version: `0.9.0-beta.35+50` · expected ARM64 split APK version code: `2050`.

## Included changes

- Menus, buttons, cards and selection controls now share the saved application
  palette instead of mixing Material magenta tones with gold controls.
- Dynamic mode changes chess-world backgrounds only; application chrome stays
  consistent across screens.
- The saved palette remains visible and selected in Settings in both Single and
  Dynamic modes and restores after restart.
- Move suggestion and Threat scan retain yellow/red semantics inside dark,
  contrasting bordered icon containers.
- Includes all Beta 34 server, artwork, credit, online and audio lifecycle work.

## Verification

- Stable palette/persistence/header regression set: 10 passed.
- Flutter analysis: no issues.
- Dedicated music lifecycle suite: 8 passed in Beta 34 validation.
- Seven pre-existing stale UI-test assumptions remain documented in Beta 34.

## APK verification

- [ ] Signed ARM64 APK built and verified.
