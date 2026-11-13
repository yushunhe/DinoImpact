#!/usr/bin/env python3
"""Split the prehistoric-plant reference sheet and pixelate each plant.

The reference is a single white-background illustration sheet. Each plant is
cut out with a small connected-component step, the stock watermark is removed
by replacing its neutral-gray pixels with nearby plant colors, then Pixel It
turns the cleaned crop into a low-resolution sprite. The final alpha mask is
taken from the cleaned silhouette, so Pixel It can work on an opaque white
background without leaving colored fringes around transparent edges.

Outputs PNGs to Assets/Art/PlantsPixelIt/ and a preview contact sheet to
tools/art/preview/plants_pixelit_sheet.png.
"""

from __future__ import annotations

import math
import os
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SOURCE = os.path.join(ROOT, "Assets", "Art", "8F8C53657EB35ED489FE464A57424287.png")
OUT_DIR = os.path.join(ROOT, "Assets", "Art", "PlantsPixelIt")
PREV_DIR = os.path.join(HERE, "preview")
PALETTE = os.path.join(ROOT, "tools", "pixelit", "palettes", "plants.json")
CONVERT = os.path.join(ROOT, "tools", "pixelit", "convert.mjs")


# Global box of the stock watermark. On the tree trunk the watermark is not
# neutral gray anymore, so all plant pixels in this band are restored from the
# nearest clean pixels above/below the band.
WATERMARK_BOX = (560, 455, 1180, 640)


# name, crop box, output width, seed inside the plant, optional split
# (split_x, keep_left). A split separates touching plants on the sheet.
SPRITES = (
    ("tree", (590, 35, 1220, 950), 156, (310, 665), None),
    ("shrub", (1015, 540, 1470, 1030), 116, (225, 410), None),
    ("fern", (35, 130, 400, 520), 82, (185, 320), None),
    ("cycad", (260, 400, 665, 965), 90, (230, 450), None),
    ("palm", (1270, 35, 1525, 540), 46, (130, 415), None),
    ("fern_frond", (1080, 235, 1370, 550), 54, (170, 185), None),
    ("horsetail", (390, 40, 610, 440), 22, (60, 330), (515, True)),
    ("horsetail_cone", (390, 40, 610, 440), 24, (155, 290), (515, False)),
    ("crown", (50, 570, 265, 960), 34, (90, 250), (232, True)),
    ("crown_small", (215, 775, 325, 965), 22, (50, 115), (250, False)),
    ("clubmoss", (610, 680, 750, 990), 24, (50, 220), (700, True)),
    ("clubmoss_small", (690, 665, 830, 970), 24, (45, 235), (710, False)),
)


