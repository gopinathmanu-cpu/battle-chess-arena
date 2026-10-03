# Retired Chess Set Studio modular-parts experiment

Created for Battle Chess Arena on 2026-09-26 using the built-in image-generation
tool. These are original project-directed fantasy illustrations, not imported
franchise or stock character art. Distributed with the project under its
GPL-3.0-or-later terms; no third-party character or trademark rights are granted.

## Files

- `modular-parts-source-v1.png`: preserved generated source sheet, 1024 × 1536.
- `modular-parts-v1.png`: prepared transparent runtime atlas.
- Preparation: `tool/prepare_custom_piece_atlas.swift`, local per-part foreground
  extraction explicitly approved by the user. The generated source is retained.
- Crops: measured source rectangles in `CustomPieceParts`, not assumed equal rows.

## Runtime status

These files are retained only as source-history evidence and are no longer
bundled or rendered by the app. Combining independent horses, bodies, heads and
accessories could create disconnected riders and inconsistent silhouettes. The
Studio now treats a complete role formation from the themed atlases as one
locked jigsaw unit, preserving rider/mount/chariot contact, orientation,
lighting, scale and baseline.

## Built-in generation prompt

Use case: stylized-concept. Asset type: one production game sprite atlas of
modular chess character parts, for a mobile chess-set character creator.
Generate a single PNG with a genuinely transparent alpha background. EXACT
uniform 4-column by 6-row grid, portrait aspect ratio 2:3. Every cell has the
same square size. No visible grid lines, absolutely no text, labels, shadows
outside sprites, scenery, panels or watermark. All 24 separate items centered
in their own cells, with at least 12 percent transparent margin on every edge;
never cross into another cell. Consistent polished hand-painted 3D miniature
toy fantasy art with crisp silhouettes and soft upper-left lighting, original
designs, slightly chunky readable game proportions.

Rows from top to bottom:

1. Four full-body horses without riders, all right-facing side view, in the same
   gentle walking pose with visible separated legs and level back: chestnut
   horse, white horse with blue saddle, black horse with red saddle, silver
   clockwork horse.
2. Four FRONT-facing headless human costumes, neck down to boots, arms down,
   empty hands, no heads, no helmets, no weapons: silver plate armour with blue
   cape; royal red-and-gold robe; bronze legionnaire cuirass and skirt; dark teal
   futuristic armour. Identical full-body proportions and neck position across
   all four costumes.
3. Four separate FRONT-facing adult heads cropped just under neck, full hair
   in frame, no crowns or helmets: short-haired clean-shaven tan man;
   dark-skinned bearded man; brown-skinned woman with dark braided hair;
   fair-skinned silver-haired woman. Each head occupies middle 70 percent of its cell.
4. Four separate empty FRONT-facing crowns/headdresses, no heads inside:
   golden five-point royal crown, silver jeweled tiara, golden sun circlet,
   blue-and-gold bishop mitre.
5. Four separate upright weapons/accessories, tip at top and handle at bottom:
   silver longsword; gold staff with blue orb; bronze spear; slender staff with
   small red pennant banner.
6. Four separate full-height rook tower miniatures, no people: grey crenellated
   castle tower, red-roof pagoda tower, golden sun temple tower, dark futuristic
   energy turret.

Items should be completely opaque within their silhouettes with TRANSPARENT
empty space surrounding them, never checkerboard baked into the artwork. Keep
every item separate. This is a tightly controlled modular sprite sheet, not a
collage or complete characters.

## Built-in edit prompt

Use case: background-extraction. Image 1 is the edit target. Remove ONLY the
entire brown grey coloured background everywhere, including between horse legs,
around hair, between costume arms and body, inside open crowns, around staff
and towers. Deliver this exact sprite sheet as a PNG with TRUE TRANSPARENT ALPHA
channel, alpha zero outside every item's silhouette. Do not replace backdrop
with white, black, grey, checkerboard, or any drawn pattern. Preserve all 24
original items pixel-faithfully including position, scale, costumes, faces,
horse poses, colors, gold highlights, and the original 1024x1536 canvas.
No items added removed cropped relocated or restyled. Do not add any shadow
or glow outside objects. The source background is wrong for game compositing;
only isolated cutout objects on transparent pixels can be used. Keep four
horses, four headless costumes, four heads, four crowns, four weapons, four
towers in their exact existing positions.

The generator retained a background and used irregular row heights. Local
background extraction and individually measured crop bounds therefore form
part of the preparation workflow; the source must not be used directly as
the runtime atlas.
