#!/usr/bin/env python3
"""Compose the "小树林" (grove) sprites from the Gemini plant set.

The seven Gemini reference renders are pixelated into the twelve sprites under
Assets/Resources/Dino. This tool arranges those sprites into dense groves in
the spirit of the reference composition: a tall central tree, smaller trees and
palms behind, cycad/fern rosettes in the middle, low plants in front and grass
clumps along the ground.

It writes several deterministic variants so world placement can pick one at
random:

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
FIELD_PREVIEW = ROOT / "tools" / "art" / "preview" / "grove_field_preview.png"

W, H = 154, 158
GROUND = 149

# variant index -> file name. Variant 1 keeps the plain "grove" name so code
# that only knows the original sprite keeps working.
VARIANTS = 4
NAMES = ["grove"] + [f"grove_{i}" for i in range(2, VARIANTS + 1)]

GRASS_DARK = (47, 100, 40, 255)
GRASS_MID = (74, 138, 56, 255)
GRASS_LIGHT = (111, 176, 82, 255)

GROUND_PLANTS = ["horsetail", "horsetail_cone", "crown", "crown_small",
                 "flower", "clubmoss_small", "fern_frond", "fern"]


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


def clamp_x(sprite: Image.Image, x: float) -> float:
    return max(sprite.width / 2, min(W - sprite.width / 2, x))


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


def compose(seed: int) -> Image.Image:
    rng = random.Random(seed)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # ---------------------------------------------------------- back: trees
    main_x = 64 + rng.uniform(-5, 5)
    put(canvas, load("tree", 1.0, rng.random() < .5), main_x, GROUND)

    second_side = 0
    if rng.random() < .9:
        second_side = rng.choice((-1, 1))
        sc = rng.uniform(.56, .72)
        tree = load("tree", sc, rng.random() < .5)
        x = main_x + second_side * rng.uniform(50, 60)
        put(canvas, tree, clamp_x(tree, x), GROUND)

    # Fan palm on the other side from the second tree (or a random side).
    palm_side = -second_side if second_side else rng.choice((-1, 1))
    palm = load("palm", 1.0, palm_side < 0)
    put(canvas, palm, clamp_x(palm, main_x + palm_side * rng.uniform(40, 48)),
        GROUND + rng.uniform(0, 1))

    # ----------------------------------------------------------- mid layer
    for _ in range(rng.randint(2, 3)):
        side = rng.choice((-1, 1))
        cycad = load("cycad", rng.uniform(.85, 1.05), rng.random() < .5)
        x = main_x + side * rng.uniform(14, 34)
        put(canvas, cycad, clamp_x(cycad, x),
            GROUND + rng.uniform(1, 3))

    bush = load("bush", rng.uniform(.9, 1.1), rng.random() < .5)
    put(canvas, bush, clamp_x(bush, main_x + rng.uniform(-42, 42)),
        GROUND + rng.uniform(1, 4))

    fern = load("fern", rng.uniform(.9, 1.1), rng.random() < .5)
    put(canvas, fern, clamp_x(fern, main_x + rng.uniform(-26, 26)),
        GROUND + rng.uniform(2, 4))

    # --------------------------------------------------------- front layer
    picks = rng.sample(GROUND_PLANTS, rng.randint(5, 7))
    for i, name in enumerate(picks):
        sprite = load(name, rng.uniform(.9, 1.15), rng.random() < .5)
        x = 12 + (i + .5) * (W - 24) / len(picks) + rng.uniform(-5, 5)
        put(canvas, sprite, clamp_x(sprite, x),
            H - rng.uniform(1, 4))

    # ------------------------------------------------------- grass clumps
    grass = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for _ in range(rng.randint(9, 12)):
        draw_grass(grass, rng,
                   rng.uniform(6, W - 6), rng.uniform(GROUND + 3, H - 6),
                   rng.uniform(12, 22), rng.uniform(8, 14))
    for _ in range(rng.randint(14, 18)):
        draw_grass(grass, rng,
                   rng.uniform(2, W - 2), rng.uniform(H - 5, H - 1),
                   rng.uniform(14, 28), rng.uniform(10, 16))
    canvas.alpha_composite(grass)
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


def field_preview(seed: int = 7, scale: int = 2) -> Image.Image:
    """Representative 3x2 landmark like Config.groveField in dino_config.lua."""
    rng = random.Random(seed)
    spacing_x, spacing_y = 4.6 * 22, 4.5 * 22
    base_w, base_h = round(154 * 1.25), round(158 * 1.25)
    w = round(2 * spacing_x + base_w + 64)
    h = round(spacing_y + base_h + 96)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # Back row first, front row last, matching dino_track.spawnGroveField().
    for row in range(1, -1, -1):
        for col in range(3):
            sc = rng.uniform(.95, 1.25)
            sprite = load(rng.choice(NAMES), sc, rng.random() < .5)
            x = (w / 2 + (col - 1) * spacing_x
                 + rng.uniform(-1, 1) * 1.2 * 22)
            # Each grove gets its own vertical offset so the front edge is jagged.
            stagger = rng.uniform(-0.7, 0.7) * 22
            base_y = (h - 8 - row * spacing_y + stagger
                      + rng.uniform(-.5, .5) * .6 * 22)
            put(canvas, sprite, x, base_y)

    big = canvas.resize((w * scale, h * scale), Image.NEAREST)
    board = checkerboard(big.width, big.height).convert("RGBA")
    board.alpha_composite(big)
    return board


def main() -> None:
    images = []
    for i, name in enumerate(NAMES):
        grove = compose(seed=101 + i * 7919)
        path = SRC / f"{name}.png"
        grove.save(path)
        ensure_meta(path)
        images.append(grove)
        print(f"wrote {path.relative_to(ROOT)} ({grove.width}x{grove.height})")

    sheet = contact_sheet(images, NAMES)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW)
    print(f"wrote {PREVIEW.relative_to(ROOT)}")

    FIELD_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    field_preview().save(FIELD_PREVIEW)
    print(f"wrote {FIELD_PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()