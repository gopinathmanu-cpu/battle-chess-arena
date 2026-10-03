# Themed character piece atlas

- Created: 2026-09-06 using the built-in OpenAI image-generation tool.
- Project license: GPL-3.0-or-later.
- File: `themed-piece-atlas.png`.
- Transparent edit: `themed-piece-atlas-transparent.png`, created from the
  original atlas with the built-in OpenAI image-generation tool. The edit
  removed only the navy background and preserved the 971 x 1619 grid.
- Gameplay atlas: `themed-piece-atlas-elephant-chariot.png`, created as a
  non-destructive edit with the built-in OpenAI image-generation tool. Every
  themed bishop is mounted on an elephant and every themed rook rides a
  chariot. Its current canvas is 971 x 1620 with genuine transparency. The
  independent Standard Staunton set is not part of this atlas.
- Crisp source edit: `themed-piece-atlas-clean-source.png`, created with the
  built-in OpenAI image-generation tool from the gameplay atlas. The edit
  preserves the 971 x 1620 canvas and all character identities while removing
  broad external shadows, loose edge pixels, and softening around silhouettes.
- Base aligned atlas: `themed-piece-atlas-aligned.png`, generated
  deterministically by `tool/build_aligned_piece_atlas.swift`. It contains the
  48 active pieces in a uniform 6 x 8 grid of exact 256 x 256 cells. Each cell
  owns one connected character silhouette, is centered independently, and
  cannot include pixels from an adjacent piece.
- Previous gameplay atlas: `themed-piece-atlas-bishop-walk-v2.png`. It preserves
  every non-Bishop cell from the base aligned atlas and replaces only column 3
  with refined elephant Bishops. Their four connected, weight-bearing legs use
  a readable three-quarter walking gait with broad feet and natural overlap.
  The atlas remains a transparent 1536 x 2048 image with exact 256 x 256 cells.
  The active file was subsequently re-isolated cell-by-cell from the largest
  connected opaque silhouette in every cell to remove neighboring-piece spill,
  including fragments that could appear above elephant Bishops. Current
  SHA-256: `efaf432f78b2b491ac1d54db02fd0f27cecaf908352722726ca6f24336f21844`.
- Previous Fantasy gameplay atlas:
  `themed-piece-atlas-fantasy-proportional-v3.png`. It was created as a
  non-destructive full-atlas refinement with the built-in OpenAI
  image-generation tool, using the Japanese and Ayodhya Historical atlases as
  proportion and orientation references. All 48 units use a consistent
  baseline and near-full-cell height; pawns are upright and lean; elephant
  Bishops and mounted Knights use one canonical right-facing three-quarter
  source orientation so the renderer can mirror the black army. The four
  Fantasy worlds, side palettes, role order, transparent alpha, and exact
  1536 x 2048 grid are preserved. SHA-256:
  `c3dd55e2e9308c4745e7ad167419c8018ac98950e454b92ed79193339dc8d8f5`.
- Previous Fantasy gameplay atlas:
  `themed-piece-atlas-fantasy-reimagined-v4.png`. All 48 pieces were newly
  generated with the built-in OpenAI image-generation tool as eight cohesive
  six-role army lineups. The four Fantasy worlds retain their established
  identities while using brighter faces and materials, visible weapons for
  every queen, seated riders on elephants/horses/chariots, consistent
  right-facing orientation, and narrow simplified pawns. The generated rows
  were isolated deterministically by `tool/build_fantasy_atlas.py`; it detects
  transparent gutters, discards disconnected neighbouring spill and low-alpha
  fringe, and fits every owned silhouette into its exact 256 x 256 cell. Final
  atlas size is 1536 x 2048 with genuine transparency. SHA-256:
  `c2c6ecb8cecaefce930d8837d1a3c62137a92b38291d75c357e4471e33e94de4`.
- Active Fantasy gameplay atlas:
  `themed-piece-atlas-fantasy-vivid-v5.png`. The built-in image-generation
  workflow refined the v4 atlas so every White elephant and horse reads as
  bright ivory/porcelain white with blue/gold tack, while Black armies retain
  dark costumes with vivid crimson/gold armor, saddle, shield and weapon
  accents. Queens retain an elegant theme-matched staff, ceremonial blade,
  spear/scepter or energy weapon. The generated source is retained as
  `fantasy-v5-generated-source.png`; `tool/build_aligned_piece_atlas.swift`
  then discarded fringe and disconnected spill and independently normalized
  all 48 owned silhouettes into exact 256 x 256 cells. Final atlas size is
  1536 x 2048 with genuine transparency. Source SHA-256:
  `7960939c24b3b092ae6cdba9504c0f7e720c4ef0d721214994710bd7552a5aaf`.
  Runtime SHA-256:
  `7a04d2f2f9ebaf1beead8e6b311f122eee123f1748d81cd2ba9bcd40f943583a`.
