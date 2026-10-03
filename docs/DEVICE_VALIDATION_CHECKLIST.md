# Android beta 18 device acceptance

Use the signed **0.9.0-beta.18** APK, not a debug build. Automated tests and APK
inspection do not certify physical-device performance or recovery. Every box
below remains pending until a tester records a result. Test a lower-end Android
phone, a recent Android phone, and two phones together for multiplayer.

Record device model, Android/API version, APK filename/build number, network,
date, pass/fail, and reproduction steps. Find the app version in **About** and
send your notes directly to your release contact.

## Installation and upgrades

- [ ] Verify the supplied APK checksum and select its correct ABI.
- [ ] Clean install; launch without a network connection and confirm local play.
- [ ] Upgrade the previous beta with the same signing key, without uninstalling.
- [ ] Preserve saved moves/clocks, online identity/history, mute setting,
  tournament progress, rematch opponent, points, and trophies after upgrading.
- [ ] Confirm installed version/build in **About**.
- [ ] Launch after force-stop and after restarting the phone.
- [ ] Check the lightning-split Classic-versus-Black-Themed knight launcher icon, including
  circular/squircle masks; old launcher caches may need a launcher refresh.

## Beta 15 economy, progression and online discovery

- [ ] Confirm 300 starting Arena Credits, the always-visible coin balance and
  animated increases/decreases; charged actions show their cost before use.
- [ ] Confirm Move Suggestion charges exactly one credit online and remains
  available without a credit charge in local play.
- [ ] Complete wins, losses and draws; confirm move-based XP every time, trophies
  for wins only, badge advancement and no duplicate reward after reopening.
- [ ] Use or dismiss the optional preferred-name prompt. Confirm congratulations
  use the name only when saved and that it can be changed in Settings.
- [ ] In Find Opponent, browse real online players ten at a time with Show More;
  offline/self/private data must not appear.
- [ ] Reject abusive or obfuscated offensive Avatar IDs on both client and server.
- [ ] Enable mobile notifications and verify invitation, scheduled-start warning
  and game-start notifications. Denying permission must leave play usable.
- [ ] Complete a 3-game, 5-game and 10-game conquest; confirm suitable opponents,
  roadmap before play/resume, next-match navigation and saved progress.
- [ ] In every match mode, confirm the opponent card is visible before the board.
  In Conquests, swipe and open appearance settings: only White may change, the
  round's Black themed army stays locked, and Classic mode remains available.

## Home screen

- [ ] Switch between Themed and Classic using the artwork cards; verify the
  selected highlight, checkmark, and full-board preview agree.
- [ ] Browse all four sets in each family using swipes and both arrows.
- [ ] Restart the app and confirm both families' last choices are remembered.
- [ ] Start a new game and confirm it uses the selected pieces and board.
- [ ] Check portrait, landscape, short screens and enlarged text; all play
  actions remain reachable, with vertical scrolling when needed.

## Beta 12 colours and invitations

- [ ] Start computer games as White and Black; check bot opening, orientation,
  hints, undo, clocks, results, and saved-game resume.
- [ ] Enable tournament colour toss and confirm the assigned colour survives resume.
- [ ] After deploying the updated server, verify online toss on both phones.
- [ ] Share an HTTPS WhatsApp invitation; check that Avatar-name fallback
  instructions and the 24-hour expiry note are present.
- [ ] Open a link with the new app installed, after force-stop, and in a browser.
- [ ] Delete an invitation and open its old link: expect a deleted message,
  not a new game. Repeat with an expired link and check the expiry message.
- [ ] Confirm revoking a used link does not delete the already-started game.
- [ ] On the older server, confirm Avatar-name-only sharing remains usable.

## Board helpers and unobtrusive settings

- [ ] Confirm Suggest Move and Threat Scan use matching font sizes and equal
  button heights in computer and online games, including larger system text.
