# Milestone 4 Device Validation Checklist

Automated verification passes; every unchecked device item below remains pending.
The implementation must pass this gate before authentication, matchmaking, or
tournaments begin. Test two emulators first, then a mid-range Android phone and
an iPhone. Headless widget tests do not certify native builds or performance.

## Environment and builds

- [ ] Install Android SDK/emulators, full Xcode and CocoaPods as applicable.
- [ ] Resolve platform findings in `flutter doctor`.
- [ ] Run `npm --prefix server ci` and `flutter pub get`.
- [ ] Run `flutter analyze`, `flutter test --timeout 30s`, and
  `npm --prefix server test`.
- [ ] Run `flutter build apk --debug` and `flutter build ios --simulator --debug`.
- [ ] For a physical iPhone, select a development signing team in Xcode.

Android/iOS runners are included. Do not overwrite `lib/main.dart` with a new
Flutter template. The generated iOS deployment target is 15.0. Native plugin
integration, signing, app identifiers and icons still need device/release review.

## Start two clients

Terminal 1, project root:

```bash
npm --prefix server start
```

Start two AVDs using Android Studio, then use `flutter devices` to confirm IDs.
In terminals 2 and 3 (substitute actual IDs if different):

```bash
flutter run -d emulator-5554
```

```bash
flutter run -d emulator-5556
```

Both Android emulators use `ws://10.0.2.2:8080`. iOS simulators use
`ws://127.0.0.1:8080`. Physical devices must be on the same Wi-Fi and use the
computer's LAN IP. On this Mac, try `ipconfig getifaddr en0`. Use one
`flutter run -d <device-id>` process per phone.

Android debug/profile manifests include a network security configuration for
cleartext local development; the main manifest includes Internet permission.
iOS declares local network usage and a local-network ATS exception. Accept the
local-network prompt, and permit incoming Node connections on the computer.
Release/public services require `wss://` and real TLS.

Configuration references:
[Android network security configuration](https://developer.android.com/privacy-and-security/security-config),
[Apple local networking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking),
[Apple local-network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).

## Shared match acceptance

- [ ] Both users choose Play Online and Connect.
- [ ] First user creates a room and copies the Game ID; second user joins it.
- [ ] Both boards open automatically; White/Black are at their respective bottom.
- [ ] Opponent pieces and out-of-turn moves cannot be selected.
- [ ] Legal highlights appear immediately; a pending request does not move pieces.
- [ ] Play `e4`, `d5`, `exd5`; both boards/history agree and show the pawn capture.
- [ ] Capture Skip is immediately usable; opponent's clock runs during the battle.
- [ ] Disable Capture battles, then verify captures are immediate.
- [ ] Verify fast battles, manual reduced motion, and OS reduced-motion settings.
- [ ] Play `e4 e5 Nf3 Nc6 Bc4 Nf6 O-O` in a fresh round; castling is not animated
  as a capture and both positions agree.
- [ ] Play `e4 a6 e5 d5 exd6` in a fresh round; en passant removes the correct pawn.
- [ ] Reach promotion and test queen, rook, bishop and knight selection across games.
- [ ] Verify check labels, SAN history and identical terminal results.
- [ ] Resign, offer/decline a draw, offer/accept a draw, then request mutual rematch.
- [ ] A rematch resets clocks/history and preserves colours and Game ID.
- [ ] Complete a rematch using Fool's Mate: `f3 e5 g4 Qh4#`.
- [ ] Let a clock expire without moving; both clients receive timeout automatically.

## Recovery and input races

- [ ] Disable Wi-Fi on one phone for several seconds. Its input locks and recovery
  UI appears; the other phone's clock continues.
- [ ] Restore Wi-Fi. The same seat resumes, full sync completes, and both boards agree.
- [ ] Interrupt a move request. On recovery the move is committed at most once.
- [ ] Background/resume each app; synchronization completes before input unlocks.
- [ ] Leave a promotion chooser open through a timeout or opponent state update;
  no stale move is submitted.
- [ ] Restart the server and verify the missing-room error is visible. The client
  must not pretend it recovered a room that no longer exists.
- [ ] Returning to the lobby keeps the seat; returning home/closing the app forgets it.

## Offline and native regression

- [ ] Stockfish first move works without UI freeze or native plugin errors.
- [ ] Reset during engine thinking does not apply an old move.
- [ ] Leave/reopen computer mode; no singleton-engine errors occur.
- [ ] Legal local play, undo/reset, promotion, checkmate, stalemate and
  insufficient-material detection still work.
- [ ] Unicode chess glyphs, capture artwork, clock text and legal highlights are
  readable on both platforms and with larger accessibility text.
- [ ] Profile several consecutive captures on a mid-range Android device with
  `flutter run --profile -d <device-id>`; record frame timing and memory.

## Release gate

- [ ] Replace generated launcher placeholders with approved original app branding.
- [ ] Review all resolved and native dependencies, compiled fonts and engine notices;
  preserve corresponding source, attribution, source rigs and licence texts.
- [ ] Add suitable authentication, storage, rate limits and TLS before public hosting.
- [ ] Complete accessibility, lifecycle and performance checks and record device/OS
  versions, results and any failures in `MILESTONE_4_VALIDATION.md`.
