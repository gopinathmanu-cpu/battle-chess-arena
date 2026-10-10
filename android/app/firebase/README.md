# Public Firebase app configuration

Android builds read `production.properties` for the Play Store package and
`mobiletest.properties` when `ORG_GRADLE_PROJECT_mobileTestPackage=true`.
These files contain the public Firebase app configuration, not service-account
credentials. The Android build generates the standard Firebase string resources
from them, so normal builds initialize the matching Firebase app automatically.

Each file has `projectId`, `senderId`, `appId`, and `apiKey` values downloaded
from that package's Firebase Android app registration. Do not use placeholder
values or include service-account keys here. If a file is absent, the game runs
with in-app and existing local notifications.

Explicit `FIREBASE_*` Dart defines can override these values for a different
Firebase project. See [the notification setup guide](../../../docs/ONLINE_GAME_NOTIFICATIONS.md).
