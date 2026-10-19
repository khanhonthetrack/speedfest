"""Tyre marks and wheel smoke (race/tm_tyre_marks.gd), our own art in TMNF's manner: a strip one
tyre wide (x across it, y along the mark, 1 m per texture): rubber laid on asphalt with the tread's
blocks showing, grooves cut into dirt, turf torn up on grass; and a soft puff for the smoke and dust.
RGBA PNGs (alpha = how much of the mark there is).
usage: python3 stadium/tools/texgen/marks.py"""
import numpy as np
from texlib import *


def _edges(w, h, seed, soft=0.18):
    """Across the strip: full in the middle, ragged soft edges (the tyre's shoulders)."""
    xx = (np.arange(w, dtype=np.float32) + 0.5) / w
    rag = blur(fbm(w, h, seed, beta=1.4, lo=2.0), 1.0) * 0.05
    d = np.minimum(xx[None, :], 1.0 - xx[None, :]) + rag
    return smoothstep(0.0, soft, d)


def mark_asphalt(name='mark_asphalt', w=128, h=256, seed=401):
    """Black rubber: the tread's blocks (two rows of slanted blocks a few cm long) printed lighter
    and darker, smeared along the slide, patchy where the tyre skipped."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / w
    v = yy / h
    block = np.sin((v * 22.0 + np.where(u < 0.5, u, -u) * 1.6) * 2.0 * np.pi) * 0.5 + 0.5
    groove = 1.0 - smoothstep(0.0, 0.035, np.abs(u - 0.5))
    smear = blur(fbm(w, h, seed, beta=1.0, lo=8.0), 0.6)
    patch = 0.7 + 0.3 * smoothstep(-1.0, 1.0, fbm(w, h, seed + 1, beta=2.4, lo=1.0, hi=8.0))
    a = _edges(w, h, seed + 2) * (0.55 + 0.25 * block + 0.08 * smear) * (1.0 - 0.6 * groove) * patch
    col = np.zeros((h, w, 3), np.float32) + srgb((14, 12, 12))[None, None, :]
    col *= (1.0 + 0.4 * block)[..., None]
    rgba = np.concatenate([col, np.clip(a * 0.8, 0, 1)[..., None]], -1)
    save(name, np.clip(rgba, 0, 1))


def mark_dirt(name='mark_dirt', w=64, h=256, seed=411):
    """Grooves in packed earth: darker damp soil turned up in fine ridges along the mark, a lighter
    crest at each edge where it was pushed aside."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / w
    ridges = np.sin(u * 2.0 * np.pi * 7.0 + blur(fbm(w, h, seed, beta=1.0, lo=4.0), 1.0) * 0.6) * 0.5 + 0.5
    crest = smoothstep(0.08, 0.0, np.minimum(u, 1.0 - u))
    a = _edges(w, h, seed + 1, soft=0.12) * (0.55 + 0.2 * ridges) + 0.35 * crest
    tone = 0.75 + 0.25 * ridges
    col = srgb((70, 58, 44))[None, None, :] * tone[..., None]
    col = col * (1 - crest[..., None]) + srgb((150, 135, 112))[None, None, :] * crest[..., None]
    rgba = np.concatenate([col, np.clip(a * 0.85, 0, 1)[..., None]], -1)
    save(name, np.clip(rgba, 0, 1))


def mark_grass(name='mark_grass', w=128, h=256, seed=421):
    """Turf torn up: dark flattened blades and bare soil showing through in clumps."""
    soil = smoothstep(-0.2, 1.2, fbm(w, h, seed, beta=1.6, lo=3.0))
    blades = blur(fbm(w, h, seed + 1, beta=0.6, lo=24.0), 0.5)
    a = _edges(w, h, seed + 2, soft=0.25) * (0.5 + 0.3 * soil + 0.1 * blades)
    col = srgb((24, 34, 14))[None, None, :] * (1.0 + 0.25 * blades)[..., None]
    col = col * (1 - soil[..., None]) + srgb((74, 60, 42))[None, None, :] * soil[..., None]
    rgba = np.concatenate([col, np.clip(a * 0.85, 0, 1)[..., None]], -1)
    save(name, np.clip(rgba, 0, 1))


def puff(name='smoke_puff', n=128, seed=431):
    """A soft round puff, lumpy at its edge (tinted per surface by the particles' colour)."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xx - n / 2 + 0.5, yy - n / 2 + 0.5) / (n / 2)
    lump = fbm(n, n, seed, beta=1.8, lo=2.0, hi=24.0)
    a = smoothstep(1.0, 0.25, r + 0.12 * lump) * (0.85 + 0.15 * lump)
    rgba = np.concatenate([np.ones((n, n, 3), np.float32) * (0.92 + 0.08 * lump)[..., None], np.clip(a, 0, 1)[..., None]], -1)
    save(name, np.clip(rgba, 0, 1))


if __name__ == '__main__':
    mark_asphalt()
    mark_dirt()
    mark_grass()
    puff()
