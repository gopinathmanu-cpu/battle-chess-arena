# Android beta 11 avatar correction

Version: `0.9.0-beta.11+26`

Verification: Flutter analysis is clean. All 25 focused avatar and online-screen
tests pass, including profile editing at 320 x 568, selection preview updates,
all-portrait rendering, and non-overlapping source rectangles. The broader run
passed 169 tests and exposed the narrow-screen issue fixed in this focused rerun.

- Fixed neighboring-avatar overlap in all 50 human and 20 bot portraits.
  Generated artwork was irregularly spaced; the renderer now uses measured
  individual source rectangles instead of assuming equal grid cells.
- Enlarged responsive picker thumbnails and added a 120-pixel selected preview
  in both profile creation and profile editing. Avatar IDs and artwork are unchanged.
- Visually reviewed a runtime rendering of all 70 portraits. To regenerate it,
  run `AVATAR_REVIEW=1 flutter test test/online_avatar_image_test.dart` and inspect
  `build/avatar-review/all-portraits.png`.

The ARM64 release APK passed signature and 16 KB ZIP alignment checks. Its
version code is 2026 and it uses the same signing certificate as beta 10.
This handoff targets ARM64 phones. Older release packages are preserved.
Device installation and physical-phone visual checks remain pending.
The server deployment and online-storage limitations in beta 10 still apply;
this avatar fix does not require server changes.
