# Android beta 10 release notes

Version: `0.9.0-beta.10+25`

## Included changes

- Each of the 20 named bots has a fixed level: Beginner 1–7, Intermediate 8–14,
  Advanced 15–20. User difficulty selection cannot change a bot's level.
- Ordinary computer games use the updated Easy, Medium, and Hard presets.
- Eight background music choices: Original, Rapid Chess, Zen Garden, Relaxing
  Evening, Inspiring Rise, Calm Waters, Deep Focus, and Epic Strategy.
- Original music remains the default. The selected mood is saved across launches.
- Reset settings restores preferences without deleting games, profiles, or
  tournament progress, and without changing fixed bot levels.
- New music is original synthesized work under GPL-3.0-or-later with the app;
  no third-party songs, samples, or music royalties are required.

## Automated verification

- Flutter analysis: no issues.
- Flutter tests: 167 passed.
- Server tests: 26 passed.
- Dependency notices: 91 preserved; no new dependency introduced for this release.
- Live online service health: reachable, protocol version 4.
- Release APKs built for ARM64, ARMv7, and x86-64.
- All three APKs passed v2 signature and 16 KB ZIP alignment verification.
- App ID: `com.manugopinath.battlechessarena`; minimum Android API 24.
- Version codes: ARM64 2025, ARMv7 1025, x86-64 4025.
- Signing certificate SHA-256 (same as beta 9):
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.

## Installation

Use the ARM64 APK for most modern Android phones. ARMv7 is for supported 32-bit
ARM phones; x86-64 is primarily for matching emulators/devices. Install over the
previous beta using the same app ID and signing key; do not uninstall if you
want to retain local progress. The source archive and checksums accompany the APKs.

## Remaining device and server checks

No Android phone was connected during packaging. Installation, audible playback,
native engine performance, and two-phone play still require device verification.
WhatsApp custom-scheme invitations need a real messaging-app test; direct tapping
is not guaranteed in every client.

This APK build does not deploy server changes. The updated online bot strength
requires a separate deployment of the included match-server source; local
tournament bot levels already work in this APK. Online rooms and profile data
remain in server memory and can be lost when the service restarts.
