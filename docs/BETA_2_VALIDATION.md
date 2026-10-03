# Android beta 2 handoff · 2026-09-20

Release: **0.9.0-beta.2+17**. Package: `com.manugopinath.battlechessarena`.
This is a closed-testing beta, not a claim of physical-device acceptance.

## Included in this build

- Twenty bot avatars; three offline cups, retries, saved progress, points, and
  championship ceremonies from the current workspace.
- About/feedback screen with installed Android version/build and device metadata.
- Local-only, bounded, privacy-minimized Flutter/Dart diagnostics; opt-out/clear
  controls; preview and manual copying of feedback reports.
- Project/Stockfish licence text and third-party notices available in the app.
- Older installations retain saves instead of running the retired beta-1 wipe.
- Unreferenced character artwork stays in source but is excluded from the APK.

## Verification

| Check | Result |
| --- | --- |
| Flutter static analysis | Passed, no issues |
| Flutter suite | Passed, 114 tests |
| Node server suite | Passed, 23 tests |
| Diagnostic privacy/persistence and handler restoration | Automated tests passed |
| Feedback validation, preview/copy, confirmation and narrow/large-text layout | Automated tests passed |
| Legacy startup save preservation | Automated test passed |
| Connected Android devices | None available |
| Signed release builds | Passed: ARMv7, ARM64, x86-64 |
| Signing certificate | Matches previous beta; SHA-256 fingerprint below |
| Package/version/permissions | Expected package, beta 2, API 24 minimum / API 36 target; no new sensitive permissions |
| APK ZIP alignment | All three pass `zipalign -c -P 16 4` |
| Native ELF alignment | All 15 bundled `.so` files have LOAD alignment of 16 KB or 64 KB |
| Configured server health | Reachable; reports protocol 3, server `0.9.0-beta.1` |
| Native install/upgrade, runtime engine and 16 KB-device tests | Pending physical device/emulator |

The Node tests initially hit sandbox localhost-binding restrictions; they passed
when rerun with local listener permission. Flutter's Android doctor reports
missing command-line tools/unknown licence status; installed build tools/NDK are
present. Full Xcode/CocoaPods are unavailable; this is not an iOS release.

Signing certificate SHA-256:
`1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
This is a public certificate fingerprint, not signing-key material.

| APK architecture | Installed version code | Approximate size (decimal MB) |
| --- | ---: | ---: |
| ARM64 (`arm64-v8a`) | 2017 | 150.1 |
| ARMv7 (`armeabi-v7a`) | 1017 | 147.2 |
| x86-64 | 4017 | 151.7 |

ARM64 beta 1 used version code 2016 with the same signing certificate. Metadata
therefore permits an update, but actual install-over-old retention is still a
device acceptance item. The ARM64 APK is approximately 9 MB smaller than the
prior inspected build; the native Stockfish engine/model remains its largest
component. The older `build/app/outputs/flutter-apk/app-release.apk` is a stale
beta-1 artifact and is **not** part of this handoff. Use ABI-labelled beta-2 files.

## Known limitations testers must receive

- No cloud Crashlytics: Firebase Android registration/configuration is absent.
  Local diagnostics do not cover native crashes, hangs/ANRs, or hard process exits.
- No automatic feedback upload. Review and copy the report, then send it to your
  beta contact. Your typed description is not persisted in the app.
- Online server data is in memory and can reset on restart/redeployment. The
  backend has not been deployed or migrated by this APK preparation.
- Tournament points/trophies belong to the installation and are separate from
  online rankings. Uninstalling/clearing app data can remove local progress.
- No devices were connected, so actual upgrade retention, native engine loading,
  two-phone play, background recovery, battery use, and performance remain open.

Use [DEVICE_VALIDATION_CHECKLIST.md](DEVICE_VALIDATION_CHECKLIST.md) for acceptance
and [ANDROID_BETA_RELEASE.md](ANDROID_BETA_RELEASE.md) for packaging instructions.

## Handoff

Run `bash tool/package_android_beta.sh` after inspecting all three release APKs.
It creates `build/beta-0.9.0-beta.2+17/` with ABI-labelled APKs, these notes, the
device checklist, SHA-256 checksums, and a source snapshot of the current working
tree. Signing material, local configuration, generated caches, and dependency
install directories are excluded. Review the archive listing before distribution.
The script refuses to overwrite a previous handoff. Nothing is uploaded.
