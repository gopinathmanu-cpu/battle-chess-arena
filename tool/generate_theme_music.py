#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Synthesize original looping music from oscillators; no samples or MIDI."""
from pathlib import Path
import argparse
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
MOOD_RATE = 22050
THEME_RATE = 16000

# name, BPM, tonic, modal pitches, synthetic voice, spacing, root movement,
# percussion. Palettes only evoke broad settings; they are not transcriptions
# or claims of culturally authentic performances.
THEMES = [
    ('anime', 96, 60, [0, 2, 4, 7, 9], 'bell', .5, [0, 7, 5, 9], 'pulse'),
    ('indianEpic', 72, 50, [0, 1, 4, 7, 8], 'plucked', 1, [0, 5, 0, 7], 'hand'),
    ('greek', 78, 57, [0, 2, 3, 7, 10], 'lyre', 1, [0, 5, 3, 7], 'frame'),
    ('futuristic', 112, 45, [0, 3, 5, 7, 10], 'synth', .5, [0, 3, 10, 5], 'pulse'),
    ('japanese', 68, 57, [0, 2, 5, 7, 9], 'plucked', 1, [0, 5, 7, 0], 'wood'),
    ('chinese', 74, 55, [0, 2, 4, 7, 9], 'reed', 1, [0, 7, 2, 9], 'wood'),
    ('mongolian', 64, 45, [0, 2, 5, 7, 10], 'flute', 2, [0, 7, 5, 0], 'frame'),
    ('egyptian', 82, 50, [0, 1, 4, 5, 7, 8, 11], 'reed', 1, [0, 1, 5, 7], 'frame'),
    ('arab', 86, 52, [0, 1, 4, 5, 7, 8, 10], 'plucked', .5, [0, 5, 1, 7], 'hand'),
    ('persian', 76, 52, [0, 2, 3, 6, 7, 9, 10], 'lyre', 1, [0, 3, 7, 6], 'hand'),
    ('english', 70, 53, [0, 2, 4, 5, 7, 9, 11], 'horn', 1, [0, 5, 7, 0], 'frame'),
    ('french', 84, 55, [0, 2, 4, 5, 7, 9, 11], 'lyre', .5, [0, 9, 5, 7], 'frame'),
    ('sparta', 98, 45, [0, 2, 3, 7, 10], 'horn', 1, [0, 3, 5, 7], 'war'),
    ('macedonian', 92, 47, [0, 2, 3, 7, 9], 'lyre', 1, [0, 7, 3, 5], 'war'),
    ('roman', 100, 48, [0, 2, 3, 5, 7, 10], 'horn', 1, [0, 5, 3, 7], 'war'),
    ('achaemenid', 74, 50, [0, 1, 3, 5, 7, 8, 10], 'reed', 1, [0, 3, 1, 7], 'frame'),
    ('ottoman', 88, 50, [0, 1, 3, 6, 7, 9, 10], 'plucked', .5, [0, 6, 3, 7], 'hand'),
    ('chola', 78, 48, [0, 1, 4, 5, 7, 8, 10], 'plucked', 1, [0, 5, 8, 7], 'hand'),
    ('maratha', 94, 50, [0, 2, 3, 7, 9, 10], 'reed', 1, [0, 3, 7, 5], 'war'),
    ('zulu', 104, 43, [0, 3, 5, 7, 10], 'flute', 1, [0, 5, 3, 7], 'hand'),
    ('aztec', 102, 48, [0, 2, 5, 7, 10], 'flute', .5, [0, 5, 10, 7], 'wood'),
    ('inca', 80, 55, [0, 2, 5, 7, 9], 'flute', 1, [0, 7, 5, 9], 'frame'),
    ('mewar', 82, 50, [0, 2, 3, 6, 7, 9, 10], 'plucked', 1, [0, 3, 7, 6], 'hand'),
    ('lanka', 90, 48, [0, 1, 4, 5, 7, 8, 11], 'bell', .5, [0, 8, 5, 7], 'war'),
    ('ayodhya', 74, 52, [0, 2, 4, 7, 9], 'plucked', 1, [0, 5, 9, 7], 'hand'),
    ('hastinapura', 88, 47, [0, 2, 3, 7, 9, 10], 'horn', 1, [0, 3, 5, 7], 'war'),
    ('kishkindha', 96, 53, [0, 2, 5, 7, 9], 'flute', .5, [0, 5, 2, 7], 'wood'),
    ('asgard', 86, 43, [0, 2, 3, 7, 10], 'horn', 1, [0, 7, 3, 5], 'war'),
    ('camelot', 76, 48, [0, 2, 4, 5, 7, 9, 11], 'lyre', 1, [0, 5, 9, 7], 'frame'),
    ('atlantis', 66, 55, [0, 2, 4, 7, 9], 'bell', 2, [0, 9, 5, 7], 'pulse'),
    ('troy', 90, 45, [0, 2, 3, 5, 7, 10], 'lyre', 1, [0, 3, 7, 5], 'war'),
]

