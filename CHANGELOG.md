# Changelog

## 0.8.2 · 2026-09-12

- Strengthen Medium with deterministic two-ply reply search and positional
  scoring for development, central control, mobility, and king safety.
- Remove arbitrary move selection from tied Medium evaluations by applying a
  stable tie-break, so the same position always produces the same move.
- Declare the opposing player the winner when a clock expires and present the
  full result animation with a clear “Winner by Timeout” announcement.
- Replace short 3, 5, and 10 minute online clocks with 15 minute Rapid and 30 or
  60 minute Classical choices, while retaining the untimed invitation option.

## 0.8.1 · 2026-09-12

- Strengthen Easy with a mixed strategy: choose varied standard opening moves,
  then select randomly among a narrow set of safe quiet or defensive moves.
- Keep tactical discipline on Easy by taking material and answering threats when
  a passive move would fall meaningfully behind.

## 0.8.0 · 2026-09-12

- Keep completed game history permanent while retaining per-player deletion for
  invitations.
- Add three authoritative computer lifelines to every online rematch round. Show
  source and destination highlights for ten seconds or until the board is tapped.
  Reopening a suggestion for the unchanged position is free.
- Queue consecutive online capture cinematics and keep at least two seconds
  between them. Give the computer the same pause after a player's capture.
- Rebalance Easy computer play around safe, near-best quiet development moves;
  keep Medium tactical and Hard at full engine strength.
- Replace the launcher artwork with an original crowned battle-knight arena icon
  across Android and iOS, and change Tournaments to “Coming Soon!!!”.

## 0.7.0 · 2026-09-12

- Add Beginner, Intermediate, and Advanced levels to online avatar profiles,
  profile editing, opponent search, game details, and the leaderboard.
- Prefer the same player level during Quick Game matchmaking, then expand to
  other levels after 15 seconds so a sparse lobby can still form a match.
- Present completed games as Won, Lost, or Draw history cards.
- Allow either player to remove an invitation from their own list without
  cancelling an accepted game or removing the other player's copy.
- Extend end-of-game presentation to every online result. Add restrained
  full-screen victory colour and confetti, a stronger trophy treatment, and an
  original synthesized applause effect governed by the global mute control.

## 0.6.0 · 2026-09-12

- Simplify Play Online around Quick Game, exact Avatar ID search, active games,
  invitations, and ranking actions. Remove completed matches and private room
  controls from the main online page.
- List every server-side open game for the authenticated player and reopen a
  selected board with its private seat credential.
- Add an exact Avatar ID lookup with avatar icon and live presence, plus invite
  and favourite actions on the search result.
- Add a personal points breakdown containing the opponent, result, completion
  time, and points awarded for each completed match.
- Support scheduled invitations with a specific local date and time. Let the
  player awaiting a response accept, decline, or propose another time; proposals
  alternate until accepted or declined.
- Permit a future invitation with an opponent even while another game with that
  opponent remains active.
- Render the eight online avatars as themed character portraits, allow players
  to change their Avatar ID and portrait, and show the opponent's ID and portrait
  inside every online game.
- Let invitation proposals choose a timed 3, 5, or 10 minute game or an untimed
  game. Counter-proposals can change both the appointment and timer format.
- Add three computer move lifelines per game. Each lifeline highlights the
  strongest move's source and target squares while leaving the move to the user,
  and the remaining count persists with an unfinished game.
- Separate the difficulty levels clearly: Easy selects deliberately weaker
  moves, Medium uses shallow tactical search, and Hard alone uses maximum
  Stockfish skill with the deepest fallback search.

## 0.5.0 · 2026-09-12

- Hide the WebSocket endpoint and connect automatically to the configured online
  service.
- Require a unique Avatar Name and one of eight bundled Material avatar icons
  before online play; authenticate returning connections with a private token.
- Persist up to fifty active and completed games on the device, including the
  opponent's Avatar Name/icon and the private seat credential needed to reopen
  a board.
- Allow games with several different opponents while enforcing at most one open
  game for the same opponent pair.
- Add an online leaderboard with three points per win, one per draw, zero per
  loss, and win/draw/loss totals. Award each completed rematch round once.
- Let players favourite opponents from game history, view their live presence,
  and send immediate or scheduled invitations. Show sent/received acceptance
  status, create the shared game when an accepted invitation becomes due, and
  persist optional in-app scheduled-game reminders.

- Add a zero-fixed-cost Render deployment Blueprint for multiplayer testing,
  managed `wss://` transport, an HTTP health check, graceful shutdown, and
  lobby heartbeats. Allow release builds to inject the hosted endpoint with
  `ONLINE_SERVER_URL`, default to the deployed Render service, and retain an
  editable endpoint for local development.
