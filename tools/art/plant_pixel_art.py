"""Deterministic cleanup for the PlantsPixelIt sprites.

The reference sheet has an antialiased white silhouette.  Pixel It turns that
antialiased rim into the lightest palette colors, which reads as a white
outline in game.  These helpers replace the rim with the nearest real plant
color and downscale with premultiplied alpha so transparency cannot bleed
back into the sprite.
"""

from __future__ import annotations

from collections import deque

import numpy as np
from PIL import Image, ImageFilter


# The two light colors that form the cutout rim in the source palette.
RIM_COLORS = np.array(
    [
        [230, 228, 184],
        [215, 190, 170],
    ],
    dtype=np.int16,
)


def _alpha_band(alpha: Image.Image, rings: int = 2) -> tuple[np.ndarray, np.ndarray]:
    """Return the opaque mask and its outermost `rings` pixel bands."""
    opaque_image = alpha.point(lambda value: 255 if value > 0 else 0)
    opaque = np.asarray(opaque_image) > 0
    band = np.zeros_like(opaque)
    current = opaque_image

    for _ in range(rings):
        eroded = current.filter(ImageFilter.MinFilter(3))
        eroded_mask = np.asarray(eroded) > 0
        band |= (np.asarray(current) > 0) & ~eroded_mask
        current = eroded

    return opaque, band


def _fill_from_nearest_plant_color(
    rgb: np.ndarray,
    opaque: np.ndarray,
    replace: np.ndarray,
    seed_block: np.ndarray | None = None,
) -> np.ndarray:
    """Replace marked pixels with the nearest unmarked opaque pixel color."""
    replace = replace & opaque
    seeds = opaque & ~replace
    if seed_block is not None:
        seeds &= ~seed_block
    if not replace.any() or not seeds.any():
        return rgb

    height, width = opaque.shape
    owner = np.full((height, width, 3), -1, dtype=np.int16)
    queue: deque[tuple[int, int]] = deque()

    for y, x in zip(*np.where(seeds)):
        owner[y, x] = rgb[y, x]
        queue.append((y, x))

    neighbours = (
        (-1, -1),
        (-1, 0),
        (-1, 1),
        (0, -1),
        (0, 1),
        (1, -1),
        (1, 0),
        (1, 1),
    )

    while queue:
        y, x = queue.popleft()
        color = owner[y, x]
        for dy, dx in neighbours:
            ny, nx = y + dy, x + dx
            if (
                0 <= ny < height
                and 0 <= nx < width
                and opaque[ny, nx]
                and owner[ny, nx, 0] < 0
            ):
                owner[ny, nx] = color
                queue.append((ny, nx))

    result = rgb.copy()
    filled = replace & (owner[:, :, 0] >= 0)
    result[filled] = owner[filled]

    # Rare disconnected specks cannot be reached by the connected BFS.  Fill
    # them from the globally nearest seed so no bright rim pixel survives.
    missing = replace & ~filled
    if missing.any():
        seed_coords = np.argwhere(seeds)
        for y, x in np.argwhere(missing):
            distances = ((seed_coords[:, 0] - y) ** 2 + (seed_coords[:, 1] - x) ** 2)
            nearest = seed_coords[int(np.argmin(distances))]
            result[y, x] = rgb[nearest[0], nearest[1]]
    return result


def clean_light_fringe(image: Image.Image, rings: int = 2) -> Image.Image:
    """Remove the light antialias rim while preserving the pixel silhouette."""
    rgba = image.convert("RGBA")
    arr = np.asarray(rgba).copy()
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = Image.fromarray(arr[:, :, 3], "L")

    opaque, band = _alpha_band(alpha, rings)
    exact_rim = np.zeros(opaque.shape, dtype=bool)
    for color in RIM_COLORS:
        exact_rim |= np.all(rgb == color, axis=2)

    minimum = rgb.min(axis=2)
    maximum = rgb.max(axis=2)
    luminance = rgb.mean(axis=2)
    chroma = maximum - minimum
    bright_rim = (luminance >= 187) & (chroma <= 50)

    rim = band & (exact_rim | bright_rim)
    arr[:, :, :3] = _fill_from_nearest_plant_color(
        rgb,
        opaque,
        rim,
        seed_block=exact_rim | bright_rim,
    ).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def outer_rim_count(image: Image.Image, rings: int = 2) -> int:
    """Count bright, desaturated pixels in the outer rim for validation."""
    rgba = image.convert("RGBA")
    arr = np.asarray(rgba)
    opaque, band = _alpha_band(rgba.getchannel("A"), rings)
    rgb = arr[:, :, :3].astype(np.int16)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    luminance = rgb.mean(axis=2)
    bright = (luminance >= 187) & (chroma <= 50)
    return int((opaque & band & bright).sum())


def downscale_pixel_art(
    image: Image.Image,
    size: tuple[int, int],
    max_colors: int = 14,
) -> Image.Image:
    """Clean, premultiply, downscale, quantize and clean once more."""
    source = clean_light_fringe(image)
    source = source.convert("RGBA")

    # Resize premultiplied color so transparent pixels cannot bleed white into
    # the silhouette, then unpremultiply before palette quantization.
    arr = np.asarray(source).astype(np.float32) / 255.0
    alpha = arr[:, :, 3:4]
    premultiplied = np.concatenate(
        [arr[:, :, :3] * alpha, alpha],
        axis=2,
    )
    resized = np.asarray(
        Image.fromarray((premultiplied * 255.0).round().astype(np.uint8), "RGBA")
        .resize(size, Image.Resampling.LANCZOS)
    ).astype(np.float32) / 255.0

    resized_alpha = resized[:, :, 3:4]
    resized_rgb = resized[:, :, :3] / np.maximum(resized_alpha, 1e-6)
    resized_rgb = np.clip(resized_rgb * 255.0, 0, 255).astype(np.uint8)
    hard_alpha = np.where(resized_alpha[:, :, 0] >= 0.5, 255, 0).astype(np.uint8)

    palette = Image.fromarray(resized_rgb, "RGB").quantize(
        colors=max_colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    result = palette.convert("RGB").convert("RGBA")
    result.putalpha(Image.fromarray(hard_alpha, "L"))
    result = clean_light_fringe(result)
    return result.crop(result.getbbox() or (0, 0, *size))
