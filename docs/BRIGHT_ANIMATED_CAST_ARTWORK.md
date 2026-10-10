# Beta 50 Animated cast artwork

Beta 50 improves character readability while retaining the four original army
identities. Black costumes stay dark, with brighter, lighter exposed faces and
hands and stronger metallic or coloured accessory contrast. Both Neon Rooks
become tall, upright heroic chariot commanders in every pose, with recognizable
energy cannons. All eight Queens have long flowing hair: only the two Olympian
Queens needed new hair; Manga, Epic and Neon retain their existing hair designs.

## Selected atlases

These nine files are the final Beta 50 cast selections. The city/world artwork
and original procedural scores are unchanged.

| File | Selection |
| --- | --- |
| `assets/cinematics/neon/white-cast-rook-v1.png` | White resting cast with the upright Rook commander |
| `assets/cinematics/neon/black-cast-bright-rook-v1.png` | Brighter Black resting cast with the upright Rook commander |
| `assets/cinematics/neon/ready-cast-bright-v1.png` | White/Black ready poses for every non-Rook role, including brighter Black characters |
| `assets/cinematics/neon/attack-cast-bright-v1.png` | White/Black attack poses for every non-Rook role, including brighter Black characters |
| `assets/cinematics/neon/ready-cast-bright-rook-v1.png` | Ready poses for the two upright Neon Rooks only |
| `assets/cinematics/neon/attack-cast-bright-rook-v1.png` | Attack poses for the two upright Neon Rooks only |
| `assets/cinematics/manga/cast-bright-v1.png` | Manga Vanguard cast with brighter Black faces/hands and contrasting accessories |
| `assets/cinematics/epic/cast-bright-v1.png` | Epic Guardians cast with brighter Black faces/hands and contrasting accessories |
| `assets/cinematics/olympian/cast-bright-hair-v1.png` | Olympian Legion cast with brighter Black characters and flowing hair on both Queens |

The full submitted edit prompts, input references, generated outputs and selected
file records are retained in
[BRIGHT_ANIMATED_CAST_PROMPTS.json](BRIGHT_ANIMATED_CAST_PROMPTS.json).
The manifest records the actual generation history, including any intermediate
brightness and Rook revisions; this document does not reconstruct omitted prompts.

The new upright Rooks' flags and capes extend into the neighbouring Knight blade
space in the ready/attack sheets. The renderer therefore selects those revised
pose sheets only for Rooks. Every other Neon role retains the earlier bright
ready/attack sheets, preventing foreign Rook fragments in their silhouettes.
Both resting casts use the final Rook revisions.

## Origin and preparation

The built-in image-generation tool edits project-directed character sheets as
identity references. Selected generator PNGs are copied intact: no raster resize,
repaint, colour-processing script or post-generation pixel manipulation is used.
Generated alpha transparency is retained. Sprite bounds, native-aspect fitting,
body-height metrics, clipping paths and facing are renderer operations.

The original files remain in the corresponding-source handoff:

- Neon: `white-cast.png`, `black-cast.png`, `ready-cast.png` and `attack-cast.png`
  under `assets/cinematics/neon/`.
- Manga, Epic and Olympian: each original `cast.png` in its world directory.
- Earlier brightness selections and generation inputs remain available as source
  records. The two earlier bright ready/attack sheets are retained at runtime for
  non-Rook roles; only the nine selected runtime atlases are declared for the APK.

The original provenance is recorded in [Neon cinematic artwork](NEON_CINEMATIC_ARTWORK.md),
[Neon pose artwork](NEON_LIVE_POSE_ARTWORK.md) and
[Animated armies artwork](ANIMATED_ARMIES_ARTWORK.md). The updated PNGs remain
project artwork under the same [open source policy](../OPEN_SOURCE_POLICY.md).

## Rendering and validation

Board pieces, stationary selection avatars, threatened-piece portraits, captured
icons and films use the selected cast. Board pieces fit each resting silhouette
to nearly 98% of the available content along one axis at native proportions.
Live encounters and films retain a shared physical body scale; revised Neon
Rook crops and body metrics match the taller commanders. Black source figures
face right and mirror in the renderer according to the actual lane.

Live move actors settle without a post-landing retreat. The primary accepted
movement/attack, defeated victim reaction, castling and film choreography remain.
This movement change is separate from the generated artwork.

Final review checks all roles and both sides at source and phone size, especially
visible skin/accessories, Queen hair, Neon cannon/chariot silhouettes in all
three poses, mirrored edges, weapons, mounts and feet. Automated checks and
actual-art review results belong in [Beta 50 validation](BETA_50_VALIDATION.md);
physical-device acceptance remains in the [device checklist](DEVICE_VALIDATION_CHECKLIST.md).
