#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Synthesize original Battle Chess Arena cinematic effects. Requires numpy."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
RNG = np.random.default_rng(20260906)


def save(name, samples):
    peak = max(1e-6, np.max(np.abs(samples)))
    samples = np.clip(samples * (.88 / peak), -1, 1)
    stereo = np.column_stack((samples, samples))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes((stereo * 32767).astype('<i2').tobytes())


def attack():
    duration = .34
    t = np.arange(round(duration * RATE)) / RATE
    phase = 2 * np.pi * (1200 * t - 1000 * t * t)
    noise = RNG.normal(0, 1, len(t))
    smooth = np.convolve(noise, np.ones(18) / 18, mode='same')
    envelope = np.sin(np.pi * t / duration) ** 1.4
    return (np.sin(phase) * .48 + smooth * .75) * envelope


def impact(duration, base, weight):
    t = np.arange(round(duration * RATE)) / RATE
    body = (
        np.sin(2 * np.pi * base * t) * np.exp(-t * (8 - weight * 2))
        + .48 * np.sin(2 * np.pi * base * 1.93 * t) * np.exp(-t * 12)
    )
    crack = RNG.normal(0, 1, len(t)) * np.exp(-t * 48)
    return body * (.65 + weight * .2) + crack * .72


def final_strike():
    duration = .92
    t = np.arange(round(duration * RATE)) / RATE
    boom = impact(duration, 54, 1.0)
    shimmer = np.sin(2 * np.pi * (420 + 760 * t) * t) * np.exp(-t * 3.6)
    return boom + shimmer * .32


def victory_applause():
    duration = 3.4
    samples = np.zeros(round(duration * RATE))
    # Many short, filtered-noise handclaps create a compact arena ovation.
    for clap_time in np.sort(RNG.uniform(.05, 3.15, 82)):
        length = round(RATE * RNG.uniform(.045, .105))
        start = round(clap_time * RATE)
        end = min(len(samples), start + length)
        t = np.arange(end - start) / RATE
        noise = RNG.normal(0, 1, len(t))
        body = noise - np.convolve(noise, np.ones(22) / 22, mode='same')
        envelope = np.exp(-t * RNG.uniform(28, 42))
        samples[start:end] += body * envelope * RNG.uniform(.22, .48)
    t = np.arange(len(samples)) / RATE
    crowd = RNG.normal(0, 1, len(samples))
    crowd = np.convolve(crowd, np.ones(150) / 150, mode='same')
    swell = np.sin(np.pi * np.minimum(t / .7, 1)) * np.exp(-np.maximum(0, t - 2.4) * 1.7)
    fanfare = (
        np.sin(2 * np.pi * 392 * t) +
        .7 * np.sin(2 * np.pi * 523.25 * t) +
        .45 * np.sin(2 * np.pi * 659.25 * t)
    ) * np.exp(-t * .75) * .055
    return samples + crowd * swell * 1.8 + fanfare


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    save('attack', attack())
    save('lightImpact', impact(.42, 118, .25))
    save('heavyImpact', impact(.62, 62, .9))
    save('finalStrike', final_strike())
    save('victoryApplause', victory_applause())
