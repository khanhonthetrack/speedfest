"""Gate textures (start, checkpoint, finish, lap), our own art in the Stadium's style: moulded
rubber bands with the gate's word repeated (the arch's faces, the gate block's curb faces), the
start and finish pads painted on the road, the checkpoint line.
usage: python3 stadium/tools/texgen/gates.py"""
import math
import numpy as np
from texlib import *

KINDS = {
    # word, ink, band (the word's backing), edge stripe
    'start': ('START', (40, 196, 72), (226, 230, 226), (40, 196, 72)),
    'cp': ('CHECKPOINT', (36, 120, 232), (30, 31, 35), (36, 120, 232)),
    'finish': ('FINISH', (226, 44, 36), (226, 230, 226), (226, 44, 36)),
}


def rubber(w, h, seed, base):
    """Moulded rubber: a base colour with fine ribs along the band, soft mottling, wear."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n1 = fbm(w, h, seed, beta=2.2, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.8, lo=40.0)
    ribs = 0.5 + 0.5 * np.cos(yy * 2 * math.pi / max(h / 40.0, 3.0))
    tone = 1.0 + 0.06 * n1 + 0.05 * n2 + 0.03 * ribs
    return srgb(base)[None, None, :] * tone[..., None], ribs, n2


def band(kind, name, ppm=128, length=8.0, height=1.25, seed=51, word_h=0.62, repeats=1):
    """A band `length` m long (u) and `height` m tall (v): the word in the kind's ink on its
    backing, stripes of the ink colour at both edges, scuffs. Text runs along u."""
    word, ink, back, edge = KINDS[kind]
    w = int(length * ppm)
    h = int(height * ppm)
    col, ribs, n2 = rubber(w, h, seed, back)
    fnt = font('orbitron-latin-900-normal', int(word_h * height * ppm))
    txt = np.zeros((h, w), np.float32)
    for r in range(repeats):
        cx = (r + 0.5) * w / repeats
        m = text_mask(w, h, word, fnt, (cx, h * 0.53), 'mm', italic=0.22, tracking=int(0.015 * ppm))
        txt = np.maximum(txt, m)
    # a dark outline round light-backed words (reads from afar), none on dark backs
    light_back = sum(back) > 400
    if light_back:
        outline = np.clip(blur(txt, 0.035 * height * ppm) * 3.0, 0, 1)
        col = lerp(col, srgb((24, 26, 30))[None, None, :], np.clip(outline - txt, 0, 1) * 0.9)
    worn = smoothstep(0.4, 1.6, fbm(w, h, seed + 2, beta=1.0, lo=10.0)) * 0.35
    col = lerp(col, srgb(ink)[None, None, :] * (1.0 + 0.05 * n2)[..., None], txt * (1.0 - worn))
    s = 0.07 * h
    stripes = np.maximum(rect_mask(w, h, -10, 0.02 * h, w + 10, 0.02 * h + s, 1.0),
                         rect_mask(w, h, -10, 0.98 * h - s, w + 10, 0.98 * h, 1.0))
    col = lerp(col, srgb(edge)[None, None, :], stripes)
    scuff = grime(w, h, seed + 3, 0.7, 2.0)
    col = lerp(col, srgb((70, 68, 64))[None, None, :], scuff * 0.25)
    hgt = 0.6 * ribs + 0.3 * n2 + 1.2 * txt + 0.8 * stripes
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.72 - 0.15 * txt
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(w // 2, h // 2))


def pad(kind, name, ppm=64, across=21.0, depth=8.0, seed=61):
    """A start or finish pad on the road (across x depth m, the line at v = 0.5): the kind's
    colour painted on concrete, a chequered band across, our emblem in the middle, worn by tyres.
    Mapped with the road's UVs: u across, v along."""
    word, ink, back, edge = KINDS[kind]
    w = int(across * ppm)
    h = int(depth * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    conc = srgb((168, 167, 163))
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.7, lo=40.0)
    col = conc[None, None, :] * (1.0 + 0.03 * n1 + 0.04 * n2)[..., None]
    paint = srgb(ink) * 0.82
    # painted panel with a light border, chequers at the line
    panel = rect_mask(w, h, 0.4 * ppm, 0.6 * ppm, w - 0.4 * ppm, h - 0.6 * ppm, 1.5)
    col = lerp(col, paint[None, None, :] * (1.0 + 0.06 * n2)[..., None], panel)
    sq = 1.0 * ppm
    cy = h * 0.5
    chk = ((np.floor(xx / sq) + np.floor((yy - cy) / sq)) % 2 == 0).astype(np.float32)
    inband = rect_mask(w, h, 0.4 * ppm, cy - 1.0 * sq, w - 0.4 * ppm, cy + 1.0 * sq, 1.0)
    col = lerp(col, lerp(srgb((24, 24, 26))[None, None, :] * np.ones((h, w, 1)), srgb((236, 236, 232))[None, None, :] * np.ones((h, w, 1)), chk), inband)
    # our emblem and the word, in white, either side of the line
    em = text_mask(w, h, word, font('orbitron-latin-900-normal', int(1.3 * ppm)), (w * 0.5, h * 0.2), 'mm', italic=0.22)
    em2 = em[::-1, ::-1]   # the same word turned round on the other side of the line
    col = lerp(col, srgb((240, 240, 236))[None, None, :], np.clip(em + em2, 0, 1) * panel)
    # tyre wear: darker, along the driving lines
    lines = 0
    for x in (0.33, 0.67):
        lines = lines + np.exp(-((xx / w - x) / 0.06) ** 2)
    wear = lines * smoothstep(-0.5, 1.2, fbm(w, h, seed + 2, beta=1.4, lo=4.0)) * 0.35
    col *= (1.0 - 0.35 * wear)[..., None]
    worn = smoothstep(1.2, 2.0, fbm(w, h, seed + 3, beta=1.8, lo=3.0)) * 0.6
    col = lerp(col, conc[None, None, :] * (1.0 + 0.04 * n2)[..., None], worn * panel)
    hgt = 0.4 * n2 + 0.5 * panel
    nrm = normal_from_height(hgt, 0.3)
    rough = 0.82 - 0.12 * panel + 0.08 * worn
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(w // 2, h // 2))


def lamp_panel(name='gate_lamps', ppm=256, w_m=2.0, h_m=1.0, seed=71):
    """A light rig's face: 2 x 4 round lamps behind lenses in a dark frame (emission in the
    albedo's alpha-free emission map: we write albedo; the material lights the lenses)."""
    w = int(w_m * ppm)
    h = int(h_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    col = srgb((26, 27, 30))[None, None, :] * (1.0 + 0.05 * fbm(w, h, seed, beta=1.0, lo=8.0))[..., None]
    lens = np.zeros((h, w), np.float32)
    for i in range(4):
        for j in range(2):
            cx = (i + 0.5) * w / 4
            cy = (j + 0.5) * h / 2
            d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (0.19 * ppm)
            lens = np.maximum(lens, 1 - smoothstep(0.92, 1.0, d))
    hot = np.clip(1.0 - np.sqrt(((xx % (w / 4)) - w / 8) ** 2 + ((yy % (h / 2)) - h / 4) ** 2) / (0.19 * ppm), 0, 1)
    col = lerp(col, srgb((250, 246, 228))[None, None, :] * (0.65 + 0.35 * hot)[..., None], lens)
    nrm = normal_from_height(2.0 * lens, 0.3)
    orm = np.stack([np.ones((h, w)), 0.6 - 0.5 * lens, 0.3 * (1 - lens)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)
    # the emission mask
    em = np.stack([lens * (0.7 + 0.3 * hot)] * 3, -1)
    from PIL import Image
    Image.fromarray(to8(em), 'RGB').save(os.path.join(OUT, name + '_emission.jpg'), quality=90)
    write_import(os.path.join(OUT, name + '_emission.jpg'), False)


def line(kind, name, ppm=64, across=21.0, depth=1.0, seed=81):
    """The checkpoint line: a band of the kind's colour across the road, white edges, worn."""
    word, ink, back, edge = KINDS[kind]
    w = int(across * ppm)
    h = int(depth * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    conc = srgb((168, 167, 163))
    n2 = fbm(w, h, seed, beta=0.7, lo=40.0)
    col = conc[None, None, :] * (1.0 + 0.04 * n2)[..., None]
    band_m = rect_mask(w, h, -10, 0.2 * h, w + 10, 0.8 * h, 1.0)
    edges = np.maximum(rect_mask(w, h, -10, 0.1 * h, w + 10, 0.2 * h, 1.0), rect_mask(w, h, -10, 0.8 * h, w + 10, 0.9 * h, 1.0))
    col = lerp(col, srgb(ink)[None, None, :] * 0.9, band_m)
    col = lerp(col, srgb((236, 236, 232))[None, None, :], edges)
    worn = smoothstep(1.0, 2.0, fbm(w, h, seed + 1, beta=1.6, lo=6.0)) * 0.6
    col = lerp(col, conc[None, None, :] * (1.0 + 0.04 * n2)[..., None], worn * (band_m + edges))
    nrm = normal_from_height(0.4 * n2, 0.3)
    rough = 0.8 - 0.1 * band_m
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    for k in KINDS:
        # the arch's faces: the word along the arch (8 m), the arch 1.25 m deep at its faces
        band(k, 'gate_%s' % k, length=8.0, height=1.25, repeats=1)
        # the gate block's curb faces: as the road's curb face (8 m x 1.25 m)
        band(k, 'curb_%s' % k, length=8.0, height=1.25, seed=57, word_h=0.5, repeats=1)
    pad('start', 'pad_start')
    pad('finish', 'pad_finish')
    line('cp', 'line_cp')
    lamp_panel()
