#!/bin/zsh
set -euo pipefail

cd '/Users/manugopinath/GameStudio/battle_chess_arena 3'
exec /Users/manugopinath/development/flutter/bin/flutter run \
  -d web-server \
  --wasm \
  --web-hostname 127.0.0.1 \
  --web-port 7357
