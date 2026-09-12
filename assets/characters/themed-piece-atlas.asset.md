# Themed character piece atlas

- Created: 2026-09-06 using the built-in OpenAI image-generation tool.
- Project license: GPL-3.0-or-later.
- File: `themed-piece-atlas.png`.
- Transparent edit: `themed-piece-atlas-transparent.png`, created from the
  original atlas with the built-in OpenAI image-generation tool. The edit
  removed only the navy background and preserved the 971 x 1619 grid.
- Reference: user-supplied five-world concept artwork, also present at `assets/concepts/piece-families.png`.
- Content: five themes, white/black armies, six roles per army. Column order: king, queen, bishop, knight, rook, pawn.
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
