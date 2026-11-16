#!/usr/bin/env python3
"""Re-cut the PlantsPixelIt art onto the game's true pixel grid.

Each source PNG sits on a different pixel granularity, which reads as
"different layers" next to dino_*.png. This tool redraws every plant at
PPU = 22 px per world unit (same grid as the dinos), heights from the
PlantUnits table in DinoPixelArt.cs:

  clean the light cutout rim -> downscale with premultiplied alpha
  -> quantize to a flat adaptive palette (no dither) -> clean the result

Run from the repo root:  python3 -I tools/art/pixelate_plants.py
"""

from PIL import Image

from plant_pixel_art import downscale_pixel_art, outer_rim_count

SRC = "Assets/Art/PlantsPixelIt"
DST = "Assets/Resources/Dino"
PPU = 22.0
MAX_COLORS = 14

# sprite name -> (source file, design height in world units)
PLANTS = {
    "tree":            ("tree",            6.5),
    "palm":            ("palm",            3.2),
    "bush":            ("shrub",           2.0),
    "cycad":           ("cycad",           2.4),
    "fern":            ("fern",            1.8),
    "fern_frond":      ("fern_frond",      1.3),
    "flower":          ("clubmoss",        1.2),
    "clubmoss_small":  ("clubmoss_small",  0.9),
    "horsetail":       ("horsetail",       1.8),
    "horsetail_cone":  ("horsetail_cone",  1.4),
    "crown":           ("crown",           1.3),
    "crown_small":     ("crown_small",     0.9),
}


def pixelate(src_path, out_path, height_units):
    im = Image.open(src_path).convert("RGBA")
    h = max(2, round(height_units * PPU))
    w = max(2, round(im.width * h / im.height))
    out = downscale_pixel_art(im, (w, h), MAX_COLORS)
    rim = outer_rim_count(out)
    if rim:
        raise RuntimeError(f"{out_path}: {rim} bright rim pixels remain")
    out.save(out_path)
    return out.width, out.height, rim


def main():
    for name, (src_name, units) in PLANTS.items():
        w, h, rim = pixelate(f"{SRC}/{src_name}.png", f"{DST}/{name}.png", units)
        print(
            f"{name:16s} {w:4d} x {h:4d}  "
            f"({h / PPU:.2f} units @ PPU {PPU:.0f}, rim={rim})"
        )


if __name__ == "__main__":
    main()
