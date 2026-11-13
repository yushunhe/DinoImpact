#!/usr/bin/env python3
"""Original pixel-art prehistoric plants for DINO IMPACT.

Shapes are inspired by a Jurassic plant sheet (tree fern, fan palm, cycad,
notched fern, single frond, horsetails, scaled crown, clubmoss, shrub) but
every sprite is drawn from scratch in the same chunky pixel language as the
ornithomimus: flat colors, a one-pixel outline, no anti-aliasing.

Pixels match the dino sprites. Import at Point filter, 22 pixels per unit,
pivot at bottom center.

Outputs PNGs to Assets/Art/Plants/ and a nearest-neighbor preview to
tools/art/preview/plants_sheet.png.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "Assets", "Art", "Plants")
PREV_DIR = os.path.join(HERE, "preview")

# Same outline family as the rider sprites, so plants sit in the same set.
OUTLINE = (33, 41, 48, 255)

# trunks
BARK = (176, 104, 52, 255)
BARK_MID = (140, 76, 36, 255)
BARK_DARK = (96, 52, 26, 255)
BARK_DEEP = (64, 36, 18, 255)
BARK_HI = (206, 142, 78, 255)

# fern greens
G_DEEP = (28, 72, 32, 255)
G_DARK = (42, 104, 40, 255)
G_MID = (62, 138, 48, 255)
G_LIGHT = (104, 168, 58, 255)
G_HI = (158, 196, 78, 255)
G_PALE = (186, 206, 104, 255)

# palm yellow-greens
Y_DEEP = (96, 112, 32, 255)
Y_DARK = (132, 140, 40, 255)
Y_MID = (176, 176, 56, 255)
Y_LIGHT = (210, 204, 84, 255)
Y_HI = (232, 220, 120, 255)

# cones and scales
ORANGE = (224, 140, 42, 255)
ORANGE_DARK = (176, 96, 28, 255)
YELLOW = (228, 196, 48, 255)
YELLOW_DARK = (176, 144, 28, 255)
YELLOW_HI = (244, 224, 104, 255)
TEAL = (36, 150, 132, 255)
TEAL_DARK = (20, 104, 98, 255)
TEAL_DEEP = (14, 72, 70, 255)
TEAL_HI = (78, 186, 162, 255)
PURPLE = (176, 72, 112, 255)
PURPLE_DARK = (124, 44, 78, 255)
PURPLE_HI = (208, 116, 146, 255)
STEM_RED = (156, 52, 68, 255)
STEM_RED_DARK = (108, 32, 48, 255)

GRASS = (59, 105, 44, 255)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = bytearray(w * h * 4)

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        i = (y * self.w + x) * 4
        self.px[i:i + 4] = bytes(c)

    def get(self, x, y):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return (0, 0, 0, 0)
        i = (y * self.w + x) * 4
        return tuple(self.px[i:i + 4])

    def opaque(self, x, y):
        return self.get(x, y)[3] > 0

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y) + int(h)):
            for xx in range(int(x), int(x) + int(w)):
                self.set(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, c):
        if rx <= 0 or ry <= 0:
            return
        for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
            for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
                dx = (x + .5 - cx) / rx
                dy = (y + .5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, c)

    def line(self, x0, y0, x1, y1, thick, c):
        x0, y0 = int(round(x0)), int(round(y0))
        x1, y1 = int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        off = thick // 2
        while True:
            self.rect(x0 - off, y0 - off, thick, thick, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = err * 2
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def poly(self, pts, c):
        if len(pts) < 3:
            return
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(math.floor(min(ys)), math.ceil(max(ys)) + 1):
            for x in range(math.floor(min(xs)), math.ceil(max(xs)) + 1):
                px, py = x + .5, y + .5
                inside = False
                j = len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / ((yj - yi) or 1e-6) + xi:
                        inside = not inside
                    j = i
                if inside:
                    self.set(x, y, c)

    def image(self):
        return Image.frombytes("RGBA", (self.w, self.h), bytes(self.px))


def add_outline(art: Canvas) -> Canvas:
    out = Canvas(art.w, art.h)
    offsets = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)]
    for y in range(art.h):
        for x in range(art.w):
            if art.opaque(x, y):
                continue
            for dx, dy in offsets:
                if art.opaque(x + dx, y + dy):
                    out.set(x, y, OUTLINE)
                    break
    for y in range(art.h):
        for x in range(art.w):
            c = art.get(x, y)
            if c[3] > 0:
                out.set(x, y, c)
    return out


class Pix:
    """y grows upward. (0, 0) is the bottom-left of the canvas."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = Canvas(w, h)

    def _dy(self, y):
        return self.h - 1 - y

    def p(self, x, y, col):
        self.c.set(int(round(x)), int(round(self._dy(y))), col)

    def rect(self, x, y, w, h, col):
        # y is the bottom of the rect in y-up space
        self.c.rect(int(x), int(self._dy(y + h - 1)), int(w), int(h), col)

    def ellipse(self, cx, cy, rx, ry, col):
        self.c.ellipse(cx, self._dy(cy), rx, ry, col)

    def line(self, x0, y0, x1, y1, thick, col):
        self.c.line(x0, self._dy(y0), x1, self._dy(y1), thick, col)

    def poly(self, pts, col):
        self.c.poly([(x, self._dy(y)) for x, y in pts], col)

    def disc(self, x, y, r, col):
        self.ellipse(x, y, r, r, col)

    def finish(self, anchor_x):
        outlined = add_outline(self.c)
        im = outlined.image()
        bbox = im.getbbox()
        if bbox is None:
            return im
        left, top, right, bottom = bbox
        half = max(anchor_x - left, right - anchor_x)
        out_w = half * 2
        out_h = bottom - top
        out = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
        out.paste(im, (half - anchor_x, -top), im)
        return out


