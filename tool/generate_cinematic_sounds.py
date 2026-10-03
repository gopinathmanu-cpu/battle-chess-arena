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


def credit_coin():
    """A short original two-strike gold-coin chime for wallet changes."""
    duration = .52
    t = np.arange(round(duration * RATE)) / RATE
    samples = np.zeros_like(t)
    for start, fundamental, amplitude in ((0.0, 1480, .72), (.115, 1975, .48)):
        local = t - start
        active = local >= 0
        ring = (
            np.sin(2 * np.pi * fundamental * local)
            + .52 * np.sin(2 * np.pi * fundamental * 1.51 * local)
            + .24 * np.sin(2 * np.pi * fundamental * 2.18 * local)
        )
        envelope = np.exp(-local * 10.5) * active
        samples += ring * envelope * amplitude
    attack = np.exp(-t * 85) * np.sin(2 * np.pi * 3120 * t) * .2
    return samples + attack


def victory_applause():
    duration = 5.2
    samples = np.zeros(round(duration * RATE))
    # A denser arena ovation, with clustered claps instead of flat white noise.
    for clap_time in np.sort(RNG.uniform(.05, 4.85, 138)):
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
    swell = np.sin(np.pi * np.minimum(t / .8, 1)) * np.exp(-np.maximum(0, t - 4.0) * 1.9)

    # Original four-phrase brass fanfare: G, C-major lift, E-major sparkle,
    # then a held C-major finish. Layered harmonics keep it warm on phones.
    fanfare = np.zeros_like(samples)
    phrases = [
        (.08, .48, (392.00, 493.88, 587.33)),
        (.62, .55, (523.25, 659.25, 783.99)),
        (1.27, .62, (659.25, 830.61, 987.77)),
        (2.02, 2.35, (523.25, 659.25, 783.99, 1046.50)),
    ]
    for start, note_length, chord in phrases:
        begin = round(start * RATE)
        end = min(len(samples), begin + round(note_length * RATE))
        note_t = np.arange(end - begin) / RATE
        attack_env = np.minimum(note_t / .035, 1)
        release_env = np.minimum((note_length - note_t) / .24, 1)
        envelope = np.maximum(0, attack_env * release_env)
        brass = np.zeros_like(note_t)
        for frequency in chord:
            brass += (
                np.sin(2 * np.pi * frequency * note_t)
                + .32 * np.sin(2 * np.pi * frequency * 2 * note_t)
                + .12 * np.sin(2 * np.pi * frequency * 3 * note_t)
            ) / len(chord)
        fanfare[begin:end] += brass * envelope * .21

    # Low ceremonial drum hits and a bright final shimmer add a clear finish.
    drums = np.zeros_like(samples)
    for hit in (.02, .60, 1.25, 2.00):
        begin = round(hit * RATE)
        hit_t = np.arange(min(round(.55 * RATE), len(samples) - begin)) / RATE
        drums[begin:begin + len(hit_t)] += (
            np.sin(2 * np.pi * (72 - 24 * hit_t) * hit_t)
            * np.exp(-hit_t * 8) * .32
        )
    shimmer_noise = RNG.normal(0, 1, len(samples))
    shimmer = (
        shimmer_noise - np.convolve(shimmer_noise, np.ones(30) / 30, mode='same')
    ) * np.exp(-np.maximum(0, t - 2.0) * 1.25) * (t >= 2.0) * .035
    return samples + crowd * swell * 1.65 + fanfare + drums + shimmer


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    save('creditCoin', credit_coin())
    save('attack', attack())
    save('lightImpact', impact(.42, 118, .25))
    save('heavyImpact', impact(.62, 62, .9))
    save('finalStrike', final_strike())
    save('victoryApplause', victory_applause())
