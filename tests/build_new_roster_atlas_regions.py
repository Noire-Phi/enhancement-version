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
# The diagonal sprint's SpriteCook in-betweens stand taller than the pool, and the RIFE
# frame index (assets/characters/sprites/inbetween/index.json) is keyed by each cell's
# padding, so this pair grows its own canvas after the shared motion one is set.
DIAGONAL_SPRINT_SHEETS = ("sprint_diagonal_v2", "sprint_diagonal_v2_inbetween")
# *_inbetween side sheets are generated (enhancement version: RIFE walks, SpriteCook
# sprints); each shares its source cycle's canvas so both drawings pad identically.
SIDE_SHEETS = ("side_walk_cycle", "side_walk_cycle_inbetween", "side_sprint_cycle",
               "side_sprint_cycle_inbetween")


def spans(values: np.ndarray, minimum: int) -> list[tuple[int, int]]:
    active = np.flatnonzero(values)
    groups = np.split(active, np.where(np.diff(active) > 1)[0] + 1)
    return [(int(group[0]), int(group[-1]) + 1) for group in groups if len(group) >= minimum]


def grown(found: list[tuple[int, int]], present: np.ndarray) -> list[tuple[int, int, int, int]]:
    """Widen each span over its thin tips (lines with only a few drawn pixels, such as a
    hair spike or fingertip) up to the first empty line, so a region never clips them.
    Returns (start, end, low limit, high limit): padding must stay between the neighbours."""
    out = []
    for index, (start, end) in enumerate(found):
        low = found[index - 1][1] if index > 0 else 0
        high = found[index + 1][0] if index + 1 < len(found) else len(present)
        while start > low and present[start - 1]:
            start -= 1
        while end < high and present[end]:
            end += 1
        out.append((start, end, low, high))
    return out


def regions(path: Path, expected_rows: int = 4, expected_columns: int = 4) -> dict:
    alpha = np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)[:, :, 3]
    rows = spans(np.count_nonzero(alpha > 10, axis=1) > 8, 100)
    if len(rows) != expected_rows:
        raise ValueError(f"{path}: expected {expected_rows} rows, found {rows}")
    rows = grown(rows, (alpha > 10).any(axis=1))
    cells = []
    for top, bottom, top_limit, bottom_limit in rows:
        band = alpha[top:bottom] > 10
        columns = spans(np.count_nonzero(band, axis=0) > 5, 100)
        if len(columns) != expected_columns:
            raise ValueError(f"{path}: expected {expected_columns} cells in row {top}, found {columns}")
        cell_row = []
        for left, right, left_limit, right_limit in grown(columns, band.any(axis=0)):
            opaque = np.argwhere(band[:, left:right])
            y0, x0 = opaque.min(axis=0)
            y1, x1 = opaque.max(axis=0) + 1
            x = max(left_limit, left + int(x0) - 2)
            y = max(top_limit, top + int(y0) - 2)
            w = min(right_limit, left + int(x1) + 2) - x
            h = min(bottom_limit, top + int(y1) + 2) - y
            cell_row.append([x, y, w, h])
        cells.append(cell_row)
    return {"canvas": [max(cell[2] for row in cells for cell in row),
                       max(cell[3] for row in cells for cell in row)], "cells": cells}


if __name__ == "__main__":
    atlas = {character: {sheet: regions(ROOT / character / f"{sheet}.png", 2 if "_v2" in sheet else 4)
                         for sheet in SHEETS + MOTION_SHEETS + DIAGONAL_SPRINT_SHEETS}
             for character in ("leonardo", "kay")}
    for character in atlas:
        for sheet in SIDE_SHEETS:
            atlas[character][sheet] = regions(ROOT / character / f"{sheet}.png", 1, 4)
        for action in ("walk", "sprint"):
            side = [atlas[character][sheet] for sheet in (f"side_{action}_cycle", f"side_{action}_cycle_inbetween")]
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
        sprint_canvas = [max([motion_canvas[axis]] + [atlas[character][sheet]["canvas"][axis]
                                                      for sheet in DIAGONAL_SPRINT_SHEETS])
                         for axis in (0, 1)]
        for sheet in DIAGONAL_SPRINT_SHEETS:
            atlas[character][sheet]["canvas"] = sprint_canvas
    (ROOT / "atlas_regions.json").write_text(json.dumps(atlas, indent=2) + "\n", encoding="utf-8")
    print("Wrote", ROOT / "atlas_regions.json")
