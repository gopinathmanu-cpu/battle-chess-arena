# Original Animated armies artwork

For Beta 50, the selected casts are `manga/cast-bright-v1.png`,
`epic/cast-bright-v1.png` and `olympian/cast-bright-hair-v1.png` under
`assets/cinematics/`. Black faces/hands and accessories are clearer; both
Olympian Queens receive flowing hair, while Manga and Epic retain existing hair.
The original `cast.png` files and world backgrounds remain intact. See the
[current selected cast record](BRIGHT_ANIMATED_CAST_ARTWORK.md) and
[submitted edit prompts](BRIGHT_ANIMATED_CAST_PROMPTS.json). The following record
describes the original generation, not the current runtime filenames.

Manga Vanguard, Epic Guardians and Olympian Legion now each have a complete
illustrated battlefield and twelve original, full-body characters for the live
game and recorded cinematic. Existing board pieces retain their familiar role
silhouettes; the new character casts remove plinths and use action poses.

The six final raster files are in `assets/cinematics/manga/`,
`assets/cinematics/epic/` and `assets/cinematics/olympian/`, each containing
`world.png` and `cast.png`. Original artwork was generated with the built-in
`image_gen` tool; no CLI, external API key, franchise characters or sampled
artwork were used. The exact six prompts and final destinations are retained in
[ANIMATED_ARMIES_ART_PROMPTS.json](ANIMATED_ARMIES_ART_PROMPTS.json).
`tool/copy_animated_art.py` records original generated-file provenance.

All outputs are copied intact. Character atlases are 1774 × 887 RGBA with genuine
alpha transparency: White above Black, roles King, Queen, Bishop, Knight, Rook,
Pawn. Bishops retain the elephant/sage silhouette, knights are mounted, and
rooks are chariots. Measured source bounds and renderer clipping preserve wide
weapons and mounts without editing bitmap files. All source figures face right;
rendering mirrors the opposing lane toward the action.

The opt-in real-art review is `test/animated_armies_stage_preview_test.dart`
with `--dart-define=CAPTURE_ANIMATED_ARMIES=true`. Its 36 frames in
`build/animated-armies-preview-v1/` cover all 48 figures across four worlds,
live selection/capture, cinematic strikes/checks/victory, short landscape and
reduced motion. All three new twelve-role contact sheets were visually reviewed
after tightening renderer gutters to remove adjacent cape/hoof fragments.
Scene labels use the test harness font; shipping fonts and animation smoothness
remain physical-device checks.

The worlds share validated chess actions while using their own procedural
effects: Manga sword arcs and comet bursts; Epic chakras, radiant magic and
lotus impacts; Olympian lightning, shield waves and laurels. Effects animate
from accepted moves and verified captures, checks and outcomes. Classic board
icons retain the selected army world. Reduced motion uses static emphasis.

Each world also has an original 40-second instrumental score synthesized by
[generate_animated_film_scores.py](../tool/generate_animated_film_scores.py).
The 22050 Hz mono PCM tracks use mathematical oscillators, original note
patterns and deterministic noise, with no recordings or external songs. They
play softly beneath the narrator and retain mute, pause, route/lifecycle and
ducking controls. The four stories call actual moves and legal threats; their
introductions and endings reflect their fictional armies.

These project assets and synthesis source are GPL-3.0-or-later and are included
in the exact corresponding-source handoff alongside the app and Stockfish.
