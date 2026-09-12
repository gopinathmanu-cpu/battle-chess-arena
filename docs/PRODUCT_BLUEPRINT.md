# Battle Chess Arena — Product Blueprint

## Product promise

Battle Chess Arena is a serious chess platform in which every optional capture
becomes a short character battle. Strategy is never blocked by spectacle:
animations are skippable, speed-selectable, and disabled by default in the
fastest competitive time controls.

## Launch piece packs

1. Manga Vanguard — original anime-inspired fantasy champions.
2. Epic Guardians — culturally respectful, original Indian epic-inspired units.
3. Olympian Legion — Greek mythology-inspired bronze and marble champions.
4. Neon Dominion — futuristic androids, mechs, and energy weapons.
5. Royal Classic — premium traditional carved pieces.

Each pack must provide the same semantic roles: king, queen, rook, bishop,
knight, and pawn for both sides. Art, audio, particles, movement, attack,
defeat, promotion, check, and checkmate sequences are data-driven pack assets.

## Animation contract

- Selection response: under 100 ms.
- Ordinary move: 180–280 ms.
- Default capture sequence: 700–1,200 ms.
- Fast capture sequence: 250–400 ms.
- Skip control: always visible during a battle.
- Reduced-motion mode: crossfade only.
- Online authority: the server commits the move before presentation begins.
- Clock: keeps running independently of animation; animation never changes time.

## Rendering path

Start with 2D skeletal animation because it has smaller downloads and performs
well on mid-range phones. Keep the renderer behind an interface so premium 3D
packs can be introduced later without changing chess rules or networking.

The current Flutter capture widget is shared between offline and online play;
replace its renderer without changing the rules or networking layers. A future
skeletal pipeline must include GPL-compatible open-source authoring tools,
runtimes, source rigs and export formats. Proprietary tooling such as Spine is
excluded by the project policy. No skeletal runtime is added in Milestone 4.

Concept artwork is currently a prototype asset, not a final production pack. A character artist should turn
approved concepts into consistent, licensed production assets.

## Capture choreography

Every attacker/defender combination should not require a unique animation.
Define reusable action classes:

- melee attack
- ranged attack
- magic attack
- block or evade
- defeat
- king check reaction
- promotion transformation

The battle director combines these actions by piece role and distance. This
keeps five complete piece packs commercially achievable.

## Platform phases

### Phase 1 — USP vertical slice

- Theme carousel and pack metadata.
- Board presentation and piece selection.
- Movement and capture-battle prototype.
- Fast and reduced-motion preferences.
- One polished representative pack for usability testing.

### Phase 2 — Chess foundation (playable vertical slice complete)

- Complete: legal moves, FEN-backed state, SAN move list, promotion, special
  moves, terminal-position detection, independent clocks, and on-device
  Stockfish adapter.
- Next: PGN import/export, saved games, analysis, and user-facing engine levels.

### Phase 3 — Online play

- Milestone 4 implemented: interactive authoritative board, colour orientation,
  seat/turn guards, promotion, capture verification, clocks, results, copy room ID,
  reconnect/full sync, resign/draw, and mutual rematch.
- Automated client/server and widget tests pass. Native two-device acceptance is
  still pending the Android SDK and full Xcode/CocoaPods toolchains.
- Next gate: complete the device checklist before adding platform services.
- Matchmaking, ratings, challenges, friends, moderation, and fair-play signals.

### Phase 4 — Tournaments

- Arena, Swiss, round-robin, scheduled, and private events.
- Pairing service, standings, tie-breaks, spectators, and organizer tools.

## Originality and cultural safety

- Use original characters, names, silhouettes, lore, effects, and sound.
- Avoid copying Battle Chess animations or identifiable manga/anime franchises.
- Engage Indian cultural consultants for sacred symbols, attire, weapons, names,
  and narrative context.
- Offer mythology-inspired packs as fantasy interpretation, not religious parody.
- Avoid gore; defeat can use disarming, teleportation, smoke, light, or retreat.

## Milestone 4 acceptance and subsequent roadmap

Finish physical/emulated Android and iOS verification using
`DEVICE_VALIDATION_CHECKLIST.md`. Keep the single-process server as the local
reference implementation. Do not begin the following roadmap until the native
two-device match is verified:

1. Authentication and persistent profiles.
2. Durable game storage and recovery.
3. Matchmaking and ratings.
4. Friends and private challenges.
5. PGN import/export, saved games and analysis.
6. Open-source skeletal animation pipeline and complete Manga Vanguard pack.
7. Original Indian, Greek, futuristic and classic packs.
8. Spectator mode.
9. Arena, Swiss and round-robin tournaments.
10. Organizer tools, fair-play monitoring, moderation and production deployment.
