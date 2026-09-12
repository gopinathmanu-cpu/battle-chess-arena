#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Synthesize original, seamless ambient motifs. Requires numpy; no samples."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
# Name, tempo, tonic, scale, timbre: original motifs, not existing songs.
WORLDS = [
    ('anime', 92, 60, [0, 2, 4, 7, 9], 'bell'),
    ('indianEpic', 72, 50, [0, 1, 4, 7, 8], 'plucked'),
    ('greek', 76, 57, [0, 2, 3, 7, 10], 'lyre'),
    ('futuristic', 88, 48, [0, 3, 5, 7, 10], 'synth'),
    ('classic', 68, 60, [0, 2, 4, 7, 9], 'harp'),
]

def create(name, bpm, tonic, scale, voice):
    beat = 60 / bpm
    count = round(32 * beat * RATE)
    mix = np.zeros((count, 2), dtype=np.float64)
    def note(start, midi, duration, amp, kind, pan=0):
        t = np.arange(round(duration * RATE)) / RATE
        f = 440 * 2 ** ((midi - 69) / 12)
        phase = 2 * np.pi * f * t
        if kind == 'pad':
            sound = np.sin(phase) + .22 * np.sin(phase * 2)
            env = np.sin(np.pi * t / duration) ** 2
        elif kind == 'bell':
            sound = np.sin(phase) + .3 * np.sin(phase * 2.005) * np.exp(-t * 3)
            env = (1-np.exp(-t*55))*np.exp(-t*1.8)
        elif kind == 'synth':
            sound = np.sin(phase + 1.1 * np.sin(phase * 2) * np.exp(-t*3))
            env = (1-np.exp(-t*28))*np.exp(-t*2.4)
        else:
            brightness = 6 if kind == 'plucked' else 3
            sound = sum(np.sin(phase*h)/h * np.exp(-t*h*.9)
                        for h in range(1, brightness+1))
            env = (1-np.exp(-t*120))*np.exp(-t*1.2)
        sound *= env * amp
        # End each event at zero; wrap reverberation tails across the loop seam.
        sound[-min(220,len(sound)):] *= np.linspace(1,0,min(220,len(sound)))
        for delay, gain in [(0,1),(.19,.17),(.37,.09)]:
            idx = (round((start+delay)*RATE)+np.arange(len(t))) % count
            np.add.at(mix[:,0],idx,sound*gain*np.sqrt((1-pan)/2))
            np.add.at(mix[:,1],idx,sound*gain*np.sqrt((1+pan)/2))
    motif = [0,2,3,1,4,3,2,1,0,1,3,2,4,2,1,0]
    for bar in range(8):
        root = tonic + [0,0,5,5,7,7,0,0][bar]
        for interval in [0,7]:
            note(bar*4*beat,root-12+interval,6*beat,.065,'pad',-.25)
        for pulse in range(4):
            degree = motif[(bar*2+pulse)%len(motif)]
            octave = 12 if voice in ['bell','harp'] else 0
            note((bar*4+pulse)*beat,tonic+scale[degree]+octave,
                 2.8*beat,.11 if pulse%2==0 else .075,voice,.3*(-1)**pulse)
        if voice in ['plucked','synth']:
            note(bar*4*beat,tonic-24,.55*beat,.1,'synth')
    mix *= .70/max(1e-6,np.max(np.abs(mix)))
    OUT.mkdir(parents=True,exist_ok=True)
    with wave.open(str(OUT/f'{name}.wav'),'wb') as file:
        file.setnchannels(2); file.setsampwidth(2); file.setframerate(RATE)
        file.writeframes((mix*32767).astype('<i2').tobytes())
    print(name, round(count/RATE,2), 'seconds')

if __name__ == '__main__':
    for world in WORLDS: create(*world)
