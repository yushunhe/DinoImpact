#!/usr/bin/env python3
"""Compose the "小树林" (grove) sprite from the Gemini plant set.

The seven Gemini reference renders are pixelated into the twelve sprites under
Assets/Resources/Dino. This tool arranges those sprites into one dense grove in
the same layout as the reference composition: a tall central tree, a fan palm
at the side, rosettes and ground plants in front, and a rock bed across the
bottom.

Run from the repo root:

    python tools/art/make_grove.py

Output:
    Assets/Resources/Dino/grove.png           the runtime sprite
    tools/art/preview/grove_preview.png       4x checkerboard preview
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Assets" / "Resources" / "Dino"
OUT = SRC / "grove.png"
PREVIEW = ROOT / "tools" / "art" / "preview" / "grove_preview.png"

W, H = 154, 158

# (sprite name, centre x, baseline y, optional scale). Back to front: the
# central tree and the side trees first, then shrubs and rosettes, then the low
# ground plants. The second tree is scaled down with nearest-neighbour so it
# reads as a smaller tree deeper in the grove.
LAYERS = [
    [
        ("tree", 64, 149, 1.0),
        ("tree", 120, 149, 0.68),
        ("palm", 20, 149, 1.0),
        ("cycad", 108, 150, 1.0),
    ],
    [
        ("bush", 40, 151, 1.0),
        ("cycad", 86, 152, 1.0),
        ("fern", 58, 153, 1.0),
        ("fern_frond", 116, 153, 1.0),
    ],
    [
        ("horsetail", 26, 154, 1.0),
        ("crown", 10, 154, 1.0),
        ("horsetail_cone", 100, 155, 1.0),
        ("flower", 142, 155, 1.0),
        ("clubmoss_small", 44, 155, 1.0),
        ("clubmoss_small", 74, 155, 1.0),
        ("crown_small", 92, 155, 1.0),
    ],
]

# Rock bed along the front edge, in the same palette as DinoPixelArt.Rock().
ROCKS = [
    (10, 153, 18, 9),
    (26, 155, 14, 7),
    (44, 153, 24, 11),
    (64, 155, 16, 8),
    (84, 153, 20, 10),
    (104, 155, 18, 8),
    (124, 153, 22, 10),
    (141, 155, 14, 7),
]

ROCK_OUTLINE = (46, 50, 52, 255)
ROCK_DARK = (91, 98, 101, 255)
ROCK_MID = (126, 135, 138, 255)
ROCK_LIGHT = (170, 179, 180, 255)


def load(name: str, scale: float = 1.0) -> Image.Image:
    sprite = Image.open(SRC / f"{name}.png").convert("RGBA")
    if scale != 1.0:
        sprite = sprite.resize(
            (max(1, round(sprite.width * scale)),
             max(1, round(sprite.height * scale))),
            Image.NEAREST,
        )
    return sprite


def put(canvas: Image.Image, sprite: Image.Image, cx: float, base_y: float) -> None:
    """Alpha-composite a sprite with its bottom-centre at (cx, base_y)."""
    x = round(cx - sprite.width / 2)
    y = round(base_y - sprite.height)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(sprite, (x, y), sprite)
    canvas.alpha_composite(layer)


def draw_rock(layer: Image.Image, cx: int, cy: int, w: int, h: int) -> None:
    """A chunky pixel rock: dark outline, shaded body, one highlight."""
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], fill=ROCK_OUTLINE)
    d.ellipse([cx - w / 2 + 1, cy - h / 2 + 1, cx + w / 2 - 1, cy + h / 2 - 1],
              fill=ROCK_DARK)
    d.ellipse([cx - w * .22, cy - h * .16, cx + w * .18, cy + h * .20],
              fill=ROCK_MID)
    d.ellipse([cx + w * .04, cy + h * .02, cx + w * .22, cy + h * .16],
              fill=ROCK_LIGHT)


def build() -> Image.Image:
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for layer in LAYERS:
        for name, cx, base_y, scale in layer:
            put(canvas, load(name, scale), cx, base_y)

    rocks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for cx, cy, w, h in ROCKS:
        draw_rock(rocks, cx, cy, w, h)
    canvas.alpha_composite(rocks)
    return canvas


def checkerboard(w: int, h: int, cell: int = 8) -> Image.Image:
    board = Image.new("RGB", (w, h), (204, 204, 204))
    d = ImageDraw.Draw(board)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if (x // cell + y // cell) % 2 == 0:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(230, 230, 230))
    return board


def main() -> None:
    grove = build()
    grove.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} ({grove.width}x{grove.height})")

    scale = 4
    big = grove.resize((grove.width * scale, grove.height * scale), Image.NEAREST)
    board = checkerboard(big.width, big.height).convert("RGBA")
    board.alpha_composite(big)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    board.save(PREVIEW)
    print(f"wrote {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()