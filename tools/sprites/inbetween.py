"""Make in-between frames for a grid sprite sheet with RIFE (ncnn-vulkan build).

Each frame is placed on a flat green key, interpolated in one RIFE pass, keyed back
to transparency, then snapped to the source art's own palette for clean cel colour.

usage: python inbetween.py <sheet.png> <columns> <out_sheet.png> [rows] [model]
Each row is one looping animation. Writes the same rows with 2x the columns:
f0, f0.5, f1, f1.5, ... (the last in-between blends the final frame into the first).
Fully transparent rows stay transparent.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

TOOLS = Path(__file__).parent
RIFE = TOOLS / "rife" / "rife-ncnn-vulkan.exe"


def cells(sheet: Image.Image, columns: int, row: int = 0, rows: int = 1) -> list[Image.Image]:
    w, h = sheet.size
    top, bottom = h * row // rows, h * (row + 1) // rows
    return [sheet.crop((w * c // columns, top, w * (c + 1) // columns, bottom)) for c in range(columns)]


def rife(a: Path, b: Path, out: Path, model: str) -> None:
    subprocess.run([str(RIFE), "-0", str(a), "-1", str(b), "-o", str(out), "-m", str(TOOLS / "rife" / model), "-x", "-u", "-z"],
                   check=True, capture_output=True)


# Flat key colour behind the sprite. Pure green suits most characters, but a
# character who wears green (Bullcap) needs another; see choose_key.
KEY = np.array([0.0, 1.0, 0.0], dtype=np.float32)
KEY_CANDIDATES = [np.array(c, dtype=np.float32) for c in ([0, 1, 0], [1, 0, 1], [0, 1, 1], [0, 0, 1])]


def choose_key(frames: list[Image.Image]) -> np.ndarray:
    """The candidate key colour furthest from every colour the character wears."""
    pixels = np.concatenate([np.asarray(f.convert("RGBA"))[np.asarray(f.convert("RGBA"))[..., 3] > 128][:, :3]
                             for f in frames]).astype(np.float32) / 255.0
    pixels = pixels[:: max(1, len(pixels) // 20000)]
    return max(KEY_CANDIDATES, key=lambda key: float(np.linalg.norm(pixels - key, axis=1).min()))


def midpoint(a: Image.Image, b: Image.Image, work: Path, model: str, key: np.ndarray = KEY) -> Image.Image:
    # One RIFE pass over sprite-on-key keeps colour and shape moving together;
    # interpolating colour and alpha separately let them drift apart (black blobs).
    for name, img in (("a", a), ("b", b)):
        arr = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
        alpha = arr[..., 3:4]
        flat = arr[..., :3] * alpha + key * (1.0 - alpha)
        Image.fromarray((flat * 255).round().astype(np.uint8)).save(work / f"{name}.png")
    rife(work / "a.png", work / "b.png", work / "m.png", model)
    rgb = np.asarray(Image.open(work / "m.png").convert("RGB")).astype(np.float32) / 255.0
    # Pull the sprite back off the key: how far each pixel is from the key colour.
    distance = np.linalg.norm(rgb - key, axis=2, keepdims=True) / np.sqrt(2.0)
    alpha = np.clip((distance - 0.12) / 0.5, 0.0, 1.0)
    colour = np.where(alpha > 0, (rgb - key * (1.0 - alpha)) / np.maximum(alpha, 1e-3), 0.0).clip(0, 1)
    out = np.concatenate([colour, alpha], axis=2)
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA")


def palette_from(frames: list[Image.Image], colours: int = 48) -> Image.Image:
    """The source art's own flat-shading palette, taken from its opaque pixels."""
    pixels = [np.asarray(f.convert("RGBA")) for f in frames]
    opaque = np.concatenate([p[p[..., 3] > 128][:, :3] for p in pixels])
    strip = Image.fromarray(opaque.reshape(1, -1, 3).astype(np.uint8), "RGB")
    return strip.quantize(colours, method=Image.Quantize.MEDIANCUT)


def clean(frame: Image.Image, palette: Image.Image) -> Image.Image:
    """Snap blurry interpolated colour back to flat cel colours and harden soft edges."""
    rgba = np.asarray(frame).copy()
    snapped = np.asarray(Image.fromarray(rgba[..., :3]).quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB"))
    alpha = rgba[..., 3].astype(np.float32) / 255.0
    # Keep a one-step soft edge like the source line art; drop haze, solidify the body.
    alpha = np.clip((alpha - 0.35) / 0.3, 0.0, 1.0)
    rgba[..., :3] = snapped
    rgba[..., 3] = (alpha * 255).round().astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def match_extent(middle: Image.Image, a: Image.Image, b: Image.Image) -> Image.Image:
    """Give the in-between the neighbours' measured height.

    The game scales each frame by its full alpha>0 bounds, and the source art has a
    faint haze (alpha 1-10) above the drawing. Cleaning removes that haze, so without
    this the in-between would measure shorter and be drawn larger. Invisible 1/255
    marker pixels at the interpolated top and bottom restore the same extent.
    """
    def rows(img: Image.Image) -> tuple[int, int] | None:
        filled = np.where((np.asarray(img)[..., 3] > 0).any(axis=1))[0]
        return (int(filled[0]), int(filled[-1])) if len(filled) else None
    ea, eb, em = rows(a.convert("RGBA")), rows(b.convert("RGBA")), rows(middle)
    if not (ea and eb and em):
        return middle
    out = np.asarray(middle).copy()
    centre = out.shape[1] // 2
    for target, current in (((ea[0] + eb[0]) // 2, em[0]), ((ea[1] + eb[1]) // 2, em[1])):
        if out[target, centre, 3] == 0:
            out[target, centre] = (0, 0, 0, 1)
    return Image.fromarray(out, "RGBA")


def main() -> None:
    src, columns, dst = Path(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])
    rows = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    model = sys.argv[5] if len(sys.argv) > 5 else "rife-v4.6"
    source = Image.open(src).convert("RGBA")
    all_frames = [cells(source, columns, r, rows) for r in range(rows)]
    palette = palette_from([f for row in all_frames for f in row if f.getbbox()])
    w, h = all_frames[0][0].size
    sheet = Image.new("RGBA", (w * columns * 2, source.height))
    with tempfile.TemporaryDirectory() as tmp:
        for r, frames in enumerate(all_frames):
            top = source.height * r // rows
            if not any(f.getbbox() for f in frames):
                continue  # unused transparent row
            for i, frame in enumerate(frames):
                after = frames[(i + 1) % len(frames)]
                middle = match_extent(clean(midpoint(frame, after, Path(tmp), model), palette), frame, after)
                sheet.paste(frame.resize((w, h)), (2 * i * w, top))
                sheet.paste(middle.resize((w, h)), ((2 * i + 1) * w, top))
    sheet.save(dst)
    print(f"wrote {dst}: {rows} rows x {columns * 2} frames of {w}x{h}")


if __name__ == "__main__":
    main()
