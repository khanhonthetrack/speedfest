"""Road decals, our own art: tyre marks a drifting car leaves through a curve (two tracks 1.77 m
apart, TMNF's track width), the burnout at the start, an oil stain, rubber scuffed onto a curb top.
RGBA albedo only (dark rubber, alpha = how much mark): blocks/tm_road_decals.gd projects them.
Their edges fade to nothing (decals don't tile). Sizes are what one texture covers.
usage: python3 stadium/tools/texgen/decals.py"""
import numpy as np
from texlib import *

RUBBER = np.array([0.018, 0.018, 0.020], np.float32)    # linear-ish dark rubber (saved as sRGB)


def _fade(n, edge):
    """1 in the middle, smoothly 0 over `edge` (fraction) at both ends, length n."""
    t = (np.arange(n, dtype=np.float32) + 0.5) / n
    return smoothstep(0.0, edge, t) * smoothstep(0.0, edge, 1.0 - t)


def _save(name, alpha):
    h, w = alpha.shape
    col = np.empty((h, w, 4), np.float32)
    col[..., :3] = RUBBER
    col[..., 3] = np.clip(alpha, 0.0, 1.0)
    save(name, col)


def skid(name='decal_skid', w=256, h=1024, width=2.6, length=10.0, seed=41):
    """Two tyre tracks along v: streaky rubber with tread lines, broken where the tyre gripped,
    the tracks wavering a little; strongest in the middle of the slide."""
    r = rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ppm = w / width
    along = fbm(w, h, seed, beta=3.0, lo=1.0, hi=5.0)
    wobble = blur(fbm(w, h, seed + 1, beta=3.0, lo=1.0, hi=4.0), 2.0)
    streak = fbm(w, h, seed + 2, beta=1.0, lo=8.0)
    alpha = np.zeros((h, w), np.float32)
    for side in (-1.0, 1.0):
        cx = w * 0.5 + side * 0.885 * ppm + wobble[:, :1] * 0.025 * ppm
        half = 0.18 * ppm * (1.0 + 0.04 * along[:, :1])
        d = np.abs(xx - cx)
        track = 1.0 - smoothstep(half * 0.65, half, d)
        tread = 0.75 + 0.25 * np.sin(2.0 * np.pi * (xx - cx) / (0.04 * ppm))
        alpha = np.maximum(alpha, track * tread)
    density = (0.6 + 0.4 * smoothstep(-1.2, 0.8, along)) * (0.85 + 0.15 * smoothstep(-1.0, 1.0, streak))
    alpha *= density * _fade(h, 0.25)[:, None] * _fade(w, 0.08)[None, :]
    _save(name, alpha)


def burnout(name='decal_burnout', w=512, h=512, seed=43):
    """The start's rubber: two dark patches where the rear wheels spin off the line (1.77 m apart
    on a 3 x 3 m decal), densest behind, thinning out forward into two short tracks."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ppm = w / 3.0
    blot = fbm(w, h, seed, beta=3.0, lo=1.0, hi=10.0)
    fine = fbm(w, h, seed + 1, beta=0.8, lo=32.0)
    alpha = np.zeros((h, w), np.float32)
    for side in (-1.0, 1.0):
        cx = w * 0.5 + side * 0.885 * ppm
        d = np.abs(xx - cx) / (0.30 * ppm)
        forward = yy / h                       # 0 behind (start), 1 ahead
        core = (1.0 - smoothstep(0.55, 1.0 + 0.2 * np.clip(blot, -1.0, 1.0), d)) * (1.0 - smoothstep(0.25, 0.95, forward))
        alpha = np.maximum(alpha, core)
    alpha *= 0.75 + 0.25 * smoothstep(-1.0, 1.0, fine)
    alpha *= _fade(h, 0.12)[:, None] * _fade(w, 0.1)[None, :]
    _save(name, alpha * 0.9)


def stain(name='decal_stain', w=512, h=512, seed=47):
    """An oil stain: an irregular blot with a darker rim and a few drips (2.5 m across)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rr = np.hypot(xx - w * 0.5, yy - h * 0.5) / (w * 0.5)
    shape = fbm(w, h, seed, beta=2.6, lo=1.0, hi=16.0)
    edge = 0.62 + 0.14 * shape
    inside = 1.0 - smoothstep(edge - 0.08, edge, rr)
    rim = inside * smoothstep(edge - 0.2, edge - 0.04, rr)
    drops = speckles(w, h, seed + 1, 0.00025, 1.5, 4.0) * (1.0 - smoothstep(0.7, 0.95, rr))
    alpha = 0.32 * inside + 0.25 * rim + 0.5 * drops
    alpha *= 0.85 + 0.15 * fbm(w, h, seed + 2, beta=1.0, lo=16.0)
    _save(name, alpha)


def scuff(name='decal_scuff', w=256, h=512, seed=53):
    """Rubber wiped onto a curb top by a wheel cutting the apex: a smear along v (1 x 4 m)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    smear = fbm(w, h, seed, beta=1.6, lo=2.0, hi=40.0)
    lines = 0.7 + 0.3 * np.sin(2.0 * np.pi * xx / 7.0 + smear * 2.0)
    alpha = smoothstep(-0.4, 0.8, smear) * lines * _fade(h, 0.3)[:, None] * _fade(w, 0.25)[None, :]
    _save(name, alpha * 0.8)


if __name__ == '__main__':
    skid()
    burnout()
    stain()
    scuff()
