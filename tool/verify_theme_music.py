#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate every generated chess-set loop's format, size and basic audio health."""
from hashlib import sha256
from pathlib import Path
import sys
import wave
import numpy as np

from generate_theme_music import THEMES, THEME_RATE

ROOT = Path(__file__).resolve().parents[1]
failures = []
hashes = set()
total = 0

for spec in THEMES:
    name = spec[0]
    path = ROOT / 'assets' / 'audio' / f'{name}.wav'
    if not path.exists():
        failures.append(f'{name}: missing')
        continue
    size = path.stat().st_size
    total += size
    digest = sha256(path.read_bytes()).hexdigest()
    if digest in hashes:
        failures.append(f'{name}: duplicate rendered audio')
    hashes.add(digest)
    with wave.open(str(path), 'rb') as audio:
        params = (audio.getnchannels(), audio.getsampwidth(), audio.getframerate())
        frames = audio.getnframes()
        samples = np.frombuffer(audio.readframes(frames), dtype='<i2').astype(float) / 32768
    seconds = frames / THEME_RATE
    peak = float(np.max(np.abs(samples)))
    rms = float(np.sqrt(np.mean(samples * samples)))
    seam = float(abs(samples[0] - samples[-1]))
    if params != (1, 2, THEME_RATE):
        failures.append(f'{name}: expected mono 16-bit {THEME_RATE} Hz, got {params}')
    if not 8 <= seconds <= 16:
        failures.append(f'{name}: duration {seconds:.2f}s outside 8-16s')
    if not 180_000 <= size <= 500_000:
        failures.append(f'{name}: size {size} outside compact budget')
    if not .70 <= peak <= .78 or not .05 <= rms <= .30:
        failures.append(f'{name}: unhealthy peak/rms {peak:.3f}/{rms:.3f}')
    if seam > .015:
        failures.append(f'{name}: loop seam delta {seam:.4f} may click')

if len(THEMES) != 31 or len(hashes) != len(THEMES):
    failures.append(f'expected 31 unique themes, got {len(THEMES)} specs/{len(hashes)} files')
if total > 12 * 1024 * 1024:
    failures.append(f'total theme audio {total} exceeds 12 MiB budget')

if failures:
    print('\n'.join(f'ERROR: {failure}' for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print(f'Verified {len(THEMES)} unique original loops: {total / 1024 / 1024:.2f} MiB total.')
