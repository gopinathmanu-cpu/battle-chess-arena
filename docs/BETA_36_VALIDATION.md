# Battle Chess Arena Beta 36 testing handoff

Version: `0.9.0-beta.36+51` · expected ARM64 split APK version code: `2051`.

## Included changes

- Light Purple is the default launcher icon for new installations and settings
  reset.
- Settings > Appearance includes a visual App icon picker with Light Purple and
  Classic Gold choices.
- The selected Android launcher icon is persisted across app restarts.
- Includes all Beta 35 application palette, server, artwork, credit, online and
  audio lifecycle work.

## Verification

- Focused app-icon source analysis: passed with no issues.
- Android release compilation and packaged manifest checks: passed.
- Full Flutter analysis: passed with no issues.
- Settings suite: 5 passed; the documented unrelated online reconnect
  `pumpAndSettle` timeout remains.

## APK verification

- [x] Signed ARM64 APK built: 200,233,003 bytes.
- [x] Package `com.manugopinath.battlechessarena.mobiletest`, label
  `Battle Chess Arena Beta`, min API 24, target API 36, version code `2051`,
  and version name `0.9.0-beta.36` verified.
- [x] Packaged manifest contains both launcher aliases; Light Purple is enabled
  and Classic Gold is available for in-app selection.
- [x] APK signature verified. Certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] Static 16 KB ZIP alignment verified.
- [x] APK SHA-256:
  `4ed283217b6b3a17b6967f57f03e31eb5e2d7f14f5f73ab0d30a6edbe3e499e7`.

## Testing limitation

Physical-device switching between both launcher icons remains pending. Some
Android launchers can take a few seconds to refresh an icon after selection.
