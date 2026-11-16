#!/usr/bin/env python3
"""Rebuild DinoImpact's plant sprites from the Gemini reference renders.

The source JPGs are pixel-art renders with a baked checkerboard (or black)
background. This tool removes that background, trims the silhouette, normalizes
each plant to the game's 22 PPU world grid, quantizes it to a flat palette and
cleans the cutout rim, recolors any remaining white points to plant green and
caps over-bright green foliage before writing the 12 sprite names expected by
Assets/StreamingAssets/Lua/dino_world.lua.

Run from the repo root:

    python tools/art/pixelate_gemini_plants.py

Check or repair the already generated PNGs without rebuilding:

    python tools/art/pixelate_gemini_plants.py --check
    python tools/art/pixelate_gemini_plants.py --fix
"""

from __future__ import annotations

import argparse
import colorsys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Assets" / "Art" / "gemini"
DST = ROOT / "Assets" / "Resources" / "Dino"
PREVIEW = ROOT / "tools" / "art" / "preview" / "gemini_plants_sheet.png"

PPU = 22.0
MAX_COLORS = 18
WHITE_MIN = 190
WHITE_MAX_CHROMA = 40
FALLBACK_GREEN = np.array([62, 110, 48], dtype=np.int16)

# Light green leaf highlights read as white dots against the dark grass at the
# game's small scale. Cap only the green foliage; tree trunks, the yellow palm,
# flowers and fruit keep their own colours.
GREEN_PLANTS = {"tree", "bush", "cycad", "fern", "fern_frond", "horsetail"}
GREEN_VALUE_CAP = 0.55
GREEN_MIN_SATURATION = 0.58

# sprite name -> (source stem, optional crop box, world height in units)
# The source folder has seven plants. The extra sprite names are derived from
# those plants so the existing world generator keeps working unchanged:
#   fern / fern_frond       <- the upper cycad frond fan
#   flower / clubmoss_small <- the clubmoss flower spike
#   horsetail_cone          <- the top of the horsetail
#   crown_small             <- the crown flower head
PLANTS = {
    "tree":           ("tree", None, 6.5),
    "palm":           ("palm", None, 3.2),
    "bush":           ("shrub", None, 2.0),
    "cycad":          ("cycad", None, 2.4),
    "fern":           ("cycad", (0, 0, 896, 720), 1.8),
    "fern_frond":     ("cycad", (0, 170, 430, 700), 1.3),
    "flower":         ("clubmoss", (0, 0, 496, 760), 1.2),
    "clubmoss_small": ("clubmoss", (0, 0, 496, 760), 0.9),
    "horsetail":      ("horsetail", None, 1.8),
    "horsetail_cone": ("horsetail", (300, 0, 592, 560), 1.4),
    "crown":          ("crown", None, 1.3),
    "crown_small":    ("crown", (0, 0, 688, 1050), 0.9),
}


def _remove_background(image: Image.Image, stem: str) -> Image.Image:
    """Turn the checkerboard/black JPG backdrop into hard alpha."""
    rgb = np.asarray(image.convert("RGB")).astype(np.int16)
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    chroma = maximum - minimum
    luminance = rgb.mean(axis=2)

    if stem == "tree":
        background = (luminance <= 22) & (chroma <= 10)
    else:
        background = (chroma <= 14) & (luminance >= 135)

    mask = Image.fromarray(((~background) * 255).astype(np.uint8), "L")
    # Drop JPG speckle, then erode one source pixel so the blend ring between
    # the plant and the backdrop does not survive downscaling as a halo.
    mask = mask.filter(ImageFilter.MedianFilter(3))
    mask = mask.filter(ImageFilter.MinFilter(3))
    alpha = np.asarray(mask)
    rgba = np.dstack([rgb.astype(np.uint8), alpha])
    return Image.fromarray(rgba, "RGBA")


