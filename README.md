# Battle Chess Arena · Milestone 4

An Android/iOS Flutter chess game with optional, short, skippable capture battles.
Original project code and visual assets are **GPL-3.0-or-later**; dependencies
retain their upstream licences. See [licensing](THIRD_PARTY_NOTICES.md).

Milestone 4 connects the online lobby to a playable authoritative board. Automated
client/server and widget verification passes. **Native two-device acceptance is
pending**. An ARM64 Android debug APK now builds with the installed Android SDK;
full Xcode and CocoaPods remain unavailable.
See [validation results](docs/MILESTONE_4_VALIDATION.md).

## Included

- Five character armies with sixty role/side portraits, themed boards and scenery,
  local rules and Stockfish play. Select a world at home, or use the palette button
  in a match to change White army, Black army, and Board world independently.
  Appearance choices apply to the current match on this device; they do not alter
  legal moves, player seats, or your opponent's appearance settings.
- Standard legal moves, castling, en passant, promotion choice, SAN history.
- Online quick matchmaking by time control, private create/join rooms, automatic
  board handoff, and assigned-colour orientation.
- Server-controlled moves, clocks, results, resign, draw offers and mutual rematch.
- Pending-move input lock, stale-state rejection, reconnect/resume/full sync.
- Copy Game ID for sharing; seat tokens remain private and in memory.
- Manga Vanguard pawn artwork for committed captures; symbolic fallback elsewhere.
- Optional, fast, reduced-motion and skippable online capture presentation.

## Development setup

Tested with Flutter **3.47.2**, Dart **3.13.2**, Node **24.14.0**. Node 22+ is
required. Android/iOS runner folders are now included. Do not recreate the app or
replace `lib/main.dart`.

Stockfish 1.8.1 is vendored in `third_party/stockfish` with Android build
compatibility fixes. Its upstream license is retained; see
`third_party/stockfish/LOCAL_CHANGES.md`. For a single ARM64 emulator, build with
`flutter build apk --debug --target-platform android-arm64` to avoid compiling
unused CPU architectures.

The SDK installed during this development session is at
`/Users/manugopinath/development/flutter`. For this machine:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter doctor
npm --prefix server ci
flutter pub get
flutter analyze
flutter test --timeout 30s
npm --prefix server test
npm --prefix server audit --omit=dev
```

Install the Android SDK/emulator with Android Studio, or full Xcode and CocoaPods
for iOS, then resolve the corresponding `flutter doctor` findings. The Flutter
suite includes a real Node-server integration test, so install server dependencies
before running the full suite. No web build is supported by the current chess and
Stockfish dependencies.

## Test two Android emulators

Start two Android virtual devices in Android Studio. Confirm their IDs with
`flutter devices`. With the usual IDs, use three terminals from the project root:

```bash
# Terminal 1: keep the development server running.
npm --prefix server start
```

```bash
# Terminal 2
flutter run -d emulator-5554
```

```bash
# Terminal 3
flutter run -d emulator-5556
```

On both apps choose **Play Online**, use `ws://10.0.2.2:8080`, and **Connect**.
Create a game on the first app, use **Copy Game ID to share**, paste it on the
second app, and join. Both boards open automatically. Play `e4`, `d5`, `exd5` to
check the pawn battle, then test draw acceptance and rematch.

For iOS simulators use `ws://127.0.0.1:8080` and the simulator IDs reported by
`flutter devices`. On two physical phones, use the computer's LAN endpoint, for
example `ws://192.168.1.20:8080`, on the same Wi-Fi. On this Mac,
`ipconfig getifaddr en0` reports the Wi-Fi address when Wi-Fi uses `en0`.
Run `flutter run -d <device-id>` in one terminal per device, replacing the IDs.
Allow the iOS local-network prompt and local Node traffic through the computer's
firewall. Use debug builds for the local `ws://` server.

The [device checklist](docs/DEVICE_VALIDATION_CHECKLIST.md) contains the remaining
acceptance steps and platform configuration details.

## Free hosted multiplayer testing

The root [`render.yaml`](render.yaml) defines a single free Render web service
in Singapore. Render supplies the public `https://`/`wss://` hostname and TLS;
the Node process exposes `GET /health` and uses the same port for WebSockets.
Follow the [Render deployment guide](docs/RENDER_DEPLOYMENT.md), then build the
mobile app with the exact hosted endpoint:

```sh
flutter build apk --release \
  --dart-define=ONLINE_SERVER_URL=wss://YOUR-SERVICE.onrender.com
```

Free instances sleep after 15 minutes without inbound HTTP or WebSocket traffic.
The first connection after sleep can take about a minute. Active clients exchange
heartbeats. Room state remains in memory and is lost if Render restarts the
instance, so this configuration is intended for testing rather than production.

## Scope and recovery limits

Keep the lobby open to retain your seat. Network loss reconnects automatically;
returning home or closing the process forgets the token. Server restarts lose all
rooms. Rematches keep the same colours and room ID. This server is for local
reference testing, not public hosting. See [protocol v2](docs/ONLINE_PROTOCOL.md)
for validation, idempotency, clock semantics, and production requirements.

The next gate is native two-device verification, including Stockfish and capture
performance. Authentication, durable storage, matchmaking and tournaments remain
future work in the [product blueprint](docs/PRODUCT_BLUEPRINT.md).

## Theme atmosphere

Home, online lobby, and game pages show the selected world backdrop. In a match, **Armies & board → Board world** controls the scenery and soundtrack independently of either army. Five original synthesized instrumental loops are bundled for offline playback. The speaker button mutes/unmutes music across screens; the preference survives app restarts. Music pauses when the app is inactive and resumes only if unmuted. These are synthesized ambient motifs, not recorded orchestral performances.

Music source and regeneration notes: [assets/audio/README.md](assets/audio/README.md). Playback uses [audioplayers](https://pub.dev/packages/audioplayers); upstream notices are retained in `docs/licenses/`.

In phone landscape orientation, local/computer and online matches keep the
entire square board visible on the left. Clocks, status, match options, and
move history appear in a scrollable panel on the right.

Use the up arrow in a match top bar to hide it and give the board more room.
The small down-arrow button over the page restores the full top bar and its
music, appearance, undo, reset, and online controls.

## Browser development

Run the game in Chrome with WebAssembly:

```sh
/Users/manugopinath/development/flutter/bin/flutter run -d web-server --wasm --web-hostname 127.0.0.1 --web-port 7357
```

Then open `http://127.0.0.1:7357`. Browser computer games use the bundled
pure-Dart legal opponent because the native Stockfish FFI library cannot load
in a browser. Android continues to use Stockfish. The current `dartchess`
dependency supports native targets only, so use `flutter run ... --wasm` for
local browser testing; a deployable cross-browser release needs a web-capable
chess-rules package.
