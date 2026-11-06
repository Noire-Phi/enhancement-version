"""Record clean source rectangles for the generated Leonardo/Kay action atlases.

The drawings are spaced irregularly, so a rigid quarter-sheet grid can include
a neighbor's shoe or crop a foot. This only reads PNG alpha and writes metadata;
the authored pixels remain unchanged.
"""

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1] / "assets/characters/sprites/new_roster"
SHEETS = ("carry_cardinal", "carry_diagonal", "taya_stun_cardinal", "taya_stun_diagonal")
MOTION_SHEETS = ("idle_cardinal", "idle_diagonal", "reaction_cardinal",
                 "reaction_diagonal", "walk_cardinal",
                 "walk_cardinal_inbetween", "walk_diagonal_v2", "walk_diagonal_v2_inbetween",
                 "sprint_cardinal", "sprint_cardinal_inbetween", "sprint_diagonal_v2")
# *_inbetween side sheets are RIFE-generated (enhancement version); they share
# their source cycle's canvas so both drawings pad identically.
SIDE_SHEETS = ("side_walk_cycle", "side_walk_cycle_inbetween", "side_sprint_cycle")


def spans(values: np.ndarray, minimum: int) -> list[tuple[int, int]]:
    active = np.flatnonzero(values)
    groups = np.split(active, np.where(np.diff(active) > 1)[0] + 1)
    return [(int(group[0]), int(group[-1]) + 1) for group in groups if len(group) >= minimum]


def regions(path: Path, expected_rows: int = 4, expected_columns: int = 4) -> dict:
    alpha = np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)[:, :, 3]
    rows = spans(np.count_nonzero(alpha > 10, axis=1) > 8, 100)
    if len(rows) != expected_rows:
        raise ValueError(f"{path}: expected {expected_rows} rows, found {rows}")
    cells = []
    for top, bottom in rows:
        columns = spans(np.count_nonzero(alpha[top:bottom] > 10, axis=0) > 5, 100)
        if len(columns) != expected_columns:
            raise ValueError(f"{path}: expected {expected_columns} cells in row {top}, found {columns}")
        cell_row = []
        for left, right in columns:
            opaque = np.argwhere(alpha[top:bottom, left:right] > 10)
            y0, x0 = opaque.min(axis=0)
            y1, x1 = opaque.max(axis=0) + 1
            x = max(left, left + int(x0) - 2)
            y = max(top, top + int(y0) - 2)
            w = min(right, left + int(x1) + 2) - x
            h = min(bottom, top + int(y1) + 2) - y
            cell_row.append([x, y, w, h])
        cells.append(cell_row)
    return {"canvas": [max(cell[2] for row in cells for cell in row),
                       max(cell[3] for row in cells for cell in row)], "cells": cells}


if __name__ == "__main__":
    atlas = {character: {sheet: regions(ROOT / character / f"{sheet}.png", 2 if "_v2" in sheet else 4)
                         for sheet in SHEETS + MOTION_SHEETS}
             for character in ("leonardo", "kay")}
    for character in atlas:
        for sheet in SIDE_SHEETS:
            atlas[character][sheet] = regions(ROOT / character / f"{sheet}.png", 1, 4)
        side = [atlas[character][sheet] for sheet in ("side_walk_cycle", "side_walk_cycle_inbetween")]
        shared = [max(entry["canvas"][axis] for entry in side) for axis in (0, 1)]
        for entry in side:
            entry["canvas"] = shared
        for action in ("carry", "taya_stun"):
            canvas = [max(atlas[character][f"{action}_{view}"]["canvas"][axis]
                          for view in ("cardinal", "diagonal"))
                      for axis in (0, 1)]
            for view in ("cardinal", "diagonal"):
                atlas[character][f"{action}_{view}"]["canvas"] = canvas
        motion_canvas = [max(atlas[character][sheet]["canvas"][axis] for sheet in MOTION_SHEETS)
                         for axis in (0, 1)]
        for sheet in MOTION_SHEETS:
            atlas[character][sheet]["canvas"] = motion_canvas
    (ROOT / "atlas_regions.json").write_text(json.dumps(atlas, indent=2) + "\n", encoding="utf-8")
    print("Wrote", ROOT / "atlas_regions.json")