def _clean_rim(image: Image.Image) -> Image.Image:
    """Replace bright/dark neutral cutout pixels with nearby plant colors."""
    pixels = np.asarray(image.convert("RGBA")).copy()
    opaque = pixels[:, :, 3] > 0
    if not opaque.any():
        return image

    neighbour_transparent = np.zeros_like(opaque)
    neighbour_transparent[1:, :] |= ~opaque[:-1, :]
    neighbour_transparent[:-1, :] |= ~opaque[1:, :]
    neighbour_transparent[:, 1:] |= ~opaque[:, :-1]
    neighbour_transparent[:, :-1] |= ~opaque[:, 1:]
    rim = opaque & neighbour_transparent

    rgb = pixels[:, :, :3].astype(np.int16)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    luminance = rgb.mean(axis=2)
    bad = rim & (((chroma <= 50) & (luminance >= 185)) |
                 ((chroma <= 18) & (luminance <= 55)))
    if not bad.any():
        return image

    good = opaque & ~bad
    owner = np.full_like(rgb, -1)
    queue: deque[tuple[int, int]] = deque()
    for y, x in zip(*np.where(good)):
        owner[y, x] = rgb[y, x]
        queue.append((y, x))

    height, width = opaque.shape
    neighbours = ((-1, -1), (-1, 0), (-1, 1), (0, -1),
                  (0, 1), (1, -1), (1, 0), (1, 1))
    while queue:
        y, x = queue.popleft()
        colour = owner[y, x]
        for dy, dx in neighbours:
            ny, nx = y + dy, x + dx
            if (0 <= ny < height and 0 <= nx < width and
                    bad[ny, nx] and owner[ny, nx, 0] < 0):
                owner[ny, nx] = colour
                queue.append((ny, nx))

    # A few isolated JPG specks are not connected to the main silhouette.
    # Fill them from the globally nearest clean plant pixel.
    missing = bad & (owner[:, :, 0] < 0)
    if missing.any() and good.any():
        seed_coords = np.argwhere(good)
        for y, x in np.argwhere(missing):
            distances = ((seed_coords[:, 0] - y) ** 2 +
                         (seed_coords[:, 1] - x) ** 2)
            nearest = seed_coords[int(np.argmin(distances))]
            owner[y, x] = rgb[nearest[0], nearest[1]]

    filled = bad & (owner[:, :, 0] >= 0)
    pixels[:, :, :3][filled] = owner[filled].astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def _white_mask(pixels: np.ndarray) -> np.ndarray:
    """Return opaque white/near-white pixels (not transparent background)."""
    rgb = pixels[:, :, :3].astype(np.int16)
    opaque = pixels[:, :, 3] > 0
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    return opaque & (rgb.min(axis=2) >= WHITE_MIN) & (chroma <= WHITE_MAX_CHROMA)


def _recolor_white_points(image: Image.Image) -> tuple[Image.Image, int]:
    """Turn every opaque white point into the nearest plant green.

    White fringes are usually leftovers from the source checkerboard or JPG
    antialiasing. Matching the nearest green pixel keeps the shading of the
    surrounding leaf; a flat leaf green is used if the sprite has no green.
    """
    pixels = np.asarray(image.convert("RGBA")).copy()
    white = _white_mask(pixels)
    count = int(white.sum())
    if count == 0:
        return image, 0

    rgb = pixels[:, :, :3].astype(np.int16)
    opaque = pixels[:, :, 3] > 0
    green = opaque & ~white & (
        (rgb[:, :, 1] >= rgb[:, :, 0] + 10) &
        (rgb[:, :, 1] >= rgb[:, :, 2] + 10)
    )

    if green.any():
        seed_coords = np.argwhere(green)
        for y, x in np.argwhere(white):
            distances = ((seed_coords[:, 0] - y) ** 2 +
                         (seed_coords[:, 1] - x) ** 2)
            nearest = seed_coords[int(np.argmin(distances))]
            rgb[y, x] = rgb[nearest[0], nearest[1]]
    else:
        rgb[white] = FALLBACK_GREEN

    pixels[:, :, :3] = rgb.astype(np.uint8)
    return Image.fromarray(pixels, "RGBA"), count


