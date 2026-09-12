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

Build the shareable APK with:

```sh
flutter build apk --release
```

Verify the APK before distribution:

```sh
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Back up the signing files before distributing the first APK. Losing the key
prevents future APKs from updating existing beta installations.