MOODS = [
    ('mood_rapid', 126, 48, [0, 2, 3, 7, 10], 'synth', .5, .04, [0, 5, 3, 7]),
    ('mood_zen', 56, 57, [0, 2, 5, 7, 9], 'bell', 2, .08, [0, 0, 5, 0]),
    ('mood_relaxing', 68, 53, [0, 2, 4, 7, 9], 'lyre', 1, .07, [0, 5, 0, 7]),
    ('mood_inspiring', 96, 60, [0, 2, 4, 7, 9], 'bell', 1, .09, [0, 7, 9, 5]),
    ('mood_calm', 60, 48, [0, 2, 4, 7, 9], 'pad', 2, .10, [0, 5, 0, 5]),
    ('mood_focus', 80, 45, [0, 3, 5, 7, 10], 'synth', 1, .06, [0, 0, 3, 0]),
    ('mood_epic', 104, 45, [0, 2, 3, 7, 10], 'plucked', .5, .10, [0, 3, 5, 7]),
]


def oscillator(phase, t, duration, kind):
    if kind == 'pad':
        sound = np.sin(phase) + .22 * np.sin(phase * 2)
        env = np.sin(np.pi * t / duration) ** 2
    elif kind == 'bell':
        sound = np.sin(phase) + .30 * np.sin(phase * 2.005) * np.exp(-t * 3)
        env = (1 - np.exp(-t * 55)) * np.exp(-t * 1.8)
    elif kind == 'synth':
        sound = np.sin(phase + 1.1 * np.sin(phase * 2) * np.exp(-t * 3))
        env = (1 - np.exp(-t * 28)) * np.exp(-t * 2.4)
    elif kind == 'flute':
        sound = np.sin(phase) + .16 * np.sin(phase * 2) + .05 * np.sin(phase * 3)
        env = (1 - np.exp(-t * 12)) * np.exp(-t * .55)
    elif kind == 'reed':
        sound = sum(np.sin(phase * h) / (h * h) for h in range(1, 6))
        env = (1 - np.exp(-t * 18)) * np.exp(-t * .75)
    elif kind == 'horn':
        sound = np.sin(phase) + .30 * np.sin(phase * 2) + .12 * np.sin(phase * 3)
        env = (1 - np.exp(-t * 9)) * np.exp(-t * .65)
    else:
        brightness = 6 if kind == 'plucked' else 3
        sound = sum(np.sin(phase * h) / h * np.exp(-t * h * .9)
                    for h in range(1, brightness + 1))
        env = (1 - np.exp(-t * 120)) * np.exp(-t * 1.2)
    return sound * env


def write_wav(name, mix, rate, channels):
    if channels == 1:
        # Rotate the circular composition to its quietest zero crossing so the
        # platform player's loop boundary cannot produce an audible click.
        previous = np.roll(mix, 1)
        seam_score = np.abs(mix) + np.abs(previous) + 8 * np.abs(mix - previous)
        mix = np.roll(mix, -int(np.argmin(seam_score)))
    mix *= .76 / max(1e-6, np.max(np.abs(mix)))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as file:
        file.setnchannels(channels)
        file.setsampwidth(2)
        file.setframerate(rate)
        file.writeframes((mix * 32767).astype('<i2').tobytes())
    size = (OUT / f'{name}.wav').stat().st_size
    print(f'{name:14} {len(mix) / rate:5.2f}s {size / 1024:6.1f} KiB')


