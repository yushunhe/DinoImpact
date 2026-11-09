#!/usr/bin/env python3
"""DINO IMPACT - white-feathered ornithomimid player sprites with a rider.

The game camera looks down from behind the player, so the character is drawn
from a rear 3/4 view: you see the dinosaur's back, folded wings, long neck and
the beak poking up-screen, with a long feathered tail trailing toward the
camera. The head is turned to one side so an eye reads from behind, and a
small rider in hide clothing sits on its back with a quiver of red-fletched
arrows.

Anatomy follows the hand sketch: ostrich-like neck and legs, small beaked
head, white plumage, feathered wings and tail.

All parts are painted flat first and get one clean outer outline at the end,
which keeps the silhouette readable at the game's low resolution.

Outputs 1x PNGs to Assets/Resources/Dino/ and enlarged previews to
tools/art/preview/.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFont

W, H = 46, 56
SS = 10  # preview scale

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "Assets", "Resources", "Dino")
PREV_DIR = os.path.join(HERE, "preview")

# palette ------------------------------------------------------------------
CLEAR = (0, 0, 0, 0)
OUTLINE = (33, 41, 48, 255)
DEEP = (140, 150, 153, 255)
SHADE = (194, 199, 195, 255)
SOFT = (222, 224, 217, 255)
WHITE = (244, 243, 234, 255)
HI = (255, 255, 255, 255)
BEAK = (201, 138, 74, 255)
BEAK_DARK = (140, 84, 40, 255)
LEG = (212, 151, 90, 255)
LEG_DARK = (143, 89, 44, 255)
EYE = (20, 26, 32, 255)
GLINT = (255, 255, 255, 255)
CLAW = (176, 162, 132, 255)

# rider palette: hide clothing, skin and a red-fletched quiver for contrast
FUR = (138, 92, 52, 255)
FUR_DARK = (94, 60, 33, 255)
FUR_LIGHT = (201, 164, 107, 255)
SKIN = (232, 184, 142, 255)
SKIN_DARK = (196, 143, 100, 255)
HAIR = (58, 42, 34, 255)
HAIR_HI = (92, 68, 52, 255)
QUIVER = (107, 66, 38, 255)
QUIVER_HI = (169, 118, 69, 255)
ARROW = (214, 190, 138, 255)
FLETCH = (224, 90, 71, 255)
BOOT = (74, 48, 30, 255)

GRASS = (59, 105, 44, 255)  # preview backdrop, matches the game grass


class Canvas:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.px = bytearray(w * h * 4)

    def set(self, x, y, c):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        i = (y * self.w + x) * 4
        self.px[i:i + 4] = bytes(c)

    def get(self, x, y):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return CLEAR
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
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                        inside = not inside
                    j = i
                if inside:
                    self.set(x, y, c)

    def arc(self, cx, cy, rx, ry, a0, a1, c, thick=1):
        steps = max(10, int(abs(a1 - a0) * 3))
        for i in range(steps + 1):
            a = a0 + (a1 - a0) * i / steps
            x = cx + math.cos(a) * rx
            y = cy + math.sin(a) * ry
            self.rect(int(round(x)) - thick // 2, int(round(y)) - thick // 2, thick, thick, c)

    def image(self):
        return Image.frombytes("RGBA", (self.w, self.h), bytes(self.px))


def add_outline(art: Canvas, diag=True) -> Canvas:
    """One clean outer outline around the union of every painted part."""
    out = Canvas(art.w, art.h)
    offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    if diag:
        offsets += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    for y in range(art.h):
        for x in range(art.w):
            if art.opaque(x, y):
                continue
            for dx, dy in offsets:
                if art.opaque(x + dx, y + dy):
                    out.set(x, y, OUTLINE)
                    break
    # paint the art on top of the outline layer
    for y in range(art.h):
        for x in range(art.w):
            c = art.get(x, y)
            if c[3] > 0:
                out.set(x, y, c)
    return out


def add_outline_under(art: Canvas) -> Canvas:
    """Return art composited over a one-pixel silhouette outline."""
    return add_outline(art)


# ---------------------------------------------------------------- part paint


def scallop(c, x0, y, w, col):
    """A single feather-edge scallop: flat line with both ends dipped 1px."""
    for i in range(w):
        c.set(x0 + i, y + (0 if 0 < i < w - 1 else 1), col)


def paint_leg(c, hipx, hipy, footx, footy, lift, side):
    """Long dinosaur leg: thick feathered thigh, backward hock, scaly
    shank and three clawed toes. Seen from behind, the toes point
    up-screen (away from the camera)."""
    hipx, hipy = float(hipx), float(hipy)
    footx, footy = float(footx), float(footy)
    ankle_y = footy - 2.4
    knee_y = hipy + (ankle_y - hipy) * .45 - lift * .5
    knee_x = hipx + (footx - hipx) * .34 + (-1.0 if side == "L" else 1.0)
    inner = 1.0 if side == "L" else -1.0

    # feathered thigh (white, like an ostrich) down to the knee
    c.line(hipx, hipy, knee_x, knee_y, 4, SOFT)
    c.line(hipx, hipy - .5, knee_x, knee_y - .5, 2, WHITE)
    c.line(hipx + inner, hipy + 1, knee_x + inner, knee_y, 1, SHADE)
    c.set(int(knee_x), int(knee_y), LEG_DARK)  # knee joint

    # bare scaled shank from the knee to the ankle
    c.line(knee_x, knee_y, footx, ankle_y, 2, LEG)
    c.line(knee_x + inner * .4, knee_y + 1, footx + inner * .4, ankle_y, 1, LEG_DARK)
    for i in range(1, 4):
        t = i / 4.0
        c.set(int(round(knee_x + (footx - knee_x) * t + inner * .4)),
              int(round(knee_y + (ankle_y - knee_y) * t)), SOFT)

    fx, fy = int(round(footx)), int(round(ankle_y))
    # heel pad plus three separated toes with pale claws
    c.rect(fx - 1, fy - 1, 3, 2, LEG)
    for dx, dy in ((-2, -3), (0, -4), (2, -3)):
        c.line(fx, fy - 1, fx + dx, fy + dy, 1, LEG)
        c.set(fx + dx, fy + dy, CLAW)
    c.set(fx, fy - 1, LEG_DARK)


def paint_tail(c, bx, by, sway):
    """Long feathered tail fanning out to the right, toward the camera.

    Three overlapping feathers of decreasing height keep the tail reading
    as a bird-dinosaur fan rather than a single blob."""
    bx, by = float(bx), float(by)
    root = (bx + 6.2, by + 4.0)
    feathers = [
        [(root[0], root[1] - .8), (bx + 12.5, by + 3.6),
         (bx + 18.8 + sway * .4, by + 2.8)],
        [(root[0] + .2, root[1] + .6), (bx + 12.4, by + 8.2),
         (bx + 18.4 + sway, by + 10.6)],
        [(root[0] + .4, root[1] + 1.6), (bx + 11.6, by + 11.2),
         (bx + 16.8 + sway * .6, by + 13.8)],
    ]
    radii = [2.4, 1.7, 0.9]
    for fi, pts in enumerate(feathers):
        for (x, y), r in zip(pts, radii):
            c.ellipse(x, y, r, r, WHITE)
        c.line(pts[0][0], pts[0][1] + .8, pts[-1][0] - .4, pts[-1][1] + .2, 1,
               SHADE if fi != 1 else SOFT)
    # soft underside shadow following the longest feather
    for (x, y), r in zip(feathers[1], radii):
        c.ellipse(x - .4, y + 1.0, r * .55, r * .45, SOFT)
    # feather-tip notches along the lower edge (kept connected)
    for x in range(int(bx + 6), int(bx + 19 + sway) + 1):
        ys = [y for y in range(30, 50) if c.opaque(x, y)]
        if not ys:
            continue
        y = max(ys)
        if (x + int(round(sway))) % 3 == 0 \
                and c.opaque(x - 1, y) and c.opaque(x + 1, y):
            c.set(x, y, CLEAR)


def paint_wing(c, bx, by, side, spread):
    """Folded wing: three long primaries trailing down the flank."""
    s = -1 if side == "L" else 1
    root = (bx + s * 7.2, by - 1.0)
    tips = [
        (bx + s * (9.8 + spread * .3), by + 4.6),
        (bx + s * (9.2 + spread * .2), by + 6.6),
        (bx + s * (10.4 + spread * .4), by + 7.6),
    ]
    for i, tip in enumerate(tips):
        my = (root[1] + tip[1]) * .5 + 1.6
        mx = (root[0] + tip[0]) * .5 + s * .5
        c.poly([(root[0] - 1.4, root[1]), (root[0] + 1.6, root[1] + 1.2),
                (mx + 1.4, my), (tip[0] + .8, tip[1]),
                (tip[0] - .8, tip[1] + .6), (mx - 1.0, my + .8)], SOFT)
        c.line(root[0], root[1] + 1.4, tip[0] - .2, tip[1] - .4, 1, SHADE)
        # bright leading edge so the wing separates from the white body
        c.line(root[0] - s * .6, root[1] + .6, tip[0] - s * .2, tip[1], 1, HI)
    c.ellipse(bx + s * 7.2, by - 1.4, 1.6, 1.0, HI)
    # contour separating the folded wing from the body
    c.line(bx + s * 6.2, by - 1.8, bx + s * 8.0, by + 2.6, 1, SOFT)


def paint_body(c, bx, by):
    # broad back seen from above/behind: deep chest, strong hips
    c.ellipse(bx, by, 9.0, 5.8, WHITE)
    c.ellipse(bx, by + 1.8, 9.4, 4.6, WHITE)
    c.ellipse(bx - 0.2, by - 1.2, 8.0, 4.8, WHITE)
    # spine catches the light, running up-screen toward the neck
    c.ellipse(bx - 0.8, by - 2.6, 3.4, 1.4, HI)
    c.ellipse(bx - 5.4, by - 2.2, 2.0, 1.1, HI)
    # soft feather mass on the flanks
    c.ellipse(bx + 4.8, by + 2.2, 3.6, 2.2, SOFT)
    c.ellipse(bx + 6.8, by + 1.0, 1.5, 1.1, SHADE)
    c.ellipse(bx - 5.2, by + 2.6, 3.0, 2.0, SOFT)
    # layered feather rows across the visible back and hips
    for i, yy in enumerate((by + 2.6, by + 3.9)):
        for j in range(4):
            scallop(c, int(bx - 6.6 + j * 3 + (i % 2) * 1.5),
                    int(yy), 3, SOFT if i % 2 else SHADE)
    scallop(c, int(bx - 5.8), int(by + 5.2), 3, SOFT)
    scallop(c, int(bx - 2.4), int(by + 5.6), 3, SHADE)


def paint_neck_head(c, bx, by, headx, head_y):
    # small crest of stiff feathers at the back of the head
    crest = [
        (headx + 1.2, head_y - 1.2, headx + 3.4, head_y - 4.6),
        (headx + 1.8, head_y - .5, headx + 4.4, head_y - 3.1),
        (headx + 2.2, head_y + .4, headx + 4.8, head_y - 1.4),
    ]
    for x0, y0, x1, y1 in crest:
        c.line(x0, y0, x1, y1, 1, WHITE)

    # long S-curved saurian neck, thick at the shoulders and tapering up
    pts = [
        (bx - 0.4, by - 3.8),
        (bx - 0.9, by - 7.4),
        (bx - 1.8, by - 11.0),
        (bx - 3.2, by - 14.8),
        (headx, head_y + 2.5),
    ]
    for i in range(len(pts) - 1):
        c.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1],
               (5, 4, 3, 3)[i], WHITE)
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        c.line(x0 + 1.4, y0, x1 + 1.4, y1, 1, SOFT)
        c.line(x0 - 1.2, y0, x1 - 1.2, y1, 1, HI)
    # feather ticks along the back of the neck
    for i in range(2, 4):
        x0, y0 = pts[i]
        c.set(int(x0 + 2), int(y0), SOFT)

    hx, hy = headx, head_y
    # long, thin pointed snout ending in a small hooked tip
    beak = [
        (hx - 0.8, hy + 1.0),
        (hx - 0.2, hy - 1.3),
        (hx - 6.8, hy - 0.6),
        (hx - 7.0, hy - 0.1),
        (hx - 6.2, hy + 0.5),
        (hx - 0.9, hy + 1.0),
    ]
    c.poly(beak, BEAK)
    c.set(int(hx - 1.0), int(hy + 0.9), BEAK_DARK)  # mouth corner
    c.set(int(hx - 4.2), int(hy - 0.4), BEAK_DARK)  # nostril
    c.set(int(hx - 6.8), int(hy + 0.1), BEAK_DARK)  # hooked tip

    # narrow skull with a bright crown
    c.ellipse(hx, hy, 2.9, 2.7, WHITE)
    c.ellipse(hx + 1.1, hy - 0.2, 1.8, 1.8, HI)
    c.ellipse(hx + 1.2, hy + 1.4, 1.7, .9, SOFT)
    c.ellipse(hx + 2.2, hy + 1.8, 1.1, .7, SHADE)

    # narrow eye on the visible cheek, under a soft brow
    ex = int(round(hx - 1.2))
    ey = int(round(hy - 1.2))
    c.rect(ex - 1, ey - 1, 3, 1, SOFT)  # brow
    c.rect(ex, ey, 1, 2, EYE)           # eye
    c.set(ex, ey, HI)                   # glint
    c.set(ex + 1, ey + 1, SOFT)         # lower lid
    c.rect(int(hx - 2.6), int(hy + 1.4), 2, 1, SOFT)  # cheek feathers

    # feather ruff at the base of the neck
    for dx, dy in ((-2.6, 0), (-1.6, -0.8), (1.8, -0.9), (2.8, 0),
                   (-0.6, -1.4), (0.8, 1.3)):
        c.set(int(bx + dx), int(by - 4.6 + dy), SOFT)


def paint_rider(c, bx, by, bob=0.0, lean=0.0):
    """Rider seen from behind: hide cloak, fur trim, diagonal quiver and
    red-fletched arrows. Kept small so the dinosaur still reads as the
    main character."""
    rx = bx + 2.2 + lean
    hip_y = by - 3.0 + bob
    shy = by - 10.0 + bob
    hy = by - 12.4 + bob

    # soft contact shadow where the rider sits on the dinosaur's back
    c.ellipse(rx, hip_y + 3.4, 4.6, 1.3, SHADE)

    # boots / legs on both flanks, drawn before the cloak
    for s in (-1, 1):
        kx, ky = rx + s * 4.2, hip_y + 3.2
        bxx, byy = rx + s * 4.8, hip_y + 6.4
        c.line(rx + s * 1.6, hip_y, kx, ky, 3, FUR)
        c.line(kx, ky, bxx, byy, 2, BOOT)
        c.set(int(kx), int(ky), FUR_DARK)
        c.set(int(bxx), int(byy), BOOT)

    # hide cloak: broad shoulders, wider hem over the dinosaur's back
    c.poly([(rx - 3.4, shy), (rx + 3.4, shy),
            (rx + 4.2, hip_y + 1.6), (rx - 4.4, hip_y + 1.6)], FUR)
    c.ellipse(rx, shy + .6, 3.2, 1.5, FUR)
    c.ellipse(rx, hip_y + 1.2, 4.0, 1.3, FUR)
    # dark side shading and fur strokes
    c.line(rx - 3.4, shy + 2, rx - 4.0, hip_y + 1, 1, FUR_DARK)
    c.line(rx + 3.4, shy + 2, rx + 4.0, hip_y + 1, 1, FUR_DARK)
    for i in (-2, -1, 0, 1, 2):
        c.line(rx + i, shy + 2, rx + i * 1.3, hip_y + 1, 1, FUR_DARK)
    # fur trim: collar and hem
    for i in range(-3, 4):
        c.set(int(rx + i), int(shy - 1), FUR_LIGHT)
    for i in range(-4, 5):
        c.set(int(rx + i), int(hip_y) + 2, FUR_LIGHT)

    # arms: fur sleeves hanging forward, skin hands near the withers
    for s in (-1, 1):
        c.line(rx + s * 3.0, shy + 1, rx + s * 3.8, shy + 4.4, 2, FUR)
        c.set(int(rx + s * 3.8), int(shy + 2), FUR_DARK)
        c.rect(int(rx + s * 3.8) - (0 if s > 0 else 1), int(shy + 4.4),
               2, 1, SKIN)

    # quiver slung from left hip to right shoulder
    q0 = (rx - 2.2, hip_y + 1.4)
    q1 = (rx + 2.8, shy + 1.0)
    c.line(q0[0], q0[1], q1[0], q1[1], 3, QUIVER)
    c.line(q0[0] + .4, q0[1] - .6, q1[0] + .4, q1[1] - .6, 1, QUIVER_HI)
    c.line(q0[0] - .2, q0[1] + .8, q1[0] - .2, q1[1] + .8, 1, FUR_DARK)
    c.line(q1[0] - 1.0, q1[1] + .4, q1[0] + 1.0, q1[1] - .4, 1, QUIVER_HI)
    c.line(q1[0] - 1.0, q1[1] + 1.0, q1[0] + 1.0, q1[1] + .2, 1, FUR_DARK)

    # three arrows rising past the right shoulder
    for dx, length in ((0.2, 3.8), (1.4, 4.6), (2.6, 5.4)):
        x0, y0 = q1[0] + dx, q1[1] - .4
        x1, y1 = x0 + 1.0, y0 - length
        c.line(x0, y0, x1, y1, 1, ARROW)
        fx, fy = int(round(x1)), int(round(y1))
        c.rect(fx - 1, fy, 2, 2, FLETCH)
        c.set(fx, fy, WHITE)

    # head: from behind we mostly see dark hair
    c.rect(int(rx) - 1, int(shy - 1), 2, 2, SKIN_DARK)  # neck
    c.ellipse(rx + .2, hy, 2.8, 2.6, SKIN)
    c.ellipse(rx + .2, hy - .6, 2.8, 2.1, HAIR)
    c.ellipse(rx - .2, hy - 1.4, 1.5, .9, HAIR_HI)
    c.set(int(rx + 2.4), int(hy + 1.0), SKIN_DARK)      # cheek/ear hint
    c.line(rx + .8, hy + 1.6, rx + .6, shy + 1.6, 1, HAIR)  # short ponytail


def paint_frame(p):
    c = Canvas()
    bx = 23.0 + p.get("lean", 0.0)
    by = 33.0 + p["bob"]
    headx = 17.6 + p.get("head_lean", 0.0)
    head_y = 10.4 + p["bob"] + p.get("head_bob", 0.0)

    paint_tail(c, bx, by, p["tail"])

    lf = p["legs"]["L"]
    rf = p["legs"]["R"]
    # far leg first so the near leg overlaps it
    paint_leg(c, bx + 4.4, by + 3.0, rf[0], rf[1], rf[2], "R")
    paint_leg(c, bx - 4.4, by + 3.0, lf[0], lf[1], lf[2], "L")

    paint_body(c, bx, by)

    # feathered "shorts" over the top of each leg
    for fx in (bx - 4.4, bx + 4.4):
        c.ellipse(fx, by + 4.2, 2.2, 1.8, WHITE)
        c.ellipse(fx - .5, by + 3.5, 1.4, 1.0, HI)
        c.ellipse(fx + .6, by + 4.9, 1.2, .8, SOFT)

    paint_wing(c, bx, by, "L", p["wing"])
    paint_wing(c, bx, by, "R", p["wing"])
    paint_neck_head(c, bx, by, headx, head_y)

    paint_rider(c, bx, by, p.get("rider_bob", 0.0), p.get("rider_lean", 0.0))

    return add_outline(c).image()


# --------------------------------------------------------------------- poses

IDLE = {
    "bob": 0,
    "tail": 0.0,
    "wing": 0.0,
    "head_bob": 0.0,
    "rider_bob": 0.0,
    "legs": {"L": (18.2, 52.4, 0), "R": (28.0, 52.4, 0)},
}
IDLE2 = {
    "bob": 1,
    "tail": 0.6,
    "wing": 0.0,
    "head_bob": -0.5,
    "rider_bob": 0.8,
    "legs": {"L": (18.2, 52.4, 0), "R": (28.0, 52.4, 0)},
}
RUN0 = {
    "bob": 2,
    "tail": -1.8,
    "wing": 1.0,
    "head_bob": 0.7,
    "lean": 0.3,
    "head_lean": 0.3,
    "rider_bob": 1.5,
    "legs": {"L": (18.0, 52.6, 0), "R": (29.6, 47.0, 3.0)},
}
RUN1 = {
    "bob": -1,
    "tail": 0.0,
    "wing": 0.0,
    "head_bob": -0.7,
    "rider_bob": -0.4,
    "legs": {"L": (18.8, 51.2, 1.2), "R": (27.4, 50.6, 1.8)},
}
RUN2 = {
    "bob": 2,
    "tail": 1.8,
    "wing": 1.0,
    "head_bob": 0.7,
    "lean": 0.3,
    "head_lean": -0.3,
    "rider_bob": 1.5,
    "legs": {"L": (17.2, 47.0, 3.0), "R": (28.2, 52.6, 0)},
}
RUN3 = {
    "bob": -1,
    "tail": 0.0,
    "wing": 0.0,
    "head_bob": -0.7,
    "rider_bob": -0.4,
    "legs": {"L": (18.6, 50.6, 1.8), "R": (28.0, 51.2, 1.2)},
}

FRAMES = [
    ("dino_idle", IDLE),
    ("dino_idle2", IDLE2),
    ("dino_run0", RUN0),
    ("dino_run1", RUN1),
    ("dino_run2", RUN2),
    ("dino_run3", RUN3),
]


def write_meta(png_path, name):
    """Unity .meta so the PNG imports as a point-filtered sprite at PPU 22.

    Existing meta files are kept so Unity GUIDs stay stable across re-exports.
    """
    meta_path = png_path + ".meta"
    if os.path.exists(meta_path):
        return
    import hashlib
    guid = hashlib.md5(("DinoImpact/" + name).encode()).hexdigest()
    meta = f"""fileFormatVersion: 2
