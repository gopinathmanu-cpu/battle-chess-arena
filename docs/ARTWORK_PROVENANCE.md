# Artwork provenance and release review

The project uses original project-directed generated illustrations and original
code-drawn artwork. These safeguards reduce infringement risk; they are not a
legal clearance, a guarantee of uniqueness or a claim that every generated pixel
is eligible for copyright protection. Laws and other rights vary by jurisdiction.

## Rules for new artwork

1. Describe the intended role, historical clothing cues, materials, composition
   and palette. Do not ask for a specific contemporary franchise design, actor,
   branded costume, stock illustration, museum photograph or named artist's style.
2. Use historical and literary sources for factual/textual context, not as image
   inputs to trace or reproduce. A traditional story does not make a recent film,
   translation, illustration or character design free to copy.
3. Record the full prompt, tool/mode, generation date when known, input-image
   provenance if any, selected source file and preparation steps. Keep rejected
   variants out of the runtime bundle. Never invent missing origin records.
4. Visually review selected assets at source and playing size. Check for obvious
   recognizable modern designs/likenesses, logos, signatures and watermarks, as
   well as cutout fragments. Replace suspicious artwork; do not merely erase a
   watermark from third-party material.
5. For imported material, verify the actual source licence and attribution rules
   under [Open Source Policy](../OPEN_SOURCE_POLICY.md). Unclear rights block
   release. A generated image cannot itself certify that no similar work exists.

## Asset records

| Family | Origin/preparation record |
| --- | --- |
| Kingdom and legendary chess armies | [Kingdom artwork](../assets/characters/kingdoms/kingdoms.asset.md); complete prompt manifests and measured source crops in the same folder and its `source/` subfolder |
| Black-piece brightness study | `concepts/black-piece-brightness-reference-v1.png`; built-in image generator, 2026-09-26, derived from the project-owned Japanese runtime atlas solely as a non-runtime colour-treatment reference; exact generation direction is recorded in the kingdom artwork record |
| Original four themed armies | [Themed atlas record](../assets/characters/themed-piece-atlas.asset.md) |
| Classic pieces | [Classic atlas record](../assets/characters/classic-piece-variations-atlas.asset.md) and [Staunton record](../assets/characters/classic-staunton-atlas.asset.md) |
| Custom Chess Set Studio parts | [Modular parts record](../assets/custom_sets/modular-parts.asset.md) |
| Human preset portraits | [Human portrait record](../assets/avatars/human-face-atlas.asset.md) |
| Bot portraits | [Bot portrait record](../assets/avatars/bot-personality-atlas.asset.md) |
| Custom multiplayer portraits | Original vector drawing in `lib/src/features/online/custom_avatar_portrait.dart`; no external portrait API or stock-image pack |
| App icon | [Icon record](../assets/branding/battle_chess_arena_icon.asset.md) |
| Neon Dominion illustrated film | [Cinematic artwork record](NEON_CINEMATIC_ARTWORK.md); submitted prompts, input pose sheets, measured renderer crops and original score generator |
| Neon Dominion live ready/attack poses | [Pose artwork record](NEON_LIVE_POSE_ARTWORK.md); two original built-in generation prompts, existing cast references, unchanged RGBA atlases and renderer-only crops |
| Manga Vanguard, Epic Guardians and Olympian Legion live/film worlds | [Animated armies artwork record](ANIMATED_ARMIES_ARTWORK.md); six original built-in generation prompts, unchanged RGBA casts/worlds, renderer crops and three original score loops |
| Beta 50 brighter Animated casts, Queen hair and upright Neon Rooks | [Selected cast artwork](BRIGHT_ANIMATED_CAST_ARTWORK.md) and [full submitted prompts](BRIGHT_ANIMATED_CAST_PROMPTS.json); nine intact runtime cast PNGs, Rook-only revised Neon pose routing, project cast references, preserved originals and renderer-only crop/body metrics |

The kingdom expansion uses the built-in image generator. Current generation
instructions require original designs and explicit copying exclusions; earlier
prompts are preserved as actually submitted, with any omissions noted rather
than reconstructed. Historical reading informs attire only. Elephants and
chariots across all realms are intentional chess fantasy adaptations, not claims
about actual armies. Legendary realms remain labelled Legendary, separate from
historical powers. No downloaded museum artwork is bundled with this expansion.
Previously existing asset records are retained; this document is not a claim
that an exhaustive similarity search or legal audit of earlier assets occurred.

### Open provenance questions (2026-09-26)

The older records disclose two user-supplied references without recorded
creator/source/permission: `assets/concepts/piece-families.png` (also used as
scenery and inspiration for original themed art/branding), and the chessboard
reference used for the Classic Flat Club silhouettes. This is missing evidence,
not a finding of infringement. Confirm the references' origin and reuse rights
or replace the affected designs before claiming release clearance. The new
kingdom atlases do not use these references as image inputs.

## Release gate

- [ ] Every newly bundled image resolves to an origin record; all referenced
      source sheets, prompts and preparation scripts are in the source handoff.
- [ ] Selected final artwork has been visually reviewed for obvious copying,
      likenesses, logos/signatures and watermarks; concerns are recorded/resolved.
- [ ] Imported assets, if any, have a verified compatible licence and attribution.
- [ ] Only selected runtime atlases, not raw source sheets or rejected variants,
      are declared as Flutter assets.
- [ ] Check any intended commercial release, trademark use or uncertain design
      with qualified counsel in the relevant jurisdictions. Do not advertise
      these assets as guaranteed copyright-free or legally cleared.

## Licensing limits and background reading

Project notices offer GPL-3.0-or-later only to the extent the project holds
licensable rights. They do not override other parties' rights or establish
exclusive ownership of AI-generated elements.

The US Copyright Office distinguishes ideas/facts from protected expression in
its [copyright FAQ](https://www.copyright.gov/help/faq/faq-protect.html). Its
[AI initiative](https://www.copyright.gov/ai/) discusses the separate questions
of AI output copyrightability and the use of protected material. These are useful
background sources, not worldwide clearance for this app.
