# Android beta 5 handoff · 2026-09-20

Release: **0.9.0-beta.5+20**. Package: `com.manugopinath.battlechessarena`.
This is a testing build; physical-device acceptance is still required.

## Changes since beta 4

- Increased the move table's first column from 56 to 72 logical pixels so the
  “Move” heading and move numbers have clearer horizontal spacing.
- Renamed First Steps Cup to **Rising Knights Cup**. The stable
  `beginner-cup-v1` identifier is unchanged, preserving existing tournament
  progress, results, points, and trophies.
- Retains beta 4's isolated crisp character atlas, mirrored black characters,
  shadow cleanup, and removal of the full-board turn border/glow.

## Automated verification

- Flutter analysis: no issues.
- Full Flutter suite: **144 passed**, including move-table width, tournament
  naming, saved tournament behavior, board layouts, and online play.
- Node server suite: **23 passed**.
- All three ABI APKs use the expected private beta certificate and package ID,
  contain only their named ABI, and pass 16 KB ZIP-alignment verification.
  Installed version codes are ARMv7 1020, ARM64 2020, and x86-64 4020.

## Remaining device acceptance

Install over beta 4 without uninstalling. Confirm the wider first table column
does not crowd White/Black notation on a narrow phone or at large text sizes.
Open the tournament screen and confirm Rising Knights Cup displays consistently,
then verify any existing beginner-cup progress still resumes. Continue with the
complete [device checklist](DEVICE_VALIDATION_CHECKLIST.md).
