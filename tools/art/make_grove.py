#!/usr/bin/env python3
"""Compose the "小树林" (grove) sprites from the Gemini plant set.

The seven Gemini reference renders are pixelated into the twelve sprites under
Assets/Resources/Dino. This tool arranges those sprites into dense groves in
the spirit of the reference composition: a tall central tree, smaller trees and
palms behind, cycad/fern rosettes in the middle, low plants in front and grass
clumps along the ground.

It writes four silhouettes for the canopy and edge positions in each woodland:

    Assets/Resources/Dino/grove.png      variant 1 (the default "grove")
    Assets/Resources/Dino/grove_2.png    variant 2
    Assets/Resources/Dino/grove_3.png    variant 3
    Assets/Resources/Dino/grove_4.png    variant 4

Run from the repo root:

    python tools/art/make_grove.py

Preview: tools/art/preview/grove_preview.png (all variants, 2x).
"""

from __future__ import annotations

import hashlib
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Assets" / "Resources" / "Dino"
PREVIEW = ROOT / "tools" / "art" / "preview" / "grove_preview.png"

W, H = 154, 158

# variant index -> file name. Variant 1 keeps the plain "grove" name so code
# that only knows the original sprite keeps working.
VARIANTS = 4
NAMES = ["grove"] + [f"grove_{i}" for i in range(2, VARIANTS + 1)]

GRASS_DARK = (47, 100, 40, 255)
GRASS_MID = (74, 138, 56, 255)
GRASS_LIGHT = (111, 176, 82, 255)

# Back to front. Base heights vary so crowns, roots and the fern skirt
# describe the same knoll. Smaller edge groves have their own silhouettes.
# (sprite, bottom-centre x, base y, scale)
GROVES = [
    [("palm", 103, 120, .79), ("tree", 61, 144, .96),
     ("cycad", 92, 142, .88), ("fern", 44, 150, .84), ("fern", 75, 151, .61)],
    [("tree", 47, 119, .73), ("tree", 99, 145, .90),
     ("fern", 38, 137, .74), ("cycad", 64, 145, .88), ("fern", 99, 151, .62)],
    [("palm", 94, 120, 1.12), ("palm", 58, 134, .80),
     ("cycad", 84, 145, 1.10), ("fern", 45, 143, .86), ("fern", 103, 149, .75)],
    [("tree", 93, 130, .78), ("cycad", 68, 140, 1.04),
     ("cycad", 35, 139, .71), ("fern", 95, 148, .88), ("fern", 54, 151, .64)],
]


def load(name: str, scale: float = 1.0, flip: bool = False) -> Image.Image:
    sprite = Image.open(SRC / f"{name}.png").convert("RGBA")
    if scale != 1.0:
        sprite = sprite.resize(
            (max(1, round(sprite.width * scale)),
             max(1, round(sprite.height * scale))),
            Image.NEAREST,
        )
    if flip:
        sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT)
    return sprite


def put(canvas: Image.Image, sprite: Image.Image, cx: float, base_y: float) -> None:
    """Alpha-composite a sprite with its bottom-centre at (cx, base_y)."""
    x = round(cx - sprite.width / 2)
    y = round(base_y - sprite.height)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(sprite, (x, y), sprite)
    canvas.alpha_composite(layer)


def draw_grass(layer: Image.Image, rng: random.Random,
               cx: float, base_y: float, width: float, height: float) -> None:
    """A 5-blade pixel grass clump in the game's grass palette."""
    d = ImageDraw.Draw(layer)
    blades = max(3, round(width / 4))
    for i in range(blades):
        x = cx - width / 2 + (i + .5) * width / blades
        x += rng.uniform(-1.2, 1.2)
        top_y = base_y - height * rng.uniform(.55, 1.0)
        lean = rng.uniform(-3.5, 3.5)
        d.line([(round(x), round(base_y)), (round(x + lean), round(top_y))],
               fill=GRASS_DARK)
        d.line([(round(x), round(base_y) - 1),
                (round(x + lean * .75), round(top_y) + 1)],
               fill=GRASS_MID if i % 2 == 0 else GRASS_LIGHT)
    d.ellipse([cx - width * .30, base_y - 3, cx + width * .30, base_y + 1],
              fill=GRASS_DARK)


