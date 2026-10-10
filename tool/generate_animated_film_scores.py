#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compose three original, seamless Animated army film scores.

All notes, motifs and percussion below are original mathematical synthesis.
There are no recordings, sampled instruments, existing melodies, MIDI files or
external audio services. The generated WAV files share this source's license.

Run: python3 tool/generate_animated_film_scores.py
"""

from array import array
from hashlib import sha256
from math import exp, pi, sin, sqrt, tanh
from pathlib import Path
from random import Random
import sys
import wave


RATE = 22050
SECONDS = 40
COUNT = RATE * SECONDS
TAU = 2 * pi
OUT = Path(__file__).resolve().parents[1] / "assets/audio"

# Chords overlap in a circular timeline; motifs and harmonic spectra distinguish
# the comet strings, radiant citadel and bronze storm without familiar tunes.
PROFILES = {
    "manga": {
        "seed": 19047,
        "chords": ((50, 57, 62, 66), (47, 54, 59, 62), (55, 62, 67, 69), (45, 52, 57, 62)),
        "motif": (0, 9, 2, 7, 14, 4, 11, 7),
        "beats": 80,
        "pulse": 61,
        "partials": (1, .31, .12, .035),
        "melody_gain": .036,
    },
    "epic": {
        "seed": 48231,
        "chords": ((45, 52, 57, 62), (48, 55, 60, 64), (43, 50, 55, 62), (50, 57, 62, 65)),
        "motif": (0, 5, 12, 7, 2, 10, 7, 14),
        "beats": 48,
        "pulse": 49,
        "partials": (1, .22, .19, .085),
        "melody_gain": .027,
    },
    "olympian": {
        "seed": 87403,
        "chords": ((38, 45, 50, 57), (41, 48, 53, 57), (43, 50, 55, 59), (45, 52, 57, 62)),
        "motif": (0, 12, 7, 3, 10, 5, 14, 7),
        "beats": 40,
        "pulse": 42,
        "partials": (1, .39, .14, .12),
        "melody_gain": .023,
    },
}


def frequency(midi):
    return round(440 * 2 ** ((midi - 69) / 12) * SECONDS) / SECONDS


def compose(theme):
    profile = PROFILES[theme]
    mix = array("d", [0]) * COUNT
    rng = Random(profile["seed"])

    def event(start, length, voice, gain, echo=True):
        samples = round(length * RATE)
        offset = round(start * RATE)
        echoes = ((0, 1), (round(.37 * RATE), .18), (round(.74 * RATE), .065)) if echo else ((0, 1),)
        for i in range(samples):
            value = voice(i / RATE, i / samples) * gain
            for delay, amount in echoes:
                mix[(offset + i + delay) % COUNT] += value * amount

    for section, chord in enumerate(profile["chords"]):
        for layer, note in enumerate(chord):
            hz = frequency(note)
            partials = profile["partials"]

            def pad(t, fraction, hz=hz, layer=layer, partials=partials):
                envelope = sin(pi * fraction) ** 2
                breath = .87 + .13 * sin(TAU * t / 8 + layer * .7)
                phase = TAU * hz * t + layer * .31
                harmonics = sum(gain * sin(phase * (index + 1)) for index, gain in enumerate(partials))
                return harmonics * envelope * breath

            event(section * 10 - 3, 16, pad, .045 if layer == 0 else .024)

    # Two-note gaps leave the spoken story clear. A distinct original motif
    # changes octave/voicing between the four harmonic sections.
    for index in range(32):
        chord = profile["chords"][index // 8]
        hz = frequency(chord[0] + 24 + profile["motif"][(index * 3 + index // 8) % 8])

        def bell(t, fraction, hz=hz):
            attack = 1 - exp(-t * 80)
            phase = TAU * hz * t
            if theme == "manga":
                voice = sin(phase + .32 * sin(phase * 2) * exp(-t * 3)) + .13 * sin(phase * 3)
            elif theme == "epic":
                voice = sin(phase) + .25 * sin(phase * 2) * exp(-t * 1.3)
            else:
                voice = sin(phase) + .22 * sin(phase * 2.76) * exp(-t * 2)
            return voice * attack * exp(-t * 1.8) * min(1, (1 - fraction) * 12)

        event(index * 1.25 + .4, 3, bell, profile["melody_gain"] * (.72 + .28 * sin(pi * index / 32) ** 2))

    for beat in range(profile["beats"]):
        if beat % 2 and not 12 <= beat * SECONDS / profile["beats"] < 29:
            continue
        pitch = profile["pulse"]

        def drum(t, fraction, pitch=pitch):
            phase = TAU * (pitch * t + 12 * (1 - exp(-t * 17)) / 17)
            return sin(phase) * (1 - exp(-t * 120)) * exp(-t * 12) * min(1, (1 - fraction) * 14)

        event(beat * SECONDS / profile["beats"], .65, drum, .04, echo=False)

    # Deterministic filtered air supplies a restrained midpoint swell. The
    # Olympian score adds low procedural storm texture, not recorded thunder.
    filtered = low = 0.0
    shimmer_hz = frequency(86 if theme == "manga" else 81 if theme == "epic" else 74)
    for index in range(COUNT):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        filtered = filtered * .965 + noise * .035
        low = low * .998 + noise * .002
        swell = sin(pi * t / SECONDS) ** 6
        mix[index] += filtered * .036 * swell + sin(TAU * shimmer_hz * t) * .005 * swell
        if theme == "olympian":
            storm = sin(pi * ((t + 3) % 10) / 10) ** 10
            mix[index] += low * .19 * storm
        mix[index] = tanh(mix[index] * 1.2)

    peak = max(abs(value) for value in mix)
    scale = .68 / peak
    seam = min(range(COUNT), key=lambda i: abs(mix[i]) + abs(mix[i - 1]) + 8 * abs(mix[i] - mix[i - 1]))
    pcm = array("h", (round(mix[(index + seam) % COUNT] * scale * 32767) for index in range(COUNT)))
    rms = sqrt(sum(sample * sample for sample in pcm) / COUNT) / 32767
    seam_step = abs(pcm[0] - pcm[-1]) / 32767
    assert .04 < rms < .4, "Score must retain a useful restrained level"
    assert seam_step < .001, "Loop boundary must not introduce a click"
    assert max(abs(sample) for sample in pcm) < 32767, "Score must not clip"
    return pcm, rms, seam_step


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for theme in PROFILES:
        pcm, rms, seam_step = compose(theme)
        if sys.byteorder != "little":
            pcm.byteswap()
        output_path = OUT / f"{theme}_film_score.wav"
        with wave.open(str(output_path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())
        digest = sha256(output_path.read_bytes()).hexdigest()
        print(f"{output_path.name}: {SECONDS}s mono {RATE}Hz 16-bit; {output_path.stat().st_size:,} bytes; RMS {rms:.3f}; seam {seam_step:.6f}; SHA256 {digest}")


if __name__ == "__main__":
    main()
