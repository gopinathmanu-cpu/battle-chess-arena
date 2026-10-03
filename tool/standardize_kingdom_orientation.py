#!/usr/bin/env python3
"""Create v2 Historical/Legendary atlases with canonical source orientation.

The renderer mirrors the black army at runtime. Consequently both source rows
must use the same source direction: near-front/viewer-left for directional
mounts and vehicles. This utility mirrors only reviewed 256px cells and never
redraws, recolours, rescales, or recompresses individual sprites.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageOps


CELL = 256
ROLES = ("king", "queen", "bishop", "knight", "rook", "pawn")

# Elephants that currently face viewer-right. Other elephant bishops already
# follow the canonical viewer-left source direction.
BISHOP_FLIPS = {
    "atlantis", "ayodhya", "camelot", "chola", "hastinapura", "inca",
    "kishkindha", "macedonian", "maratha", "ottoman", "troy",
}

# Most source horse knights face viewer-right. These five already face left.
KNIGHT_LEFT = {"asgard", "chinese", "japanese", "sparta", "zulu"}

# Directional chariot drivers/fronts that currently face viewer-right.
ROOK_FLIPS = {
    "achaemenid", "atlantis", "ayodhya", "camelot", "chola",
    "hastinapura", "inca", "lanka", "maratha", "mewar", "sparta",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    sources = sorted(args.directory.glob("*-v1.png"))
    if len(sources) != 27:
        raise SystemExit(f"Expected 27 v1 kingdom atlases, found {len(sources)}")

    entries = []
    for source in sources:
        kingdom = source.stem.removesuffix("-v1")
        output = source.with_name(f"{kingdom}-v2.png")
        if output.exists() and not args.overwrite:
            raise SystemExit(f"Refusing to overwrite {output}; pass --overwrite")

        image = Image.open(source).convert("RGBA")
        if image.size != (1536, 512):
            raise SystemExit(f"Expected 1536x512 atlas: {source}")

        flipped_roles = []
        if kingdom in BISHOP_FLIPS:
            flipped_roles.append("bishop")
        if kingdom not in KNIGHT_LEFT:
            flipped_roles.append("knight")
        if kingdom in ROOK_FLIPS:
            flipped_roles.append("rook")

        result = image.copy()
        for role in flipped_roles:
            column = ROLES.index(role)
            for row in range(2):
                box = (
                    column * CELL,
                    row * CELL,
                    (column + 1) * CELL,
                    (row + 1) * CELL,
                )
                result.paste(ImageOps.mirror(image.crop(box)), box)
        result.save(output, optimize=True)
        entries.append({
            "id": kingdom,
            "source": str(source),
            "sourceSha256": digest(source),
            "runtime": str(output),
            "runtimeSha256": digest(output),
            "flippedRolesBothRows": flipped_roles,
            "canonicalSourceDirection": "near-front/viewer-left",
        })

    manifest = args.directory / "orientation-standard-v2.json"
    manifest.write_text(json.dumps({
        "version": 2,
        "cellSize": CELL,
        "roles": ROLES,
        "policy": {
            "source": "Directional units face viewer-left in both source rows.",
            "runtime": "Black is mirrored by ThemedPieceSprite so armies face each other.",
            "uprightRoles": "King, Queen and Pawn remain near-front and unchanged.",
        },
        "entries": entries,
    }, indent=2) + "\n")
    print(f"Wrote {len(entries)} standardized atlases and {manifest}")


if __name__ == "__main__":
    main()