def compose(index: int) -> Image.Image:
    rng = random.Random(101 + index * 7919)
    canvas = Image.new("RGBA", (W, H))
    layers = GROVES[index]
    # Shared leaf-litter and shade under overlapping roots, broadest in the
    # interior. Small shelves at different depths break up the forest floor.
    shade = ImageDraw.Draw(canvas)
    for _, x, y, size in layers:
        width = round(29 * size)
        shade.polygon([(x - width, y - 2), (x - width + 7, y - 7), (x + 4, y - 10),
                       (x + width - 4, y - 6), (x + width, y - 1), (x + 8, y + 3),
                       (x - 9, y + 3)], fill=(42, 61, 31, 90))
    # Broken patches of grass bind neighbouring roots. Leave the outer
    # corners transparent so two overlapping groves never form a flat seam.
    for _, x, y, size in layers:
        for _ in range(5):
            draw_grass(canvas, rng, x + rng.uniform(-20, 20) * size,
                       y + rng.uniform(-3, 2), rng.uniform(8, 16), rng.uniform(4, 8))
    for name, x, y, size in layers:
        put(canvas, load(name, size, rng.random() < .5), x, y)
    # A single understory species repeats around two roots in each grove.
    small = ["fern_frond", "clubmoss_small", "horsetail", "fern_frond"][index]
    for _, x, y, _ in layers[-2:]:
        for dx, dy in [(-13, -2), (9, 2), (17, 0)]:
            put(canvas, load(small, rng.uniform(.42, .68), dx < 0), x + dx, y + dy)
        draw_grass(canvas, rng, x + 4, y + 2, 16, 6)
    return canvas


def ensure_meta(image_path: Path) -> None:
    """Create a Unity .meta next to a new variant (stable name-based GUID)."""
    meta_path = image_path.with_suffix(image_path.suffix + ".meta")
    if meta_path.exists():
        return
    template = (SRC / "tree.png.meta").read_text(encoding="utf-8")
    guid = hashlib.md5(f"DinoImpact/{image_path.name}".encode("utf-8")).hexdigest()
    template = template.replace(
        "guid: 538b043cd5c2542033fedd6bd76695e1", f"guid: {guid}", 1)
    meta_path.write_text(template, encoding="utf-8")


def checkerboard(w: int, h: int, cell: int = 8) -> Image.Image:
    board = Image.new("RGB", (w, h), (204, 204, 204))
    d = ImageDraw.Draw(board)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if (x // cell + y // cell) % 2 == 0:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(230, 230, 230))
    return board


def contact_sheet(images: list[Image.Image], names: list[str],
                  scale: int = 2, gap: int = 8, label: int = 14) -> Image.Image:
    cell_w = max(im.width for im in images) * scale
    cell_h = max(im.height for im in images) * scale + label
    cols = 2
    rows = (len(images) + cols - 1) // cols
    sheet = checkerboard(cols * cell_w + (cols + 1) * gap,
                         rows * cell_h + (rows + 1) * gap)
    sheet = sheet.convert("RGBA")
    font = ImageFont.load_default()
    d = ImageDraw.Draw(sheet)
    for i, (im, name) in enumerate(zip(images, names)):
        col, row = i % cols, i // cols
        x = gap + col * (cell_w + gap)
        y = gap + row * (cell_h + gap)
        d.text((x, y), f"{name}  {im.width}x{im.height}", fill=(20, 20, 20, 255),
               font=font)
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x, y + label))
    return sheet


def main() -> None:
    images = []
    for i, name in enumerate(NAMES):
        grove = compose(i)
        path = SRC / f"{name}.png"
        grove.save(path)
        ensure_meta(path)
        images.append(grove)
        print(f"wrote {path.relative_to(ROOT)} ({grove.width}x{grove.height})")

    sheet = contact_sheet(images, NAMES)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW)
    print(f"wrote {PREVIEW.relative_to(ROOT)}")

if __name__ == "__main__":
    main()