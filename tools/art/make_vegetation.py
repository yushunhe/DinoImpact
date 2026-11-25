#!/usr/bin/env python3
"""Rebuild the vegetation sprites, fern beds, and groves from their atlases."""
from pathlib import Path

from PIL import Image

import make_ferns
import make_grove

ART = Path(__file__).resolve().parent
OUTPUT = make_ferns.OUTPUT
PREVIEW = ART / "preview" / "gemini_plants_sheet.png"

# The fern palette also supplies the tree, palm and understory greens.
BARK = ("4c3426", "66452e", "805336", "975e3b", "ac744a")
GOLD = ("8f7938", "a78d3f", "bb9f47", "c5ac51")
RUSSET = ("502833", "703740", "8d4b4b", "a55e57", "b57766")
RAMP = make_ferns.PALETTE + BARK

# Sprite name, native dimensions, and species-specific colors.
# Every source atlas is ordered left to right, top to bottom.
CANOPY = (
    None,  # The tree fern has its own source image.
    ("palm", (39, 70), GOLD),
    ("bush", (47, 43), ()),
    ("cycad", (46, 53), ()),
)
UNDERSTORY = (
    ("flower", (16, 26), RUSSET),
    ("clubmoss_small", (13, 20), RUSSET),
    ("horsetail", (20, 40), GOLD),
    ("horsetail_cone", (15, 31), GOLD),
    ("crown", (15, 29), GOLD),
    ("crown_small", (13, 20), GOLD),
)


def export_sprite(atlas, crop, name, dimensions, accents=()):
    palette = make_ferns.make_palette(RAMP + accents)
    sprite = make_ferns.extract(atlas, crop, dimensions, palette, brightness=1.06)
    sprite.save(OUTPUT / f"{name}.png")


def export_atlas(stem, columns, plants):
    with Image.open(ART / f"{stem}-atlas.png") as source:
        atlas = source.convert("RGBA")
    rows = len(plants) // columns
    for index, plant in enumerate(plants):
        if plant is None:
            continue
        row, column = divmod(index, columns)
        crop = (atlas.width * column // columns, atlas.height * row // rows,
                atlas.width * (column + 1) // columns, atlas.height * (row + 1) // rows)
        export_sprite(atlas, crop, *plant)


def main():
    with Image.open(ART / "tree-fern.png") as source:
        tree = source.convert("RGBA")
    export_sprite(tree, (0, 0, tree.width, tree.height), "tree", (108, 143))
    export_atlas("canopy", 2, CANOPY)
    export_atlas("understory", 3, UNDERSTORY)
    make_ferns.main()
    make_grove.main()

    names = ["tree"] + [entry[0] for entry in CANOPY + UNDERSTORY if entry is not None]
    names += ["fern", "fern_frond"]
    images = []
    for name in names:
        with Image.open(OUTPUT / f"{name}.png") as sprite:
            images.append(sprite.copy())
    make_grove.contact_sheet(images, names, cols=6).save(PREVIEW)


if __name__ == "__main__":
    main()
