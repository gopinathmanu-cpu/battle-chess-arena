# Android beta 4 handoff · 2026-09-20

Release: **0.9.0-beta.4+19**. Package: `com.manugopinath.battlechessarena`.
This is a testing build; physical-device acceptance is still required.

## Changes since beta 3

- Replaced the irregular themed-piece crop map with an exact 6 x 8 atlas of 48
  isolated 256 x 256 sprites. Every character is independently centered on a
  consistent baseline, so adjacent rooks cannot leak into pawn cells.
- Cleaned broad external shadows and stray transparent-edge pixels while
  retaining character identity, internal dimensional shading, mounts, weapons,
  bases, palettes, and transparent backgrounds.
- Enabled high-quality antialiasing for themed and Standard Staunton pieces.
- Mirrored black themed characters horizontally at render time so opposing
  white and black pieces visually face one another; role labels remain upright.
- Removed the animated green/blue border and glow around the whole board in
  local, computer, tournament, and online games. Clocks, status text, and the
  compact online turn indicator remain available.

## Automated verification

- Flutter analysis: no issues.
- Full Flutter suite: **144 passed**, including the black-character mirror
  transform, atlas selection, board layouts, settings, and online play.
- Node server suite: **23 passed**.
- The atlas builder found and exported all 48 active character silhouettes into
  exact cells; the production PNG is 1536 x 2048 with genuine transparency.
- All three ABI APKs use the expected private beta certificate and package ID,
  contain only their named ABI, and pass 16 KB ZIP-alignment verification.
  Installed version codes are ARMv7 1019, ARM64 2019, and x86-64 4019.

## Remaining device acceptance

Install over beta 3 without uninstalling. Inspect every themed army on a real
phone, especially all pawn cells, wide chariot rooks, elephant bishops, weapon
tips, mounts, and bases. Confirm pieces remain sharp in portrait and landscape,
and that turn changes no longer add a board-wide border or glow. Continue with
the complete [device checklist](DEVICE_VALIDATION_CHECKLIST.md).

No backend deployment, storage migration, Firebase SDK, cloud crash reporting,
or automatic feedback upload is included. Existing in-memory backend and
device-local tournament-point limitations remain.
