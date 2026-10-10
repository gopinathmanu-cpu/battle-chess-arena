#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Render the original Neon Dominion film score using Python's standard library.

The 40-second loop is composed for this project from mathematical oscillators,
deterministic noise, envelopes and circular echoes. No recordings, samples,
existing songs, MIDI or external audio services are used. The generated WAV is
licensed GPL-3.0-or-later with this editable synthesis source.

Run: python3 tool/generate_neon_film_score.py
"""

from array import array
from math import exp, pi, sin, sqrt, tanh
from pathlib import Path
from random import Random
import sys
import wave


RATE = 22050
SECONDS = 40
COUNT = RATE * SECONDS
TAU = 2 * pi
OUT = Path(__file__).resolve().parents[1] / "assets/audio/neon_film_score.wav"


def frequency(midi):
    # Whole cycles across the loop keep sustained oscillators phase-continuous.
    return round(440 * 2 ** ((midi - 69) / 12) * SECONDS) / SECONDS


def compose():
    mix = array("d", [0]) * COUNT
    rng = Random(731903)

    def add_event(start, length, voice, gain, echo=True):
        samples = round(length * RATE)
        offset = round(start * RATE)
        delays = ((0, 1), (round(.31 * RATE), .19), (round(.62 * RATE), .09)) if echo else ((0, 1),)
        for i in range(samples):
            t = i / RATE
            value = voice(t, i / samples) * gain
            for delay, attenuation in delays:
                mix[(offset + i + delay) % COUNT] += value * attenuation

    # Four suspended/minor harmonies overlap across the circular boundary.
    # A soft low drone holds the city together; higher voices rise and recede.
    chords = ((50, 57, 62, 65), (46, 53, 57, 62), (53, 60, 67, 69), (48, 55, 62, 64))
    for chord_index, chord in enumerate(chords):
        for voice_index, note in enumerate(chord):
            hz = frequency(note)
            phase_offset = voice_index * .47

            def pad(t, fraction, hz=hz, phase_offset=phase_offset):
                envelope = sin(pi * fraction) ** 2
                slow_breath = .84 + .16 * sin(TAU * t / 12 + phase_offset)
                phase = TAU * hz * t + phase_offset
                return (sin(phase + .16 * sin(TAU * t / 6)) + .15 * sin(phase * 2)) * envelope * slow_breath

            add_event(chord_index * 10 - 2, 14, pad, .058 if voice_index == 0 else .035)

    # Quiet, deliberately sparse eight-note motifs return with changed voicing.
    # The score supports the narrator rather than competing with spoken words.
    motif = (0, 7, 3, 10, 7, 12, 5, 3)
    for index in range(32):
        root = chords[(index // 8) % len(chords)][0]
        note = root + 12 + motif[(index * 3 + index // 8) % len(motif)]
        hz = frequency(note)

        def pluck(t, fraction, hz=hz):
            attack = 1 - exp(-t * 55)
            decay = exp(-t * 2.15)
            tail = min(1, (1 - fraction) * 12)
            phase = TAU * hz * t
            return sin(phase + .65 * sin(phase * 2) * exp(-t * 3)) * attack * decay * tail

        strength = .021 + .016 * sin(pi * index / 32) ** 2
        add_event(index * 1.25 + .625, 2.5, pluck, strength)

    # Restrained 96 BPM heartbeat with no sharp snare or speech-band cymbals.
    for beat in range(64):
        strength = .038 + .018 * sin(pi * beat / 64) ** 2

        def pulse(t, fraction):
            phase = TAU * (48 * t + 9 * (1 - exp(-t * 16)) / 16)
            return sin(phase) * (1 - exp(-t * 110)) * exp(-t * 11) * min(1, (1 - fraction) * 15)

        if beat % 2 == 0 or 24 <= beat < 48:
            add_event(beat * .625, .65, pulse, strength, echo=False)

    # A filtered, cinematic air swell blooms midway then releases into the loop.
    filtered = 0.0
    for i in range(COUNT):
        t = i / RATE
        filtered = filtered * .97 + rng.uniform(-1, 1) * .03
        swell = sin(pi * t / SECONDS) ** 6
        shimmer = sin(TAU * frequency(81) * t) + .35 * sin(TAU * frequency(88) * t)
        mix[i] += filtered * .038 * swell + shimmer * .006 * swell
        mix[i] = tanh(mix[i] * 1.25)

    peak = max(abs(value) for value in mix)
    normalization = .68 / peak
    # Select a quiet zero crossing for the actual file seam. Since all notes
    # and echoes wrap around COUNT, this rotation does not cut the composition.
    seam = min(range(COUNT), key=lambda i: abs(mix[i]) + abs(mix[i - 1]) + 8 * abs(mix[i] - mix[i - 1]))
    pcm = array("h", (round(mix[(i + seam) % COUNT] * normalization * 32767) for i in range(COUNT)))
    rms = sqrt(sum(sample * sample for sample in pcm) / COUNT) / 32767
    seam_step = abs(pcm[0] - pcm[-1]) / 32767
    return pcm, rms, seam_step


def main():
    pcm, rms, seam_step = compose()
    if sys.byteorder != "little":
        pcm.byteswap()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"{OUT.name}: {SECONDS}s, mono {RATE} Hz / 16 bit, {OUT.stat().st_size:,} bytes, RMS {rms:.3f}, seam step {seam_step:.6f}")
    assert seam_step < .001, "Loop boundary must not introduce a click"


if __name__ == "__main__":
    main()
