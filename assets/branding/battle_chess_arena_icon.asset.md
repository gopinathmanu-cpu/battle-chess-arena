# Classic versus Themed Knight launcher icon

- Active master: `battle_chess_arena_icon_v7.png`, opaque 1254 × 1254 RGB PNG.
- Version 7 is the user's selected `icon-options/option-1.png`, copied exactly
  without regeneration or retouching. Both backgrounds are gold; the ivory
  Classic knight has gold trim without the later sapphire ornament. The single
  gold-white lightning divider and black mounted themed knight are retained.
  Generation prompt: `icon-options/README.md`, Option 1. Export hashes are in
  `launcher-icons.manifest.json`. Version 6 is retained as a fallback.
- Previous masters: `battle_chess_arena_icon_v5.png`, `battle_chess_arena_icon_v4.png`, `battle_chess_arena_icon_v3.png`,
  `battle_chess_arena_icon_v2.png`, and
  `battle_chess_arena_icon.png`, retained as recoverable fallbacks.
- Version 6 SHA-256: `0916092b44045973d66c8704b36eaabfe59b175bec2e872227143ec1dbfb9223`.
- Version 6: built-in image-generation tool, 2026-09-26, editing version 5.
  Replaces the dark violet backdrop with daylight sky blue and ivory behind
  the black themed knight. Retains the white Classic knight and single bolt.
- Built-in image-generation tool, 2026-09-20. Version 5 retains the Black Manga
  Vanguard knight, simplifies the divider to one central lightning notch, and
  insets both subjects for circular and adaptive launcher masks.
- Character origin: top row, fourth cell of
  `assets/characters/themed-piece-atlas-elephant-chariot.png` (Manga Vanguard).
- This is a high-resolution interpretation of that project-owned mounted knight,
  not a pixel-exact crop. The board atlas itself is unchanged.
- An ivory Staunton knight faces a black-and-gunmetal Manga Vanguard mounted
  knight. Their inward-facing heads and the thick gold lightning seam remain readable at
  small launcher and favicon sizes.
- Original project visual asset, distributed under GPL-3.0-or-later.
- Regenerate native launcher sizes on macOS with
  `node tool/update_launcher_icons.mjs`; `--check` verifies dimensions, colour
  formats and SHA-256 consistency with `launcher-icons.manifest.json`.
  The export utility also supports transparent masters (Android alpha, lossless
  ivory flattening for iOS); the current master needs no flattening.

## Version 6 final prompt (built-in image-generation tool)

```text
Edit this chess app launcher icon. Preserve the ivory white classic Staunton knight on the left facing right and black armored themed mounted horse-and-rider knight on the right facing left, preserving their identities. Change the dark violet/black background behind the black knight to bright airy pale sky blue and ivory, including a light blue/white chessboard floor. Keep the left background luminous warm light gold. Welcoming daylight, not ominous: no dark background, dark purple haze, or black corners. The knight and horse themselves must remain black/gunmetal with silver and crimson accents, with strong contrast against the light background. Preserve exactly ONE broad gold-white lightning divider with ONE central notch, no extra spikes, branches or bolts. Slightly inset BOTH subjects so the entire classic base and themed rider, cape and horse fit safely inside an inscribed circle, with breathing room; corners contain background only. Square opaque full-bleed artwork, no visible circle or border. Crisp polished original fantasy game art, no recognizable franchise additions, no text, logos, watermarks or extra figures. Deliver one finished icon.
```

Reference: `battle_chess_arena_icon_v5.png`, SHA-256
`4fc3883bc73caa20e5b520d52925ff53022feb9b157f7ef1a7c172e95b876ad5`.
This edit does not change the underlying provenance caveats documented in
`docs/ARTWORK_PROVENANCE.md` and is not a legal clearance guarantee.

## Version 5 final prompt (built-in image-generation tool)

