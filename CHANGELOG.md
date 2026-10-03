# Changelog

## 0.9.0-beta.36+51 — First Google Play release

Released to Google Play; source checked in on 2026-10-03.

- Package Android beta 36 (build 51). Add a visual App icon selector under
  Settings > Appearance. New installations default to the Light Purple icon;
  users can switch between Light Purple and Classic Gold, with the selection
  persisted across restarts.
- Package Android beta 33 (build 48). Restore invitations and connected-player
  browsing against the currently deployed capability-less protocol-v4 service.
  Invitations now default to a supported 30-minute live clock instead of a
  disabled Daily format. Connected-player browsing falls back to leaderboard
  presence data, still showing 10 at a time with Show 10 more, while newer
  services retain exact available-player filtering.
- Package Android beta 32 (build 47) with server beta 7. Add a complete
  user-facing credit guide covering every cost, earning path, free action,
  badge reward, fairness rule and planned pack. Protect real-player online
  games from move suggestions and add a server-authoritative low-balance grant
  that restores balances below 2 to 5 after a rolling 24-hour cooldown.
- Package Android beta 31 (build 46). Apply the same 5-credit immediate retry
  or free retry after a persisted 15-minute cooldown to Conquests. Preserve the
  roadmap and conquered rounds, and prevent the bottom action from bypassing
  the retry choice.
- Package Android beta 30 (build 45). Preview the one-time coin reward beside
  every tier in the Badge summary. Tournament losses and draws now offer a
  clearly priced 5-credit immediate rematch or a free retry after a persisted
  15-minute cooldown.
- Package Android beta 29 (build 44). Grant one-time animated bonus credits for
  every badge upgrade: 25 Bronze, 50 Silver, 75 Gold, 100 Platinum, 150 Diamond
  and 250 Grandmaster. Persist stable badge claims so repeated result screens,
  reloads and rematches cannot duplicate rewards, and celebrate the coin grant
  with the badge unlock.
- Package Android beta 28 (build 43). Make My Themes use the same full-board
  swipe-and-arrow carousel as built-in chess sets, with no custom-set dropdown.
  Classic/Themed selection now exits My Themes reliably. Separate Create and
  Edit actions open the relevant Studio editor directly. Rename testing credit
  credit addition to Top-up Credits and stop displaying the private Top-up code anywhere
  in Settings.
- Package Android beta 27 (build 42). Remove the chessboard zoom overlay
  controls so they never cover a piece or square. Use unobstructed two-finger
  pinch zoom instead; pan with one finger while enlarged, then pinch fully out
  to restore 100% chess-set swiping.
- Package Android beta 26 (build 41). Show the complete “Scroll left or right
  to select chess set” Home-board guidance without ellipsis, allowing a second
  line on narrow or large-text displays while retaining the matching quick-game
  typography.
- Package Android beta 25 (build 40). Add zoom controls to every playable
  chessboard. At 100%, horizontal swipes continue to browse chess sets; after
  zooming in up to 300%, disable set switching and use drag/pinch gestures to
  inspect and pan around the board. Restoring 100% re-enables chess-set swiping.
- Package Android beta 24 (build 39). Replace every dropdown shown in the Game
  Settings sheet with a consistent, compact settings row and checked-choice
  panel. Preserve application palette, music, Home chess set, computer
  difficulty and offline/online Classic-set choices without form-field boxes or
  dropdown arrows.
- Package Android beta 23 (build 38). Match the two Home carousel guidance
  labels in size and weight with clearer spacing; place Play assists directly
  below the board in computer, tournament, conquest and online games; and keep
  return/resign controls below captured pieces. Remove redundant manual-save
  wording because matches autosave, while retaining failure-only save recovery.
  Make the Classic family card follow the selected application colour scheme.
- Package Android beta 22 (build 37). Keep the first-time Play Online
  **Save & Enter Arena** action in a persistent safe-area footer so it remains
  visible below the Avatar ID and image selector on small phones. Make the
  player-level selector responsive to prevent narrow-screen overflow. Apply a
  consistent warm-gold default to menus, cards, dialogs and navigation surfaces,
  with five predefined application colour schemes selectable and persisted from
  Settings.
- Package Android beta 21 (build 36). Standardize all 27 Historical and
  Legendary atlases to a canonical near-front/viewer-left source orientation
  for elephants, horses and directional chariots. Preserve the original pixels
  through lossless per-cell mirroring; Black remains mirrored at render time so
  opposing armies face one another consistently.
