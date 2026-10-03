# Battle Chess Arena · 0.9.0 Beta 14

An Android/iOS Flutter chess game with optional, short, skippable capture battles.
Original project code and visual assets are **GPL-3.0-or-later**; dependencies
retain their upstream licences. See [licensing](THIRD_PARTY_NOTICES.md).

The Beta 14 testing handoff targets ARM64 Android phones. Automated
client/server tests, signature checks, and static 16 KB alignment checks are
recorded with the handoff.
**Native two-device and install-over-old acceptance remain pending**; full Xcode
and CocoaPods are unavailable. See [current beta validation](docs/BETA_14_VALIDATION.md).
The new online invite links, expiry, and colour toss require a separate server
deployment; building an APK does not deploy the server.

## Included

- **Custom multiplayer avatars** combine hairstyles/colours, skin tones, face
  shapes, facial hair, glasses/shades, outfits and backgrounds, with child,
  teen, adult and senior appearances. Open **Play Online → Create your avatar**
  in profile setup or editing. See [the avatar guide](docs/CUSTOM_AVATARS.md).
  This next-build feature needs an updated app and online service for opponents
  to see custom portraits; the packaged Beta 14 APK predates it.
- **Chess Set Studio** lets you select complete fitted role formations from the
  themed worlds, colour the board, choose a background and save named sets locally.
  Mounted and chariot pieces keep their rider, orientation and proportions intact.
  Open it from Home or Game settings. See [the studio guide](docs/CUSTOM_CHESS_SETS.md).
  This is a next-build feature in the source; the packaged Beta 14 APK predates it.
- **About** provides the app version and licence/source information, without
  player-facing diagnostics. Send testing notes directly to your release contact.
  Beta upgrades preserve earlier saves. See the [Android beta guide](docs/ANDROID_BETA_RELEASE.md)
  and [device checklist](docs/DEVICE_VALIDATION_CHECKLIST.md).
- Thirty-one character armies with 372 role/side portraits, themed boards and scenery,
  local rules and Stockfish play. Select a world at home, or use **Game settings →
  Armies & board** to change White army, Black army, and Board world independently.
  Themed bishops ride elephants and themed rooks ride matching chariots.
  Home filters Fantasy, Historical and Legendary sets; all four Classic options
  remain available. Small Home previews show artwork without covering it with
  role-letter badges. See [kingdom sets](docs/KINGDOM_CHESS_SETS.md) and
  [artwork provenance](docs/ARTWORK_PROVENANCE.md). This expansion is a next-build
  feature; the packaged Beta 14 APK predates it.
  Appearance choices apply to the current match on this device; they do not alter
  legal moves, player seats, or your opponent's appearance settings.
- Standard legal moves, castling, en passant, promotion choice, SAN history.
- A single **Game settings** gear keeps appearance, sound, difficulty, and
  animation controls off the play surface. The scrollable panel opens only on
  request, is available with the top bar hidden, and does not pause timed games.
- A compact **Captured pieces** box shows actual victims for both sides, using
  the selected armies or standard pieces. It handles promotion, en passant,
  undo, saved games, and complete online reconnect history. **Game settings →
  Show captured pieces** saves the show/hide choice on this device across modes.
- Free **Analyse attack threats** cycles through the opponent's legal captures
  in the current position, blinking attacker/victim squares red for three seconds
  each. It does not spend lifelines, pause clocks, or predict your next move.
  Reduced motion keeps highlights steady; moves, backgrounding, and disconnects
  cancel the scan. Kings are handled by the existing check indicator, not captures.
- An in-match **Standard chess pieces** switch replaces the character armies
  with bundled Staunton artwork. Move history is shown as a numbered
  White/Black table, the opponent's last move survives game resume, and a
  compact clock and status indicators identify whose turn it is without tinting
  or glowing around the full board.
- A simplified online lobby with level-aware quick matchmaking, exact Avatar ID
  search, server-listed active games, and one-tap game resume. Players choose
  Beginner, Intermediate, or Advanced; Quick Game prefers that level and widens
  the search after 15 seconds.
- Twenty fictional built-in opponents with globally varied real-style names and
  Beginner, Intermediate, or Advanced proficiency. When no person is available,
  players can select one from the online lobby; its moves remain server-authoritative.
- Three offline bot tournaments split those 20 avatars by proficiency: Rising
  Knights Cup, Tactician Cup, and Mastery Cup. Play quarterfinals, semifinals,
  and a final; resume saved rounds or retry losses/draws against the same opponent
  without losing earlier wins. Follow an illustrated trophy trail, earn 100/200/300
  local tournament points per Beginner/Intermediate/Advanced win, and celebrate
  championships with fireworks, confetti, and applause. See
  [bot tournaments](docs/BOT_TOURNAMENTS.md).
- A separate **Conquests** home entry offers **Indo-Arabian** (3 matches),
  **European** (5), **Asian** (10), and full **World Conquest** (19). Matching army chess sets,
  saved campaign progress and a shared local adaptive practice level adjust
  the next challenge after wins or losses without altering fixed-level bots.
  See [Conquests](docs/CONQUESTS.md).
