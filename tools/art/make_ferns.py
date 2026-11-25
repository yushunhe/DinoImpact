#!/usr/bin/env python3
"""Export foliage sprites and four fern beds from the shared fern atlas."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ART = Path(__file__).resolve().parent
OUTPUT = ART.parents[1] / "Assets/Resources/Dino"
PALETTE = ("23432a", "33582e", "457137", "5b8540", "72964a", "88a452",
           "a4b863", "6e7744")
# Plant name, center x and y, width in pixels, angle in degrees.
BEDS = [
    [("rosette", 170, 61, 54, -16), ("fronds", 60, 89, 43, 24),
     ("rosette", 119, 106, 75, 9), ("fronds", 174, 130, 62, -35),
     ("fronds", 85, 156, 58, 36), ("rosette", 146, 184, 56, -12)],
    [("fronds", 73, 54, 51, -30), ("rosette", 95, 85, 72, 18),
     ("fronds", 55, 112, 47, 15), ("fronds", 172, 134, 50, -42),
     ("rosette", 180, 167, 69, -21), ("fronds", 132, 187, 57, 40)],
    [("rosette", 189, 61, 55, 15), ("fronds", 161, 91, 54, 24),
     ("rosette", 126, 127, 69, 22), ("fronds", 76, 151, 62, 35),
     ("rosette", 54, 182, 50, -8), ("fronds", 175, 193, 40, -13)],
    [("fronds", 147, 62, 51, -18), ("rosette", 92, 88, 69, -15),
     ("fronds", 66, 134, 61, 4), ("rosette", 107, 164, 77, 12),
     ("fronds", 156, 186, 53, 42), ("rosette", 199, 151, 49, 8)],
]


def extract(atlas, crop, size, palette, brightness=1.12):
    piece = atlas.crop(crop)
    mask = piece.getchannel("A").point(lambda alpha: 255 if alpha >= 148 else 0)
    piece.putalpha(mask)
    piece = piece.crop(mask.getbbox()).resize(size, Image.Resampling.BOX)
    cutout = piece.getchannel("A").point(lambda alpha: 255 if alpha >= 128 else 0)
    colors = ImageEnhance.Brightness(piece.convert("RGB")).enhance(brightness)
    result = colors.quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(cutout)
    return result.crop(cutout.getbbox())


def fern_bed(sprites, layout):
    bed = Image.new("RGBA", (256, 256))
    ground = ImageDraw.Draw(bed)
    for _, x, y, width, _ in layout:
        rx, ry = width * .40, width * .18
        ground.ellipse((x - rx, y - ry, x + rx, y + ry), fill=(53, 62, 34, 38))
        ground.ellipse((x - rx * .7, y - ry * .7, x + rx * .7, y + ry * .7),
                       fill=(69, 68, 40, 60))
    for species, x, y, width, angle in layout:
        spr = sprites[species]
        spr = spr.resize((width, round(spr.height * width / spr.width)), Image.Resampling.NEAREST)
        if angle < 0:
            spr = spr.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        # Small variations in lean keep all the crowns rooted in the same ground plane.
        spr = spr.rotate(angle * .16, resample=Image.Resampling.NEAREST, expand=True)
        bed.alpha_composite(spr, (x - spr.width // 2, y - spr.height // 2))
    return bed


def make_palette(colors):
    palette = Image.new("P", (1, 1))
    ramp = bytes.fromhex("".join(colors))
    palette.putpalette(ramp + ramp[:3] * (256 - len(colors)))
    return palette


def main():
    palette = make_palette(PALETTE)
    with Image.open(ART / "low-fern-redraw.png") as source:
        source = source.convert("RGBA")
        crop = source.getchannel("A").point(lambda a: 255 if a >= 148 else 0).getbbox()
        width, height = crop[2] - crop[0], crop[3] - crop[1]
        fern = extract(source, crop, (80, round(80 * height / width)), palette, brightness=1.10)
    # Keep each sprite's original registration height for the ground-level pivot.
    for name, width, height in [("fern", 62, 48), ("fern_frond", 36, 36)]:
        plant = fern.resize((width, round(width * fern.height / fern.width)), Image.Resampling.NEAREST)
        if name == "fern_frond":
            plant = plant.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        framed = Image.new("RGBA", (width, height))
        framed.alpha_composite(plant, (0, height - plant.height))
        framed.save(OUTPUT / f"{name}.png")
    sprites = {"rosette": fern, "fronds": fern.transpose(Image.Transpose.FLIP_LEFT_RIGHT)}
    for index, layout in enumerate(BEDS):
        fern_bed(sprites, layout).save(OUTPUT / f"terrain_fern_{index}.png")


if __name__ == "__main__":
    main()
