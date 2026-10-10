# Saved custom chess sets

Beta 48 removes new custom-theme creation from Home and Settings. Existing sets
remain on the device and can be selected under **My Themes**. Choose **Edit** on
an existing set to adjust it, then **Save & use**. The legacy creation/library
renderer remains in the source for saved-set compatibility, without an app entry.

## Piece builder

Choose White or Black, then one of the six chess roles. The builder offers four
compatible complete formations drawn from the four Animated Fantasy armies:
Manga Vanguard, Epic Guardians, Olympian Legion and Neon Dominion. Older saved
designs retain their original formations until explicitly edited. A formation
is a fitted jigsaw unit: the Horse and knight rider, Elephant and bishop rider,
or Chariot and rook rider keep their original orientation, contact points,
lighting and proportions. Kings, queens and lean pawns likewise remain complete.

Changes apply only to that role on that side; both pieces of a duplicated role
share the design. **Apply to this whole army** gives every role on the selected
side the same visual world. Black formations are mirrored as a whole and retain
the brighter gold, silver and colour accents used by the animated sets.

Piece scaling and free mixing of anatomy/accessories are deliberately not
available. Every formation uses the same square-fit and baseline rules as the
new animated pieces, preventing floating riders, disconnected limbs and clipped
or mismatched composites.

## Board and background

Use a preset palette or enter your own square colours. Four surface finishes
are available: solid, wood, marble and neon. Seven backgrounds combine the four
existing illustrated worlds with midnight, forest and royal gradients. Side
accent colours and the gradient tint can also be customized.

## Saved collection

Up to 20 existing named sets are stored on the current device. Use, edit or
delete a saved set from Home. Deletion asks for confirmation; leaving
a changed draft asks before discarding it. A failed save keeps the draft available.

The active saved set is remembered across launches. It is a device-local display
preference shared by computer play, tournaments and online play, including an
ongoing game. Boards, promotion choices, capture animations and captured-piece
displays use the same designs. No legal moves, player colours, clocks, difficulty
levels or network game data are changed.

Choosing a built-in Animated/Classic set deactivates the custom appearance without
deleting the collection. Resetting game settings does the same. Deleting the
active custom set restores the built-in appearance.

## Current scope

The builder reuses bundled, complete animated formation sprites; it does not
generate art on the phone or accept uploaded images. Sets are not yet
cloud-synced, exported, sold or automatically shown to
an online opponent; each player controls their own display. Uninstalling or
clearing app data removes the device-local collection.

Artwork provenance and preparation workflows are recorded beside the kingdom
and character atlases in `assets/characters/`.

## Validation (2026-09-26)

- Automated validation covers persistence/failures, independent army
  formations, draft cancellation, real atlas selection, game integration,
  promotion, captures and compact/large-text layouts.
- Native phone installation and performance testing remain part of the Beta 18
  device checklist.
