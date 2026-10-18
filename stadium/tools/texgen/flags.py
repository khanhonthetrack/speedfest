"""National flags for the Stadium's flagpoles (env/tm_stadium_build.gd), drawn from their
geometric definitions (all at 3:2 for the poles; proportions inside each flag as specified, the
coats of arms left out where a flag has one: Spain's civil flag). One atlas, 8 x 3 cells, hoist on
the left; env/tm_flag.gdshader picks a cell per flag.
usage: python3 stadium/tools/texgen/flags.py"""
import math
import numpy as np
from PIL import Image, ImageDraw
from texlib import OUT, write_import
import os

CW, CH = 384, 256          # one cell (3:2)
COLS, ROWS = 8, 3
PAD = 6                    # gutter round each cell (edge colours repeated: no bleeding in mips)

# the atlas order; env/tm_stadium_build.gd FLAG_ORDER names them
FLAGS = ['poland', 'germany', 'france', 'italy', 'united_kingdom', 'usa', 'japan', 'sweden',
         'finland', 'norway', 'denmark', 'netherlands', 'belgium', 'austria', 'czechia', 'ukraine',
         'hungary', 'spain', 'ireland', 'switzerland', 'greece', 'estonia', 'lithuania', 'latvia']

RED = (220, 20, 60)


def h_bands(d, w, h, cols, weights=None):
    weights = weights or [1] * len(cols)
    total = sum(weights)
    y = 0.0
    for c, k in zip(cols, weights):
        y1 = y + h * k / total
        d.rectangle([0, round(y), w, round(y1)], fill=c)
        y = y1


def v_bands(d, w, h, cols):
    for i, c in enumerate(cols):
        d.rectangle([round(w * i / len(cols)), 0, round(w * (i + 1) / len(cols)), h], fill=c)


def nordic(d, w, h, field, cross, inner=None, t=1 / 8, cx=None):
    """A Nordic cross: field, the cross (width t of the height) with its upright at cx of the width
    from the hoist, optionally an inner cross (Norway)."""
    d.rectangle([0, 0, w, h], fill=field)
    cx = cx if cx is not None else 0.375
    x = w * cx
    y = h * 0.5
    tw = h * t
    d.rectangle([x - tw, 0, x + tw, h], fill=cross)
    d.rectangle([0, y - tw, w, y + tw], fill=cross)
    if inner:
        iw = tw * 0.5
        d.rectangle([x - iw, 0, x + iw, h], fill=inner)
        d.rectangle([0, y - iw, w, y + iw], fill=inner)


def star(d, cx, cy, r, fill, points=5):
    pts = []
    for k in range(points * 2):
        a = -math.pi / 2 + k * math.pi / points
        rr = r if k % 2 == 0 else r * 0.382
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill)


def band_poly(x0, y0, x1, y1, half):
    """A straight band from (x0, y0) to (x1, y1), half wide, as a polygon."""
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy)
    ox, oy = -dy / n * half, dx / n * half
    return [(x0 + ox, y0 + oy), (x1 + ox, y1 + oy), (x1 - ox, y1 - oy), (x0 - ox, y0 - oy)]


