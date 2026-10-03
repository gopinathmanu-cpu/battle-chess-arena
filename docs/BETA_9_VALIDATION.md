# Android Beta 9 validation

Version: `0.9.0-beta.9+24`

## Friend-facing changes

- The About page contains only the app version, a short description, and
  required open-source licence links.
- Online-play labels and errors use plain player-facing language.
- The in-game settings flow can select Themed armies or any Classic set.
- Suggest Move and Threat Scan share one compact action row on a 390 x 844
  portrait display.
- Human avatars use a 10 x 5 atlas with integer cells and safe circular gutters.
- Victory audio uses the extended 5.2-second celebration cue.
- Play Online can create and share a WhatsApp invitation containing the host's
  Avatar name, direct join link, and fallback game code. Installed apps route
  the link to the invited room on both cold and warm starts.

## Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 156 tests passed.
- Online service tests: 23 tests passed.
- Android release APK: all three ABI builds completed; the ARM64 APK passed
  Android v2 signature verification and contains the `battlechessarena://join`
  VIEW/BROWSABLE intent filter.
