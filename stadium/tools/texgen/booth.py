"""The control booths' windows, our own drawing in the Stadium's style: one module (2.2 m wide, the
glass's height), laid round the booths (UV-mapped by blocks/shapes/control.gd): dark posts at its
sides, a mullion, two transoms, a dark head with a warm light strip, tinted see-through panes
(alpha: the glass blends, the frame is solid).
usage: python3 stadium/tools/texgen/booth.py"""
import numpy as np
from texlib import *


def booth_window(name='booth_window', w=256, h=512, seed=511):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fine = fbm(w, h, seed, beta=1.0, lo=20.0)
    frame = np.zeros((h, w), np.float32)
    post = 0.055 * w
    frame = np.maximum(frame, rect_mask(w, h, -10, -10, post, h + 10, 0.8))
    frame = np.maximum(frame, rect_mask(w, h, w - post, -10, w + 10, h + 10, 0.8))
    frame = np.maximum(frame, rect_mask(w, h, 0.5 * w - 0.018 * w, -10, 0.5 * w + 0.018 * w, h + 10, 0.8))
    for y in (0.47, 0.67):
        frame = np.maximum(frame, rect_mask(w, h, -10, y * h - 0.008 * h, w + 10, y * h + 0.008 * h, 0.8))
    frame = np.maximum(frame, rect_mask(w, h, -10, h - 0.012 * h, w + 10, h + 10, 0.8))
    head = rect_mask(w, h, -10, -10, w + 10, 0.1 * h, 0.8)
    light = rect_mask(w, h, post, 0.065 * h, w - post, 0.09 * h, 1.2)
    # panes: a cool tint, lighter toward the top (the sky in them), a soft streak of reflection
    sky = 0.55 + 0.2 * (1.0 - yy / h)
    streak = np.clip(1.0 - np.abs((xx - 0.3 * w) + 0.35 * (yy - 0.5 * h)) / (0.08 * w), 0, 1) * 0.15
    pane = np.stack([0.42 * sky, 0.47 * sky, 0.52 * sky], -1) + streak[..., None]
    dark = srgb((34, 35, 38))[None, None, :] * (1.0 + 0.06 * fine)[..., None]
    col = lerp(pane, dark, np.clip(frame + head, 0, 1))
    col = lerp(col, srgb((235, 196, 140))[None, None, :] * np.ones((h, w, 1)), light)
    alpha = np.clip(0.38 + 0.62 * np.clip(frame + head + light, 0, 1), 0, 1)
    rgba = np.concatenate([np.clip(col, 0, 1), alpha[..., None]], -1)
    hgt = 1.2 * np.clip(frame + head, 0, 1)
    nrm = normal_from_height(hgt, 0.5)
    orm = np.stack([np.ones((h, w), np.float32), 0.15 + 0.45 * np.clip(frame + head, 0, 1),
                    0.3 * np.clip(frame + head, 0, 1)], -1)
    save(name, rgba, nrm, orm)


def booth_wall(name='booth_wall', w=1024, h=512, seed=513):
    """The room behind the windows, its wall facing them: 8 m (u) by 4 m (v, top at row 0): light
    concrete panels 2 m wide between dark joints, a dark opening into the back rooms in the middle
    (a rail, consoles and a cabinet in our colours in the gloom), a skirting at the floor."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fine = fbm(w, h, seed, beta=1.0, lo=20.0)
    mott = fbm(w, h, seed + 1, beta=2.2, lo=2.0, hi=24.0)
    col = srgb((168, 168, 164))[None, None, :] * (1.0 + 0.05 * fine + 0.06 * mott)[..., None]
    joints = np.zeros((h, w), np.float32)
    for k in range(5):
        x = k * w / 4
        joints = np.maximum(joints, rect_mask(w, h, x - 3, -10, x + 3, h + 10, 0.8))
    joints = np.maximum(joints, rect_mask(w, h, -10, 0.5 * h - 2, w + 10, 0.5 * h + 2, 0.8))
    col = lerp(col, srgb((92, 92, 90))[None, None, :] * np.ones((h, w, 1)), joints * 0.8)
    x0, x1, y0, y1 = 0.36 * w, 0.64 * w, 0.18 * h, 0.9 * h
    hole = rect_mask(w, h, x0, y0, x1, y1, 1.0)
    inside = srgb((26, 28, 32))[None, None, :] * (1.0 + 0.3 * (yy - y0) / (y1 - y0))[..., None]
    col = lerp(col, inside, hole)
    rail = rect_mask(w, h, x0, 0.62 * h, x1, 0.64 * h, 0.8) + rect_mask(w, h, x0, 0.2 * h, x1, 0.22 * h, 0.8)
    consoles = rect_mask(w, h, x0 + 0.02 * w, 0.72 * h, x1 - 0.02 * w, 0.9 * h, 0.8)
    cabinet = rect_mask(w, h, 0.47 * w, 0.42 * h, 0.53 * w, 0.9 * h, 0.8)
    col = lerp(col, srgb((70, 72, 78))[None, None, :] * np.ones((h, w, 1)), np.clip(rail, 0, 1) * hole)
    col = lerp(col, srgb((52, 54, 60))[None, None, :] * np.ones((h, w, 1)), consoles * hole)
    col = lerp(col, srgb((44, 86, 170))[None, None, :] * np.ones((h, w, 1)), cabinet * hole)
    frame = np.clip(rect_mask(w, h, x0 - 8, y0 - 8, x1 + 8, y1 + 8, 1.0) - hole, 0, 1)
    col = lerp(col, srgb((120, 120, 118))[None, None, :] * np.ones((h, w, 1)), frame)
    skirt = rect_mask(w, h, -10, 0.95 * h, w + 10, h + 10, 0.8)
    col = lerp(col, srgb((60, 60, 62))[None, None, :] * np.ones((h, w, 1)), skirt)
    hgt = -1.0 * joints - 1.5 * hole + 0.5 * frame
    nrm = normal_from_height(hgt, 0.4)
    orm = np.stack([np.ones((h, w), np.float32), 0.8 - 0.3 * hole, np.zeros((h, w), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    booth_window()
    booth_wall()
