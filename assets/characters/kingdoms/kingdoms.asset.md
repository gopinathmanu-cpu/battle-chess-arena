# Kingdom-inspired chess armies

Twenty-seven project-directed sprite atlases created with the built-in
`image_gen` tool on 2026-09-26, extending the existing four to 31 themed sets.
The complete prompts are recorded in `kingdom-prompts-v1.json`,
`kingdom-role-prompts-v1.json`, `historical-expansion-prompts-v1.json`,
`source/legendary-expansion-prompts-v1.json` and
`source/french-royals-prompt-v3.json`. No external museum artwork is copied
into the game. GPL-3.0-or-later applies to rights the project can grant; generated
output is not a guarantee of non-infringement or exclusive copyright ownership.
See [provenance safeguards](../../../docs/ARTWORK_PROVENANCE.md).
`initial-kingdoms-preparation-v1.json` maps the first eight selected runtime
atlases to their exact source sheets, crop configurations and SHA-256 hashes.
Expansion manifests carry the corresponding records for later sets.
Run `node tool/verify_kingdom_provenance.mjs` to verify selected runtime hashes,
PNG dimensions and explicit asset declarations. This is an integrity check,
not a copyright or similarity assessment.

## Design scope

These are fictional chess adaptations inspired by historical court dress,
military attire, not exact uniforms or portraits of named
rulers. Chess roles such as a queen, mounted knight and advisor are adapted for
readability; they do not assert that each culture used those exact roles.
Chess-side colour is carried by garments/materials, not ethnicity or complexion.
Pawns are simple adult foot soldiers, not miniature children.

| Atlas | Clothing inspiration |
| --- | --- |
| `japanese-v1.png` | Late-medieval/Momoyama shogunate, lacquered armour and court silk |
| `chinese-v1.png` | Ming-inspired imperial robes and cavalry armour |
| `mongolian-v1.png` | 13th-century Mongol/Yuan court robes, gugu headdress and mounted archery |
| `egyptian-v1.png` | New Kingdom-inspired linen and royal collars/headdresses |
| `arab-v1.png` | Abbasid-inspired layered robes/caftans and turbans |
| `persian-v1.png` | Early-17th-century Safavid-inspired brocade and wrapped turbans |
| `english-v1.png` | Late-medieval court dress, plate armour and foot archer |
| `french-v1.png` | Late-medieval court dress and plate-armoured cavalry |

The historical expansion adds Sparta, Macedonian, Roman, Achaemenid Persian,
Ottoman, Chola, Maratha, Zulu, Aztec, Inca and Mewar armies. The separate
Legendary group adds Lanka, Ayodhya/Kosala, Hastinapura/Kuru, Kishkindha, Asgard,
Camelot, Atlantis and the epic Troy. Their full prompts and descriptive research
sources are in the two expansion manifests. These are independently invented
court characters, not copies of modern film/game adaptations or actors.

All final bishops are elephant-mounted warriors; all final rooks are warriors
standing in compact wheeled chariots. These intentionally consistent chess-role
motifs are fantasy adaptations, including in armies that did not historically
use war elephants or chariots. They are not historical claims. The first four
existing themed sets already use these motifs and retain their original artwork.

Every Queen now carries a readable theme-appropriate staff, sword, bow, mace or
spear. The 24 previously unarmed kingdom Queen pairs were refined as a single
controlled 48-cell sheet and composited Queen-column-only; Asgard, Atlantis,
Hastinapura and the four original sets already had armed Queens. The edit prompt,
prepared source checksum and QA workflow are recorded in
`source/queen-weapons-v1.asset.md`.

## Preparation and rendering

Keep the generated source sheets separately from runtime artwork. Runtime
atlases contain 6 columns (King, Queen, elephant Bishop, horse Knight, chariot
Rook, Pawn) and
2 rows (White, Black), with isolated 256×256 transparent cells. Every sprite is
centred horizontally and normalized to the same foot baseline. The local
preparation utility preserves foreground RGB and uses alpha/cutout processing
to keep neighboring pieces out of each cell.

Some generated source sheets contain unrequested scenery, labelled bases or a
different role order. Measured source crops explicitly exclude those bases and
map to the correct role order. Earlier advisor and fortress columns are replaced
after cutout preparation using `tool/compose_kingdom_atlas.swift`; they are not
the shipped bishop/rook designs. Supplement sheets have White/Black columns and
four theme rows: Japanese/Chinese/Mongolian/Egyptian in the east sheets and
Arab/Persian/English/French in the west sheets. This grouping is only a filename
convention for processing, not a historical classification.

French royals were generated again as a separate two-column sheet because the
initial crowded royal garments could not be isolated without clipping. The
selected runtime atlas combines that third-generation royal sheet with the
second-generation horses/pawns and the reviewed elephant/chariot supplements;
`source/french-composition-v1.json` records the exact twelve-cell assembly.
`tool/assemble_kingdom_cells.swift` performs this assembly without redrawing.
`source/french-reference-v1.png` preserves the project's own first generated
French attempt, used as the visual reference for the second attempt. It had
only one army and is not shipped; the input was not an external artwork.

