# Conquests

Home has separate **Tournaments** and **Conquests** entries. The three original
proficiency cups and 20 fixed-strength bots are unchanged. Conquest scores do
not contribute to tournament cup scores.

Four routes provide different campaign lengths: Indo-Arabian Conquest has 3
matches, European Conquest has 5, Asian Conquest has 10, and World Conquest is
the full 19-army historical catalog. Each round's named opponent supplies the
Black army and default board, while White starts with the player's selected
themed army. Swipes and appearance settings may change only the player's White
army; the opponent's Black army is visibly locked to that round, including when
an older save resumes. The player can still toggle both sides to Classic pieces
and back without losing the locked themed opponent. Global custom artwork does
not override conquest armies. Conquest players are always White and rounds use
Rapid 15+10, so colour toss is not offered.

Within every route, opponents are ordered by an approximate smallest-to-largest
ranking of the peak forces their historical counterparts could mobilize. Exact
cross-era headcounts are too disputed to display as fact, so the game uses a
stable relative order rather than invented troop totals. Since conquest bot
strength rises after each won round, the largest imperial armies occupy the
latest and toughest stops. The full route culminates with the Roman Empire and
Chinese Imperial Court.

World Conquest retains the original `history-conquest-v1` save identity, so a
saved History Conquest continues under the new name without losing progress.

Opening or continuing a conquest always shows its roadmap before play. The map
reveals every opponent, marks conquered/current/upcoming realms, and offers the
button for the next match or saved-match resume. Returning from a match also
lands on this roadmap.

Win to unlock the next army. Losses and draws retain conquered realms and allow
unlimited rematches. This is a sequential campaign, not a simulated knockout
bracket. Army artwork and chess matchups remain historical interpretations
rather than simulations.

## Adaptive practice level

All conquests share one local player estimate, initially 6/20. A win adds one,
a loss subtracts one and a draw leaves it unchanged, bounded to 1–20. The next
opponent target is the rounded estimate plus 0.35 per conquered realm, capped
to 1–20. A loss always lowers the previous attempt by at least one (floor 1);
a win raises it by at least one (ceiling 20); a draw retains the previous level.
The estimate is a practice tuning value, **not measured Elo**. Assists are allowed
and assisted results count; this is adaptive entertainment, not skill certification.

The level is snapshotted when an attempt begins and never changes mid-game or
on resume, even if the other campaign changes the shared estimate. Existing
BotStrength mapping controls Stockfish skill, depth and time, and fallback
search depth/mistake probability. Easy/Medium/Hard settings and the original
persona levels are not changed by this system.

Conquest progress and the estimate are stored together in `conquest_player_v1`
in local preferences. Serialized writes and attempt guards prevent duplicate
result callbacks from awarding progress or updating strength twice. The profile
is for the local installation, not a cloud/account rating; clearing app data
resets it. No online games or ordinary computer games affect it.
