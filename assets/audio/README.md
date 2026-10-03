# Original chess-set theme music

GPL-3.0-or-later. Created 2026-09-06 for Battle Chess Arena.

Each of the 31 themed chess sets has its own original instrumental loop. The
files are synthesized entirely from mathematical oscillators, deterministic
noise and envelopes. They contain no third-party songs, recordings, samples,
MIDI, model-generated audio, or copied melodies.

Theme loops are mono PCM WAV, 16,000 Hz, 16 bit, 8–15 seconds, and collectively
limited to 12 MiB. Their tails wrap and the circular render is rotated to a
quiet zero crossing for clean looping. Compact PCM avoids decoder differences
across supported Android/iOS devices while remaining materially smaller than
the previous stereo theme recordings.

| Musical direction | Chess-set assets |
| --- | --- |
| Bright fantasy bells / synth | `anime`, `futuristic`, `atlantis` |
| South Asian-inspired modal plucks, reeds and ceremonial rhythm | `indianEpic`, `chola`, `maratha`, `mewar`, `lanka`, `ayodhya`, `hastinapura`, `kishkindha` |
| East Asian-inspired pentatonic plucks, reeds and wood percussion | `japanese`, `chinese`, `mongolian` |
| West/Central Asian and North African-inspired modal plucks/reeds | `egyptian`, `arab`, `persian`, `achaemenid`, `ottoman` |
| Mediterranean-inspired lyre, horn and frame/war rhythm | `greek`, `sparta`, `macedonian`, `roman`, `troy` |
| Medieval European-inspired lyre and horn | `english`, `french`, `camelot` |
| African- and American-kingdom-inspired synthetic flute/percussion palettes | `zulu`, `aztec`, `inca` |
| Norse-myth-inspired low horn and ceremonial rhythm | `asgard` |

These are atmospheric, respectful fictional cues—not reconstructions or claims
of authentic traditional performances. Broad scales and timbre families guide
the setting, while each melody is generated from its own deterministic random
seed and then transformed. This avoids quoting recognizable traditional,
commercial, film, television, or game music.

Regenerate the theme loops with
`python3 tool/generate_theme_music.py --themes-only` (requires NumPy). Validate
format, unique hashes, loudness, loop seams and the total size budget with
`python3 tool/verify_theme_music.py`.

## Selectable background moods

The music picker has eight choices: Chess Set Theme (the theme-dependent track)
and these seven original mood compositions:

| Asset | Mood | Tempo |
| --- | --- | ---: |
| mood_rapid.wav | Rapid Chess — brisk synth patterns | 126 BPM |
| mood_zen.wav | Zen Garden — sparse bells and sustained pads | 56 BPM |
| mood_relaxing.wav | Relaxing Evening — soft plucked strings | 68 BPM |
| mood_inspiring.wav | Inspiring Rise — bright bells and moving harmony | 96 BPM |
| mood_calm.wav | Calm Waters — slow layered pads | 60 BPM |
| mood_focus.wav | Deep Focus — restrained repeating synth | 80 BPM |
| mood_epic.wav | Epic Strategy — rhythmic plucks and low drone | 104 BPM |

Created for Battle Chess Arena using `tool/generate_theme_music.py`. No music
downloads, third-party recordings, samples, MIDI, or existing songs are used.
These project-original assets are licensed GPL-3.0-or-later with the app and
require no third-party music royalties. They are licensed original works, not
public-domain recordings. The synthesis source is included as the editable
source for the recordings.

Run `python3 tool/generate_theme_music.py --moods-only` to regenerate only these
seven moods while preserving the original theme recordings.

## Cinematic effects

The original `creditCoin.wav`, `attack.wav`, `lightImpact.wav`,
`heavyImpact.wav`, `finalStrike.wav`, and `victoryApplause.wav` effects are
synthesized from oscillators and deterministic noise. They contain no
third-party recordings or samples. The short two-strike coin chime plays for
each confirmed credit increase or decrease. Regenerate the effects with
`python3 tool/generate_cinematic_sounds.py`.
The 5.2-second victory cue combines a four-phrase synthesized brass fanfare,
ceremonial drum hits, final shimmer, and a denser arena ovation.

The short `checkMale.wav`, `checkFemale.wav`, and `youWon.wav` cues are
offline speech generated with the macOS system voices named in
`tool/generate_voice_cues.sh`; no voice recording or network service is used.
