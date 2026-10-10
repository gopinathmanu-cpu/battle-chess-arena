#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Copy original generated illustrations intact; never modify raster artwork."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
FILES = [
  {
    "key": "manga-cast",
    "source": "/Users/manugopinath/.codex/generated_images/01a0fc4e-55f3-7b71-b0b0-4b34a2fa5765/exec-39a1edc5-bf32-4acb-9b98-6c85d4997117.png",
    "dest": "assets/cinematics/manga/cast.png"
  },
  {
    "key": "epic-cast",
    "source": "/Users/manugopinath/.codex/generated_images/01a0fc4e-55f3-7b71-b0b0-4b34a2fa5765/exec-2f9eb861-da77-42ea-8a98-a7d96a2c1877.png",
    "dest": "assets/cinematics/epic/cast.png"
  },
  {
    "key": "olympian-cast",
    "source": "/Users/manugopinath/.codex/generated_images/01a0fc4e-55f3-7b71-b0b0-4b34a2fa5765/exec-c806ec0e-ba1f-4cbe-92c0-7bfc8054c352.png",
    "dest": "assets/cinematics/olympian/cast.png"
  },
  {
    "key": "manga-world",
    "source": "/Users/manugopinath/.codex/generated_images/01a0fc4e-55f3-7b71-b0b0-4b34a2fa5765/exec-89057f4c-f690-450e-b336-8ba6549a3dfe.png",
    "dest": "assets/cinematics/manga/world.png"
  },
  {
    "key": "epic-world",
    "source": "/Users/manugopinath/.codex/generated_images/01a0fc4e-55f3-7b71-b0b0-4b34a2fa5765/exec-5d78070a-a0ca-49f2-8f41-90272d95ec14.png",
    "dest": "assets/cinematics/epic/world.png"
  },
  {
    "key": "olympian-world",
    "source": "/Users/manugopinath/.codex/generated_images/01a0fc4e-55f3-7b71-b0b0-4b34a2fa5765/exec-2e18ad87-5db8-443b-a8fe-60a1ad24ac2d.png",
    "dest": "assets/cinematics/olympian/world.png"
  }
]

if __name__ == '__main__':
    for item in FILES:
        destination = ROOT / item['dest']
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            raise FileExistsError(destination)
        shutil.copyfile(item['source'], destination)
        print(f"{item['dest']}: {destination.stat().st_size:,} bytes")
