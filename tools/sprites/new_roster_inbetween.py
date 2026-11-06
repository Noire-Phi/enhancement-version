"""In-between sheets for Leonardo and Kay's irregular atlases (diagonal and side runs).

Their drawings sit at uneven positions, recorded per cell in atlas_regions.json.
Each pair of neighbouring cells is padded onto the shared canvas exactly as the game
does (bottom-aligned, centred), interpolated with RIFE, and the result is written to
a new "<sheet>_inbetween.png" with the same rows and columns, evenly spaced, so the
repo's own tests/build_new_roster_atlas_regions.py can record its regions.

usage: python new_roster_inbetween.py <repo root>
"""
import json
import sys
import tempfile
from pathlib import Path

from PIL import Image

import inbetween as ib

SHEETS = ("walk_diagonal_v2", "sprint_diagonal_v2", "side_walk_cycle", "side_sprint_cycle")
GAP = 60  # transparent space between drawings so the region builder can split them


def padded(sheet: Image.Image, rect: list, canvas: list) -> Image.Image:
    x, y, w, h = rect
    cell = Image.new("RGBA", (canvas[0], canvas[1]))
    cell.paste(sheet.crop((x, y, x + w, y + h)), ((canvas[0] - w) // 2, canvas[1] - h))
    return cell


def main() -> None:
    root = Path(sys.argv[1]) / "assets/characters/sprites/new_roster"
    atlas = json.loads((root / "atlas_regions.json").read_text(encoding="utf-8"))
    for character in ("leonardo", "kay"):
        for key in SHEETS:
            sheet = Image.open(root / character / f"{key}.png").convert("RGBA")
            entry = atlas[character][key]
            canvas, grid = entry["canvas"], entry["cells"]
            frames = [[padded(sheet, rect, canvas) for rect in row] for row in grid]
            palette = ib.palette_from([f for row in frames for f in row])
            columns = len(grid[0])
            out = Image.new("RGBA", (columns * (canvas[0] + GAP) + GAP, len(grid) * (canvas[1] + GAP) + GAP))
            with tempfile.TemporaryDirectory() as tmp:
                for r, row in enumerate(frames):
                    for i, frame in enumerate(row):
                        middle = ib.clean(ib.midpoint(frame, row[(i + 1) % columns], Path(tmp), "rife-v4.6"), palette)
                        out.alpha_composite(middle, (GAP + i * (canvas[0] + GAP), GAP + r * (canvas[1] + GAP)))
            target = root / character / f"{key}_inbetween.png"
            out.save(target)
            print("wrote", target.name, "for", character)


if __name__ == "__main__":
    main()