- [ ] Browse all 31 themed boards at phone size. Confirm every role uses the
  same near-full-square height, pawns are visibly lean, and no piece is clipped.
- [ ] Confirm Black costumes remain recognizably black while gold, silver and
  coloured accessories stay legible on both square colours for every set.
- [ ] Confirm each set loads its own complementary board palette and both armies
  remain distinct when switching board worlds independently in game settings.
- [ ] Open **Choose board colours**, use both square-colour pickers and confirm
  the live preview and contrast warning. Apply a vivid palette and restart.
- [ ] Confirm the last light/dark colours persist. Use the chessboard/paintbrush
  toolbar icon to alternate between them and the set palette without changing
  pieces, background, music, clocks, moves or online state.
- [ ] Inspect faces for both armies across all sets on a small phone. Faces and
  accessories should stay bright while Black costumes remain recognisably dark.

- [ ] Check all 48 themed role/side sprites: each is sharp and centered, with
  no neighboring-piece fragments, clipped weapons/mounts/bases, or broad shadow.
- [ ] Place opposing themed pieces side by side and confirm black is mirrored so
  both characters face one another; role labels must remain readable and upright.
- [ ] Confirm turn changes do not tint, border, or glow over the full board;
  the clock/status indicators still identify the side to move.
- [ ] Game settings opens only from the gear, closes with Close/Back/outside tap,
  scrolls at large font sizes, and is accessible with the top bar hidden.
- [ ] Settings switches do not occupy the main board view; opening/changing
  them neither moves pieces nor pauses clocks. Tournament difficulty stays fixed.
- [ ] The Captured pieces box shows both sides' actual victims in their selected
  piece style. Verify en passant, promotion, capture of a promoted piece, undo,
  save/resume, online reconnect gaps, and an empty new-game/rematch box.
- [ ] Show captured pieces persists across app restart and local/online modes;
  hiding the box does not erase its history or change the board size.
- [ ] Analyse attack threats shows each legal capture source and victim in red
  for three seconds, then the next pair; no lifeline is spent or move submitted.
- [ ] Pinned attackers/unsafe king captures are excluded; pawn captures, capture
  promotions, and en passant highlight correctly. Check is still indicated separately.
- [ ] Reduced motion is steady red. Stop, board input, undo/reset, Settings,
  app backgrounding, online state changes/disconnect, and exit cancel the scan.
- [ ] On a small phone, threat scanning brings the board into view. Test both
  player colours, no-threat positions, tournament games, and portrait/landscape.

## Offline chess and engine

- [ ] Computer games work at Easy, Medium, and Hard; no frozen first move.
- [ ] Leave and reopen computer mode repeatedly; no native engine/singleton errors.
- [ ] Reset or leave during engine thinking; no stale move appears afterward.
- [ ] Resume unfinished games with correct moves, clocks, appearance, and lifelines.
- [ ] Verify castling, en passant, all promotion choices, checkmate, stalemate,
  repetition, fifty-move draws, and insufficient material.
- [ ] Verify standard pieces and all four themed armies, including bishop/rook art.
- [ ] Exercise hints/lifelines, undo where allowed, capture battles, and Skip.
- [ ] Confirm computer moves remain responsive at each difficulty on the device.

## Tournaments and points

- [ ] Enter all three cups; check proficiency, seeded opponents, byes, and locks.
- [ ] Loss, resignation, timeout, and draw offer the same-round rematch.
- [ ] Earlier wins/points survive rematches, leaving, force-stop, and phone restart.
- [ ] Each round win adds exactly 100/200/300 points for the cup's difficulty.
- [ ] Final win opens the ceremony; trophies and totals refresh afterward.
- [ ] Reopening results and replaying celebrations never award more points.
- [ ] All cups completed: 1,800 local points and three trophies.
- [ ] Unfinished rounds resume; backgrounding pauses the local clock.
- [ ] Save failures show an actionable message rather than silently losing progress.

