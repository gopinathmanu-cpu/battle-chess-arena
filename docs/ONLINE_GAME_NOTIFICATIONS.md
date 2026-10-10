# Online game alerts

The inviter can enter a read-only board immediately after sending a Play Now
invitation, or tap their pending invitation later. Shared WhatsApp invitations
also offer a **Wait at the chessboard** action. Acceptance announces the
opponent with a notification sound, then opens the actual server game after two
seconds. No moves are possible on the waiting board. The server starts the
clock on acceptance; the preview does not create a second game or clock.

An app-level account connection listens for all the player's game activity,
even outside Online Play. New games and opponent moves in another game create
a bell with a count at the bottom right. Tapping a listed update opens that game
through the authenticated account. Your own moves and updates to the board
already on screen are silent. Alerts are coalesced by game and deduplicated by
accepted game state. Scheduled reminders retain the existing local scheduler.

The existing Online Play **Mobile notifications** setting remains opt-in and
remembered. Local notifications work while the app process and account connection
are running. Receiving new game events after the app is suspended or closed
requires Firebase Cloud Messaging configuration described below. This repository
has the optional client/server integration, but no mobile Firebase app registration
values are configured or deployed by this change.

## Activate Firebase Cloud Messaging

The network deployment guide identifies the existing Firebase/Google Cloud
project as `battechessarena`. Verify that project in your console before using it.
You can register the mobile app in this existing project.

The repository includes a read-only configuration check:

```sh
python3 tool/configure_firebase_push.py --project battechessarena
```

After approving project activation and Android app registration, add `--apply`.
The helper uses the signed-in Google Cloud CLI account, activates Firebase if
needed, registers both Android packages, and saves their public configuration
under `android/app/firebase/`. OAuth tokens are not written or printed.
Normal Android builds then pick the configuration matching the package, and
Firebase initializes from the generated Android resources. Dart defines remain
available as an override for other projects or iOS builds.

1. In Firebase Console → Project settings, register the Android package
   `com.manugopinath.battlechessarena`. Register
   `com.manugopinath.battlechessarena.mobiletest` separately if testing the beta
   package. Use each package's matching Firebase app ID.
2. Supply the public Firebase configuration to Flutter (for example with a local
   `--dart-define-from-file` JSON file):

   ```json
   {
     "FIREBASE_API_KEY": "your-public-firebase-api-key",
     "FIREBASE_APP_ID": "1:your-project-number:android:your-app-id",
     "FIREBASE_MESSAGING_SENDER_ID": "your-project-number",
     "FIREBASE_PROJECT_ID": "your-project-id"
   }
   ```

   The app can initialize Firebase from these overrides; no Google Services Gradle
   plugin is required. These client values are not server credentials. Never
   put a service-account private key in the app or in this file.
3. Enable the Firebase Cloud Messaging HTTP v1 API on the project. Grant the
   Cloud Run runtime service account `roles/firebasecloudmessaging.admin`
   (or a custom role with `cloudmessaging.messages.create`) on this project.
4. Deploy the prepared server with `FCM_PROJECT_ID=your-project-id`, retaining
   its existing Firestore environment variables. `GamePushSender` uses the
   runtime service identity via the Google metadata service. No private key is
   stored in the repository. Device registrations persist in the same durable
   checkpoint as player profiles. Notifications are delivered only after a
   successful game-state save.
5. Build/install the newly configured app, enable **Mobile notifications**,
   and grant OS permission. An unconfigured build continues to support the
   waiting board and in-app notifications. A configured server advertises
   `game_push`; legacy servers retain local notification behavior.

For iOS, register the matching bundle ID, use its iOS Firebase app ID, enable
Push Notifications and the Remote notifications background capability, and
upload an APNs authentication key to Firebase. This change does not provision
Apple signing capabilities or APNs credentials. Notification display payloads
allow the OS to show updates in the background, and tapping uses FCM's initial
message / opened-message stream to navigate to the game.

## Verification on two real phones

- Send a named invite and stay at the waiting board: no moves or timer decrement
  on the preview; acceptance shows arrival once with sound and opens the correct
  board. Declined, deleted and expired invites show their final state.
- Leave Online Play and open a computer or Tournament game: an opponent move in
  the online game shows the bottom-right bell; its item opens the correct seat.
- Stay in the relevant online game: your own moves and incoming updates do not
  produce a second app-level alert.
- Enable notifications, background the app, then lock or close it normally:
  opponent arrival and moves show an OS notification; tapping reopens that game.
- Disable notifications and verify OS alerts stop; in-app game updates remain
  available. Test reconnect and repeated commands without duplicate alerts.
- Android force-stop and iOS force-quit restrictions can prevent delivery until
  the app is opened again. Respect OS notification settings and sound/DND rules.

References: [Flutter FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[Receiving messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api).
