# Third-Party Notices

This file records direct runtime dependencies. Transitive dependencies must be
reviewed from the generated Flutter lockfile before each release.

| Component | Purpose | License | Source |
| --- | --- | --- | --- |
| Flutter | Android/iOS application framework | BSD-3-Clause | https://github.com/flutter/flutter |
| dartchess | Chess rules, legal moves, FEN and SAN | GPL-3.0 | https://github.com/lichess-org/dartchess |
| Stockfish | On-device computer opponent | GPL-3.0 | https://github.com/official-stockfish/Stockfish |
| web_socket_channel | Flutter WebSocket client | BSD-3-Clause | https://github.com/dart-lang/http/tree/master/pkgs/web_socket_channel |
| app_links | Mobile game-invite deep links | Apache-2.0 | https://github.com/llfbandit/app_links |
| url_launcher | Open WhatsApp invitation links | BSD-3-Clause | https://github.com/flutter/packages/tree/main/packages/url_launcher |
| chess.js | Server-side chess validation | BSD-2-Clause | https://github.com/jhlywa/chess.js |
| ws | Node.js WebSocket server | MIT | https://github.com/websockets/ws |

The Flutter `stockfish` package is a mobile integration layer around the
Stockfish engine. Preserve its notices and the corresponding Stockfish source
offer when distributing binaries.

The concept image in `assets/concepts/` is a user-supplied reference previously
recorded as original project artwork. Its creator/source/permission evidence
is not recorded and must be confirmed before release clearance; see
`docs/ARTWORK_PROVENANCE.md`. The Classic Flat Club reference has the same
open provenance question. Project notices do not grant third-party character,
trademark or franchise rights, or resolve these input-origin questions.

The original Manga Vanguard pawn-duel asset is also distributed under
GPL-3.0-or-later. Its generation record is stored beside the image.

The three additional Animated worlds use original project-directed battlefield
and full-body character artwork, with built-in generation prompts recorded in
`docs/ANIMATED_ARMIES_ART_PROMPTS.json`. Their original synthesized film scores
and source generator are described in `docs/ANIMATED_ARMIES_ARTWORK.md` and are
distributed under GPL-3.0-or-later alongside the app.

The modular Chess Set Studio illustrations are original project-directed assets
distributed under GPL-3.0-or-later. Their generation prompts and local preparation
record are in `assets/custom_sets/modular-parts.asset.md`.

The custom multiplayer avatar illustrations are original, code-drawn vector
layers in `lib/src/features/online/custom_avatar_portrait.dart`, distributed
under GPL-3.0-or-later. They do not use an external avatar API, stock portrait
pack, downloaded photographs or an additional runtime dependency.

The kingdom and legendary-army expansion uses original project-directed
generated illustrations. Generation prompts and selected source/preparation
records are under `assets/characters/kingdoms/`. Historical reference reading
informs clothing descriptions; external museum/stock images are not included.
See `docs/ARTWORK_PROVENANCE.md` for the release-review safeguards. GPL notices
apply only to rights the project can grant; generation is not a warranty of
non-infringement or a claim of exclusive copyright in AI-generated elements.

Neon Dominion's live ready/attack companion atlases are original project-directed
assets made with the built-in image-generation tool. Existing cast references,
exact prompts, unchanged alpha and renderer preparation are recorded in
`docs/NEON_LIVE_POSE_ARTWORK.md` and `docs/NEON_LIVE_POSE_PROMPTS.json`.
They add no runtime dependency, external character pack or voice recording.

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