- Online play uses the authoritative server deployed to Cloud Run in the
  Firebase project, with automatic reconnect and scale-to-zero configuration
  for cost-conscious testing.
- **Arena Credits** start at 300 and apply only when a server-hosted round
  actually starts: 2 per live human round, 3 per Daily human round, or 4 per
  server-computer round. Meaningful completions and a capped daily Top-up keep
  casual play sustainable; all offline play, discovery, invitations,
  reconnects, Conquests, tournaments, customization and on-device assists
  remain free. A single gold-coin balance stays in the global header and each
  charged action shows the same coin with its exact cost. Confirmed balance
  changes animate and play a short mute-aware coin chime. A server-authorized
  online Move suggestion costs 1 credit.
  Checkout is deliberately disabled until verified store billing and stronger
  account storage are in place. See the [credit economy](docs/ARENA_CREDITS.md).
- Unique, editable Avatar IDs with 50 diverse human face portraits, multiple open opponents, a
  ranked leaderboard, and permanent completed-game history cards marked Won,
  Lost, or Draw. Invitations can be removed from the player's own list. Wins
  award three points and draws award one.
- A bottom-of-lobby **Your Chess Circle** keeps saved online players in Family,
  Friends and Professionals sections, with online/offline presence, immediate
  invitations, moving/removal controls and private on-device persistence.
  Existing favourites migrate to Friends. Invitations also support exact
  date-and-time scheduling, alternating counter-proposals, acceptance status,
  and persistent in-app reminders.
- New computer games and tournament rounds default to Rapid 15+10 (15 minutes
  per player, plus 10 seconds after each legal move). Computer setup also offers
  Untimed Practice. Existing saved games retain their original clock rules.
- Friend invitations default to Daily, 24 hours per move, with live Rapid 15+10
  and Classical 30/60 minute alternatives. Daily requires the updated service
  with durable storage enabled; see [clock rollout](docs/GAME_CLOCKS.md).
- Server-controlled moves, clocks, results, resign, draw offers and mutual rematch.
- Pending-move input lock, stale-state rejection, reconnect/resume/full sync.
- Copy Game ID for sharing; private seat tokens are never included in share links.
- Manga Vanguard pawn artwork for committed captures; symbolic fallback elsewhere.
- Optional, fast, reduced-motion and skippable online capture presentation.
- Unlimited move suggestions, with quick Suggest/Threat icons beside game
  settings. Online suggestions still require your turn and the updated server;
  highlights last ten seconds or until the board is tapped.
- Swipe left/right on the game board to browse the selected Classic/Themed
  family without moving a piece. Saved local/tournament games keep their set;
  online rooms remember it separately per seat on this device.
- Home settings provide music, display preferences, Classic/Themed selections
  and reset. Computer-game headers reserve their space for quick actions;
  New game and Hide top bar are available in settings.
- Capture cinematics are sequenced with at least two seconds of clear board time
  between consecutive battles.
- Result presentation for local and online games, with full-screen ambient victory
  graphics and a short original applause effect that follows the mute setting.
- A lightning-split Classic-versus-Black-Themed knight launcher icon,
  over a faint golden standard chess set and board. The large, shining knight
  remains the focus. Native Android/iOS sizes share one master asset.

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
Release signing and repeatable beta builds are documented in the
[Android beta release guide](docs/ANDROID_BETA_RELEASE.md).

## Firebase network play

**Play Online** connects to the containerized match server running on Cloud Run
in the Firebase project. To deploy it to another project, use the helper script:

```sh
gcloud init
./tool/deploy_firebase_network.sh YOUR_FIREBASE_PROJECT_ID
```

The repository is configured with the deployed `battechessarena` endpoint, so a
normal `flutter build apk --release` is ready for online play. The script also
prints a command that overrides `ONLINE_SERVER_URL` for another deployment.

See the [Firebase network deployment guide](docs/FIREBASE_NETWORK_DEPLOYMENT.md)
for the cost-efficient Cloud Run settings, connectivity tradeoffs, and health
check steps.

## Scope and recovery limits

Network loss reconnects automatically. Rematches keep the same colours and room
ID. This server remains a reference test deployment rather than a production
service. See [protocol v2](docs/ONLINE_PROTOCOL.md) for validation, idempotency,
clock semantics, identity, invitations, and recovery requirements.

Version 0.6.0 persists player and seat tokens in device preferences, so returning
home or restarting the app can reopen recorded games. Cloud Run currently stores
rooms, unique-name registrations, and leaderboard points in server memory. A
container restart removes that server-side state; durable cloud recovery requires
a database before production launch.

The next gate is native two-device verification, including Stockfish and capture
performance. Authentication, durable storage, matchmaking and tournaments remain
future work in the [product blueprint](docs/PRODUCT_BLUEPRINT.md).

## Theme atmosphere

Home, online lobby, and game pages show the selected world backdrop. In a match, **Armies & board → Board world** controls the scenery and soundtrack independently of either army. All 31 themed sets have distinct compact, project-original synthesized loops bundled for offline playback. The speaker button mutes/unmutes music across screens; the preference survives app restarts. Music pauses when the app is inactive and resumes only if unmuted. These are sample-free synthesized ambient cues, not recorded or copied performances.

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
