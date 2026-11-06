# Generated running in-betweens

`inbetween.py` and `new_roster_inbetween.py` add a frame between every pair of drawn
run/walk poses with [RIFE](https://github.com/nihui/rife-ncnn-vulkan) (Vulkan build,
`rife-v4.6` model). Each frame is keyed on flat green, interpolated in one pass,
keyed back to transparency and snapped to the source art's own palette.

Setup (Windows): Python 3.12 with `pillow numpy`, and the rife-ncnn-vulkan release
unpacked so that `rife/rife-ncnn-vulkan.exe` and `rife/rife-v4.6/` sit beside these scripts.

- One-row or grid sheets (`motion_polish/*_side.png`, `relaxed/*.png`):
  `python inbetween.py <original 4-frame sheet> 4 <output sheet> [rows]`.
  Always run on the original four-frame art (git history), not on an 8-frame result.
- Leonardo/Kay irregular atlases: `python new_roster_inbetween.py <repo root>`, delete
  any rejected `*_inbetween.png`, then `python tests/build_new_roster_atlas_regions.py`.

Large, dark-on-dark leg swings (Leonardo and Kay's sprints) smear, so those sheets
were rejected and keep their four drawn frames. Review every result at game scale.
