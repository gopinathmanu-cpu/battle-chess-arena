# Neon Dominion live character poses

Beta 50 selects `ready-cast-bright-rook-v1.png` and
`attack-cast-bright-rook-v1.png` in `assets/cinematics/neon/` for Rooks only.
Non-Rook roles use `ready-cast-bright-v1.png` and `attack-cast-bright-v1.png`:
the revised Rooks' flags/capes overlap the Knight blade space, so this routing
keeps foreign fragments out of other characters. Both Rooks are tall,
upright chariot commanders with energy cannons; Black faces/hands and accessories
are brighter. Resting sprites use `white-cast-rook-v1.png` and
`black-cast-bright-rook-v1.png`. Original sheets remain preserved. See the
[current selected cast record](BRIGHT_ANIMATED_CAST_ARTWORK.md) and
[submitted edit prompts](BRIGHT_ANIMATED_CAST_PROMPTS.json).

Generated on 2026-10-03 with the built-in image-generation tool, using the
existing White and Black Neon casts as identity and costume references. These
companion atlases add ready and extended attack poses for all six roles on both
sides. The original casts and generated source images remain intact.

- `assets/cinematics/neon/ready-cast.png`: 1774 × 887 RGBA, White above Black.
- `assets/cinematics/neon/attack-cast.png`: 1774 × 887 RGBA, White above Black.
- Columns: king, queen, bishop/elephant, knight/horse, rook/chariot, pawn.
- All source figures face right. The renderer mirrors the opposing lane.

The generated transparency is preserved without raster editing. Individual
source bounds and clipping paths belong to the renderer. Live and cinematic
captures blend the selected ready/attack sheets with the selected resting cast.
The original rest/pose generation is recorded here; current standalone rest
sprites use the selected Beta 50 rest cast above.
Reduced motion uses a settled pose.

Exact prompts, reference paths, dimensions and SHA-256 hashes are recorded in
[`NEON_LIVE_POSE_PROMPTS.json`](NEON_LIVE_POSE_PROMPTS.json). These are original
game assets distributed under the project's GPL-3.0-or-later license.