- Add multiplayer Quick Match queues for 3, 5, and 10 minute games,
  cancellable opponent search, and retain private Game ID rooms.
- Add an animated checkmate result popup with distinct user-victory and computer-victory treatments, plus a two-line assessment derived from the player's captures, checks, development, castling, and game length.

## Unreleased · 2026-09-06

- Persist unfinished local/computer games with legal move history, clocks,
  difficulty, armies, board world, and battle speed. Offer Resume Last Game or
  confirmed New Game at startup, and confirm in-match resets before clearing.
- Strengthen capture cinematics with synchronized original whoosh, light/heavy
  impact, and final-strike effects governed by the global mute control.
- Give each fighter its themed piece artwork, role-colored insignia, and combat
  treatment; highlight the attacker as VICTOR and desaturate the defeated piece.
- Add a cinematic capture caption naming the attacking and captured pieces with
  their source and target squares, using standard chess piece notation.
- Animate capturing pieces along their exact source-to-target board path before
  the battle cinematic, with correct orientation for either online seat.
- Expand boards when the match top bar is hidden while retaining an eight-pixel
  visual frame, and place the restore control in the details panel clear of clocks.
- Pace the on-board capture, impact beat, and battle cinematic as a synchronized
  1.5-second sequence, with a tuned 700-millisecond fast mode.
- Add Easy, Medium, and Hard computer difficulty selection at home and during
  matches. Each level controls native Stockfish skill and thinking time, plus
  the browser/fallback opponent's search depth.
- Add show/hide controls for the local, computer, and online match top bars so
  the chessboard can use the recovered vertical space.
- Add a Flutter Web development target and isolate native Stockfish behind a
  platform adapter. WebAssembly browser sessions use the legal Dart fallback;
  Android keeps the native engine.
- Replace the navy character-atlas background with genuine PNG transparency.
- Add responsive local and online landscape match layouts: the complete board
  stays visible on the left while clocks, status, controls, and moves use a
  separately scrollable right panel.
- Extend world scenery to home and online lobby pages; add five original
  bundled instrumental loops with a global persistent mute button and
  automatic lifecycle pause/resume. Restore the visible page soundtrack on back.

- Replace board chess glyphs with sixty themed character portraits covering all
  six roles, both sides, and five worlds. Add white/black army previews at home.
- Add independent white army, black army, and board-world customization in local
  and online games, themed scenery, and character promotion/capture rendering.
- Preserve chess-role badges, legal-square semantics, and board orientation.
- Keep computer games playable with a legal, two-ply backup opponent if native
  search stalls, fails, or returns an illegal move. Show reduced strength in
  the match and keep using the backup for that session.
- Wait for Stockfish's UCI readiness acknowledgement before searching, allowing
  slow native network initialization without losing the computer's first move.
- Allow more time for search responses and drain stopped searches before reuse.
- Add a retry action when the computer cannot return a move.
- Add engine, appearance, landscape, and fallback regression tests; Flutter
  suite passes 38 tests.

## 0.4.0 · 2026-09-05

- Added a playable online board with seat orientation, legal highlights, promotion,
  authoritative commits, interpolated clocks and terminal results.
- Extracted shared chessboard and capture widgets; retained original pawn artwork.
- Added optional/fast/fade-only capture battles that never alter official clocks.
- Added automatic reconnect, seat resume, full sync and pending-command retries.
- Added resign, draw offers/responses and mutual rematches using protocol v2.
- Added strict input validation, command receipts, round/ply guards and timed
  state broadcasts, including timeout without incoming player commands.
- Fixed the original game_state parsing condition, null-seat validation, and
  castling falsely reported as a capture when encoded king-to-rook.
- Generated Android/iOS runners while preserving all original source and assets.
- Added Flutter domain/widget and real two-client Node integration coverage;
  recorded dependency licences and locked resolved packages.
- Automated verification passes; native Android/iOS two-device acceptance is
  pending missing platform toolchains. This is not a production release.

## 0.3.0

- Added the original Manga Vanguard Dawn Guard and Dusk Raider pawn asset.
- Integrated character art into pawn-versus-pawn capture cinematics.
- Added the Flutter online lobby and WebSocket protocol client.
- Added an open-source server-authoritative match reference implementation.
- Added move, seat, clock, timeout, reconnect, and state-sequence tests/protocols.

## 0.2.1

- Licensed the complete project and original bundled assets as GPL-3.0-or-later.
- Added an open-source-only dependency and asset policy.
- Added direct third-party dependency notices and a release review gate.

## 0.2.0

- Replaced free-form demo movement with legal standard chess.
- Added special moves, promotion selection, SAN history, and end-state display.
- Added local two-player and Stockfish computer play.
- Added independent chess clocks, undo, and reset.
- Added a Manga Vanguard capture cinematic with fast and skip controls.
- Added rules regression tests.
