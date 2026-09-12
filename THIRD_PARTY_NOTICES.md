# Third-Party Notices

This file records direct runtime dependencies. Transitive dependencies must be
reviewed from the generated Flutter lockfile before each release.

| Component | Purpose | License | Source |
| --- | --- | --- | --- |
| Flutter | Android/iOS application framework | BSD-3-Clause | https://github.com/flutter/flutter |
| dartchess | Chess rules, legal moves, FEN and SAN | GPL-3.0 | https://github.com/lichess-org/dartchess |
| Stockfish | On-device computer opponent | GPL-3.0 | https://github.com/official-stockfish/Stockfish |
| web_socket_channel | Flutter WebSocket client | BSD-3-Clause | https://github.com/dart-lang/http/tree/master/pkgs/web_socket_channel |
| chess.js | Server-side chess validation | BSD-2-Clause | https://github.com/jhlywa/chess.js |
| ws | Node.js WebSocket server | MIT | https://github.com/websockets/ws |

The Flutter `stockfish` package is a mobile integration layer around the
Stockfish engine. Preserve its notices and the corresponding Stockfish source
offer when distributing binaries.

The concept image in `assets/concepts/` is an original project asset distributed
under GPL-3.0-or-later. It must not be interpreted as granting rights to any
third-party character, trademark, or franchise.

The original Manga Vanguard pawn-duel asset is also distributed under
GPL-3.0-or-later. Its generation record is stored beside the image.

## Milestone 4 resolved dependencies and generated runners

No new runtime dependency or imported character artwork was added. Flutter
3.47.2 generated the Android/iOS runner templates and placeholder launcher assets
from the [Flutter source repository](https://github.com/flutter/flutter/tree/3.47.2),
under Flutter's BSD-3-Clause licence (Flutter Authors). These placeholders need
original release branding; they are not part of the character pack.

The `stockfish` Flutter integration package **1.8.1** itself is GPL-3.0, from
[Arjan Aswal's repository](https://github.com/ArjanAswal/stockfish). Its bundled
engine source and all notices must accompany the corresponding-source release.
`dartchess` resolves to 0.13.1, `web_socket_channel` to 3.0.3, `chess.js` to 1.4.0,
and `ws` to 8.21.3. The installed Node package licences were inspected directly.

The [resolved licence inventory](docs/DEPENDENCY_LICENSES.md) records direct,
transitive, development and SDK packages. Complete upstream copyright/licence
texts and hashes are preserved in `docs/licenses/`, including Flutter's combined
engine notices. Regenerate using `python3 tool/collect_licenses.py` after installing
dependencies. The common Dart package licences in this lockfile are BSD-3-Clause,
Apache-2.0 and GPL-3.0. SDK engine notices cover multiple upstream components;
review the actual native distribution and corresponding-source bundle before
shipping, as required by `OPEN_SOURCE_POLICY.md`.

Prettier 3.6.2 ([source](https://github.com/prettier/prettier/tree/3.6.2), MIT,
Prettier contributors) was used as a development formatting tool via `npm exec`;
it is not bundled as an app or server dependency. No font/audio/rig asset was
added to the app. Original pawn artwork and its generation record are unchanged.
