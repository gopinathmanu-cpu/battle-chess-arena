# Android beta 18 testing handoff

Version: `0.9.0-beta.18+33` · expected ARM64 split APK version code: `2033`.

## Included changes

- Show opponent identity and match details before the board in local, computer,
  tournament and Conquest play, consistent with online games.
- Lock each Conquest round's themed Black army to its named opponent across
  swipes, settings and resume. White remains customizable and Classic mode is
  still available.
- Show the guaranteed 300-credit welcome balance immediately and keep active
  online games connected directly to the global wallet header.
- Send the complete authoritative credit account with balance-changing server
  responses, preserving transaction reason/ID, exact-once animation and cache.
- Rebuild Chess Set Studio with complete fitted themed formations instead of
  disconnected modular anatomy, and arm all previously unarmed kingdom Queens
  with a weapon appropriate to their visual theme.
- Standardize play-action icons: yellow Move suggestion bulb, red Threat scan,
  clearer Themed/Classic target-style toggle and outlined settings gear.
- Expand the main-page chessboard selection to the full responsive chooser
  width while preserving a square board in portrait and landscape layouts.
- Show the former Original chess-set category as Fantasy without changing its
  saved identifier or the four sets it contains.
- Resolve each of the 31 themed chess sets to a distinct project-original,
  sample-free soundtrack; keep all loops within a 12 MiB aggregate budget.
- Replace the flat Home header with a bright bordered welcome card without the
  repeated app icon, plus clearer selection/play headings and brighter cards.
- Add a collapsible **Your Chess Circle** at the bottom of Play Online, grouping
  saved players into Family, Friends and Professionals with presence, invite,
  move and remove controls. Migrate legacy favourites into Friends.
- Present one global credit total with a gold star-coin, remove the duplicate
  online-lobby balance and accounting split, and play an original mute-aware
  coin sound exactly once for every confirmed increase or decrease.

## Automated verification

- `flutter analyze`: no issues.
- `flutter test`: all 356 tests passed.
- `npm --prefix server test`: all 58 tests passed with localhost integration enabled.
- Kingdom provenance verifier: all 27 selected runtime atlases and hashes passed.
- Queen atlas pixel verifier: only Queen columns changed in 24 atlases; the 3
  already-armed kingdom atlases remained rendered-pixel identical.
- Theme-audio verifier: 31 distinct mono PCM loops passed format, duration,
  loudness, seam, unique-hash and 12 MiB aggregate-budget checks.
- `git diff --check`: passed.

## APK verification

- [x] Signed ARM64 APK built successfully: 198,154,408 bytes.
- [x] Package `com.manugopinath.battlechessarena`, min API 24, target API 36,
  version code `2033` and version name `0.9.0-beta.18` verified.
- [x] APK Signature Scheme v2 verified. Certificate SHA-256:
  `1daa383a6d68696b8598e9144e51a06d2a7ceba1065a14bc742bdc747ef3af51`.
- [x] Static 16 KB ZIP alignment verified.
- [x] APK SHA-256:
  `555814dd77960ca3eab3a56df5e9442601620cd98d97ef1d0221f64f213dd521`.

## Testing limitations

Physical-device installation, opponent-panel layout, Conquest artwork locking,
wallet feedback and final Queen legibility at phone board scale remain pending.
Install over the earlier ARM64 beta without uninstalling to preserve local
saves. Online features require the matching server revision to be deployed.
