"""Repack a fixed-grid sprite sheet whose drawings spill over their cells.

The relaxed/motion-polish loaders cut every sheet into an even grid (relaxed sheets also
drop the top 12 px of each cell to hide the feet of the row above). Where a ponytail,
hair or shoe crosses a cell line it is clipped, or a neighbour's piece shows up. This
gives every drawing its own, larger cell: each opaque blob goes to the cell holding its
centre, faint edge pixels go to the nearest blob, and the cell grows by one factor in
both directions, so the loaders' column count (from the sheet's aspect) is unchanged.
Each drawing keeps its sideways offset from its cell centre (no stride jitter) and sits
a fixed distance above its cell bottom (the game anchors feet by visible bounds).
Pixels are copied, never redrawn.

usage: python repack_grid_sheet.py <sheet.png> <rows> <columns> <top_trim> [--out <png>]
"""
import sys
from collections import deque

import numpy as np
from PIL import Image

SOLID = 40       # alpha that counts as part of a drawing's body
BOTTOM_PAD = 10  # transparent rows kept under the lowest pixel of each drawing
SIDE_PAD = 6


def blobs(mask: np.ndarray) -> np.ndarray:
    labels = np.zeros(mask.shape, np.int32)
    count = 0
    h, w = mask.shape
    for sy, sx in zip(*np.nonzero(mask)):
        if labels[sy, sx]:
            continue
        count += 1
        labels[sy, sx] = count
        queue = deque([(sy, sx)])
        while queue:
            y, x = queue.popleft()
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not labels[yy, xx]:
                    labels[yy, xx] = count
                    queue.append((yy, xx))
    return labels


def grow(owner: np.ndarray, faint: np.ndarray, steps: int = 40) -> np.ndarray:
    """Give faint pixels the owner of the nearest solid pixel (4-neighbour growth)."""
    for _ in range(steps):
        todo = faint & (owner < 0)
        if not todo.any():
            break
        padded = np.pad(owner, 1, constant_values=-1)
        for neighbour in (padded[2:, 1:-1], padded[:-2, 1:-1], padded[1:-1, 2:], padded[1:-1, :-2]):
            take = todo & (owner < 0) & (neighbour >= 0)
            owner[take] = neighbour[take]
    return owner


def repack(path: str, rows: int, columns: int, top_trim: int, out: str) -> None:
    image = np.array(Image.open(path).convert("RGBA"))
    h, w = image.shape[:2]
    cw, ch = w / columns, h / rows
    alpha = image[..., 3]
    labels = blobs(alpha >= SOLID)
    cell_of = np.full(h * w, -1, np.int32).reshape(h, w)  # owner cell index per pixel
    ys, xs = np.nonzero(labels)
    ids = labels[ys, xs]
    sums_y = np.bincount(ids, ys); sums_x = np.bincount(ids, xs); sizes = np.bincount(ids)
    for blob in range(1, len(sizes)):
        if sizes[blob] == 0:
            continue
        cy, cx = sums_y[blob] / sizes[blob], sums_x[blob] / sizes[blob]
        cell = min(rows - 1, int(cy // ch)) * columns + min(columns - 1, int(cx // cw))
        cell_of[labels == blob] = cell
        by, bx = np.nonzero(labels == blob)
        if by.max() - by.min() > ch * 1.4:
            raise SystemExit(f"{path}: blob {blob} spans {by.max() - by.min()} px, taller than a cell; drawings touch")
    faint = (alpha > 0) & (cell_of < 0)
    cell_of = grow(cell_of, faint)
    rest = (alpha > 0) & (cell_of < 0)  # isolated faint markers stay in the cell they sit in
    ry, rx = np.nonzero(rest)
    cell_of[ry, rx] = np.minimum(rows - 1, (ry // ch).astype(int)) * columns + np.minimum(columns - 1, (rx // cw).astype(int))
    # Measure every drawing, then one growth factor that fits them all.
    boxes = {}
    for cell in range(rows * columns):
        cy, cx = np.nonzero(cell_of == cell)
        if len(cy) == 0:
            continue
        col, row = cell % columns, cell // columns
        centre = (col + 0.5) * cw
        boxes[cell] = (cy.min(), cy.max() + 1, cx.min(), cx.max() + 1, centre)
    need_h = max(b[1] - b[0] for b in boxes.values()) + top_trim + BOTTOM_PAD + 4
    need_w = max(2 * max(b[4] - b[2], b[3] - b[4]) for b in boxes.values()) + 2 * SIDE_PAD
    k = max(1.0, need_h / ch, need_w / cw)
    new_w, new_h = int(np.ceil(w * k)), int(np.ceil(h * k))
    # Snap so that new_w / columns and new_h / rows stay whole and in the old ratio.
    ncw, nch = int(np.ceil(cw * k)), int(np.ceil(ch * k))
    new_w, new_h = ncw * columns, nch * rows
    result = np.zeros((new_h, new_w, 4), np.uint8)
    for cell, (y0, y1, x0, x1, centre) in boxes.items():
        col, row = cell % columns, cell // columns
        dx = int(round(col * ncw + ncw / 2 - centre))
        dy = int(row * nch + nch - BOTTOM_PAD - y1)
        own = cell_of[y0:y1, x0:x1] == cell
        target = result[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
        target[own] = image[y0:y1, x0:x1][own]
    Image.fromarray(result).save(out)
    old_cols = round(w / (h / rows * 1.025)) if rows == 5 else columns
    new_cols = round(new_w / (new_h / rows * 1.025)) if rows == 5 else columns
    assert old_cols == new_cols == columns or rows != 5, (old_cols, new_cols, columns)
    print(f"{path}: {w}x{h} -> {new_w}x{new_h} (x{k:.3f}), {len(boxes)} drawings")


if __name__ == "__main__":
    args = sys.argv[1:]
    out = args[args.index("--out") + 1] if "--out" in args else args[0]
    repack(args[0], int(args[1]), int(args[2]), int(args[3]), out)
