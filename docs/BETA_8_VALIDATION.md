# Android beta 8 handoff · 2026-09-20

Release: **0.9.0-beta.8+23**. Package: `com.manugopinath.battlechessarena`.
This is a testing build; physical-device acceptance is still required.

## Changes since beta 7

- Replaced the launcher artwork with a circle-safe Classic-versus-Themed icon:
  one ivory Staunton knight faces the Black Manga Vanguard mounted knight across
  a single-notch gold lightning divider.
- Regenerated all Android, iOS, web, maskable, and favicon exports from the new
  opaque master and validated all 25 output files.
- The protocol-v4 Firebase Cloud Run server was reset to a clean revision. All
  previous in-memory human and game data was removed while the 20 built-in bots
  remain available across Beginner, Intermediate, and Advanced levels.

## Automated verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 152 tests passed.
- `npm --prefix server test`: 23 tests passed.
- All three APKs passed release-signing verification and 16 KiB page-alignment
  validation with the established Battle Chess Arena Beta certificate
  (`SHA-256 1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`).

## Android artifacts

| ABI | Version code | SHA-256 |
| --- | ---: | --- |
| armeabi-v7a | 1023 | `58ae7cd7d1b5b8144e94a881085ed2908af3bb4ee9bdd8846a57ad3f34cfbe3e` |
| arm64-v8a | 2023 | `90df072967d94e6753b9cc2e400d9cebcbb58f0365e2456ef60e279a20e87251` |
| x86_64 | 4023 | `b99e14a5e1aee44b24c4de2f17c134924b834c8799a2e1081a03e8e49bfada57` |

All artifacts must report package `com.manugopinath.battlechessarena` and
version name `0.9.0-beta.8`.

## Remaining device acceptance

Install over Beta 7 without uninstalling. Confirm the launcher icon remains
clear under the phone's square, rounded-square, and circular masks. Exercise
Themed and Classic Home selections, start each game mode, and verify Firebase
online registration plus matches against human and built-in opponents.