def walk(x0, y0, x1, y1):
    x0, y0 = int(round(x0)), int(round(y0))
    x1, y1 = int(round(x1)), int(round(y1))
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = err * 2
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return pts


def curl(px, x, y, dx, dy, col):
    """A 1-turn fiddlehead. dx, dy is the incoming direction (y-up)."""
    ang = math.atan2(dy, dx)
    r = 3.2
    last = None
    for i in range(8):
        a = ang + 0.55 + i * 0.62
        rr = r * (1 - i * 0.08)
        qx = int(round(x + math.cos(a) * rr))
        qy = int(round(y + math.sin(a) * rr))
        px.p(qx, qy, col)
        if last and abs(qx - last[0]) + abs(qy - last[1]) > 1:
            for sx, sy in walk(last[0], last[1], qx, qy):
                px.p(sx, sy, col)
        last = (qx, qy)
    px.p(x, y, col)


def frond(px, x0, y0, x1, y1, every, leaf, stem, dark, light, do_curl=True, width=1):
    pts = walk(x0, y0, x1, y1)
    if len(pts) < 2:
        return
    dx = x1 - x0
    dy = y1 - y0
    ln = math.hypot(dx, dy) or 1
    dx, dy = dx / ln, dy / ln
    nx, ny = -dy, dx
    for x, y in pts:
        px.p(x, y, stem)
        if width > 1:
            px.p(x + int(round(nx)), y + int(round(ny)), stem)
    step = 0
    for i, (x, y) in enumerate(pts):
        if i < 1 or i > len(pts) - 2:
            continue
        if i % every != 0:
            continue
        t = i / (len(pts) - 1)
        length = max(2, int(round(leaf * (1.05 - 0.5 * t))))
        for sign, col in ((-1, dark), (1, light)):
            for k in range(1, length + 1):
                ox = int(round(nx * sign * k + dx * k * 0.45))
                oy = int(round(ny * sign * k + dy * k * 0.45))
                px.p(x + ox, y + oy, col)
                if k < length and length >= 3:
                    px.p(x + ox + int(round(dx)), y + oy + int(round(dy)), col)
        step += 1
    if do_curl:
        tip = pts[-1]
        curl(px, tip[0], tip[1], dx, dy, light)


def tapered(px, x0, y0, x1, y1, w0, w1, col):
    pts = walk(x0, y0, x1, y1)
    n = max(1, len(pts) - 1)
    for i, (x, y) in enumerate(pts):
        w = w0 + (w1 - w0) * (i / n)
        r = max(0, int(round(w)))
        if r <= 0:
            px.p(x, y, col)
        else:
            px.disc(x, y, r, col)