- Reference: user-supplied five-world concept artwork, also present at `assets/concepts/piece-families.png`.
- Active gameplay content: four themes, white/black armies, six roles per army.
  The gameplay atlas clears the two obsolete Royal Classic rows to transparent
  pixels; the original source atlases retain them only as generation history.
  Column order: king, queen, bishop, knight, rook, pawn.
- Source row and column bounds are recorded in `CharacterPiece` in `board_appearance.dart`; the generated rows are not evenly spaced.
- Rendering: the app now uses transparent character cutouts. The original
  opaque navy atlas remains in the project as a source backup.
- Original pawn-duel artwork remains unchanged.

## Transparent-background edit prompt

Use case: background-extraction. Asset type: production chess-character sprite
atlas for a Flutter mobile game. Remove the entire dark navy/black background
and replace it with genuine transparent alpha pixels. Preserve all sixty chess
character miniatures and their pedestal bases, exact 6-column by 10-row layout,
canvas dimensions, positions, scale, poses, silhouettes, spacing, row order,
colors, and internal dark details. Retain clean antialiased edges around hair,
capes, weapons, crowns, horses, shields, robots, and pedestals. Avoid cropping,
moving, redrawing, recoloring, added or deleted characters, text, dividers,
checkerboards, opaque replacement backgrounds, halos, and watermarks.

## Initial generation prompt

Create ONE production sprite atlas for Battle Chess Arena: exactly 6 columns by 10 rows, sixty separate compact FULL BODY collectible character chess miniatures, each centered inside its own equal sized cell with at least 10% clear padding all edges. Portrait image aspect ratio 3:5, high resolution. Transparent background, no checkerboard, no labels, no text, no scenery, no grid lines, no shadows outside cell. Consistent readable silhouettes, polished illustrated fantasy game art, large heads, small bases, detailed faces, compact upright poses, all facing viewer. Columns ALWAYS KING crowned male leader, QUEEN crowned female leader, BISHOP mystical staff-bearing sage, KNIGHT mounted warrior on compact horse/mechanical mount, ROOK heavily armored shield-bearing fortress guardian, PAWN small infantry recruit. Rows 1 and 2 original manga fantasy: row1 ivory gold crimson sun army; row2 charcoal violet cyan moon army. Rows 3 and 4 Indian epic-inspired original heroes: row3 golden armor saffron ivory ornate crowns lotus motifs; row4 deep teal bronze maroon ornate armor. Rows 5 and 6 Greek mythology-inspired: row5 ivory marble gold skyblue Olympian robes laurel crowns; row6 dark bronze plum wine-red underworld robes. Rows 7 and 8 science fiction: row7 white silver cyan android commanders robotic cavalry mechs and small robots; row8 black gunmetal magenta violet androids robots. Rows 9 and 10 royal fantasy carved figurines: row9 ivory gold sculpted humanoid monarchs sages knights guardians infantry; row10 obsidian silver carved same types. Every single cell contains precisely one unique character representing its role. Do not use Unicode chess symbols or generic standard chess silhouettes. Keep row/column geometry exact for automated cell rendering. The supplied reference image is style inspiration only, NOT an edit target: use its collectible character approach, but create complete six-role armies for both sides across five themes.

## Refinements

1. Requested a uniform six-column, ten-row grid with full characters and transparent alpha. The generator retained variable row heights and a checkerboard background.
2. Final edit: replace only the checkerboard with opaque dark navy #11131F; preserve all sixty characters, placement, colors, silhouettes, and image dimensions. No transparency, pattern, or grid.

The final atlas is rendered using explicit cell bounds rather than assuming a uniform grid. Board scenery is sampled at runtime from the rightmost scenic panels of the existing concept image; no source images were cropped or overwritten.

## Elephant bishop and chariot rook edit prompt

