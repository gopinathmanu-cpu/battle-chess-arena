# Android beta release

Beta APKs use a private release key rather than Android's shared debug key. Keep
the keystore and `android/key.properties` outside source control and back them up
securely. Every update to an installed beta must be signed with the same key.
The shareable mobile beta application ID is
`com.manugopinath.battlechessarena.mobiletest`, with the launcher label
`Battle Chess Arena Beta`. It installs alongside the Play Store app,
`com.manugopinath.battlechessarena`. These are separate installations with
separate saved data; the beta cannot update the Play Store installation.

The local build expects `android/key.properties` with these entries:

```properties
storeFile=/absolute/path/to/upload-key.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Build architecture-specific, shareable APKs with:

```sh
flutter pub get
flutter analyze
flutter test
npm --prefix server test
ORG_GRADLE_PROJECT_mobileTestPackage=true flutter build apk --release --split-per-abi
```

For the current ARM64-only handoff, append `--target-platform android-arm64`.
The Gradle property selects the beta package and label. For a production Play
bundle, explicitly use the production identity:

```sh
ORG_GRADLE_PROJECT_mobileTestPackage=false flutter build appbundle --release
```

Confirm a production bundle's version code exceeds the highest version already
released on that Play app; the mobile beta's ABI version code belongs to its
separate package.

Verify the APK before distribution:

```sh
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
zipalign -c -P 16 -v 4 build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Back up the signing files before distributing the first APK. Losing the key
prevents future APKs from updating existing beta installations.

Choose `app-arm64-v8a-release.apk` for ARM64 phones, `app-armeabi-v7a-release.apk`
for supported 32-bit ARM devices, and `app-x86_64-release.apk` for x86-64
devices/emulators. Each is independently installable, not a dependent split-install
APK. Do not assume an emulator APK will work on a phone.

The current release is `0.9.0-beta.50+65`. Its final build and packaging checks are
recorded in [Beta 50 validation](BETA_50_VALIDATION.md). Flutter adds ABI offsets to split APK version codes;
ARM64 beta 1 used 2016, beta 2 used 2017, beta 3 used 2018, beta 4 uses 2019,
beta 5 uses 2020, beta 6 uses 2021, beta 7 uses 2022, beta 8 uses 2023,
beta 9 uses 2024, beta 10 uses 2025, beta 11 uses 2026, beta 12 uses 2027,
beta 13 uses 2028, beta 14 uses 2029, beta 15 uses 2030, beta 16 uses 2031,
beta 17 uses 2032, beta 18 uses 2033, beta 34 uses 2049, beta 35 uses 2050,
beta 36 uses 2051, beta 37 uses 2052, beta 38 uses 2053, beta 39 uses 2054, beta 40 uses 2055, beta 41 uses 2056, beta 42 uses 2057, beta 43 uses 2058, beta 44 uses 2059, beta 45 uses 2060, beta 46 uses 2061, beta 47 uses 2062, beta 48 uses 2063, beta 49 uses 2064, and beta 50 uses 2065.
Continue the same packaging scheme
when upgrading: switching to a universal APK with a lower version code can be
rejected as a downgrade. Confirm actual values with `aapt dump badging`. Do not
uninstall to work around a downgrade if saves matter.

## Tester experience and privacy

**About** shows the app version, description, and open-source licences. There
is no player-facing diagnostics or feedback section. Testers should share the
version, phone model, and reproduction steps directly with their release contact.

APK packaging does not deploy the match server. Fixed online bot levels require
the matching server source to be deployed separately. Local bot tournaments work
with this APK. Online data can reset on server restart; local tournament points
are not a server-backed account balance. Beta 12 adds revocable HTTPS WhatsApp
links with 24-hour expiry and Avatar-name fallback instructions. Direct links
and online colour toss need the updated server deployed separately. Without
its capability flags, the app shares Avatar-name-only instructions and disables
online toss. Link verification and two-phone acceptance remain pending.

## Distribution handoff

Provide matching source, checksums, release notes, and the
[device checklist](DEVICE_VALIDATION_CHECKLIST.md) alongside the APK. The public
repository link does not replace the exact source for uncommitted beta changes.
Exclude signing files, local configuration, caches, and credentials from source
archives and review their file lists before sharing.

Create the current ARM64 handoff with the exact working-tree source used to build
the APK, including uncommitted changes:

```sh
bash tool/package_android_beta.sh docs/BETA_50_VALIDATION.md arm64-v8a
```

The output is `build/beta-0.9.0-beta.50+65/`, containing the signed APK,
`corresponding-source.tar.gz`, `SHA256SUMS`, and handoff documentation. The source
archive includes the GPL app and bundled Stockfish source while excluding keys,
credentials, caches, and generated builds. Inspect its file list and verify
checksums before sharing the APK and corresponding source together.

[Firebase App Distribution](https://firebase.google.com/docs/app-distribution/android/distribute-console)
can deliver APKs after registering the Android app and selecting testers. Uploading
or inviting testers is a separate explicit release action, never automatic.
