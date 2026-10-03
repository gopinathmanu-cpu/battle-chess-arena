#!/usr/bin/env python3
"""Build the 6x8 Fantasy character atlas from reviewed generated lineups.

Requires Pillow. Each input is a transparent 2172x724 image containing six
equal 362px role regions in king, queen, bishop, knight, rook, pawn order.
Low-alpha generator fringe is discarded, then each role is independently
fitted into a 256px production cell so adjacent artwork cannot leak in.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


ROLE_NAMES = ("king", "queen", "bishop", "knight", "rook", "pawn")
ALPHA_FLOOR = 24
CELL = 256
BASELINE = 244
MAX_HEIGHT = 226
MAX_WIDTH = (196, 196, 224, 224, 224, 96)


def dominant_component(source: Image.Image) -> Image.Image:
    """Remove disconnected spill from a neighbouring generated figure."""
    rgba = source.convert("RGBA")
    alpha = rgba.getchannel("A")
    width, height = rgba.size
    opaque = bytearray(1 if value >= ALPHA_FLOOR else 0 for value in alpha.getdata())
    visited = bytearray(width * height)
    largest: list[int] = []
    for start, visible in enumerate(opaque):
        if not visible or visited[start]:
            continue
        component: list[int] = []
        queue = deque([start])
        visited[start] = 1
        while queue:
            index = queue.popleft()
            component.append(index)
            x, y = index % width, index // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if opaque[neighbor] and not visited[neighbor]:
                        visited[neighbor] = 1
                        queue.append(neighbor)
        if len(component) > len(largest):
            largest = component
    if not largest:
        raise ValueError("No substantial connected sprite component found")
    keep = bytearray(width * height)
    for index in largest:
        keep[index] = 1
    cleaned_alpha = alpha.point(lambda value: value if value >= ALPHA_FLOOR else 0)
    cleaned_data = bytearray(cleaned_alpha.tobytes())
    for index in range(width * height):
        if not keep[index]:
            cleaned_data[index] = 0
    rgba.putalpha(Image.frombytes("L", (width, height), bytes(cleaned_data)))
    return rgba


def find_column_cuts(lineup: Image.Image) -> list[int]:
    alpha = lineup.getchannel("A")
    width, height = lineup.size
    pixels = alpha.load()
    cuts = [0]
    nominal_width = width // 6
    for column in range(1, 6):
        nominal = column * nominal_width
        candidates = range(max(1, nominal - 100), min(width - 1, nominal + 101))
        cut = min(
            candidates,
            key=lambda x: (
                sum(1 for y in range(height) if pixels[x, y] >= ALPHA_FLOOR),
                abs(x - nominal),
            ),
        )
        cuts.append(cut)
    cuts.append(width)
    return cuts


def clean_and_fit(source: Image.Image, role: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    rgba = dominant_component(source)
    alpha = rgba.getchannel("A").point(lambda value: value if value >= ALPHA_FLOOR else 0)
    rgba.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"No visible pixels found for {ROLE_NAMES[role]}")
    sprite = rgba.crop(bounds)
    scale = min(MAX_WIDTH[role] / sprite.width, MAX_HEIGHT / sprite.height)
    size = (
        max(1, round(sprite.width * scale)),
        max(1, round(sprite.height * scale)),
    )
    sprite = sprite.resize(size, Image.Resampling.LANCZOS)
    return sprite, bounds


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("inputs", nargs=8, type=Path)
    parser.add_argument("--rows-dir", type=Path)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    if args.output.exists() and not args.overwrite:
        raise SystemExit(f"Refusing to overwrite existing output: {args.output}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.rows_dir:
        args.rows_dir.mkdir(parents=True, exist_ok=True)

    atlas = Image.new("RGBA", (CELL * 6, CELL * 8), (0, 0, 0, 0))
    report: list[str] = []
    for row, path in enumerate(args.inputs):
        lineup = Image.open(path).convert("RGBA")
        if lineup.size != (2172, 724):
            raise SystemExit(f"Expected 2172x724 lineup, received {lineup.size}: {path}")
        cuts = find_column_cuts(lineup)
        prepared_row = Image.new("RGBA", (CELL * 6, CELL), (0, 0, 0, 0))
        for role in range(6):
            region = lineup.crop((cuts[role], 0, cuts[role + 1], 724))
            sprite, source_bounds = clean_and_fit(region, role)
            x = role * CELL + (CELL - sprite.width) // 2
            y = BASELINE - sprite.height
            prepared_row.alpha_composite(sprite, (x, y))
            report.append(
                f"row={row} role={ROLE_NAMES[role]} cut=({cuts[role]},{cuts[role + 1]}) "
                f"source={source_bounds} "
                f"output=({x},{y},{x + sprite.width},{y + sprite.height})"
            )
        atlas.alpha_composite(prepared_row, (0, row * CELL))
        if args.rows_dir:
            prepared_row.save(args.rows_dir / f"{row:02d}-{path.stem}.png", optimize=True)

    atlas.save(args.output, optimize=True)
    args.output.with_suffix(".report.txt").write_text("\n".join(report) + "\n")
    print(f"Wrote 48 isolated sprites to {args.output} ({atlas.width}x{atlas.height})")


if __name__ == "__main__":
    main()