def draw(name, w, h):
    img = Image.new('RGB', (w, h), (255, 255, 255))
    d = ImageDraw.Draw(img)
    W, B, Y = (255, 255, 255), (0, 0, 0), (255, 206, 0)
    if name == 'poland':
        h_bands(d, w, h, [W, (220, 20, 60)])
    elif name == 'germany':
        h_bands(d, w, h, [B, (221, 0, 0), (255, 206, 0)])
    elif name == 'france':
        v_bands(d, w, h, [(0, 35, 149), W, (237, 41, 57)])
    elif name == 'italy':
        v_bands(d, w, h, [(0, 146, 70), W, (206, 43, 55)])
    elif name == 'ukraine':
        h_bands(d, w, h, [(0, 87, 183), (255, 215, 0)])
    elif name == 'netherlands':
        h_bands(d, w, h, [(174, 28, 40), W, (33, 70, 139)])
    elif name == 'belgium':
        v_bands(d, w, h, [B, (253, 218, 36), (239, 51, 64)])
    elif name == 'ireland':
        v_bands(d, w, h, [(22, 155, 98), W, (255, 136, 62)])
    elif name == 'austria':
        h_bands(d, w, h, [(200, 16, 46), W, (200, 16, 46)])
    elif name == 'hungary':
        h_bands(d, w, h, [(205, 42, 62), W, (67, 111, 77)])
    elif name == 'spain':
        h_bands(d, w, h, [(170, 21, 27), (241, 191, 0), (170, 21, 27)], [1, 2, 1])
    elif name == 'estonia':
        h_bands(d, w, h, [(0, 114, 206), B, W])
    elif name == 'lithuania':
        h_bands(d, w, h, [(253, 185, 19), (0, 106, 68), (193, 39, 45)])
    elif name == 'latvia':
        h_bands(d, w, h, [(158, 48, 57), W, (158, 48, 57)], [2, 1, 2])
    elif name == 'czechia':
        h_bands(d, w, h, [W, (215, 20, 26)])
        d.polygon([(0, 0), (w * 0.5, h * 0.5), (0, h)], fill=(17, 69, 126))
    elif name == 'japan':
        d.rectangle([0, 0, w, h], fill=W)
        r = h * 0.3
        d.ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=(188, 0, 45))
    elif name == 'switzerland':
        d.rectangle([0, 0, w, h], fill=(218, 41, 28))
        s = h * 0.62 / 32.0          # the cross: arms 6 x 7 of a 32 field
        cx, cy = w / 2, h / 2
        d.rectangle([cx - 3 * s, cy - 10 * s, cx + 3 * s, cy + 10 * s], fill=W)
        d.rectangle([cx - 10 * s, cy - 3 * s, cx + 10 * s, cy + 3 * s], fill=W)
    elif name == 'sweden':
        nordic(d, w, h, (0, 106, 167), (254, 204, 0), t=1 / 10, cx=7 / 16)
    elif name == 'finland':
        nordic(d, w, h, W, (0, 47, 108), t=3 / 22, cx=6.5 / 18)
    elif name == 'denmark':
        nordic(d, w, h, (200, 16, 46), W, t=1 / 14, cx=4.5 / 12.5)
    elif name == 'norway':
        nordic(d, w, h, (186, 12, 47), W, inner=(0, 32, 91), t=2 / 16, cx=8 / 22)
    elif name == 'greece':
        blue = (13, 94, 175)
        h_bands(d, w, h, [blue, W] * 4 + [blue])
        cs = h * 5 / 9
        d.rectangle([0, 0, cs, cs], fill=blue)
        tw = h / 9 * 0.5
        d.rectangle([cs / 2 - tw, 0, cs / 2 + tw, cs], fill=W)
        d.rectangle([0, cs / 2 - tw, cs, cs / 2 + tw], fill=W)
    elif name == 'usa':
        red, blue = (178, 34, 52), (60, 59, 110)
        h_bands(d, w, h, [red, W] * 6 + [red])
        cw, ch = w * 0.4, h * 7 / 13
        d.rectangle([0, 0, cw, ch], fill=blue)
        r = ch / 10 * 0.62
        for row in range(9):
            n = 6 if row % 2 == 0 else 5
            for k in range(n):
                x = cw / 12 * (2 * k + 1 + (0 if row % 2 == 0 else 1))
                y = ch / 10 * (row + 1)
                star(d, x, y, r, W)
    elif name == 'united_kingdom':
        blue, red = (1, 33, 105), (200, 16, 46)
        d.rectangle([0, 0, w, h], fill=blue)
        # St Andrew's saltire (white) and St Patrick's (red, counterchanged), then St George's
        diag = h / 30 * 3
        for (x0, y0, x1, y1) in [(0, 0, w, h), (0, h, w, 0)]:
            d.polygon(band_poly(x0, y0, x1, y1, diag), fill=W)
        rd = h / 30 * 1
        for (x0, y0, x1, y1, side) in [(0, 0, w, h, 1), (w, h, 0, 0, 1), (0, h, w, 0, -1), (w, 0, 0, h, -1)]:
            # the red band offset to one side of the white, from each corner to the centre
            mx, my = w / 2, h / 2
            dx, dy = mx - x0, my - y0
            n = math.hypot(dx, dy)
            ox, oy = -dy / n * rd * side, dx / n * rd * side
            d.polygon(band_poly(x0 + ox, y0 + oy, mx + ox, my + oy, rd), fill=red)
        cw = h / 30 * 10 / 2
        d.rectangle([w / 2 - cw, 0, w / 2 + cw, h], fill=W)
        d.rectangle([0, h / 2 - cw, w, h / 2 + cw], fill=W)
        cr = h / 30 * 6 / 2
        d.rectangle([w / 2 - cr, 0, w / 2 + cr, h], fill=red)
        d.rectangle([0, h / 2 - cr, w, h / 2 + cr], fill=red)
    else:
        raise ValueError(name)
    return img


def atlas(name='flags'):
    cell_w, cell_h = CW + 2 * PAD, CH + 2 * PAD
    out = Image.new('RGB', (cell_w * COLS, cell_h * ROWS))
    for i, flag in enumerate(FLAGS):
        # drawn 4x and scaled down: smooth edges on stars and diagonals
        big = draw(flag, CW * 4, CH * 4).resize((CW, CH), Image.LANCZOS)
        padded = Image.new('RGB', (cell_w, cell_h))
        padded.paste(big.resize((cell_w, cell_h), Image.NEAREST), (0, 0))   # gutter = edge colours
        padded.paste(big, (PAD, PAD))
        out.paste(padded, ((i % COLS) * cell_w, (i // COLS) * cell_h))
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, '%s_albedo.png' % name)
    out.save(p, optimize=True)
    write_import(p, False)
    print(name, out.size, len(FLAGS), 'flags')


if __name__ == '__main__':
    atlas()