Reviewed exclusions in crop JSONs remove specific neighbouring foreground
fragments. They are recorded rather than silently selecting only a largest
component (which could lose detached weapons). Source PNGs remain unchanged.
Normalized intermediate and QA reports are produced under `build/kingdom-review/`;
historical/legendary atlas reports accompany their source/final records. Small
residual plinth-top edges on a few initial horse/pawn cutouts are not neighbouring
pieces; check their appearance during mobile acceptance. Sources and rejected
intermediates are not declared as Flutter runtime assets.

The renderer now gives every built-in themed role the same 94%-of-square visual
height on one baseline. Wide mounts/chariots are compressed horizontally when
needed, while the pawn is capped at a deliberately lean width. Black-side
rendering preserves dark costumes and boosts the existing metallic and coloured
accessories without an additive lift to true black. These are art presentation
rules, not movement or engine changes. Custom user-created sets use the same
fixed full-square fit; Classic artwork is unchanged. The generated Japanese brightness
study used to calibrate this treatment is recorded at
`docs/concepts/black-piece-brightness-reference-v1.png`; it is a visual reference,
not a runtime atlas, because generative edits do not preserve exact cell geometry.

## Orientation standard v2

All Historical and Legendary runtime atlases now use their `*-v3.png` versions.
The v3 side-colour refinement preserves the v2 orientation and exact alpha/grid
geometry. In White elephant and horse cells, neutral grey mount material below
the rider is converted to cool ivory while saturated blue/gold tack remains
untouched. In Black rows, existing crimson and gold details receive selective
contrast without lifting true-black costume areas. Queen cells retain the
reviewed theme-specific weapon artwork. The repeatable transformation is in
`tool/refine_kingdom_side_colours.swift`; v2 remains the orientation source.
Directional source units follow one canonical near-front three-quarter direction:
viewer-left in both source rows. The board renderer mirrors the Black source row,
so the two armies face one another during play. Upright Kings, Queens and Pawns
remain near-front and unchanged; reviewed elephant Bishops, horse Knights and
directional chariot Rooks were mirrored cell-by-cell only where required.

`tool/standardize_kingdom_orientation.py` performs the lossless transformation.
It does not redraw, recolour, resize or move any sprite. The exact reviewed roles,
v1/v2 SHA-256 values and direction policy are recorded in
`orientation-standard-v2.json`. The original v1 atlases remain as provenance
sources and are no longer bundled in the application.

Each built-in realm also has an explicit two-colour board palette in
`lib/src/features/play/board_appearance.dart`. The palettes use muted complementary
tones, avoid near-black playable squares and are regression-tested for light/dark
luminance separation. This keeps black costumes, pale costumes and metallic
accessories distinguishable without changing the source atlases.

## Reference reading

Sources informed descriptive clothing cues, not image tracing or copying:

- Japanese arms: [Met, Art of the Samurai](https://www.metmuseum.org/exhibitions/listings/2009/art-of-the-samurai/photo-gallery).
- Japanese dress: [Tokyo National Museum, 16th-century kosode](https://www.tnm.jp/modules/r_collection/index.php?colid=I4069&controller=dtl&id=44&lang=en&t=type).
- Chinese court dress: [National Palace Museum, Ming portrait study](https://www.npm.gov.tw/NewChineseArtDownload.ashx?bid=4318) and [Palace Museum, empress dress study](https://www.dpm.org.cn/Uploads/File/2020/04/23/u5ea1462ea9baa.pdf).
- Mongol/Yuan court: [Met, The World of Khubilai Khan](https://www.metmuseum.org/exhibitions/listings/2010/khubilai-khan) and [University of Washington, 13th–14th-century Mongolian robe](https://depts.washington.edu/silkroad/exhibit/mongols/fig_104.html).
- Egyptian royalty: [Met, New Kingdom royal representation](https://www.metmuseum.org/art/collection/search/549632) and [Met, royal dress representation](https://www.metmuseum.org/art/collection/search/548355).
- Abbasid clothing: [School of Abbasid Studies](https://www.abbasidstudies.org/abbasids/clothing/).
- Safavid clothing: [Met, Fashion in Safavid Iran](https://www.metmuseum.org/essays/fashion-in-safavid-iran).
- English/French arms: [Royal Armouries, Hundred Years War](https://royalarmouries.org/objects-and-stories/stories/the-hundred-years-war-1337-1453) and [Met, European armour 1400–1500](https://www.metmuseum.org/fr/essays/fashion-in-european-armor-1400-1500).
- Late-medieval women's dress: [Ashmolean brass-rubbing collection](https://britisharchaeology.ashmus.ox.ac.uk/brass-rubbings/brass-rubb-women.html).
