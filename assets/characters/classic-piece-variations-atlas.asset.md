# Classic Piece Variations Atlas

- Output: `classic-piece-variations-atlas.png`
- Size: 1536 × 2048 RGBA (6 columns × 8 rows; 256 px cells)
- SHA-256: `97f8d3d2d41c175daed2125fe640d45dd1f36767de1b7a98859ef824de06b684`
- Generator: built-in OpenAI image generation tool

## Layout

Columns are king, queen, bishop, knight, rook, pawn. Each variation uses two
rows: light pieces first, dark pieces second.

1. Magnetic 3D — durable cream and black teaching-board pieces
2. Wooden 3D — maple and walnut
3. Flat Club — bold black/white icons based on the supplied reference
4. Flat Teaching — rounder cream/charcoal educational icons

## Prompt

> Use the supplied chessboard reference image for the visual language of rows 5–8: flat, clean, recognizable standard chess symbols with strong black/white contrast and simple outlines. Create exactly 48 pieces in an exact 6-column by 8-row transparent RGBA atlas. Fixed column order: king, queen, bishop, knight, rook, pawn. Rows 1–2: Magnetic Teaching 3D, chunky molded cream and matte black pieces with visible flat magnetic bases. Rows 3–4: Wooden 3D, traditional pale maple and dark walnut Staunton pieces. Rows 5–6: Flat Club, closely based on the reference's conventional silhouettes, white-filled light pieces with bold black outlines and solid black dark pieces. Rows 7–8: Flat Teaching, a second rounder, chunkier educational-diagram variation in cream and charcoal. One complete centered piece per cell, consistent baseline, minimum 10 percent transparent gutter. No chessboard, colored squares, scenery, grid lines, borders, text, labels, logos, watermark, fantasy characters, crops, overlaps, neighboring fragments, glow, or opaque background.

The generated atlas was normalized to 1536 × 2048, then every cell was rebuilt
from its largest connected opaque silhouette using
`tool/build_aligned_piece_atlas.swift`. This removes generator fringe pixels and
guarantees that no piece can spill into a neighboring cell.