def clean_crop(source: Image.Image, box, seed, split):
    """Return a watermark-free RGB crop and its binary plant silhouette."""
    x0, y0, x1, y1 = box
    crop = np.asarray(source.crop(box), dtype=np.int16)
    channel_max = crop.max(axis=2)
    channel_min = crop.min(axis=2)
    mean = crop.mean(axis=2)
    chroma = channel_max - channel_min

    # The stock watermark is neutral gray. Removing it before masking keeps
    # the watermark from joining separate plants into one component.
    watermark = (chroma <= 14) & (mean > 110) & (mean < 251)
    clean = crop.copy()
    clean[watermark] = 255

    clean_chroma = clean.max(axis=2) - clean.min(axis=2)
    clean_min = clean.min(axis=2)
    mask = ~((clean_min >= 250) & (clean_chroma <= 5))
    mask = ndi.binary_closing(mask, structure=np.ones((3, 3)), iterations=1)
    mask = ndi.binary_fill_holes(mask)

    labels, count = ndi.label(mask)
    if count == 0:
        raise RuntimeError(f"no plant found in crop {box}")

    sx, sy = seed
    sx = min(max(sx, 0), mask.shape[1] - 1)
    sy = min(max(sy, 0), mask.shape[0] - 1)
    selected = labels[sy, sx]
    if selected == 0:
        sizes = ndi.sum(mask, labels, range(1, count + 1))
        selected = int(np.argmax(sizes)) + 1
    mask = labels == selected

    if split is not None:
        split_x, keep_left = split
        local_x = min(max(split_x - x0, 0), mask.shape[1])
        if keep_left:
            mask[:, local_x:] = False
        else:
            mask[:, :local_x] = False

    band = np.zeros_like(mask)
    bx0 = max(0, WATERMARK_BOX[0] - x0)
    by0 = max(0, WATERMARK_BOX[1] - y0)
    bx1 = min(mask.shape[1], WATERMARK_BOX[2] - x0)
    by1 = min(mask.shape[0], WATERMARK_BOX[3] - y0)
    if bx0 < bx1 and by0 < by1:
        band[by0:by1, bx0:bx1] = True

    # Fill both the neutral watermark and the watermark band with the nearest
    # surviving plant color. This is important on the tree trunk and cycad
    # fronds, where the watermark crosses the plant rather than only the white.
    remove = (watermark | band) & mask
    valid = mask & ~remove
    if not valid.any():
        raise RuntimeError(f"empty plant after watermark removal in crop {box}")
    nearest = ndi.distance_transform_edt(
        ~valid, return_distances=False, return_indices=True
    )
    filled = clean[tuple(nearest)]
    filled[~mask] = 255

    ys, xs = np.where(mask)
    tight = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    rgb = filled[tight[1] : tight[3], tight[0] : tight[2]].astype(np.uint8)
    alpha = mask[tight[1] : tight[3], tight[0] : tight[2]]
    return rgb, alpha


def run_pixelit(rgb, alpha, target_width, name, workdir):
    height, width = alpha.shape
    target_height = max(1, round(height * target_width / width))

    # Pixel It's scale is a percentage. scale=50 halves the image, so a 2x
    # target-sized input gives one final sprite pixel per averaged 2x2 block.
    work_w, work_h = target_width * 2, target_height * 2
    if max(work_w, work_h) > 900:
        raise RuntimeError(f"{name}: Pixel It input exceeds 900 px ({work_w}x{work_h})")

    source_rgb = Image.fromarray(rgb, "RGB").resize(
        (work_w, work_h), Image.Resampling.LANCZOS
    )
    mask = Image.fromarray((alpha * 255).astype(np.uint8), "L").resize(
        (target_width, target_height), Image.Resampling.NEAREST
    )

    input_path = os.path.join(workdir, f"{name}_input.png")
    output_path = os.path.join(workdir, f"{name}_pixelit.png")
    source_rgb.save(input_path)
    subprocess.run(
        [
            "node",
            CONVERT,
            input_path,
            output_path,
            "--scale",
            "50",
            "--palette",
            PALETTE,
            "--palette-convert",
            "--out-width",
            str(target_width),
            "--out-height",
            str(target_height),
        ],
        cwd=ROOT,
        check=True,
    )

    result = Image.open(output_path).convert("RGBA")
    if result.size != mask.size:
        mask = mask.resize(result.size, Image.Resampling.NEAREST)
    result.putalpha(mask)

    # Pixel It may average the outermost pixels with the white backdrop. Keep
    # the silhouette intact and replace those fringe pixels with the nearest
    # opaque plant color instead of punching holes in thin tips.
    pixels = np.asarray(result).copy()
    rgb_px = pixels[:, :, :3]
    opaque = pixels[:, :, 3] > 0
    white = opaque & (rgb_px.min(axis=2) >= 248) & (
        rgb_px.max(axis=2) - rgb_px.min(axis=2) <= 5
    )
    valid = opaque & ~white
    if white.any() and valid.any():
        nearest = ndi.distance_transform_edt(
            ~valid, return_distances=False, return_indices=True
        )
        filled = pixels[nearest[0], nearest[1]]
        pixels[white, :3] = filled[white, :3]
    result = Image.fromarray(pixels, "RGBA")
    result = result.crop(result.getbbox())
    return result


def checkerboard(size, cell=16):
    bg = Image.new("RGBA", size, (238, 238, 238, 255))
    draw = ImageDraw.Draw(bg)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(214, 214, 214, 255))
    return bg