def _tame_green_highlights(image: Image.Image, name: str) -> tuple[Image.Image, int]:
    """Clamp over-bright green foliage so it cannot read as white speckles."""
    if name not in GREEN_PLANTS:
        return image, 0

    pixels = np.asarray(image.convert("RGBA")).copy()
    rgb = pixels[:, :, :3]
    changed = 0
    for y, x in np.argwhere(pixels[:, :, 3] > 0):
        r, g, b = (float(rgb[y, x, 0]) / 255.0,
                   float(rgb[y, x, 1]) / 255.0,
                   float(rgb[y, x, 2]) / 255.0)
        hue, saturation, value = colorsys.rgb_to_hsv(r, g, b)
        hue_deg = hue * 360.0
        if saturation <= 0.18:
            hue_deg = 105.0
        elif not 50.0 <= hue_deg <= 180.0:
            continue
        if value <= GREEN_VALUE_CAP and saturation >= GREEN_MIN_SATURATION:
            continue
        new_h, new_s, new_v = colorsys.hsv_to_rgb(
            hue_deg / 360.0,
            max(saturation, GREEN_MIN_SATURATION),
            min(value, GREEN_VALUE_CAP),
        )
        rgb[y, x] = [
            round(new_h * 255),
            round(new_s * 255),
            round(new_v * 255),
        ]
        changed += 1

    return Image.fromarray(pixels, "RGBA"), changed


