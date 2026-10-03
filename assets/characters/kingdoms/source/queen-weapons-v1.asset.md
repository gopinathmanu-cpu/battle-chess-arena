# Queen weapon refinement

Created for Battle Chess Arena on 2026-09-26 with the built-in image-generation
tool, then normalized with `tool/prepare_kingdom_atlas.swift` and composited with
`tool/queen_weapon_sheet.swift`. The runtime update changes only column 2 (the
Queen) in 24 kingdom atlases. Pixel comparison against the previous runtime
atlases is performed by `tool/verify_queen_weapon_atlases.swift`.

Asgard, Atlantis and Hastinapura already had armed Queens and were not edited.
The four original themed armies already use Queen staffs in
`themed-piece-atlas-bishop-walk-v2.png` and were not edited.

## Files

- Prepared 48-cell transparent source: `queen-weapons-v1.png`
- Prepared source SHA-256:
  `4bef68e31ed61366c5830c77fac71a424357afe18065a9719c43f4e3d00c8cce`
- Generated draft retained by the image tool:
  `/Users/manugopinath/.codex/generated_images/01a0dd19-8f6d-71a3-8c79-62a5f9feccb8/exec-49f93b20-85e2-4b95-b926-42ef071ff883.png`

## Edit prompt

Use case: precise-object-edit. Edit the supplied production transparent chess
Queen sprite sheet. Preserve the exact grid, every Queen identity, face, crown,
hair, costume, proportions, side palette, lighting, full-body framing, baseline
and transparent background. Modify only hands/arms as minimally needed and add
exactly one clearly visible, firmly held, theme-appropriate weapon to every
Queen. Each weapon and grip must form one connected silhouette, remain inside
its cell and avoid floating parts, broken grips, body intersections, cropping,
extra limbs, text, scenery, bases or shadows.

Adjacent White/Black cells use the same weapon with their side palette. Cell
pairs, in row-major order: Achaemenid lotus staff; Arab saif; Ayodhya bow; Aztec
macuahuitl; Camelot longsword; Chinese jian; Chola vel; Egyptian khopesh;
English longsword; French court sword; Inca sun mace; Japanese katana;
Kishkindha gada; Lanka trident; Macedonian spear; Maratha talwar; Mewar sword;
Mongolian recurve bow; Ottoman kilij; Persian shamshir; Roman gladius; Sparta
dory; Troy bronze spear; Zulu assegai.

The first raw edit had coloured low-alpha fringe. It was never copied to a
runtime atlas. The existing preparation tool re-isolated and normalized every
complete Queen-with-weapon silhouette into exact 256×256 cells. Only those
reviewed cells were then inserted into the existing atlases.