guid: {guid}
TextureImporter:
  internalIDToNameTable: []
  externalObjects: {{}}
  serializedVersion: 11
  mipmaps:
    mipMapMode: 0
    enableMipMap: 0
    sRGBTexture: 1
    linearTexture: 0
    fadeOut: 0
    borderMipMap: 0
    mipMapsPreserveCoverage: 0
    alphaTestReferenceValue: 0.5
    mipMapFadeDistanceStart: 1
    mipMapFadeDistanceEnd: 3
  bumpmap:
    convertToNormalMap: 0
    externalNormalMap: 0
    heightScale: 0.25
    normalMapFilter: 0
  isReadable: 0
  streamingMipmaps: 0
  streamingMipmapsPriority: 0
  vTOnly: 0
  ignoreMasterTextureLimit: 0
  grayScaleToAlpha: 0
  generateCubemap: 6
  cubemapConvolution: 0
  seamlessCubemap: 0
  textureFormat: 1
  maxTextureSize: 2048
  textureSettings:
    serializedVersion: 2
    filterMode: 0
    aniso: 1
    mipBias: 0
    wrapU: 1
    wrapV: 1
    wrapW: 0
  nPOTScale: 0
  lightmap: 0
  compressionQuality: 50
  spriteMode: 1
  spriteExtrude: 1
  spriteMeshType: 0
  alignment: 9
  spritePivot: {{x: 0.5, y: 0.14}}
  spritePixelsToUnits: 22
  spriteBorder: {{x: 0, y: 0, z: 0, w: 0}}
  spriteGenerateFallbackPhysicsShape: 0
  alphaUsage: 1
  alphaIsTransparency: 1
  spriteTessellationDetail: -1
  textureType: 8
  textureShape: 1
  singleChannelComponent: 0
  flipbookRows: 1
  flipbookColumns: 1
  maxTextureSizeSet: 0
  compressionQualitySet: 0
  textureFormatSet: 0
  ignorePngGamma: 0
  applyGammaDecoding: 0
  platformSettings:
  - serializedVersion: 3
    buildTarget: DefaultTexturePlatform
    maxTextureSize: 2048
    resizeAlgorithm: 0
    textureFormat: -1
    textureCompression: 0
    compressionQuality: 50
    crunchedCompression: 0
    allowsAlphaSplitting: 0
    overridden: 0
    androidETC2FallbackOverride: 0
    forceMaximumCompressionQuality_BC6H_BC7: 0
  spriteSheet:
    serializedVersion: 2
    sprites: []
    outline: []
    physicsShape: []
    bones: []
    spriteID:
    internalID: 0
    vertices: []
    indices:
    edges: []
    weights: []
    secondaryTextures: []
    nameFileIdTable: {{}}
  spritePackingTag:
  pSDRemoveMatte: 0
  pSDShowRemoveMatteOption: 0
  userData:
  assetBundleName:
  assetBundleVariant:
