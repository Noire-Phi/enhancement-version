"""Generate one in-between frame for every walk/sprint frame pair the game uses.

Input: the folder written by export_locomotion_frames.gd (frames + manifest.json).
Output: assets/characters/sprites/inbetween/<character>_<n>.png atlases and index.json,
which scenes/locomotion_inbetweens.gd installs at runtime.

usage: python locomotion_inbetweens.py <export dir> <repo root> [--skip CHARACTER/ANIMATION|CHARACTER/* ...]

Current build (see tools/sprites/README.md):
  --skip "Bullcap Head/*" Kay/sprint_left Kay/sprint_down_left Kay/sprint_up_left
         Leonardo/sprint_left Leonardo/sprint_down_left Leonardo/sprint_up_left
"""
import json
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

import inbetween as ib

PAGE_WIDTH = 4096
PAGE_HEIGHT = 8192
PAD = 2


def main() -> None:
    export_dir, repo = Path(sys.argv[1]), Path(sys.argv[2])
    skip = set(sys.argv[sys.argv.index("--skip") + 1:]) if "--skip" in sys.argv else set()
    manifest = json.loads((export_dir / "manifest.json").read_text(encoding="utf-8"))["pairs"]
    out_dir = repo / "assets/characters/sprites/inbetween"
    out_dir.mkdir(parents=True, exist_ok=True)
    by_character: dict[str, list[tuple[str, dict]]] = {}
    for key, pair in manifest.items():
        if f"{pair['character']}/{pair['animation']}" in skip or f"{pair['character']}/*" in skip:
            continue
        by_character.setdefault(pair["character"], []).append((key, pair))
    index = {}
    with tempfile.TemporaryDirectory() as tmp:
        for character, pairs in by_character.items():
            files = sorted({p[f] for _, p in pairs for f in ("a", "b")})
            sources = [Image.open(export_dir / f).convert("RGBA") for f in files]
            palette = ib.palette_from(sources)
            key_colour = ib.choose_key(sources)
            print(character, "key colour", key_colour.tolist(), flush=True)
            frames = []
            for n, (key, pair) in enumerate(pairs):
                a = Image.open(export_dir / pair["a"]).convert("RGBA")
                b = Image.open(export_dir / pair["b"]).convert("RGBA")
                if a.size != b.size:
                    print("skip size mismatch", character, pair["animation"])
                    continue
                middle = ib.match_extent(ib.clean(ib.midpoint(a, b, Path(tmp), "rife-v4.6", key_colour), palette), a, b)
                box = middle.getbbox() or (0, 0, 1, 1)
                frames.append((key, middle.crop(box), box[:2], middle.size))
                if n % 20 == 0:
                    print(f"{character}: {n}/{len(pairs)}", flush=True)
            # Shelf-pack the cropped frames into pages.
            slug = character.lower().replace(" ", "_")
            pages, placements = [], []
            x = y = shelf = 0
            page = 0
            for key, image, offset, size in sorted(frames, key=lambda f: -f[1].height):
                w, h = image.size
                if x + w + PAD > PAGE_WIDTH:
                    x, y, shelf = 0, y + shelf + PAD, 0
                if y + h + PAD > PAGE_HEIGHT:
                    pages.append(y + shelf)
                    page, x, y, shelf = page + 1, 0, 0, 0
                placements.append((page, x, y, key, image, offset, size))
                x += w + PAD
                shelf = max(shelf, h)
            pages.append(y + shelf)
            for p, height in enumerate(pages):
                sheet = Image.new("RGBA", (PAGE_WIDTH, max(1, height)))
                path = f"{slug}_{p}.png"
                for page_index, px, py, key, image, offset, size in placements:
                    if page_index != p:
                        continue
                    sheet.paste(image, (px, py))
                    index[key] = {"atlas": f"res://assets/characters/sprites/inbetween/{path}",
                                  "rect": [px, py, image.width, image.height, offset[0], offset[1]],
                                  "size": list(size)}
                sheet.save(out_dir / path, optimize=True)
                print("wrote", path, sheet.size, flush=True)
    (out_dir / "index.json").write_text(json.dumps({"pairs": index}, indent=1) + "\n", encoding="utf-8")
    print("index entries:", len(index))


if __name__ == "__main__":
    main()
