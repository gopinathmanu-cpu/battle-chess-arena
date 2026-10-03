# Quick play controls

- Home has a compact accented header and a Settings shortcut. Music, display
  preferences, Classic/Themed selection and reset are available there.
- Computer headers omit the theme name and expose Suggest, Threat scan, family
  switch, Settings and Undo. New game and Hide top bar are in Settings.
- Online headers expose Suggest, Threat scan, family switch and Settings.
  Copy Game ID remains available in Settings.
- Suggest and Threat shortcuts also appear in the settings header and the
  compact controls when the main top bar is hidden.
- Swipe the board left/right to browse within its current Classic/Themed family.
  A swipe must travel at least 48 logical pixels; it never submits a chess move.
  Vertical drags and short drags do not change the set. Capture animations block
  set changes until they finish. Accessibility actions offer Next/Previous set.
- Local/tournament saves retain their selected armies, board and Classic style.
  Online appearance is device-local and stored separately per room and seat;
  changing it does not alter the opponent's selection.
- Suggestions no longer have a three-use quota. Old exhausted local saves work
  immediately. Online requests keep authoritative turn/status and replay checks,
  and require deploying the updated server to remove its old quota. No deployment
  was performed as part of this UI change. Engine failures remain retryable.

Validation: static analysis clean; 312 Flutter tests and 47 server tests passed.
Additional gesture/persistence checks cover safe swipes, retained selections,
independent online rooms/seats, exhausted legacy hint saves, 320px settings,
and continued home-carousel swiping. Home was rendered and visually inspected
at 390×844, with layout tests also covering narrow phones and landscape.