```text
Use case: precise-object-edit. Edit the supplied Battle Chess Arena launcher
icon for circular and adaptive masks. Preserve the ivory Classic knight, the
black-and-gunmetal Manga Vanguard mounted knight, their inward-facing poses,
and gold-versus-violet backgrounds. Scale and reposition the subjects so their
essential silhouettes fit within an inscribed circular safe area; only
background may extend into the corners. Use one simple gold-white lightning
divider made from two broad diagonal sections joined by one central notch—no
repeated zigzags, branches, secondary bolts, or sawtooth chain. Deliver normal
full-square opaque artwork with no visible circle, rounded corners, border,
text, logo, watermark, additional characters, duplicate limbs, or crops.
```

## Version 4 prompt (built-in image-generation tool)

```text
Use case: precise-object-edit. Create an alternate Battle Chess Arena launcher
icon from the supplied diagonal Classic-versus-Themed knight icon. Keep exactly
one polished ivory Classic Staunton knight on the left, facing right. On the
right, transform the themed mounted knight into the Black Manga Vanguard army:
one fantasy knight wearing black and gunmetal armor with restrained violet,
crimson, and silver highlights, mounted on one black armored horse and facing
left. Replace the straight divider with a bold jagged lightning-bolt split from
upper-left to lower-right, glowing electric gold-white and readable at 48 px.
Use warm ivory/gold on the Classic half and deep charcoal/violet on the themed
half. Square 1:1 opaque image, crisp launcher-safe shapes, no text, logo,
watermark, extra people, horses or chess pieces, duplicate limbs, weapons,
clutter, or cropped essential features.
```

## Version 3 prompt (built-in image-generation tool)

```text
Use case: precise-object-edit. Edit the supplied diagonal split Battle Chess
Arena launcher icon while preserving its core design, colors, lighting,
characters, and exact upper-left to lower-right luminous diagonal divider. Keep
exactly one ivory Classic Staunton knight on the left, facing right, and exactly
one red-haired Manga Vanguard themed knight mounted on one white armored horse
on the right, facing left. Make the two knight heads confront each other across
the diagonal. Scale both subjects down and move them inward so the Classic base
and themed horse-and-rider silhouette have launcher-safe margins. Keep the
Classic piece and themed mounted knight visually equal in weight. Thicken the
diagonal gold seam so it remains visible at 48 px. Square 1:1, opaque background,
no rounded corners, text, letters, logos, watermark, extra people, horses or
chess pieces, duplicate limbs, weapons, clutter, or boundary crops. Crisp bold
mobile-game icon readable at small size.
```

## Version 2 prompt (built-in image-generation tool)

```text
Use case: precise-object-edit
Asset type: premium Battle Chess Arena launcher icon, readable from 24 px through 1024 px.
Input image 1: EDIT TARGET and identity reference; preserve its mounted red-haired knight, white horse, red-white-gold palette, bright optimistic fantasy tone, and chess-knight pedestal concept.
Primary request: refine and simplify this artwork into a more iconic, polished game-app mark. Keep one bold mounted-knight silhouette, but crop slightly closer so the rider, horse head, sweeping red cape, and chess-knight pedestal dominate the square. Improve silhouette separation and facial readability. Reduce tiny armor filigree and visual noise while retaining premium cel-shaded anime/fantasy rendering.
Scene/backdrop: full-bleed warm golden radial glow with a subtle large-scale checkerboard suggestion. Retain only a few faint, oversized Staunton silhouettes in the far background; lower contrast and blur them so they never compete with the hero. Remove the scattered star sparkles except for at most one restrained highlight.
Composition/framing: centered, compact emblem-like triangular composition with balanced breathing room for automatic rounded-square and circle masks; all essential features inside the central 80% safe zone; no thin detail at the outer edge.
Lighting/mood: luminous, heroic, energetic, high contrast on the foreground with a darker warm-gold rim behind the white horse for separation.
Color palette: vivid crimson, ivory white, metallic gold, warm amber; controlled highlights, deeper red shadows, no washed-out yellow cast.
Materials/textures: clean glossy enamel-like armor and chess-piece base, crisp broad shapes, restrained detail that survives downsampling.
Constraints: opaque square image; no text, initials, numbers, logos, labels, border, frame, watermark, additional characters, extra limbs, distorted hands, distorted horse anatomy, or mockup. Preserve the recognizable project identity, but make it cleaner and more legible at launcher size. Deliver one finished icon only.
```
