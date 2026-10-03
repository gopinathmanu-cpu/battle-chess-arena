# Human face avatar atlas

- Created: 2026-09-20 with the built-in OpenAI image-generation tool.
- Project license: GPL-3.0-or-later.
- Production file: `human-face-atlas-v2.png`.
- Dimensions: 1800 x 900 RGBA PNG, containing ten portraits per row in five rows.
  The artwork spacing is irregular; it is NOT a uniform 180 x 180 grid.
- Runtime cropping: measured source rectangles in
  `lib/src/features/online/avatar_portrait_regions.dart`, rendered directly with
  `Canvas.drawImageRect`. Each portrait is independently centered in its circle.
- SHA-256: `ca3f04a3724725091fbf6fce44c0f4f0b85e2f5421d05810265fe6398dbd6380`.
- Runtime IDs: `avatar-01` through `avatar-50`, in row-major order.

## Generation prompt

Use case: stylized-concept. Asset type: production mobile-game avatar sprite
atlas. Create exactly 50 distinct friendly human face avatars, with no chess
pieces or fantasy characters. Include balanced men and women plus boys, girls,
and teenagers; broad skin tones and global facial features; straight, wavy,
curly, coily, braided, locs, short, medium, and long hairstyles; natural hair
colors; adult men with and without beards or moustaches; glasses on a few adults
and teens. Use polished high-quality 2D game-avatar illustration with clean,
crisp contours and consistent art direction. Arrange exactly 10 columns by 5
rows with one centered, front-facing head-and-shoulders portrait per equal cell,
consistent scale and eye line, safe hair/shoulder padding, and a simple circular
color backdrop. Use bright even lighting and welcoming neutral expressions.
Exactly 50 portraits, no empty cells or duplicates, no text, labels, numbers,
logos, watermarks, chess imagery, crowns, armor, weapons, helmets, costumes,
borders, or overlap. Keep children and teenagers age-appropriate, fully
clothed, and non-photorealistic.

## V2 cleanup prompt

The original atlas was supplied as the edit reference to the built-in OpenAI
image-generation tool with this prompt:

> Edit this avatar atlas while preserving the same 50 distinct illustrated
> people, their row-major order, facial identity, apparent age, skin tone,
> hairstyle, clothing colors, and friendly polished 3D-cartoon style. Output
> one exact 10-column by 5-row rectangular contact sheet with perfectly equal
> square cells. Every portrait must be centered independently within its own
> cell and composed safely for a circular avatar crop: entire hair silhouette
> and face inside a centered circle, shoulders may end near the lower edge, and
> at least 8% clean background gutter on the left, right, and top. No hair,
> clothing, shadow, or background circle may cross a cell boundary or overlap
> an adjacent cell. Use crisp straight cell boundaries, no grid lines, no text,
> no logos, no duplicate or missing people. Keep each cell's soft pastel
> circular background but ensure it stays fully inside its own square.
> Landscape 2:1 atlas, high resolution.

The output was resized to 1800 x 900. Resizing did not make the generated grid
uniform, so runtime cropping now uses individually measured portrait bounds.
The original artwork and stable avatar IDs are preserved.
