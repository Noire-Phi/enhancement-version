# Generated running in-betweens

Two passes of in-between frames, made with [RIFE](https://github.com/nihui/rife-ncnn-vulkan)
(Vulkan build, `rife-v4.6`, run locally on the GPU). Each frame sits on a flat key colour,
is interpolated in one pass, keyed back to transparency and snapped to the source art's
own palette. The key is chosen per character so it is far from every colour they wear
(cyan for the characters in green, otherwise green).

Setup (Windows): Python 3.12 with `pillow numpy`, and the rife-ncnn-vulkan release
unpacked so that `rife/rife-ncnn-vulkan.exe` and `rife/rife-v4.6/` sit beside these scripts
(the `rife` folder is git-ignored).

## Pass 1: 4 → 8 frames, baked into the sheets

- One-row or grid sheets (`motion_polish/*_side.png`, `relaxed/*.png`):
  `python inbetween.py <original 4-frame sheet> 4 <output sheet> [rows]`.
  Always run on the original four-frame art (git history), not on an 8-frame result.
- Leonardo/Kay irregular atlases: `python new_roster_inbetween.py <repo root>`, delete
  any rejected `*_inbetween.png`, then `python tests/build_new_roster_atlas_regions.py`.

## Pass 2: every cycle doubled again, installed at runtime

1. `godot --headless --path . --script res://tools/sprites/export_locomotion_frames.gd -- <export dir>`
   exports each walk/sprint frame as the game builds it, plus every neighbouring pair.
2. `python locomotion_inbetweens.py <export dir> <repo root> --skip ...` (current skip list
   is in the script's docstring) writes `assets/characters/sprites/inbetween/`.
3. `scenes/locomotion_inbetweens.gd` slots them into every animation whose pairs are all
   present, at double the frame rate, so the stride timing is unchanged.

Rejected and left on their drawn frames: Bullcap (already 16 drawn frames; doubling
produced faint cross-faded frames). Leonardo's and Kay's side/diagonal sprints smeared in
RIFE (black trousers over large leg swings), so their `side_sprint_cycle_inbetween.png` and
`sprint_diagonal_v2_inbetween.png` are SpriteCook drawings instead (8 frames, see
docs/decisions.md). `new_roster_inbetween.py` leaves them alone, and they stay on the
pass 2 skip list until that pass is re-run on them. Review every result at game scale.