def _downscale(image: Image.Image, height: int) -> Image.Image:
    """Premultiplied resize -> flat palette -> hard alpha -> rim cleanup."""
    bounds = image.getbbox()
    if bounds:
        image = image.crop(bounds)

    width = max(2, round(image.width * height / image.height))
    rgba = np.asarray(image).astype(np.float32) / 255.0
    alpha = rgba[:, :, 3:4]
    premultiplied = np.concatenate([rgba[:, :, :3] * alpha, alpha], axis=2)
    resized = np.asarray(
        Image.fromarray((premultiplied * 255).round().astype(np.uint8), "RGBA")
        .resize((width, height), Image.Resampling.LANCZOS)
    ).astype(np.float32) / 255.0

    resized_alpha = resized[:, :, 3:4]
    resized_rgb = np.clip(
        (resized[:, :, :3] / np.maximum(resized_alpha, 1e-6)) * 255.0,
        0, 255,
    ).astype(np.uint8)
    hard_alpha = np.where(
        resized_alpha[:, :, 0] >= 0.5, 255, 0
    ).astype(np.uint8)

    palette = Image.fromarray(resized_rgb, "RGB").quantize(
        colors=MAX_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    result = palette.convert("RGB").convert("RGBA")
    result.putalpha(Image.fromarray(hard_alpha, "L"))
    if result.getbbox():
        result = result.crop(result.getbbox())
    return _clean_rim(result)


def _make_sprite(
    name: str, stem: str, crop, units: float
) -> tuple[Image.Image, int, int]:
    image = Image.open(SRC / f"{stem}.jpg").convert("RGB")
    if crop:
        image = image.crop(crop)
    image = _remove_background(image, stem)
    out = _downscale(image, max(2, round(units * PPU)))
    out, green_count = _tame_green_highlights(out, name)
    out, white_count = _recolor_white_points(out)
    out.save(DST / f"{name}.png")
    return out, white_count, green_count


def _checkerboard(size: tuple[int, int], cell: int = 8) -> Image.Image:
    board = Image.new("RGBA", size, (238, 238, 238, 255))
    draw = ImageDraw.Draw(board)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle(
                    (x, y, x + cell - 1, y + cell - 1),
                    fill=(214, 214, 214, 255),
                )
    return board


def _write_preview(images: list[tuple[str, Image.Image]]) -> None:
    scale = 4
    pad = 14
    label_height = 22
    columns = 4
    cell_width = max(image.width * scale for _, image in images) + pad * 2
    cell_height = max(image.height * scale for _, image in images) + pad * 2 + label_height
    rows = (len(images) + columns - 1) // columns
    sheet = _checkerboard((columns * cell_width, rows * cell_height), cell=10)
    draw = ImageDraw.Draw(sheet)

    for index, (name, image) in enumerate(images):
        cell_x = (index % columns) * cell_width
        cell_y = (index // columns) * cell_height
        big = image.resize(
            (image.width * scale, image.height * scale),
            Image.Resampling.NEAREST,
        )
        board = _checkerboard(big.size, cell=10)
        board.alpha_composite(big)
        sheet.alpha_composite(
            board,
            (
                cell_x + (cell_width - big.width) // 2,
                cell_y + label_height + (cell_height - label_height - big.height) // 2,
            ),
        )
        draw.text(
            (cell_x + pad, cell_y + 4),
            f"{name} {image.width}x{image.height}",
            fill=(20, 20, 20, 255),
        )

    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW)


def _check_existing() -> int:
    """Report any white points in the generated plant sprites."""
    failures = 0
    for name in PLANTS:
        path = DST / f"{name}.png"
        if not path.exists():
            print(f"{name:16s} MISSING")
            failures += 1
            continue
        pixels = np.asarray(Image.open(path).convert("RGBA"))
        count = int(_white_mask(pixels).sum())
        if name in GREEN_PLANTS:
            rgb = pixels[:, :, :3].astype(float) / 255.0
            maximum = rgb.max(axis=2)
            minimum = rgb.min(axis=2)
            saturation = np.where(
                maximum > 1e-6,
                (maximum - minimum) / np.maximum(maximum, 1e-6),
                0,
            )
            value = maximum
            red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
            delta = maximum - minimum
            hue = np.zeros_like(maximum)
            nonzero = delta > 1e-6
            mask = (maximum == red) & nonzero
            hue[mask] = ((green - blue)[mask] / delta[mask]) % 6
            mask = (maximum == green) & nonzero
            hue[mask] = ((blue - red)[mask] / delta[mask] + 2)
            mask = (maximum == blue) & nonzero
            hue[mask] = ((red - green)[mask] / delta[mask] + 4)
            hue *= 60
            light_green = (
                (pixels[:, :, 3] > 0) &
                (value >= 0.65) &
                (
                    (saturation <= 0.18) |
                    ((hue >= 50) & (hue <= 180) & (saturation <= 0.45))
                )
            )
            count = max(count, int(light_green.sum()))
        print(f"{name:16s} white_points={count}")
        if count:
            failures += 1
    return 1 if failures else 0


def _fix_existing() -> int:
    """Recolor white points in the generated PNGs without rebuilding them."""
    failures = 0
    for name in PLANTS:
        path = DST / f"{name}.png"
        if not path.exists():
            print(f"{name:16s} MISSING")
            failures += 1
            continue
        image = Image.open(path).convert("RGBA")
        image, green_count = _tame_green_highlights(image, name)
        fixed, count = _recolor_white_points(image)
        if count or green_count:
            fixed.save(path)
        print(f"{name:16s} white->green={count} green-highlights={green_count}")
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check",
        action="store_true",
        help="only scan the generated PNGs for white points; do not rebuild",
    )
    mode.add_argument(
        "--fix",
        action="store_true",
        help="only recolor white points in the generated PNGs; do not rebuild",
    )
    args = parser.parse_args()
    if args.check:
        return _check_existing()
    if args.fix:
        result = _fix_existing()
        return result or _check_existing()

    DST.mkdir(parents=True, exist_ok=True)
    images: list[tuple[str, Image.Image]] = []
    for name, (stem, crop, units) in PLANTS.items():
        image, white_count, green_count = _make_sprite(name, stem, crop, units)
        images.append((name, image))
        print(f"{name:16s} {image.width:3d} x {image.height:3d}  "
              f"({image.height / PPU:.2f} units @ PPU {PPU:.0f})  "
              f"white->green={white_count}  green-highlights={green_count}")

    _write_preview(images)
    print(f"preview -> {PREVIEW.relative_to(ROOT)}")
    return _check_existing()


if __name__ == "__main__":
    raise SystemExit(main())