def create_theme(index, spec):
    name, bpm, tonic, scale, voice, spacing, progression, percussion = spec
    beat = 60 / bpm
    count = round(16 * beat * THEME_RATE)
    mix = np.zeros(count, dtype=np.float64)
    rng = np.random.default_rng(4103 + index * 7919)

    def add_note(start, midi, duration, amp, kind):
        length = max(2, round(duration * THEME_RATE))
        t = np.arange(length) / THEME_RATE
        frequency = 440 * 2 ** ((midi - 69) / 12)
        sound = oscillator(2 * np.pi * frequency * t, t, duration, kind) * amp
        fade = min(120, len(sound))
        sound[-fade:] *= np.linspace(1, 0, fade)
        for delay, gain in ((0, 1), (.17, .13), (.31, .07)):
            positions = (round((start + delay) * THEME_RATE) + np.arange(length)) % count
            np.add.at(mix, positions, sound * gain)

    def add_hit(start, strength, kind):
        duration = .16 if kind in ('wood', 'pulse') else .28
        length = round(duration * THEME_RATE)
        t = np.arange(length) / THEME_RATE
        noise = rng.normal(0, 1, length)
        if kind == 'wood':
            sound = np.sin(2 * np.pi * (720 - 420 * t / duration) * t)
        elif kind == 'pulse':
            sound = np.sin(2 * np.pi * (95 - 38 * t / duration) * t)
        elif kind == 'war':
            sound = np.sin(2 * np.pi * (82 - 30 * t / duration) * t) + noise * .12
        elif kind == 'hand':
            sound = noise * .42 + np.sin(2 * np.pi * 180 * t)
        else:
            sound = noise * .32 + np.sin(2 * np.pi * 125 * t)
        sound *= np.exp(-t * (18 if kind == 'wood' else 11)) * strength
        positions = (round(start * THEME_RATE) + np.arange(length)) % count
        np.add.at(mix, positions, sound)

    # Each realm receives a unique seeded motif which is transformed on repeat.
    # No melody or performance data is imported from any existing composition.
    steps = round(4 / spacing)
    motif = rng.integers(0, len(scale), size=max(8, steps * 2))
    motif[-1] = 0
    for bar in range(4):
        root = tonic + progression[bar]
        add_note(bar * 4 * beat, root - 12, 4.7 * beat, .045, 'pad')
        add_note(bar * 4 * beat, root - 5, 3.8 * beat, .025, 'pad')
        for step in range(steps):
            degree = int(motif[(bar * steps + step) % len(motif)])
            if bar & 1:
                degree = (degree + 1) % len(scale)
            octave = 12 if voice in ('bell', 'flute') and step % 3 == 0 else 0
            add_note((bar * 4 + step * spacing) * beat,
                     tonic + scale[degree] + octave,
                     min(2.2, spacing * 1.7) * beat,
                     .085 if step % 2 == 0 else .060, voice)
        for pulse in range(4):
            accent = .10 if pulse == 0 else .055
            if percussion == 'war' and pulse in (0, 2):
                accent *= 1.35
            add_hit((bar * 4 + pulse) * beat, accent, percussion)
    write_wav(name, mix, THEME_RATE, 1)


def create_mood(name, bpm, tonic, scale, voice, spacing=.5,
                pad_level=.065, progression=None):
    beat = 60 / bpm
    count = round(32 * beat * MOOD_RATE)
    mix = np.zeros((count, 2), dtype=np.float64)

    def note(start, midi, duration, amp, kind, pan=0):
        t = np.arange(round(duration * MOOD_RATE)) / MOOD_RATE
        frequency = 440 * 2 ** ((midi - 69) / 12)
        sound = oscillator(2 * np.pi * frequency * t, t, duration, kind) * amp
        fade = min(220, len(sound))
        sound[-fade:] *= np.linspace(1, 0, fade)
        for delay, gain in ((0, 1), (.19, .17), (.37, .09)):
            positions = (round((start + delay) * MOOD_RATE) + np.arange(len(t))) % count
            np.add.at(mix[:, 0], positions, sound * gain * np.sqrt((1 - pan) / 2))
            np.add.at(mix[:, 1], positions, sound * gain * np.sqrt((1 + pan) / 2))

    motif = [0, 2, 3, 1, 4, 3, 2, 1, 0, 1, 3, 2, 4, 2, 1, 0]
    for bar in range(8):
        root = tonic + progression[bar % len(progression)]
        for interval in (0, 7):
            note(bar * 4 * beat, root - 12 + interval, 6 * beat,
                 pad_level, 'pad', -.25)
        for step in range(round(4 / spacing)):
            pulse = step * spacing
            degree = motif[(bar * 2 + step) % len(motif)]
            octave = 12 if voice in ('bell', 'harp') else 0
            note((bar * 4 + pulse) * beat, tonic + scale[degree] + octave,
                 2.8 * beat, .11 if step % 2 == 0 else .075,
                 voice, .3 * (-1) ** step)
        if voice in ('plucked', 'synth'):
            note(bar * 4 * beat, tonic - 24, .55 * beat, .1, 'synth')
    write_wav(name, mix, MOOD_RATE, 2)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--themes-only', action='store_true')
    group.add_argument('--moods-only', action='store_true')
    args = parser.parse_args()
    if not args.moods_only:
        for theme_index, theme in enumerate(THEMES):
            create_theme(theme_index, theme)
    if not args.themes_only:
        for mood in MOODS:
            create_mood(*mood)
