"""Cut-out lattice cards (alpha: the holes), our own drawings in the Stadium's style, for the steel
TMNF draws as alpha cards: a white X-braced panel (girders, the grandstands' spine), a dark railing,
a dark truss girder (catwalks' sides), a dark grating (catwalk floors), a dark slotted plate (the
platform columns' faces).
usage: python3 stadium/tools/texgen/lattice.py"""
import math
import numpy as np
from texlib import *


def bar(w, h, x0, y0, x1, y1, width):
    """A straight bar (pixels) from (x0, y0) to (x1, y1), `width` thick: its mask and, across it, a
    0..1..0 profile (a tube's shading)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    along = (xx - x0) * ux + (yy - y0) * uy
    across = (xx - x0) * -uy + (yy - y0) * ux
    half = width * 0.5
    inside = smoothstep(half + 0.75, half - 0.75, np.abs(across)) * smoothstep(-1.0, 0.5, along) * \
        smoothstep(ln + 1.0, ln - 0.5, along)
    prof = np.clip(1.0 - (across / max(half, 1e-3)) ** 2, 0.0, 1.0)
    return inside, np.sqrt(prof) * inside


def card(name, w, h, bars, base, seed, plates=(), rough=0.55, metal=0.3):
    """Bars (x0, y0, x1, y1, width in pixels) and plates (polygons) in `base` colour, shaded as
    tubes, the rest cut out (alpha 0)."""
    mask = np.zeros((h, w), np.float32)
    tube = np.zeros((h, w), np.float32)
    for b in bars:
        m, p = bar(w, h, *b)
        mask = np.maximum(mask, m)
        tube = np.maximum(tube, p)
    if plates:
        pm = poly_mask(w, h, plates, blur_px=0.8)
        mask = np.maximum(mask, pm)
        tube = np.maximum(tube, pm * 0.8)
    grime_ = grime(w, h, seed, 0.5, 2.0)
    fine = fbm(w, h, seed + 1, beta=1.0, lo=30.0)
    shade = 0.62 + 0.38 * tube
    col = srgb(base)[None, None, :] * (shade * (1.0 + 0.04 * fine))[..., None]
    col = lerp(col, srgb((96, 92, 86))[None, None, :] * np.ones((h, w, 1)), grime_ * 0.25)
    alpha = np.clip(mask * 1.6, 0, 1)
    rgba = np.concatenate([np.clip(col, 0, 1), alpha[..., None]], -1)
    nrm = normal_from_height(tube * 2.0, 0.6, wrap=True)
    orm = np.stack([np.ones((h, w), np.float32), np.full((h, w), rough, np.float32),
                    np.full((h, w), metal, np.float32)], -1)
    save(name, rgba, nrm, orm)


def xbrace(name='lattice_xbrace', s=512):
    """A square panel: a tubular frame, its two diagonals and an upright through the middle, gusset
    plates at the corners and a round one where the diagonals cross."""
    t = 0.05 * s
    e = t * 0.5
    bars = [(0, e, s, e, t), (0, s - e, s, s - e, t), (e, 0, e, s, t), (s - e, 0, s - e, s, t),
            (e, e, s - e, s - e, 0.75 * t), (s - e, e, e, s - e, 0.75 * t), (s / 2, 0, s / 2, s, 0.6 * t)]
    c = s / 2
    r = 0.09 * s
    hub = [[(c + r * math.cos(a), c + r * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 16, endpoint=False)]]
    g = 0.13 * s
    corners = [[(0, 0), (g, 0), (0, g)], [(s, 0), (s - g, 0), (s, g)], [(0, s), (g, s), (0, s - g)],
               [(s, s), (s - g, s), (s, s - g)]]
    card(name, s, s, bars, (232, 234, 236), 301, hub + corners, rough=0.45, metal=0.2)


def railing(name='lattice_railing', w=1024, h=128):
    """A dark railing 8 m long (u) and 1 m high (v, top at row 0): a top rail, a second rail under
    it with a zig-zag between them, posts every 2 m, a mid rail and a kick rail."""
    t = 0.07 * h
    bars = [(0, t / 2, w, t / 2, t), (0, 0.3 * h, w, 0.3 * h, 0.6 * t), (0, 0.62 * h, w, 0.62 * h, 0.5 * t),
            (0, h - t / 2, w, h - t / 2, t)]
    for k in range(5):
        x = k * w / 4
        bars.append((x, 0, x, h, 0.9 * t))
    n = 16
    for k in range(n):
        x0 = k * w / n
        x1 = (k + 1) * w / n
        bars.append((x0, t, x1, 0.3 * h, 0.4 * t) if k % 2 == 0 else (x0, 0.3 * h, x1, t, 0.4 * t))
    card(name, w, h, bars, (52, 54, 58), 303, rough=0.6, metal=0.1)


def girder(name='lattice_girder', w=1024, h=128):
    """A dark truss girder 8 m long (u) and 1 m deep (v): its two chords, a diagonal every 1 m
    (alternating) and an upright every 2 m."""
    t = 0.1 * h
    bars = [(0, t / 2, w, t / 2, t), (0, h - t / 2, w, h - t / 2, t)]
    for k in range(9):
        x = k * w / 8
        if k % 2 == 0:
            bars.append((x, 0, x, h, 0.8 * t))
        if k < 8:
            x1 = (k + 1) * w / 8
            bars.append((x, t, x1, h - t, 0.6 * t) if k % 2 == 0 else (x, h - t, x1, t, 0.6 * t))
    card(name, w, h, bars, (58, 60, 64), 305, rough=0.6, metal=0.1)


def grate(name='lattice_grate', s=256):
    """A dark grating 1 m square: flat bars 4 cm apart one way, cross rods every 20 cm."""
    bars = []
    for k in range(26):
        y = (k + 0.5) * s / 25
        bars.append((0, y, s, y, 0.012 * s))
    for k in range(6):
        x = (k + 0.5) * s / 5
        bars.append((x, 0, x, s, 0.02 * s))
    card(name, s, s, bars, (46, 47, 50), 307, rough=0.7, metal=0.1)


def plate(name='lattice_plate', w=1024, h=128):
    """A dark girder plate 8 m long (u) and 1 m across (v): solid edges, a panel every 1.1 m (solid
    joints between), each with a close grille along its middle between two long slots (cut out)."""
    t = 0.14 * h
    bars = [(0, t / 2, w, t / 2, t), (0, h - t / 2, w, h - t / 2, t)]
    plates = []
    pw = 1.1 / 8.0 * w
    k = 0
    while k * pw < w:
        x = k * pw
        bars.append((x, 0, x, h, 0.06 / 8.0 * w * 1.0))
        k += 1
    # the grille: a close mesh (solid but for its shading) between two rails
    g0, g1 = 0.32 * h, 0.68 * h
    bars += [(0, g0, w, g0, 0.04 * h), (0, g1, w, g1, 0.04 * h)]
    plates.append([(0, g0), (w, g0), (w, g1), (0, g1)])
    x = 0.0
    while x < w:
        bars.append((x, g0, x, g1, 2.0))
        x += 5.0
    card(name, w, h, bars, (52, 54, 56), 309, plates=plates, rough=0.6, metal=0.1)


if __name__ == '__main__':
    xbrace()
    railing()
    girder()
    grate()
    plate()