Modify only the bishop and rook columns across all ten themed army rows of the
transparent 6-column by 10-row atlas. In column 3, keep each bishop character
recognizable as a mystical sage and seat the character on a compact elephant
matching that row's theme, colors, materials, lighting, and pedestal. In column
5, keep each rook recognizable as a fortress guardian and place the character
on a compact two-wheeled chariot matching that row. Preserve every king, queen,
knight, and pawn; all ten themes and sides; exact ordering, canvas, transparent
background, row and column alignment, scale, spacing, facing direction, and
palette. Keep exactly one complete unit per cell and exactly 60 units total.
Do not include or modify the separate Standard Staunton set. No text, labels,
dividers, board, scenery, watermark, missing pieces, or cropped mounts.

## Perspective and integration refinement

The bishop rider and elephant must face the same subtle three-quarter sideways
direction as the neighboring knight. Seat the bishop naturally on the
elephant's back in a fitted saddle or howdah, with believable contact, aligned
body direction, integrated robe and legs, matched lighting, and one shared
ground shadow. Never place the bishop behind, floating above, or facing against
the elephant.

Render the rook as a dimensional two-wheeled chariot in the same slight
three-quarter direction as the neighboring knight. Use foreshortened elliptical
wheels, visible vehicle depth and platform, and place the fortress guardian
clearly inside or on the chariot. Match the rider and vehicle direction,
perspective, materials, lighting, and ground shadow. Preserve all other roles,
the exact atlas ordering, transparent background, theme palettes, cell
alignment, padding, and complete silhouettes.

## Bishop anatomy and chariot wheel refinement

For the first eight active rows, remove every bishop's rein-holding gesture and
all visible reins. Each bishop shows exactly one arm and one hand: the hand
holding the staff. Conceal the entire opposite arm and hand behind the torso,
robe, or elephant. For each rook chariot, keep the near wheel fully visible and
show the far wheel only partially, naturally occluded by the chariot body in
three-quarter perspective. Preserve every other character, pose, palette, cell
position, and transparent background. The Standard Staunton atlas remains
unchanged.

## Royal Classic removal

Remove every ivory and black Royal Classic unit from rows 9 and 10 of the
gameplay atlas and clear the full bottom band to genuine transparent alpha.
Leave rows 1 through 8 unchanged and aligned to their existing source bounds.
No piece, base, wheel, mount, weapon, outline, shadow, or stray pixel may remain
in the removed rows. Do not modify the separate Standard Staunton atlas.

## Crispness and alignment edit prompt

Use case: background-extraction. Asset type: production chess-character sprite
atlas for a Flutter mobile game. Treat the existing elephant-and-chariot atlas
as the edit target. Clean and sharpen every character in the first eight rows.
Remove only broad external cast shadows and stray edge pixels while retaining
natural internal shading. Preserve the exact role order, army rows, character
identity, pose, palette, direction, proportions, pedestal, complete silhouette,
and genuine transparent background. Center precisely one complete piece per
cell with transparent separation. Use crisp antialiased contours and sharper
fine details at mobile sprite size. No halos, blur, checkerboard, background,
text, grid, watermark, redesign, recoloring, reordering, cropped weapons,
mounts, wheels, bases, or heads. Keep the inactive bottom area transparent.

## Realistic elephant walking refinement

Use case: precise-object-edit. Asset type: production Battle Chess Arena
character sprite atlas. Modify only the eight Bishop sprites in column 3. Make
each elephant's lower body and legs look like a real elephant walking naturally
rather than a solid pedestal: four connected weight-bearing legs, thick
columnar anatomy, broad round feet, subtle joints and wrinkles, and a calm
three-quarter gait with natural near/far overlap. Keep the compact collectible
game proportions and leg silhouettes readable at 64 px. Preserve every rider,
staff, robe, saddle, elephant head, trunk, theme palette, cell position and
transparent background. Preserve all non-Bishop cells pixel-for-pixel. Avoid
horse or human legs, extra or missing legs, detached limbs, impossible joints,
running, rearing, floating, reins, extra hands, text, scenery, glow, broad
shadows, cropping, recoloring, or redesigning other pieces.

The built-in image-generation result was normalized to the exact atlas size,
then `tool/replace_aligned_atlas_column.swift` copied only column index 2 over
the prior aligned atlas. Low-alpha fringe pixels were cleared during compositing
so the other 40 sprites remain byte-for-byte sourced from the previous atlas.