- Package Android beta 18 (build 33). Show an opponent identity/details card
  before the board in local, computer, tournament and Conquest play, matching
  the online-game presentation. In Conquests, keep the round opponent's Black
  themed army locked across swipes, settings and resume; let the player change
  only White or temporarily use Classic pieces. Show the guaranteed 300-credit
  welcome balance immediately, synchronize the game screen directly with the
  wallet, and attach the full authoritative ledger entry to every server credit
  response so deductions, rewards, labels and animations remain exact-once.
- Rebuild Chess Set Studio around complete, compatible themed formations instead
  of independently layered body parts. Keep Horse/Elephant/Chariot riders,
  orientation, lighting and contact points locked as one fitted unit; provide
  four formation choices per role and a whole-army apply action; mirror Black as
  a complete sprite and remove arbitrary scaling that caused visual misfits.
- Arm every previously unarmed kingdom Queen with a connected, theme-appropriate
  staff, sword, bow, mace, trident or spear. Preserve all non-Queen atlas pixels
  and leave already-armed Queens unchanged.
- Use a filled yellow bulb for Move suggestion, a red radar for header Threat
  scan, a clearer target-style chess-piece toggle, and one consistent outlined
  gear for settings entry points.
- Let the main-page chessboard selection fill the complete width of its
  responsive chooser column, keeping the preview square and the pieces large.
- Rename the four-set user-facing `Original` theme category to `Fantasy` while
  retaining its stable internal identifier for saved-selection compatibility.
- Give all 31 themed chess sets distinct, sample-free synthesized soundtracks,
  including dedicated Arab, Chinese, Japanese and other setting-led palettes.
  Use compact mono PCM, quiet loop seams and an enforced 12 MiB total budget.
- Refresh Home with a bright bordered welcome card, remove the repeated app
  icon, add clearer chess-set/play section cues and lift selector/action-card
  contrast while retaining full-width board previews and compact scrolling.
- Replace the flat online Favourites row with a collapsible **Your Chess
  Circle** card at the bottom of Play Online. Organize saved players as Family,
  Friends or Professionals; show their refreshed online/offline status; invite,
  move or remove them from their player menu. Existing favourites migrate to
  Friends automatically and the categorized list remains private on-device.
- Simplify credits to one clearly labelled, server-authoritative total in the
  global header. Remove the duplicate Play Online balance and player-facing
  accounting-bucket split; replace ambiguous double-ring/`AC` marks with a gold
  star coin and plain numbers. Play one original, mute-aware coin chime for each
  exact-once confirmed increase or decrease.
- Package Android beta 17 (build 32) with brighter face-scale character detail
  and persistent board-only colour customization. Add a chessboard/paintbrush
  quick toggle, separate light/dark colour pickers, vivid presets, live preview
  and a minimum-contrast guard without changing pieces or scenery.
- Package Android beta 16 (build 31) with the themed-piece visibility and
  per-set board-contrast pass.
- Enlarge every themed character to a common near-full-square height, keep
  pawns deliberately lean, and add side-aware silhouette edging plus selective
  colour contrast so Black costumes remain black while gold, silver and accent
  details stay visible. Give every chess set its own complementary high-contrast
  board palette so pieces remain distinct on both light and dark squares.
- Package Android beta 15 (build 30) with paged real-player discovery,
  respectful Avatar-ID validation, mobile invitation/game reminders, three
  conquest lengths and roadmaps, server-backed Arena Credits, move-suggestion
  costs, persistent XP/trophies/badges, and optional local nickname wording.
  Keep avatar creation limited to online play and allow users to remain unnamed.
- Add server-authoritative Arena Credits with a 300-credit welcome balance,
  capped daily Top-ups and completion rewards, per-round online costs,
  one-credit online Move suggestions, idempotent bonus/purchased ledgers,
  balance history, an always-visible animated balance, coin cost badges on
  every charged action, exact spend feedback and stronger reward celebrations.
  Keep every local mode and non-match online operation free; leave real-money
  checkout disabled until secure store verification and production accounts exist.
- Expand the built-in catalogue to 31 themed sets, grouped into Original,
  Historical and Legendary; preserve all four Classic sets and saved IDs.
  Add full-board previews and a compact group filter. All themed bishops ride
  elephants and rooks use chariots; smaller pawns and a shared baseline make
  kings/queens visually taller. Keep historical inspiration distinct from
  fictional/epic interpretations. Record generation prompts, source crops and
  copyright-risk safeguards; do not claim blanket legal clearance.
