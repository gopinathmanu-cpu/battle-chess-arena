# Android beta release

Beta APKs use a private release key rather than Android's shared debug key. Keep
the keystore and `android/key.properties` outside source control and back them up
securely. Every update to an installed beta must be signed with the same key.
The beta application ID is `com.manugopinath.battlechessarena`.

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
flutter build apk --release --split-per-abi
```

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

The current release is `0.9.0-beta.36+51`. Flutter adds ABI offsets to split APK version codes;
ARM64 beta 1 used 2016, beta 2 used 2017, beta 3 used 2018, beta 4 uses 2019,
beta 5 uses 2020, beta 6 uses 2021, beta 7 uses 2022, beta 8 uses 2023,
beta 9 uses 2024, beta 10 uses 2025, beta 11 uses 2026, beta 12 uses 2027,
beta 13 uses 2028, beta 14 uses 2029, beta 15 uses 2030, beta 16 uses 2031,
beta 17 uses 2032, beta 18 uses 2033, beta 34 uses 2049, beta 35 uses 2050,
and beta 36 uses 2051.
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

[Firebase App Distribution](https://firebase.google.com/docs/app-distribution/android/distribute-console)
can deliver APKs after registering the Android app and selecting testers. Uploading
or inviting testers is a separate explicit release action, never automatic.