def make_sheet(images, path, scale=3):
    pad = 10
    label_h = 18
    cols = 4
    widths = []
    heights = []
    for _, image in images:
        widths.append(image.width * scale + pad * 2)
        heights.append(image.height * scale + pad * 2 + label_h)
    rows = math.ceil(len(images) / cols)
    col_w = max(widths)
    row_h = max(heights)
    sheet = checkerboard((cols * col_w, rows * row_h), cell=12)
    draw = ImageDraw.Draw(sheet)
    for i, (name, image) in enumerate(images):
        cx = (i % cols) * col_w
        cy = (i // cols) * row_h
        big = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
        cell = checkerboard(big.size, cell=12)
        cell.alpha_composite(big)
        x = cx + (col_w - cell.width) // 2
        y = cy + label_h
        sheet.alpha_composite(cell, (x, y))
        draw.text((cx + pad, cy + 3), f"{name}  {image.width}x{image.height}", fill=(20, 20, 20, 255))
    sheet.save(path)


def write_readme(images):
    lines = [
        "史前植物参考图切分像素素材",
        "",
        "来源：Assets/Art/8F8C53657EB35ED489FE464A57424287.png",
        "生成：python3 tools/art/make_plants_pixelit.py",
        "像素化：tools/pixelit/convert.mjs（Pixel It，scale 50 + 植物调色板）",
        "处理：逐株切分、清除白底与参考图水印、最近色量化、透明背景。",
        "",
        "Unity 导入：Texture Type = Sprite，Filter Mode = Point，Compression = None，",
        "Pixels Per Unit = 22，Pivot = Bottom Center (0.5, 0)。",
        "底部为地面接触边；大平原上建议只作装饰，不要给树和灌木加伤害判定。",
        "",
        "文件：",
    ]
    for name, image in images:
        lines.append(f"  {name}.png  {image.width}x{image.height}")
    lines += [
        "",
        "预览：tools/art/preview/plants_pixelit_sheet.png",
        "调色板：tools/pixelit/palettes/plants.json",
        "",
    ]
    with open(os.path.join(OUT_DIR, "README.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def update_meta_settings(images):
    """Keep Unity's generated .meta files in the project's pixel-art setup."""
    replacements = (
        ("filterMode: 1", "filterMode: 0"),
        ("spriteMeshType: 1", "spriteMeshType: 0"),
        ("alignment: 0", "alignment: 7"),
        ("spritePivot: {x: 0.5, y: 0.5}", "spritePivot: {x: 0.5, y: 0}"),
        ("spritePixelsToUnits: 100", "spritePixelsToUnits: 22"),
        ("spriteGenerateFallbackPhysicsShape: 1", "spriteGenerateFallbackPhysicsShape: 0"),
        ("textureCompression: 1", "textureCompression: 0"),
        ("cookieLightType: 0", "cookieLightType: 1"),
    )
    for name, _ in images:
        meta = os.path.join(OUT_DIR, f"{name}.png.meta")
        if not os.path.exists(meta):
            continue
        with open(meta, encoding="utf-8") as f:
            text = f.read()
        for old, new in replacements:
            text = text.replace(old, new)
        with open(meta, "w", encoding="utf-8") as f:
            f.write(text)


def main():
    source = Image.open(SOURCE).convert("RGB")
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREV_DIR, exist_ok=True)
    results = []

    with tempfile.TemporaryDirectory(prefix="plants-pixelit-") as workdir:
        for name, box, width, seed, split in SPRITES:
            rgb, alpha = clean_crop(source, box, seed, split)
            result = run_pixelit(rgb, alpha, width, name, workdir)
            path = os.path.join(OUT_DIR, f"{name}.png")
            result.save(path, optimize=True)
            results.append((name, result))
            print(f"{name}: {result.width}x{result.height}")

    write_readme(results)
    update_meta_settings(results)
    make_sheet(results, os.path.join(PREV_DIR, "plants_pixelit_sheet.png"))
    print(f"sheet: {os.path.join(PREV_DIR, 'plants_pixelit_sheet.png')}")


if __name__ == "__main__":
    main()