- Add a custom multiplayer avatar builder with live vector portraits, four
  starter looks, adjustable age/face/skin, twelve hairstyles, ten hair colours,
  independent moustaches/beards, glasses/shades, outfits and backgrounds.
  Keep preset portraits and bots unchanged. Persist compact designs with player
  profiles and share through the optional `custom_avatars` service capability;
  older services use a preset without deleting the local custom design.
- Add Chess Set Studio: independently customize White/Black roles with fitted
  themed formations; choose board
  colours/finishes and backgrounds; save, use, edit, duplicate and delete local
  sets. Integrate custom appearances into computer, tournament and online play,
  promotions, capture animations and captured-piece displays without changing rules.
- Package Android beta 14 (build 29) with full-board Home previews, artwork-led
  Themed/Classic selection, saved set choices, and responsive play actions.
- Upgrade the home Themed/Classic selector to knight-artwork cards with
  colour-matched gradients, selection borders, and accessible checked states.
- Replace home piece strips with full starting-board previews for all four
  themed and four classic chess sets. Swipe or use left/right arrows to select,
  remember both families' choices across launches, and use a compact responsive
  landing page with side-by-side selection and play actions on wider screens.
- Package Android beta 13 (build 28) with matching 14-point assist-button text,
  wrapping instead of shrinking, and equal button heights in computer/online play.
- Package Android beta 12 (build 27) for ARM64 testing with colour selection,
  optional toss, HTTPS WhatsApp invitations, revocation, and automatic expiry.
  Online features require the matching server deployment.
- Restore WhatsApp direct invites as revocable HTTPS links with Avatar-name
  fallback instructions, Android App Link association, and browser fallback.
  Add Delete invitation link and explicit deleted/expired messages. Links expire
  after 24 hours; unstarted scheduled invitations remain valid until at least
  15 minutes after their scheduled start. Started games and history are preserved.
- Share WhatsApp invitations using the player's Avatar name and search/invite
  instructions, without creating a room or including a non-clickable game link.
- Add optional authoritative colour tosses for online matches and local bot
  tournaments. Remember the assigned colour on resume. Let ordinary computer
  players choose White or Black, with correct board orientation, hints and results.
- Correct avatar overlap using measured portrait bounds for all 50 human and
  20 bot images. Enlarge selection thumbnails and add a 120-pixel selected
  portrait preview in the new-profile and edit-profile pickers.
- Package Android beta 10 (build 25) with fixed bot levels 1–20, retuned ordinary
  computer difficulty, eight music choices with saved selection, and settings reset.
- Add eight background music choices (unchanged Original plus seven original
  synthesized moods), remember the selection across launches, and add a game
  settings reset that keeps saved games, profiles, progress, and bot levels.
- Assign all 20 named bots fixed levels 1–20 within their existing proficiency
  tiers. Use persona strength independently of user difficulty in tournaments,
  native/fallback play, and online server move selection; display level labels.
- Retune native computer difficulty to Skill 0/6/20 with depth limits 2/7/18.
  Negotiate supported Elo targets (800/1400/2500); use skill-based play when
  a target is unsupported, and reset strength limits between searches.
- Prepare Android beta 9 (build 24): use a friend-facing About page without
  diagnostics or implementation notes, simplify all online-play wording, add a
  unified in-game Themed/Classic set picker, place Suggest Move and Threat Scan
  together, improve avatar crop safety, expand the victory fanfare, and add
  WhatsApp invitations that deep-link friends directly into a shared game.
- Prepare Android beta 8 (build 23): introduce a circle-safe launcher icon with
  one single-notch lightning divider between an ivory Classic knight and the
  Black Manga Vanguard mounted knight. Ship against the clean protocol-v4
  Firebase server revision with all 20 built-in opponents available.
- Prepare Android beta 7 (build 22): add a compact Home Themed/Classic selector,
  place white and black previews on separate rows, offer four aligned Classic
  sets (Magnetic 3D, Wooden 3D, Flat Club, and Flat Teaching), persist the
  selection through saved games, and re-isolate all themed sprites to eliminate
  neighboring-piece overlap around elephant Bishops.
- Replace the single-character launcher artwork with a gold lightning-split icon
  in which an ivory Classic knight and Black Manga Vanguard mounted knight face
  each other.
