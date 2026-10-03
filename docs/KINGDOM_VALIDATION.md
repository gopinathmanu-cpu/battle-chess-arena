# Kingdom expansion validation

Source changes: 2026-09-26. No APK or server deployment is produced by this task.
The packaged Beta 14 APK does not include these changes.

## Automated checks

- Full Flutter regression suite: 301 tests passed before the final visual-only
  crop repairs and Home preview badge refinement; rerun required after final QA.
- Renderer checks decode all 31 themed sets (372 role/side sprites), inspect
  transparent cell margins, paint at 48px and check a common baseline.
- Every pawn is narrower and shorter than all five major roles in its own army;
  bishops, knights and rooks are shorter than both royals. A rounding-margin
  adjustment fixes the very narrow Egyptian queen/pawn width comparison.
- Catalogue/persistence tests cover all 31 IDs, the original four indices, all
  four Classic styles, separate White/Black/board selections and all eight music
  choices without adding audio files.
- Home tests cover all 35 built-in previews, filtered-index mapping, wraparound,
  remembered choices, 320×568 / 390×844 / 844×390 layouts, large text, and access
  to the final item of the 31-world settings dropdown on a narrow screen.
- Crop preparation: four offline Swift regression checks pass (overlap rejection,
  required explicit exclusions, successful audited isolation, invalid bounds).
- Home previews suppress role badges only in the gallery, so small previews show
  the actual illustrations. Tests retain the default badges on live game boards.
- Flutter analysis: no issues found before final preview-only refinement.

## Visual review

Review sheets are generated under `build/themed-piece-review/` and Home captures
under `build/home-visuals/`. Sources, complete actual prompts, measured source
crops and selected runtime atlases are preserved in `assets/characters/kingdoms/`.
Full-resolution and board-size inspections complement automated geometry checks:
passing bounding-box tests alone cannot establish correct anatomy or absence of
an underlying source-image overlap.

Final mounted-piece repairs are being reviewed separately; this record must not
be read as final asset acceptance until those are complete.

The review found and repaired underlying tusk/tail overlaps in four legendary
sets, and identified the same issue in Chola for a targeted mounted-only repair.
Ottoman foreground masks were refined to preserve complete source tusks/tails.
Automated alignment checks passing did not replace these source-level reviews.

## Remaining release acceptance

- Test on an Android phone: gallery swipe responsiveness, image-cache memory,
  mixed army choices, promotions, capture animations and small-board readability.
- Resolve the two older reference-origin questions documented in
  [artwork provenance](ARTWORK_PROVENANCE.md). No blanket copyright clearance
  or exhaustive similarity search is claimed.
- Build and sign the next APK separately when requested. No live user/game data,
  online service deployment, bot levels or chess rules were changed by this task.
