# Custom multiplayer avatars

Open **Play Online**, then choose **Create your avatar** when creating a profile.
For an existing profile, use the pencil beside your Avatar name, then choose
**Create your avatar** or **Edit your avatar**. The 50 preset portraits and 20
computer-opponent portraits are unchanged.

Start with a Man, Woman, Boy or Girl look and adjust any combination:

- Child, teen, adult or senior appearance; masculine/feminine styling.
- Four face shapes and eight skin tones.
- Twelve hairstyles and ten hair colours, including shaved, curls, afro,
  braids, long hair, silver/white and expressive colours.
- Independent moustache and beard options, including no facial hair.
- Round, rectangular or cat-eye glasses, sunglasses or aviators.
- Six outfits with eight colours and eight portrait backgrounds.

The live preview is built from scalable vector layers rather than a cropped
image sheet. Hair, facial features and glasses share the same alignment at both
small multiplayer sizes and the larger selection preview. Every option remains
available for every starting look.

Choose **Use avatar**, then save the enclosing profile (or **Enter Arena** for a
new profile). Cancelling the editor or profile dialog does not change the saved
profile. Reset affects the current draft only. The design is retained with the
profile on this device; switching to a preset replaces the selected design.
If the connection drops while a profile edit is saving, the current app session
keeps the change queued and retries after reconnecting. Wait for saving to finish
before closing the app; an unacknowledged change is not yet persisted.

## Online sharing and rollout

The updated app and service share a compact design ID through existing player
profiles, game snapshots, invitations, search results, rankings and game history.
No photograph, image upload, external image service or new account is needed.

Both players need the updated app to render custom portraits. Until the online
service is updated, the app preserves your custom design locally and shows a
notice that other players see a preset. Reconnecting after the service update
publishes the retained design. Existing server storage limitations still apply;
this feature does not add cloud backup or cross-device profile recovery.

This is a next-build source feature, not part of the already-packaged Beta 14 APK.
Building a new APK does not deploy the service. Physical-device/two-player
acceptance is still required before release.

## Validation (2026-09-26)

- Full Flutter suite: **282 tests passed**; analyzer: **no issues**.
- Full server suite: **39 tests passed**, including avatar validation and sharing.
- Verified option rendering, circular bounds, persistence, save/cancel/reset,
  preset compatibility, rejected updates and interrupted-save recovery.
- Reviewed rendered portraits and editor layouts at 390×844, 320×568 with 2×
  text, and 640×360/844×390 landscape. Review images are in
  `build/custom-avatar-review/` and `build/avatar-studio-visuals/`.
- No APK was built and no live service was deployed for this change.