## Online: two phones

The APK uses the bundled Cloud Run secure WebSocket endpoint. Override
`ONLINE_SERVER_URL` for a separate test server. Local-server tests need an
explicitly configured debug build; emulator localhost is no longer the default.

- [ ] Browse all 50 human face avatars; confirm every crop is centered, unique,
  selectable, and contains no chess-piece artwork. Check children, teenagers,
  adults, varied skin tones, hair, facial hair, glasses, and head coverings.
- [ ] Create different Avatar IDs on both phones, choose different face
  portraits, and select proficiency levels.
- [ ] With the next-build avatar editor, create Man/Woman/Boy/Girl looks and
  vary age, skin tone, face, hairstyle/colour, moustache, beard and eyewear.
  Confirm circular thumbnails match the large preview without clipped layers.
- [ ] Save a custom avatar, restart, edit it, cancel a changed draft and reset
  a draft. Check 320-pixel width, landscape and large system text.
- [ ] On two updated apps and service, confirm custom avatars appear in search,
  invitations, games, rankings and history. On an older service, verify the
  preset-portrait notice, retained local design and successful online play.
- [ ] Find each other, quick-match, invite, accept, and enter matching boards.
- [ ] Test computer-avatar fallback when no human opponent is available.
- [ ] Play captures, castling, en passant, promotion; both boards/history agree.
- [ ] Verify server clocks, resignations, draws, timeouts, rematches, and rankings.
- [ ] Test favorites, scheduled invitations, counter-proposals, and reminders.
- [ ] Switch Wi-Fi/mobile data, use airplane mode briefly, then reconnect.
- [ ] Interrupt a move request: it is applied at most once; input waits for sync.
- [ ] Background or force-stop one phone; recover its seat while the server still
  retains the room. Online clocks continue while a player is away.
- [ ] Test a cold-start connection and a long session with WebSocket reconnection.
- [ ] Restart a disposable test backend: show an honest missing-room/profile
  state, not false recovery. Do not disrupt a server hosting other testers.

**Known beta limitation:** deployments without `FIRESTORE_PROJECT_ID` keep rooms,
profiles, invitations, credits and rankings in server memory and can reset on
restart/redeployment; Daily games are disabled there. Confirm the shared beta
endpoint uses the matching Firestore-backed revision before relying on recovery.
Local XP, badges and tournament progress remain device-local and are not synced.

## Music, accessibility, and performance

- [ ] Listen to all eight music choices and confirm clean looping at low volume.
- [ ] Music selection survives theme changes, force-stop, and restart.
- [ ] Reset settings restores Original music, sound on, and default appearance
  while retaining games, profiles, tournament progress, and fixed bot levels.
- [ ] Confirm levels 1–20 beside bot names and unchanged levels on rematch.
- [ ] Check TalkBack, large text, narrow screens, landscape, and system insets.
- [ ] Mute persists; calls/backgrounding do not restart unwanted audio.
- [ ] OS reduced motion avoids new trophy-path/celebration motion.
- [ ] Play for at least 30 minutes and repeat celebrations; record freezes,
  memory growth, battery use, heat, and responsiveness on lower-end hardware.
- [ ] Profile capture/celebration frame timings in a matching profile build.
- [ ] Test native-library loading on a 16 KB Android device/emulator. Static ZIP
  and ELF alignment checks alone do not prove runtime compatibility.

## Shareable-beta gate

- [ ] Flutter analysis/tests and Node tests pass for the exact source snapshot.
- [ ] Signature, package ID, version, permissions, ABIs, and alignment verified.
- [ ] Licence notices and corresponding source archive accompany the APK.
- [ ] Testers receive release notes, known limitations, this checklist, and a
  clear contact for submitting reports.

References: [Flutter Android releases](https://docs.flutter.dev/deployment/android),
[Android 16 KB compatibility](https://developer.android.com/guide/practices/page-sizes).