def trunk(px, x, y0, y1, w, bands):
    """Upright trunk. y0 is the base, y1 the top, both y-up."""
    px.rect(x - w // 2, y0, w, y1 - y0, BARK)
    px.rect(x - w // 2, y0, 2, y1 - y0, BARK_HI)
    px.rect(x + w // 2 - 2, y0, 2, y1 - y0, BARK_DARK)
    for by in bands:
        px.rect(x - w // 2 + 1, by, w - 2, 2, BARK_DEEP)


def root(px, x0, y0, x1, y1):
    tapered(px, x0, y0, x1, y1, 1.6, 0.2, BARK_MID)
    # darker underside
    tapered(px, x0, y0 - 1, x1, y1 - 1, 0.6, 0.0, BARK_DARK)


# ---------------------------------------------------------------- plants


def make_tree():
    w, h = 88, 132
    px = Pix(w, h)
    cx = 44
    # roots first so the trunk covers the joint
    root(px, cx, 18, cx - 22, 4)
    root(px, cx - 2, 18, cx - 12, 5)
    root(px, cx, 16, cx, 3)
    root(px, cx + 2, 18, cx + 12, 5)
    root(px, cx, 18, cx + 22, 4)
    trunk(px, cx, 14, 78, 9, (26, 40, 54, 66))
    # a little flare where the crown starts
    px.rect(cx - 5, 74, 11, 6, BARK)
    px.rect(cx - 5, 74, 2, 6, BARK_HI)
    px.rect(cx + 4, 74, 2, 6, BARK_DARK)

    branches = [
        # x0, y0, x1, y1, every, leaf, curl
        (cx, 112, cx - 6, 124, 3, 3, False),
        (cx, 110, cx + 8, 124, 3, 3, True),
        (cx - 2, 104, cx - 30, 116, 3, 4, True),
        (cx + 2, 104, cx + 32, 114, 3, 4, True),
        (cx - 3, 96, cx - 36, 100, 3, 4, True),
        (cx + 3, 96, cx + 36, 98, 3, 4, False),
        (cx - 3, 88, cx - 32, 80, 3, 4, True),
        (cx + 3, 88, cx + 30, 78, 3, 3, True),
        (cx - 2, 80, cx - 22, 70, 3, 3, False),
        (cx + 2, 80, cx + 20, 68, 3, 3, True),
        (cx, 92, cx + 4, 84, 4, 2, True),
    ]
    stems = (BARK_DARK, BARK_MID, BARK_DARK)
    for i, (x0, y0, x1, y1, every, leaf, do_curl) in enumerate(branches):
        dark = G_DARK if i % 2 == 0 else G_DEEP
        light = G_LIGHT if i % 3 else G_HI
        frond(px, x0, y0, x1, y1, every, leaf, stems[i % 3], dark, light, do_curl)
    return px.finish(cx)


def palm_blade(px, ox, oy, deg, length, col):
    rad = math.radians(deg)
    dx, dy = math.sin(rad), math.cos(rad)
    nx, ny = -dy, dx
    tip = (ox + dx * length, oy + dy * length)
    mid = (ox + dx * length * 0.42, oy + dy * length * 0.42)
    w = 2.4
    px.poly([
        (ox + nx * 0.6, oy + ny * 0.6),
        (ox - nx * 0.6, oy - ny * 0.6),
        (mid[0] + nx * w, mid[1] + ny * w),
        tip,
        (mid[0] - nx * w, mid[1] - ny * w),
    ], col)
    px.p(int(round(tip[0])), int(round(tip[1])), Y_HI)


def make_palm():
    w, h = 72, 112
    px = Pix(w, h)
    cx = 36
    trunk(px, cx, 4, 58, 5, (14, 26, 38, 50))
    origin_y = 58
    # sides first, center last, so the fan overlaps like a real crown
    for i in range(15):
        t = i / 14
        deg = -108 + t * 216
        bell = 1 - abs(t - 0.5) * 2
        length = 14 + bell * 24
        col = (Y_DARK, Y_MID, Y_LIGHT, Y_HI, Y_LIGHT)[i % 5]
        palm_blade(px, cx, origin_y, deg, length, col)
    # dark petioles at the collar, on top of the blades
    px.rect(cx - 4, 56, 9, 5, BARK_DARK)
    px.rect(cx - 3, 57, 2, 4, BARK)
    for ox in (-3, -1, 1, 3):
        px.p(cx + ox, 61, Y_DEEP)
        px.p(cx + ox, 62, Y_DEEP)
    return px.finish(cx)


def make_cycad():
    w, h = 96, 88
    px = Pix(w, h)
    cx = 48
    # thick fibrous trunk
    px.ellipse(cx, 22, 13, 16, BARK_DARK)
    px.ellipse(cx - 1, 24, 11, 14, BARK)
    px.rect(cx - 8, 16, 3, 20, BARK_HI)
    px.rect(cx + 6, 14, 3, 18, BARK_DEEP)
    # vertical fiber nicks
    for fy in (12, 18, 24, 30):
        px.p(cx - 4, fy, BARK_DARK)
        px.p(cx + 1, fy + 2, BARK_DEEP)
        px.p(cx + 5, fy, BARK_DARK)
    # skirt of old leaf bases
    for i, ox in enumerate(range(-10, 11, 3)):
        px.p(cx + ox, 8, BARK_DEEP)
        px.p(cx + ox, 7, BARK_DARK)
        if i % 2 == 0:
            px.p(cx + ox, 6, BARK_DEEP)

    crown = (cx, 40)
    # radiating pinnate fronds, including a few that droop
    specs = [
        (-150, 18, 2),
        (-125, 24, 3),
        (-100, 30, 3),
        (-75, 34, 3),
        (-50, 32, 3),
        (-28, 30, 3),
        (-8, 26, 2),
        (10, 28, 3),
        (30, 32, 3),
        (52, 34, 3),
        (74, 32, 3),
        (98, 28, 3),
        (122, 22, 2),
        (148, 16, 2),
    ]
    for i, (deg, length, leaf) in enumerate(specs):
        rad = math.radians(deg)
        dx, dy = math.sin(rad), math.cos(rad)
        x1 = crown[0] + dx * length
        y1 = crown[1] + dy * length
        dark = G_DEEP if i % 2 == 0 else G_DARK
        light = G_MID if i % 3 else G_LIGHT
        frond(px, crown[0], crown[1], x1, y1, 3, leaf, G_DARK, dark, light, do_curl=False)
    return px.finish(cx)


def notched_leaf(px, x, y, hw, height, dark, mid, light, lean=0):
    """Broad blade with bites taken out of the edge so the silhouette reads."""
    for i in range(int(height)):
        t = i / max(1, height - 1)
        prof = math.sin(t * math.pi) ** 0.62
        half = int(round(hw * prof))
        shift = int(round(lean * t))
        if 2 < i < height - 3 and i % 4 == 0:
            half = max(1, half - 2)
        for dx in range(-half, half + 1):
            col = light if abs(dx) <= max(1, half // 3) else (mid if abs(dx) < half else dark)
            px.p(x + shift + dx, y + i, col)
        px.p(x + shift, y + i, light if i % 3 == 0 else mid)


def make_fern():
    w, h = 58, 46
    px = Pix(w, h)
    cx = 29
    for ox, col in ((-8, G_DARK), (-3, G_MID), (2, G_DARK), (7, G_DEEP)):
        px.rect(cx + ox, 1, 2, 7, col)
    notched_leaf(px, cx - 14, 5, 7, 26, G_DEEP, G_DARK, G_MID, lean=-3)
    notched_leaf(px, cx - 4, 6, 8, 34, G_DARK, G_MID, G_LIGHT, lean=-1)
    notched_leaf(px, cx + 8, 5, 7, 30, G_DEEP, G_MID, G_LIGHT, lean=3)
    notched_leaf(px, cx + 1, 8, 6, 24, G_DARK, G_LIGHT, G_HI, lean=0)
    curl(px, cx - 18, 9, -0.4, 0.8, G_MID)
    px.line(cx - 16, 6, cx - 20, 8, 1, G_DARK)
    return px.finish(cx)


def make_frond():
    w, h = 44, 60
    px = Pix(w, h)
    cx = 16
    # a smaller darker frond behind
    frond(px, cx + 6, 6, cx + 18, 40, 3, 4, G_DEEP, G_DEEP, G_DARK, do_curl=False)
    # main olive feather
    pts = walk(cx, 4, cx + 4, 54)
    for x, y in pts:
        px.p(x, y, Y_DEEP)
    dx, dy = 0.1, 1
    nx, ny = -1, 0.1
    for i, (x, y) in enumerate(pts):
        if i < 2 or i % 3 != 0:
            continue
        t = i / (len(pts) - 1)
        length = max(3, int(round(7 * math.sin(t * math.pi) ** 0.6)))
        for sign, col in ((-1, Y_DARK), (1, Y_MID)):
            for k in range(1, length + 1):
                ox = int(round(nx * sign * k * 0.9 + dx * k * 0.3))
                oy = int(round(ny * sign * k + dy * k * 0.15))
                px.p(x + ox, y + oy, col if k < length else Y_LIGHT)
                if k in (2, 3):
                    px.p(x + ox, y + oy - 1, Y_LIGHT if sign > 0 else Y_DARK)
        # midrib of the pinna
        px.p(x - 2, y, Y_DEEP)
        px.p(x + 2, y, Y_DEEP)
    return px.finish(cx + 2)


def horsetail_stem(px, x, y0, segments, flared=True):
    y = y0
    for i in range(segments):
        seg_h = 6 if i < segments - 1 else 5
        half = 2 if i % 2 == 0 else 1
        top = y + seg_h
        # cup: wider at the top node
        px.rect(x - half, y, half * 2 + 1, seg_h - 1, G_MID if i % 2 == 0 else G_DARK)
        px.rect(x - half - 1, top - 2, half * 2 + 3, 2, G_DEEP)
        px.p(x - half, y + 1, G_LIGHT)
        y = top
    return y


def whorl(px, x, y, col, reach=5):
    """Needles sticking out of a node, tips up. Long enough to clear the stem."""
    needles = (
        (-reach, 1), (-reach + 1, 3), (-2, reach),
        (2, reach), (reach - 1, 3), (reach, 1),
        (-3, 0), (3, 0),
    )
    for ox, oy in needles:
        px.line(x, y, x + ox, y + oy, 1, col)
        px.p(x + ox, y + oy, G_HI)


def make_horsetail():
    w, h = 36, 58
    px = Pix(w, h)
    cx = 18
    horsetail_stem(px, cx, 3, 7)
    for i, node_y in enumerate((8, 15, 22, 29, 36, 43)):
        whorl(px, cx, node_y, G_LIGHT if i % 2 == 0 else G_MID, reach=5 if i < 4 else 3)
    return px.finish(cx)


def make_horsetail_cone():
    w, h = 32, 62
    px = Pix(w, h)
    cx = 16
    top = horsetail_stem(px, cx, 3, 5)
    for node_y in (9, 16, 23):
        whorl(px, cx, node_y, G_MID, reach=4)
    px.ellipse(cx, top + 7, 3.4, 7.0, ORANGE_DARK)
    px.ellipse(cx - 0.3, top + 7.5, 2.5, 5.6, ORANGE)
    px.p(cx - 1, top + 9, (236, 186, 84, 255))
    px.p(cx, top + 5, ORANGE_DARK)
    px.p(cx + 1, top + 8, ORANGE_DARK)
    px.p(cx, top + 12, YELLOW_HI)
    return px.finish(cx)


def scale_column(px, cx, y0, y1, w0, w1, cols, palette, tip_down=True):
    rows = max(3, (y1 - y0) // 3)
    for r in range(rows):
        t = r / max(1, rows - 1)
        y = int(y0 + (y1 - y0) * t)
        w = w0 + (w1 - w0) * t
        n = cols
        for i in range(n):
            u = (i + (0.5 if r % 2 else 0.0)) / n
            x = int(round(cx - w / 2 + u * w))
            col = palette[(r + i) % len(palette)]
            hi = palette[min(len(palette) - 1, (r + i) % len(palette))]
            # overlapping downward scale
            px.p(x, y, col)
            px.p(x - 1, y + 1, col)
            px.p(x, y + 1, hi)
            px.p(x + 1, y + 1, col)
            px.p(x, y + 2, palette[0])


def make_crown(big=True):
    if big:
        w, h = 32, 48
        cx, y0, y1, hw = 16, 3, 28, 8
        cone_h = 14
    else:
        w, h = 20, 30
        cx, y0, y1, hw = 10, 2, 16, 5
        cone_h = 9
    px = Pix(w, h)
    scale_column(
        px, cx, y0, y1, hw * 2 - 2, hw * 2 + 2, 4 if big else 3,
        (TEAL_DEEP, TEAL_DARK, TEAL, TEAL_HI),
    )
    # yellow cone, slightly narrower, sitting on the teal
    scale_column(
        px, cx, y1 - 2, y1 + cone_h, hw * 2 - 2, 3,
        4 if big else 3,
        (YELLOW_DARK, YELLOW, YELLOW_HI, YELLOW),
    )
    return px.finish(cx)


def make_clubmoss(big=True):
    if big:
        w, h = 28, 44
        cx = 14
        body_top = 16
        stem_top = 26
        cone_r = (3.1, 4.2)
    else:
        w, h = 22, 34
        cx = 11
        body_top = 12
        stem_top = 20
        cone_r = (2.3, 3.2)
    px = Pix(w, h)
    # roots
    root_col = BARK_DARK
    px.line(cx, 4, cx - 8, 1, 1, root_col)
    px.line(cx, 4, cx + 7, 1, 1, root_col)
    px.line(cx - 1, 4, cx - 3, 1, 1, BARK_MID)
    px.p(cx - 8, 1, BARK_DEEP)
    px.p(cx + 7, 1, BARK_DEEP)
    scale_column(
        px, cx, 3, body_top, 4 if big else 3, 7 if big else 5, 3 if big else 2,
        (G_DEEP, G_DARK, G_MID, G_LIGHT),
    )
    # thin red stalk
    px.line(cx, body_top, cx, stem_top, 1, STEM_RED)
    px.p(cx - 1, body_top + 2, STEM_RED_DARK)
    # purple cone
    px.ellipse(cx, stem_top + 3, cone_r[0], cone_r[1], PURPLE_DARK)
    px.ellipse(cx, stem_top + 3.4, cone_r[0] - 0.8, cone_r[1] - 1.0, PURPLE)
    px.p(cx - 1, stem_top + 4, PURPLE_HI)
    px.p(cx + 1, stem_top + 2, PURPLE_DARK)
    px.p(cx, stem_top + int(cone_r[1]) + 2, PURPLE_HI)
    return px.finish(cx)


def leaflet(px, x, y, dx, dy, col, hi):
    """A 4-pixel oval pinna aimed along (dx, dy), which should be a unit step."""
    px.p(x, y, col)
    px.p(x + dx, y + dy, col)
    px.p(x + dx * 2, y + dy * 2, hi)
    px.p(x + dx + (1 if dy == 0 else 0), y + dy + (1 if dx == 0 else 0), col)


def make_shrub():
    w, h = 72, 60
    px = Pix(w, h)
    cx = 36
    # bulbous base
    px.ellipse(cx, 12, 12, 9, BARK_DARK)
    px.ellipse(cx - 1, 13, 10, 7, BARK)
    px.ellipse(cx - 3, 15, 5, 4, BARK_HI)
    px.rect(cx + 4, 8, 3, 8, BARK_DEEP)
    # fiber fringe along the bottom
    for i, ox in enumerate(range(-10, 11, 2)):
        px.p(cx + ox, 4, BARK_DEEP)
        px.p(cx + ox + (i % 2), 3, BARK_DARK)
    # arching compound stems
    stems = [
        (cx - 2, 18, cx - 28, 28, -1, 1),
        (cx - 1, 19, cx - 22, 40, -1, 1),
        (cx, 20, cx - 8, 50, -1, 1),
        (cx, 20, cx + 6, 52, 1, 1),
        (cx + 1, 19, cx + 22, 42, 1, 1),
        (cx + 2, 18, cx + 28, 30, 1, 1),
        (cx + 1, 18, cx + 16, 22, 1, 0),
        (cx - 1, 18, cx - 14, 20, -1, 0),
    ]
    for i, (x0, y0, x1, y1, side, up) in enumerate(stems):
        pts = walk(x0, y0, x1, y1)
        for x, y in pts:
            px.p(x, y, G_DEEP)
        for j, (x, y) in enumerate(pts):
            if j < 2 or j % 3 != 0:
                continue
            col = G_MID if (i + j) % 2 == 0 else G_DARK
            hi = G_LIGHT if (i + j) % 3 else G_HI
            # pair of oval leaflets
            px.p(x, y + 1, col)
            px.p(x + side, y + 1 + up, hi)
            px.p(x + side * 2, y + up, col)
            px.p(x - side, y - 1, G_DARK)
            px.p(x - side * 2, y - 1, col)
            if (i + j) % 5 == 0:
                px.p(x + side, y + 1, YELLOW_DARK)
    return px.finish(cx)


PLANTS = [
    ("tree", make_tree, "树蕨，卷曲嫩芽和板根。可替换 tree"),
    ("palm", make_palm, "扇叶树。新装饰"),
    ("cycad", make_cycad, "放射叶苏铁。新装饰"),
    ("fern", make_fern, "缺刻阔叶蕨丛。可替换 fern"),
    ("fern_frond", make_frond, "单片羽状蕨叶。新装饰"),
    ("horsetail", make_horsetail, "轮叶节茎。新装饰"),
    ("horsetail_cone", make_horsetail_cone, "带橙色孢子囊的节茎。新装饰"),
    ("crown", lambda: make_crown(True), "黄冠鳞叶植物。新装饰"),
    ("crown_small", lambda: make_crown(False), "小号黄冠。新装饰"),
    ("clubmoss", lambda: make_clubmoss(True), "紫穗石松。可替换 flower"),
    ("clubmoss_small", lambda: make_clubmoss(False), "小号石松。新装饰"),
    ("shrub", make_shrub, "复叶灌木。可替换 bush"),
]


def preview(sprites):
    scale = 4
    pad = 10
    label_h = 16
    cell_w = max(im.width for im in sprites.values()) * scale + pad * 2
    cell_h = max(im.height for im in sprites.values()) * scale + pad * 2 + label_h
    cols = 4
    rows = math.ceil(len(PLANTS) / cols)
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), GRASS[:3])
    draw = ImageDraw.Draw(sheet)
    for i, (name, _, _) in enumerate(PLANTS):
        im = sprites[name]
        big = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
        col, row = i % cols, i // cols
        x = col * cell_w + (cell_w - big.width) // 2
        y = row * cell_h + pad + label_h
        sheet.paste(big, (x, y), big)
        draw.text((col * cell_w + 6, row * cell_h + 3), name, fill=(244, 236, 210))
    os.makedirs(PREV_DIR, exist_ok=True)
    path = os.path.join(PREV_DIR, "plants_sheet.png")
    sheet.save(path)
    return path


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sprites = {}
    notes = []
    for name, fn, note in PLANTS:
        im = fn()
        path = os.path.join(OUT_DIR, name + ".png")
        im.save(path)
        sprites[name] = im
        notes.append((name, im.size, note))
        print(f"{name:16} {im.width:3}x{im.height:<3}  {path}")
    sheet = preview(sprites)
    print("preview", sheet)
    readme = os.path.join(OUT_DIR, "README.txt")
    lines = [
        "史前植物像素素材（原创）",
        "",
        "造型参考侏罗纪植物图鉴，像素是重新画的，不是临摹、也不是缩小原图。",
        "风格和玩家恐龙一致：扁平色块、一像素描边、硬边、无抗锯齿。",
        "",
        "地面接触点在图片底边中心。另一个 AI 接进游戏时：",
        "  Texture Type = Sprite",
        "  Filter Mode = Point",
        "  Compression = None",
        "  Pixels Per Unit = 22（和 dino_*.png 同一像素密度）",
        "  Pivot = Bottom Center (0.5, 0)",
        "",
        "建议对应：",
        "  tree.png       -> Resources/Dino/tree.png",
        "  shrub.png      -> Resources/Dino/bush.png",
        "  fern.png       -> Resources/Dino/fern.png",
        "  clubmoss.png   -> Resources/Dino/flower.png   （小装饰，可选）",
        "  其余是新植被，大平原上当装饰撒，不要当障碍，否则树会变成伤害判定。",
        "",
        "文件：",
    ]
    for name, size, note in notes:
        lines.append(f"  {name}.png  {size[0]}x{size[1]}  {note}")
    lines.append("")
    lines.append("重新生成： python3 tools/art/make_plants.py")
    lines.append("")
    with open(readme, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
