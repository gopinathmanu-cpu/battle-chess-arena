# Original theme music

GPL-3.0-or-later. Created 2026-09-06 for Battle Chess Arena.

Five original instrumental motifs synthesized with oscillators and envelopes;
no third-party songs, recordings, or samples. Stereo PCM WAV, 22,050 Hz, 16 bit.
Loop tails wrap into the beginning of each file for continuity.

- anime.wav: bright bell fantasy motif, 92 BPM.
- indianEpic.wav: Indian-inspired modal plucked strings and drone, 72 BPM.
- greek.wav: lyre-like plucks and soft drone, 76 BPM.
- futuristic.wav: FM synth arpeggio and bass, 88 BPM.
- classic.wav: harp-like major pentatonic motif, 68 BPM.

Regenerate with `python3 tool/generate_theme_music.py` (requires numpy).
These are original synthesized approximations, not authentic instrument recordings.

## Cinematic effects

The original `attack.wav`, `lightImpact.wav`, `heavyImpact.wav`,
`finalStrike.wav`, and `victoryApplause.wav` effects are synthesized from
oscillators and deterministic noise. They contain no third-party recordings or
samples. Regenerate them with `python3 tool/generate_cinematic_sounds.py`.
