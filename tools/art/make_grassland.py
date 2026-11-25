#!/usr/bin/env python3
"""Bake the four grassland textures into one seamless, world-scale pixel field."""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SIZE = 1024
# Cool damp moss through to tawny grass. All four stay below the value of pickups.
BASE = np.array([(63, 100, 64), (72, 111, 57), (90, 119, 55), (116, 126, 62)])
# Dots are transparent. s = shade, m = midtone, h = blade catching light.
MOTIFS = (
    # Moss forms low, rounded cushions.
    (("..mmm.....", ".mhhmm.mm.", "mmmmsmmhm.", ".sss.mmms.", "......ss.."),
     ("..hmm...", ".mmss.hm", ".....mms")),
    # A few upright blades sit in the quieter meadow.
    (("....h..", ".m..h..", "..m.m.h", "...msh.", "...ss.."),
     ("...h.", ".m.m.", "..ms.")),
    # Wind lays broken, almost parallel strokes across the grass.
    ((".........hh...", ".......hmm....", "...hh.mm...hm.", ".hmm.mm..mmm..", ".ss....sss...."),
     (".......hh", "....hmm..", "..mm.....", ".s...mm..")),
    # A forked dry stalk with two short seed heads.
    ((".....hh..", ".....hm..", ".hm.m....", "..mm..hm.", "...mmm...", "..ss....."),
     ("hh....", ".mm..h", "..mhh.", "...s..")),
)


def noise(rng, columns, rows):
    """Value noise on a torus. All frequencies meet at the outer texture edges."""
    grid = rng.uniform(-1, 1, (rows, columns))
    x = np.arange(SIZE)[None, :] * columns / SIZE
    y = np.arange(SIZE)[:, None] * rows / SIZE
    ix, iy = x.astype(int), y.astype(int)
    fx, fy = x - ix, y - iy
    fx *= fx * (3 - 2 * fx)
    fy *= fy * (3 - 2 * fy)
    nx, ny = (ix + 1) % columns, (iy + 1) % rows
    top = grid[iy, ix] * (1 - fx) + grid[iy, nx] * fx
    bottom = grid[ny, ix] * (1 - fx) + grid[ny, nx] * fx
    return top * (1 - fy) + bottom * fy


def grassland():
    rng = np.random.default_rng(48271)
    climate = noise(rng, 5, 6) + .48 * noise(rng, 12, 11) + .18 * noise(rng, 37, 31)
    # Blend over irregular contours; the same field selects the foreground marks.
    centers = np.quantile(climate, [.10, .36, .64, .91])
    blend = np.round(np.interp(climate, centers, np.arange(4)) * 5) / 5
    styles = np.rint(blend).astype(int)
    tone = .55 * noise(rng, 14, 18) + .30 * noise(rng, 48, 62) + .15 * noise(rng, 126, 132)
    steps = np.rint(4 * tone)
    colors = np.stack([np.interp(blend, np.arange(4), ramp) for ramp in BASE.T], axis=-1)
    pixels = (colors + steps[:, :, None] * [3, 3, 2]).astype(np.uint8)

    # Uneven clusters leave open ground between patches. Wrap every brush pixel,
    # including highlights, so an entire clump can straddle a repeat boundary.
    offsets = {'s': (-13, -13, -7), 'm': (-5, -6, -3), 'h': (13, 12, 5)}
    for _ in range(2100):
        cx, cy = rng.integers(SIZE, size=2)
        for _ in range(rng.integers(2, 7)):
            x, y = (np.array([cx, cy]) + rng.normal(0, 11, size=2).astype(int)) % SIZE
            style = styles[y, x]
            motif = MOTIFS[style][rng.integers(2)]
            direction = 1 if style == 2 else rng.choice((-1, 1))
            strength = rng.uniform(.48, 1.08)
            palette = {k: np.clip(colors[y, x] + steps[y, x] * np.array([3, 3, 2])
                                  + np.array(rgb) * strength, 0, 255).astype(np.uint8)
                       for k, rgb in offsets.items()}
            for dy, row in enumerate(motif):
                for dx, value in enumerate(row):
                    if value != '.':
                        pixels[(y + dy) % SIZE, (x + direction * dx) % SIZE] = palette[value]
    return Image.fromarray(pixels)


if __name__ == '__main__':
    grassland().save(ROOT / 'Assets/Resources/Dino/ground_grass.png', optimize=True)