- Prepare Android beta 6 (build 21): replace chess-character profile icons with
  a scrollable catalog of 50 diverse human face portraits. Give computer
  opponents human portraits too, retain legacy avatar rendering, and advance
  the online protocol to v4 so stale servers fail clearly.
- Prepare Android beta 5 (build 20): widen the move-number column for better
  table spacing and rename the beginner tournament to Rising Knights Cup
  without changing its stable save identifier.
- Prepare Android beta 4 (build 19): replace irregular character crops with a
  sharp, shadow-cleaned 6 x 8 atlas of isolated, centered 256 px sprites. Remove
  the distracting full-board turn border/glow while retaining compact status,
  and mirror black character art so opposing armies face one another.
- Prepare Android beta 3 (build 18): add free, cancellable three-second capture
  threat scans with red source/victim highlights and reduced-motion support.
- Track actual captured pieces, including en passant and promoted victims, with
  correct undo, resume, reconnect, and rematch behavior. Persist panel visibility.
- Consolidate in-game settings into a dismissible, accessible gear-menu sheet;
  keep gameplay actions outside it and clocks running while it is open.
- Replace the dark launcher artwork with a bright anime icon based on Manga
  Vanguard's White Knight. Regenerate and validate all 20 native icon sizes.
- Prepare Android beta 2 (build 17): add About/feedback with installed metadata,
  bounded local diagnostics, opt-out/clear controls, reviewed report copying,
  and bundled licence notices. No cloud telemetry or Firebase SDK is added.
- Retire beta-1 startup data deletion so upgrades preserve older saves, history,
  settings, and tournament points, even without the legacy marker.
- Package only referenced character images; retain unused source assets in the
  repository. Refresh physical-device and signed-APK testing checklists.
- Add visual tournament trophy trails, championship ceremonies with replay,
  reduced-motion support, and persistent player totals of 100/200/300 points per
  proficiency-tier round win. Replays and duplicate saves never duplicate points.
- Replace the Tournaments placeholder with three proficiency-based bot cups,
  seeded knockout brackets, saved rounds and trophies, and unlimited rematches
  for lost or drawn rounds. Keep each cup separate from ordinary saved games.
- Add twenty clearly identified built-in computer avatars with globally varied
  names and three proficiency levels as an authoritative online fallback when
  no real opponent is available.
- Replace the Render multiplayer option with a single Firebase-project Cloud Run
  path behind **Play Online**, configured by `ONLINE_SERVER_URL`.
- Add a Standard Chess Set toggle backed by a dedicated Staunton image atlas,
  tabular move history, restored opponent-move highlighting, and stronger
  visual turn indicators for local, computer, and online matches.
- Increase the Standard Chess Set's on-board scale and update only the themed
  armies so bishops ride elephants and rooks ride matching chariots.
- Remove the Royal Classic theme while retaining the independent Standard
  Staunton chess-set toggle unchanged. Legacy Royal Classic saves migrate to
  Manga Vanguard without losing their game state.

## 0.9.0-beta.1 · 2026-09-12

- Load the authoritative active-game list behind a compact progress state and
  remove the stale local-card pass that made completed games flash on screen.
- Perform the requested historical-data cleanup once for Beta 1, then preserve
  all games created after the cleanup marker is written.
- Explicitly restore enabled theme music after capture cinematics, including
  platforms that temporarily take audio focus for sound effects.
- Package the first friend-testing Android beta as an optimized release build
  with a stable private signing key for future beta updates.
- Replace the generated example package identifiers with the stable
  `com.manugopinath.battlechessarena` Android and iOS application identity.

## 0.8.5 · 2026-09-12

- Prevent invitation timer dropdown failures when an existing invitation uses
  an old or unsupported duration such as 6,000,000 milliseconds.
- Normalize unsupported invitation durations to the closest current 15, 30, or
  60 minute option before opening the timer dialog.

## 0.8.4 · 2026-09-12

- Route every mobile difficulty through Stockfish with a direct skill mapping:
  Easy 5, Medium 10, and Hard 20.
- Retain the safe varied Easy and deterministic Medium Dart players as browser
  and native-engine failure fallbacks.

## 0.8.3 · 2026-09-12

- Finalize the three computer levels: controlled safe variation on Easy,
  deterministic positional and tactical search on Medium, and maximum native
  Stockfish skill on Hard.
- Treat games with no moves as fresh games, clear any empty cached save, and do
  not show the Resume/New Game prompt until at least one move has been played.

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
