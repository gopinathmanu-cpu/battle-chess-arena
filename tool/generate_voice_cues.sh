#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Generates the short offline UI voice cues with macOS system speech.
set -euo pipefail

voice_tmp="$(mktemp -d)"
trap 'rm -rf "$voice_tmp"' EXIT
voice_out="$(cd "$(dirname "$0")/.." && pwd)/assets/audio"

make_cue() {
  cue_name="$1"
  cue_voice="$2"
  cue_rate="$3"
  cue_text="$4"
  /usr/bin/say -v "$cue_voice" -r "$cue_rate" \
    -o "$voice_tmp/$cue_name.aiff" "$cue_text"
  /usr/bin/afconvert -f WAVE -d LEI16@22050 \
    "$voice_tmp/$cue_name.aiff" "$voice_out/$cue_name.wav"
}

make_cue checkMale Aman 175 'Check.'
make_cue checkFemale Samantha 180 'Check.'
make_cue youWon Aman 168 'You won!'
