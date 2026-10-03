# Built-in bot tournaments

Open **Tournaments** from the home screen. Three cups divide the existing
20 computer avatars by their declared proficiency:

| Cup | Proficiency | Bots | Entrants including you |
| --- | --- | ---: | ---: |
| Rising Knights Cup | Beginner | 7 | 8 |
| Tactician Cup | Intermediate | 7 | 8 |
| Mastery Cup | Advanced | 6 | 7 |

Each cup uses an eight-seat knockout bracket: quarterfinal, semifinal, final.
Mastery Cup gives one bot a first-round bye. The human always has a real
opponent and plays White by default, or can enable **Toss for colours** before
starting a round. The result is shown and saved before play, so resuming does
not reroll. Each side starts with ten minutes and three lifelines.
Each bot has its own fixed level, independent of the user's Easy/Medium/Hard
selection. Beginner bots occupy levels 1–7, Intermediate 8–14, and Advanced 15–20.
Native strength, fallback strength, and online move selection use this fixed
assignment. See [engine settings](COMPUTER_DIFFICULTY.md) for the differences
between native and online engines; these are game levels, not measured Elo.
The normal fallback engine remains available if native Stockfish cannot run.

| Level | Bot | Tier |
| ---: | --- | --- |
| 1 | Amina Diallo | Beginner |
| 2 | Lucas Martin | Beginner |
| 3 | Mei Lin | Beginner |
| 4 | Omar Haddad | Beginner |
| 5 | Sofia Rossi | Beginner |
| 6 | Kwame Mensah | Beginner |
| 7 | Ana Costa | Beginner |
| 8 | Priya Nair | Intermediate |
| 9 | Diego Alvarez | Intermediate |
| 10 | Haruto Sato | Intermediate |
| 11 | Nadia Petrova | Intermediate |
| 12 | Thandi Ndlovu | Intermediate |
| 13 | Noah Williams | Intermediate |
| 14 | Fatima Zahra | Intermediate |
| 15 | Arjun Mehta | Advanced |
| 16 | Elena Popescu | Advanced |
| 17 | Mateo Silva | Advanced |
| 18 | Min Jun | Advanced |
| 19 | Emma Clarke | Advanced |
| 20 | Ivan Petrov | Advanced |

Assignments are explicit and remain stable on resume and rematch. Tournament
and online opponent pickers show both proficiency and level. Shipping these
changes requires an updated app and a deployment of the updated match server.

Winning advances one round. Losing (including resignation or timeout) leaves
that round available for unlimited rematches against the same opponent. Draws
also require a replay. Earlier wins stay saved, and opponents are not shuffled
on a retry. Checkmate, stalemate, insufficient material, threefold repetition,
and the fifty-move rule are handled. Undo and difficulty changes are disabled
inside a tournament match.

Other bot matches are simulated, labelled as such in the bracket, and fixed by
the run's saved seed. They are not background engine games. Future rounds remain
locked until the player wins the current round. Winning the final saves the cup's
champion status and full attempt history.

## Journey, celebrations, and player points

Each cup has a visual trophy trail with opponent portraits, completed-round
checkmarks, an animated progress path, and locked future rounds. The home screen
and tournament lobby show your total tournament points and trophy count.
Winning the final opens a championship ceremony with a laurel trophy, fireworks,
confetti, and applause. The trophy screen can replay the ceremony without
awarding more points. Animation finishes after seven seconds; reduced-motion
settings show a static celebration instead, and applause respects audio mute.

| Proficiency | Points per round win | Points for all three wins |
| --- | ---: | ---: |
| Beginner | 100 | 300 |
| Intermediate | 200 | 600 |
| Advanced | 300 | 900 |

Every round victory, including a win after a rematch or opponent timeout, earns
the cup's reward. Losses, draws, unfinished games, and simulated bot matches earn
no points and never deduct earlier rewards. The final earns the same round-win
reward, not an additional completion bonus.

Points are derived from the saved round victories: saving a result twice,
reopening the app, or replaying a ceremony cannot duplicate them. Existing saved
victories receive credit automatically. There is no separate balance that can
get out of sync with the bracket. Completing all current cups earns 1,800 points
and three trophies. These personal tournament points are separate from online
leaderboard points and are lost if this installation's app data is cleared.

## Saving and resuming

Each cup has its own local save containing the bracket seed, results, attempt
number, and any unfinished game. Move history, remaining clocks, appearance,
and lifelines resume together. Saving a tournament does not modify the regular
Play Computer/Local saved game or the online game history. Clocks pause while
the match is closed or the app is in the background. Moves, periodic clock
updates, app backgrounding, and leaving the board save progress. Unfinished
rounds can be resumed, including a round where no move has yet been made.

These are offline, personal bot cups. Progress belongs to this installation,
does not synchronize across devices, and does not award online leaderboard
points. No server deployment or online profile is needed.

## Adding future events

`lib/src/domain/bot_tournament.dart` contains the catalog and bracket rules.
`BotTournament` provides a stable versioned ID, title, description, proficiency,
optional explicit opponent IDs, optional board theme, time control, and
`pointsPerWin` (default 100). Add a catalog entry to create another themed
knockout event. Keep the ID, roster, and points-per-win stable for an existing
saved event; use a new versioned ID
when changing its format, rewards, or participants. Retain older catalog entries
so their saved points remain in the player's total. Rosters must contain at least
one bot.

`TournamentStorage` owns independent saves and rejects updates from old or
finished match attempts. `TournamentMatchConfig` connects the existing chess
screen to the tournament save and result flow. New challenge formats such as
puzzles, Swiss, or round-robin events should have their own progression rules;
they are not implemented by this knockout format.