"""
    with open(meta_path, "w") as f:
        f.write(meta)


def _grass_tile(size=64):
    """Deterministic, tileable grass texture matching the game's backdrop."""
    tile = Image.new("RGBA", (size, size), GRASS)
    d = ImageDraw.Draw(tile)
    dark = (52, 94, 38, 255)
    light = (68, 117, 50, 255)
    for i in range(size * size // 9):
        x = (i * 37 + 11) % size
        y = (i * 53 + 7) % size
        col = dark if (i * 29) % 100 < 62 else light
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):  # wraps cleanly
            d.point((x + dx, y + dy), fill=col)
    # a few wind-bent blades, drawn with wrap so the tile stays seamless
    for k in range(5):
        x = (k * 23 + 5) % size
        y = (k * 17 + 31) % size
        for j in range(3):
            d.point(((x + j) % size, (y - j) % size), fill=light)
    return tile


def gameplay_preview(images, screen=(960, 540), frames=12, ms=110):
    """Mock the actual in-game view using dino_config.lua's camera numbers.

    The player sits just below screen centre (camera yOffset 3.1, ortho 6.2),
    so the sprite renders at roughly its native 32x40 pixels - what players
    actually see, not a blown-up art sheet.
    """
    sw, sh = screen
    ppu = 22.0                 # TextureImporter spritePixelsToUnits
    ortho = 6.2                # C.camera.size
    cam_y = 3.1                # C.camera.yOffset
    scale = 1.08               # P scale in dino_player.lua
    speed = 6.4                # C.player.forwardMax, full sprint

    px_per_unit = sh / (ortho * 2)
    k = px_per_unit / ppu * scale
    dw, dh = max(1, round(W * k)), max(1, round(H * k))
    feet_y = sh / 2 + cam_y * px_per_unit
    # pivot (0.5, 0.14) -> feet are 14% up from the bottom of the sprite
    sprite_y = round(feet_y - dh * 0.86)

    su = max(1, round(sh / 270))     # keep the ground texture chunky at 2x
    tile = _grass_tile().resize((64 * su, 64 * su), Image.NEAREST)
    ts = tile.width
    tile_w = (sw // ts + 2) * ts
    backdrop = Image.new("RGBA", (tile_w, sh + ts), GRASS)
    for ty in range(0, sh + ts, ts):
        for tx in range(0, tile_w, ts):
            backdrop.alpha_composite(tile, (tx, ty))

    run = [images[f"dino_run{i}"].resize((dw, dh), Image.NEAREST)
           for i in range(4)]

    out_frames = []
    scroll_total = speed * px_per_unit * (frames * ms / 1000.0)
    for i in range(frames):
        # running up-screen = the ground slides down toward the camera
        off = int(round(scroll_total * i / frames))
        start = (-off) % ts
        canvas = backdrop.crop((0, start, sw, start + sh)).copy()
        shadow = Image.new("RGBA", canvas.size, CLEAR)
        sd = ImageDraw.Draw(shadow)
        rx = 22 * su
        sd.ellipse((sw // 2 - rx, feet_y - 5 * su, sw // 2 + rx, feet_y + 9 * su),
                   fill=(12, 24, 10, 70))
        canvas.alpha_composite(shadow)
        canvas.alpha_composite(run[i % 4], (sw // 2 - dw // 2, sprite_y))
        out_frames.append(canvas.convert("RGB"))

    path = os.path.join(PREV_DIR, "ornithomimus_ingame.gif")
    out_frames[0].save(path, save_all=True, append_images=out_frames[1:],
                       duration=ms, loop=0, optimize=False)
    out_frames[0].save(os.path.join(PREV_DIR, "ornithomimus_ingame.png"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREV_DIR, exist_ok=True)

    images = {}
    for name, pose in FRAMES:
        im = paint_frame(pose)
        path = os.path.join(OUT_DIR, name + ".png")
        im.save(path)
        write_meta(path, name)
        images[name] = im

    pad, label_h = 18, 26
    fw, fh = W * SS, H * SS
    sheet = Image.new("RGBA", (len(FRAMES) * fw + pad * (len(FRAMES) + 1),
                               fh + label_h + pad * 2), GRASS)
    d = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for i, (name, _) in enumerate(FRAMES):
        x = pad + i * (fw + pad)
        y = pad + label_h
        big = images[name].resize((fw, fh), Image.NEAREST)
        sheet.alpha_composite(big, (x, y))
        d.text((x + 2, pad + 7), name.replace("dino_", ""), fill=(247, 241, 216, 255), font=font)
    sheet.save(os.path.join(PREV_DIR, "ornithomimus_sheet.png"))

    def gif(names, durations, path):
        frames = []
        for n in names:
            im = images[n]
            bg = Image.new("RGBA", im.size, GRASS)
            bg.alpha_composite(im)
            frames.append(bg.convert("RGB").resize((W * SS, H * SS), Image.NEAREST))
        frames[0].save(path, save_all=True, append_images=frames[1:],
                       duration=durations, loop=0, optimize=False)

    # large pixel-art sheet: 2 rows x 3 columns at 14x, easy to judge detail
    big = 14
    cols, rows = 3, 2
    bw, bh = W * big, H * big
    gap, top = 16, 30
    frame_list = [name for name, _ in FRAMES]
    bigsheet = Image.new("RGBA", (cols * bw + gap * (cols + 1),
                                  rows * (bh + top) + gap), GRASS)
    bd = ImageDraw.Draw(bigsheet)
    for i, name in enumerate(frame_list):
        cx = gap + (i % cols) * (bw + gap)
        cy = gap + (i // cols) * (bh + top)
        bd.text((cx + 2, cy + 6), name.replace("dino_", ""),
                fill=(247, 241, 216, 255), font=font)
        bigsheet.alpha_composite(
            images[name].resize((bw, bh), Image.NEAREST), (cx, cy + top))
    bigsheet.save(os.path.join(PREV_DIR, "ornithomimus_frames.png"))

    def gif_big(names, durations, path):
        fr = []
        for n in names:
            bgf = Image.new("RGBA", (W * big, H * big), GRASS)
            bgf.alpha_composite(
                images[n].resize((W * big, H * big), Image.NEAREST))
            fr.append(bgf.convert("RGB"))
        fr[0].save(path, save_all=True, append_images=fr[1:],
                   duration=durations, loop=0, optimize=False)

    gif_big([f"dino_run{i}" for i in range(4)], [110] * 4,
            os.path.join(PREV_DIR, "ornithomimus_run_big.gif"))
    gif_big(["dino_idle", "dino_idle2"], [520, 520],
            os.path.join(PREV_DIR, "ornithomimus_idle_big.gif"))

    close = images["dino_idle"].resize((W * 16, H * 16), Image.NEAREST)
    bg = Image.new("RGBA", close.size, GRASS)
    bg.alpha_composite(close)
    bg.save(os.path.join(PREV_DIR, "ornithomimus_idle_closeup.png"))

    gif([f"dino_run{i}" for i in range(4)], [110, 110, 110, 110],
        os.path.join(PREV_DIR, "ornithomimus_run.gif"))
    gif(["dino_idle", "dino_idle2"], [520, 520],
        os.path.join(PREV_DIR, "ornithomimus_idle.gif"))

    gameplay_preview(images)

    print("wrote", OUT_DIR)
    print("wrote", PREV_DIR)


if __name__ == "__main__":
    main()
