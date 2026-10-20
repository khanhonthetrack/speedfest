"""The control booths' windows, our own drawing in the Stadium's style: one module (2.2 m wide, the
glass's height), laid round the booths (UV-mapped by blocks/shapes/control.gd): dark posts at its
sides, a mullion, two transoms, a dark head with a warm light strip, tinted see-through panes
(alpha: the glass blends, the frame is solid). Also the room behind them, the camera pub's
facade and the camera lights' spotlights.
usage: python3 stadium/tools/texgen/booth.py"""
import os
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
    """The room behind the windows, its wall facing them: 8 m (u) by 4 m (v, top at row 0), dark
    as TMNF's room reads through its glass: a light concrete column every 4 m, between them an
    opening into the gloom of the back rooms (a gallery's rails, consoles, a cabinet in our blue in
    every other one), a skirting at the floor."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fine = fbm(w, h, seed, beta=1.0, lo=20.0)
    mott = fbm(w, h, seed + 1, beta=2.2, lo=2.0, hi=24.0)
    col = srgb((168, 168, 164))[None, None, :] * (1.0 + 0.05 * fine + 0.06 * mott)[..., None]
    joints = rect_mask(w, h, -10, 0.5 * h - 2, w + 10, 0.5 * h + 2, 0.8)
    col = lerp(col, srgb((92, 92, 90))[None, None, :] * np.ones((h, w, 1)), joints * 0.8)
    hole = np.zeros((h, w), np.float32)
    frame = np.zeros((h, w), np.float32)
    y0, y1 = 0.06 * h, 0.94 * h
    for k in range(2):
        x0, x1 = (k + 0.09) * w / 2, (k + 0.91) * w / 2
        hole = np.maximum(hole, rect_mask(w, h, x0, y0, x1, y1, 1.0))
        frame = np.maximum(frame, rect_mask(w, h, x0 - 6, y0 - 6, x1 + 6, y1 + 6, 1.0))
    frame = np.clip(frame - hole, 0, 1)
    inside = srgb((26, 28, 32))[None, None, :] * (1.0 + 0.3 * (yy - y0) / (y1 - y0) + 0.08 * mott)[..., None]
    col = lerp(col, inside, hole)
    rail = rect_mask(w, h, -10, 0.30 * h, w + 10, 0.32 * h, 0.8) + rect_mask(w, h, -10, 0.58 * h, w + 10, 0.60 * h, 0.8)
    posts = np.zeros((h, w), np.float32)
    for k in range(8):
        x = (k + 0.5) * w / 8
        posts = np.maximum(posts, rect_mask(w, h, x - 3, 0.30 * h, x + 3, 0.60 * h, 0.8))
    consoles = np.zeros((h, w), np.float32)
    for k in range(2):
        consoles = np.maximum(consoles, rect_mask(w, h, (k + 0.14) * w / 2, 0.74 * h, (k + 0.86) * w / 2, 0.92 * h, 0.8))
    cabinet = rect_mask(w, h, 0.22 * w, 0.40 * h, 0.28 * w, 0.92 * h, 0.8)
    col = lerp(col, srgb((70, 72, 78))[None, None, :] * np.ones((h, w, 1)), np.clip(rail + posts, 0, 1) * hole)
    col = lerp(col, srgb((52, 54, 60))[None, None, :] * np.ones((h, w, 1)), consoles * hole)
    col = lerp(col, srgb((44, 86, 170))[None, None, :] * np.ones((h, w, 1)), cabinet * hole)
    col = lerp(col, srgb((120, 120, 118))[None, None, :] * np.ones((h, w, 1)), frame)
    skirt = rect_mask(w, h, -10, 0.95 * h, w + 10, h + 10, 0.8)
    col = lerp(col, srgb((60, 60, 62))[None, None, :] * np.ones((h, w, 1)), skirt)
    hgt = -1.0 * joints - 1.5 * hole + 0.5 * frame
    nrm = normal_from_height(hgt, 0.4)
    orm = np.stack([np.ones((h, w), np.float32), 0.8 - 0.3 * hole, np.zeros((h, w), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def pub_facade(name='pub_facade', w=1024, h=256, seed=517):
    """The camera pub's long sides (blocks/shapes/control.gd PUB_ROWS), TMNF's layout in our
    drawing: 32 m (u, the block's length; mirror-symmetric, so either way round reads the same)
    by the section from the roof's edge (v 0) down its rounded top and the facade to its foot
    (rows of 512: 0..58 the rounded edge, 58..103 the lamp strip, 103..512 the facade, 5.207 m):
    light panels with faint joints every 4 m, a lamp housing every 9 m on the strip, a row of six
    dark windows at each end (z 0.25..8.36, 1.56..2.79 m above the foot), grime toward the foot."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    zm = (xx + 0.5) / w * 32.0                    # metres along
    r = (yy + 0.5) / h * 512.0                    # rows of 512
    ym = 2.0 + (512.0 - r) / (512.0 - 103.0) * 5.207      # height on the ground pub's facade
    fine = fbm(w, h, seed, beta=1.0, lo=20.0)
    mott = fbm(w, h, seed + 1, beta=2.2, lo=2.0, hi=24.0)
    col = srgb((219, 219, 217))[None, None, :] * (1.0 + 0.02 * fine + 0.02 * mott)[..., None]
    hgt = np.zeros((h, w), np.float32)
    face = (r >= 103).astype(np.float32)
    joints = np.zeros((h, w), np.float32)
    for k in range(9):
        joints = np.maximum(joints, 1 - smoothstep(0.0, 0.03, np.abs(zm - 4.0 * k)))
    col = lerp(col, srgb((150, 150, 148))[None, None, :] * np.ones((h, w, 1)), (joints * face * 0.5)[..., None])
    hgt -= joints * face
    # the rounded edge: light, a darker line at the roof; the lamp strip under it with housings
    edge = (r < 58).astype(np.float32)
    col = lerp(col, srgb((224, 224, 222))[None, None, :] * (1.0 + 0.02 * fine)[..., None], edge[..., None])
    col = lerp(col, srgb((60, 60, 62))[None, None, :] * np.ones((h, w, 1)), ((r < 6) * 1.0)[..., None])
    strip = ((r >= 58) & (r < 103)).astype(np.float32)
    col = lerp(col, srgb((185, 185, 185))[None, None, :] * (1.0 + 0.03 * fine)[..., None], strip[..., None])
    rail = strip * (1 - smoothstep(0.0, 4.0, np.abs(r - 70.0)))
    col = lerp(col, srgb((96, 96, 98))[None, None, :] * np.ones((h, w, 1)), rail[..., None])
    for zc in (2.5, 11.5, 20.5, 29.5):
        hous = strip * (1 - smoothstep(0.55, 0.6, np.abs(zm - zc))) * smoothstep(74.0, 78.0, r) * (1 - smoothstep(96.0, 100.0, r))
        lens = hous * (1 - smoothstep(0.38, 0.42, np.abs(zm - zc))) * smoothstep(84.0, 86.0, r)
        col = lerp(col, srgb((70, 70, 72))[None, None, :] * np.ones((h, w, 1)), hous[..., None])
        col = lerp(col, srgb((250, 246, 232))[None, None, :] * np.ones((h, w, 1)), lens[..., None])
        hgt += 0.8 * hous
    # the windows: six dark panes a row at each end, dark gaps between them
    win = np.zeros((h, w), np.float32)
    pane = np.zeros((h, w), np.float32)
    for z0 in (0.25, 23.64):
        for k in range(6):
            a = z0 + k * 8.11 / 6.0
            b = a + 8.11 / 6.0
            win = np.maximum(win, rect_mask(w, h, a / 32.0 * w, 0, b / 32.0 * w, h, 0.6) *
                             smoothstep(3.55, 3.57, ym) * (1 - smoothstep(4.78, 4.80, ym)) * face)
            pane = np.maximum(pane, rect_mask(w, h, (a + 0.05) / 32.0 * w, 0, (b - 0.05) / 32.0 * w, h, 0.6) *
                              smoothstep(3.6, 3.62, ym) * (1 - smoothstep(4.73, 4.75, ym)) * face)
    sheen = 1.0 + 0.25 * np.clip((ym - 3.56) / 1.23, 0, 1)
    col = lerp(col, srgb((23, 23, 23))[None, None, :] * np.ones((h, w, 1)), win[..., None])
    col = lerp(col, srgb((44, 44, 46))[None, None, :] * sheen[..., None], pane[..., None])
    hgt -= 1.2 * win
    grime_ = grime(w, h, seed + 2, 0.6, 2.0) * np.clip((2.8 - ym) / 0.8, 0, 1) * face
    col = lerp(col, srgb((120, 116, 108))[None, None, :] * np.ones((h, w, 1)), (grime_ * 0.35)[..., None])
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.6 + 0.1 * mott - 0.45 * pane + 0.1 * grime_
    orm = np.stack([np.ones((h, w), np.float32), np.clip(rough, 0.1, 1.0), 0.3 * pane], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def pub_end(name='pub_end', s=512, seed=519):
    """The camera pub's ends: a dark curtain wall 8 m square (world-mapped), panes 1.6 m wide and
    1.33 m high between lighter mullions, each pane a little different, lighter toward its top."""
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    um = xx / s * 8.0
    vm = yy / s * 8.0
    fine = fbm(s, s, seed, beta=1.0, lo=20.0)
    cu = um / 1.6
    cv = vm / (8.0 / 6.0)
    r = rng(seed)
    shade = r.uniform(0.85, 1.15, (6, 5)).astype(np.float32)
    pane_shade = shade[np.clip(cv.astype(int), 0, 5), np.clip(cu.astype(int), 0, 4)]
    up = 1.0 + 0.35 * (1.0 - (cv % 1.0))
    col = srgb((30, 32, 36))[None, None, :] * (pane_shade * up * (1.0 + 0.03 * fine))[..., None]
    mull = np.maximum(1 - smoothstep(0.03, 0.05, np.minimum(cu % 1.0, 1 - cu % 1.0) * 1.6),
                      1 - smoothstep(0.03, 0.05, np.minimum(cv % 1.0, 1 - cv % 1.0) * (8.0 / 6.0)))
    col = lerp(col, srgb((84, 86, 90))[None, None, :] * np.ones((s, s, 1)), mull[..., None])
    nrm = normal_from_height(1.0 * mull, 0.5)
    orm = np.stack([np.ones((s, s), np.float32), 0.15 + 0.45 * mull, 0.3 * (1 - mull)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def spots(name, length_m, height_m, centres, d_m, w, h, seed):
    """A strip of round spotlights (the camera lights', TMNF's layout): a dark housing with panel
    joints every 2 m, a lens (d_m across, silvery, lit: the emission map) at each centre (metres
    along; across, the strip's middle)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    um = (xx + 0.5) / w * length_m
    vm = (yy + 0.5) / h * height_m
    fine = fbm(w, h, seed, beta=1.0, lo=8.0)
    col = srgb((30, 31, 34))[None, None, :] * (1.0 + 0.06 * fine)[..., None]
    joint = 1 - smoothstep(0.0, 0.03, np.abs(((um + 1.0) % 2.0) - 1.0))
    col = lerp(col, srgb((14, 14, 16))[None, None, :] * np.ones((h, w, 1)), joint[..., None])
    lens = np.zeros((h, w), np.float32)
    rim = np.zeros((h, w), np.float32)
    hot = np.zeros((h, w), np.float32)
    r = 0.5 * d_m
    for c in centres:
        d = np.sqrt((um - c) ** 2 + (vm - 0.5 * height_m) ** 2) / r
        lens = np.maximum(lens, 1 - smoothstep(0.82, 0.9, d))
        rim = np.maximum(rim, (1 - smoothstep(0.98, 1.06, d)) * smoothstep(0.82, 0.9, d))
        hot = np.maximum(hot, np.clip(1.0 - d, 0, 1))
    col = lerp(col, srgb((70, 72, 76))[None, None, :] * np.ones((h, w, 1)), rim[..., None])
    col = lerp(col, srgb((236, 236, 230))[None, None, :] * (0.7 + 0.3 * hot)[..., None], lens[..., None])
    nrm = normal_from_height(2.0 * lens + 1.0 * rim - 0.5 * joint, 0.3)
    orm = np.stack([np.ones((h, w), np.float32), 0.6 - 0.45 * lens, 0.3 + 0.4 * rim], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)
    em = np.stack([lens * (0.6 + 0.4 * hot)] * 3, -1)
    from PIL import Image
    Image.fromarray(to8(em), 'RGB').save(os.path.join(OUT, name + '_emission.jpg'), quality=90)
    write_import(os.path.join(OUT, name + '_emission.jpg'), False)


def camera_spots():
    """The camera lights' top bar nose (32 m, 0.5 m high: four lamps in a group, a group every ~10 m,
    mirror-symmetric) and a floodlight bank's face (6.56 m by 0.9 m: six pairs of lamps)."""
    nose = []
    for g in (1.05, 10.95, 21.05, 30.95):
        nose += [g + o for o in (-0.645, -0.215, 0.215, 0.645)]
    spots('spots_nose', 32.0, 0.5, nose, 0.36, 2048, 32, 521)
    bank = []
    for k in range(6):
        c = (k + 0.5) * 6.56 / 6
        bank += [c - 0.2, c + 0.2]
    spots('spots_bank', 6.56, 0.9, bank, 0.34, 1024, 140, 523)


if __name__ == '__main__':
    booth_window()
    booth_wall()
    pub_facade()
    pub_end()
    camera_spots()
