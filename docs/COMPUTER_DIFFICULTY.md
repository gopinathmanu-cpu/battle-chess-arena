# Computer difficulty

Ordinary Play Computer matches use these native Stockfish presets:

| Difficulty | Skill fallback | Maximum depth | Requested Elo | Move time limit |
| --- | ---: | ---: | ---: | ---: |
| Easy | 0 | 2 | 800, only if supported | 250 ms |
| Medium | 6 | 7 | 1400, only if supported | 650 ms |
| Hard | 20 | 18 | 2500, only if supported | 2500 ms |

The client reads the engine's advertised UCI options before searching. Elo
limiting takes precedence over Skill Level; these are alternative strength
controls, not additive ones. The bundled engine supports Elo 1320–3190, so Easy
uses Skill 0 with Elo limiting disabled. It never clamps 800 upwards to 1320.
Medium and Hard enable their supported Elo targets. Engines without Elo support
use the skill fallback. Every search explicitly resets supported strength
controls and clears search history, including after a stronger move suggestion.

Search ends at the depth or time limit, whichever is reached first. Hard may
therefore finish below depth 18 on slower phones. These settings are tuning
targets, not measured FIDE or online ratings; depth and time limits also affect
strength. Beginner playtesting remains necessary to assess how forgiving Easy
feels. An exact 800-rated opponent is not claimed.

Named bots use their own fixed [levels 1–20](BOT_TOURNAMENTS.md), independent of
these presets. In native tournament play, bot levels map to Skill 0–20, depth
2–18, and 250–2625 ms per move. Elo limiting is disabled for named bots so it
cannot override their skill. The tier remains in saved games for compatibility;
actual strength is resolved from the opponent's stable catalog entry on resume.
Move suggestions use Hard regardless of the selected opponent difficulty.
Browser play and native-engine failure retain the existing Dart fallback, whose
search and move selection are separate and have no Stockfish Elo calibration.
The Dart fallback uses the bot's fixed level to select search depth and reduce
random mistakes as level rises. Online bots also use their fixed level, resolved
from the server's persona ID, with decreasing random mistakes and reply search
from level 8. The server uses its lightweight move selector rather than native
Stockfish; equal level numbers across engines do not imply measured equal Elo.
Human-versus-human games are unaffected.

See the [Stockfish UCI documentation](https://official-stockfish.github.io/docs/stockfish-wiki/UCI-Protocol-and-Stockfish-Commands.html)
for strength option precedence, capability negotiation, and search limits.
