#!/usr/bin/env python3
"""Re-cut the PlantsPixelIt art onto the game's true pixel grid.

Each source PNG sits on a different pixel granularity, which reads as
"different layers" next to dino_*.png. This tool redraws every plant at
PPU = 22 px per world unit (same grid as the dinos), heights from the
PlantUnits table in DinoPixelArt.cs:

  downscale (LANCZOS) -> quantize to a flat adaptive palette (no dither)
  -> threshold alpha to fully opaque / fully transparent pixels

Run from the repo root:  python3 -I tools/art/pixelate_plants.py
"""
import os
from PIL import Image

SRC = "Assets/Art/PlantsPixelIt"
DST = "Assets/Resources/Dino"
PPU = 22.0
MAX_COLORS = 14

# sprite name -> (source file, design height in world units)
PLANTS = {
    "tree":            ("tree",            4.5),
    "palm":            ("palm",            2.2),
    "bush":            ("shrub",           1.2),
    "cycad":           ("cycad",           1.3),
    "fern":            ("fern",            1.0),
    "fern_frond":      ("fern_frond",      0.9),
    "flower":          ("clubmoss",        0.9),
    "clubmoss_small":  ("clubmoss_small",  0.6),
    "horsetail":       ("horsetail",       1.2),
    "horsetail_cone":  ("horsetail_cone",  1.0),
    "crown":           ("crown",           1.0),
    "crown_small":     ("crown_small",     0.65),
}


def pixelate(src_path, out_path, height_units):
    im = Image.open(src_path).convert("RGBA")
    h = max(2, round(height_units * PPU))
    w = max(2, round(im.width * h / im.height))

    # smooth downscale, then flatten back to hard pixels via quantization
    rgb = im.convert("RGB").resize((w, h), Image.LANCZOS)
    alpha = im.getchannel("A").resize((w, h), Image.BILINEAR)
    alpha = alpha.point(lambda v: 255 if v >= 110 else 0)

    pal = rgb.quantize(colors=MAX_COLORS, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
    out = Image.new("RGBA", (w, h))
    out.paste(pal.convert("RGB"), (0, 0), alpha)
    out.save(out_path)
    return w, h


def main():
    for name, (src_name, units) in PLANTS.items():
        w, h = pixelate(f"{SRC}/{src_name}.png", f"{DST}/{name}.png", units)
        print(f"{name:16s} {w:4d} x {h:4d}  ({h / PPU:.2f} units @ PPU {PPU:.0f})")


if __name__ == "__main__":
    main()
