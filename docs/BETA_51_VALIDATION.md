# Beta 51 testing build

Built from the current workspace on 2026-10-04 with build-name override
`0.9.0-beta.51` and build number `66`. The source pubspec remains at the
previous Play release version; saved version 51 and 65 artifacts are preserved.

Package: `com.manugopinath.battlechessarena.mobiletest` (separate beta install).
Architecture: ARM64. Release signed with the existing upload key.

Includes all current Unreleased changes, including evenly spaced gameplay
header icons and a fixed credit counter with scrolling icons on narrow screens.

Verification: 64 focused gameplay/header widget tests passed; static analysis of
all four changed header-related files reported no issues. No physical-device
check has been performed for this build. See DEVICE_VALIDATION_CHECKLIST.md.

The waiting board and in-app game alerts are included. Closed-app push alerts
still require the pending Firebase project activation and server deployment.
