"""Gate textures (start, checkpoint, finish, lap), our own art in the Stadium's style: moulded
rubber bands with the gate's word repeated (the arch's faces, the gate block's curb faces), the
start and finish roads (TMNF's RoadRace layout).
usage: python3 stadium/tools/texgen/gates.py"""
import math
import numpy as np
from texlib import *

KINDS = {
    # word, ink, band (the word's backing), lines along the band ((top, bottom) as shares of its
    # height, colour): TMNF's RaceSigns layout (START green on white under one green line, FINISH
    # white on red between white lines, CHECKPOINT blue on dark between blue lines)
    'start': ('START', (52, 168, 64), (228, 226, 222), [((0.07, 0.12), (52, 168, 64))]),
    'cp': ('CHECKPOINT', (44, 96, 214), (34, 34, 37), [((0.15, 0.19), (44, 96, 214)), ((0.86, 0.90), (44, 96, 214))]),
    'finish': ('FINISH', (242, 240, 236), (196, 28, 22), [((0.15, 0.18), (242, 240, 236)), ((0.89, 0.92), (242, 240, 236))]),
    # MULTILAP yellow on dark under a yellow line, over a chequered strip
    'lap': ('MULTILAP', (226, 200, 34), (34, 34, 37), [((0.12, 0.16), (226, 200, 34))], (0.80, 0.94)),
}


def rubber(w, h, seed, base):
    """Moulded rubber: a base colour with fine ribs along the band, soft mottling, wear."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n1 = fbm(w, h, seed, beta=2.2, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.8, lo=40.0)
    ribs = 0.5 + 0.5 * np.cos(yy * 2 * math.pi / max(h / 40.0, 3.0))
    tone = 1.0 + 0.06 * n1 + 0.05 * n2 + 0.03 * ribs
    return srgb(base)[None, None, :] * tone[..., None], ribs, n2


def band(kind, name, ppm=128, length=8.0, height=1.25, seed=51, word_h=0.62, repeats=1, fit=1.0, joints=False):
    """A band `length` m long (u) and `height` m tall (v): the word in the kind's ink on its
    backing (`repeats` times, each condensed to at most `fit` of its slot's width, as TMNF's
    long words), the kind's lines along it (and its chequered strip), scuffs; with `joints` a
    raised joint between the slots (TMNF's sign panels). Text runs along u."""
    word, ink, back, lines = KINDS[kind][:4]
    w = int(length * ppm)
    h = int(height * ppm)
    col, ribs, n2 = rubber(w, h, seed, back)
    tracking = int(0.015 * ppm)
    fnt = font('orbitron-latin-900-normal', int(word_h * height * ppm))
    probe = ImageDraw.Draw(Image.new('L', (8, 8)))
    wide = probe.textlength(word, font=fnt) + tracking * (len(word) - 1)
    pad = h
    one = text_mask(int(wide) + 2 * pad, h, word, fnt, (wide / 2 + pad, h * 0.53), 'mm', italic=0.22, tracking=tracking)
    squeeze = min(1.0, fit * w / repeats / wide)
    one = np.asarray(Image.fromarray(to8(one)).resize((int(one.shape[1] * squeeze), h), Image.LANCZOS),
                     np.float32) / 255.0
    txt = np.zeros((h, w), np.float32)
    for r in range(repeats):
        x0 = int((r + 0.5) * w / repeats - one.shape[1] / 2)
        a, b = max(x0, 0), min(x0 + one.shape[1], w)
        txt[:, a:b] = np.maximum(txt[:, a:b], one[:, a - x0:b - x0])
    # a dark outline round light-backed words (reads from afar), none on dark backs
    light_back = sum(back) > 400
    if light_back:
        outline = np.clip(blur(txt, 0.035 * height * ppm) * 3.0, 0, 1)
        col = lerp(col, srgb((24, 26, 30))[None, None, :], np.clip(outline - txt, 0, 1) * 0.9)
    worn = smoothstep(0.4, 1.6, fbm(w, h, seed + 2, beta=1.0, lo=10.0)) * 0.35
    col = lerp(col, srgb(ink)[None, None, :] * (1.0 + 0.05 * n2)[..., None], txt * (1.0 - worn))
    stripes = np.zeros((h, w), np.float32)
    for (y0, y1), c in lines:
        m = rect_mask(w, h, -10, y0 * h, w + 10, y1 * h, 1.0)
        col = lerp(col, srgb(c)[None, None, :], m * (1.0 - worn))
        stripes = np.maximum(stripes, m)
    if len(KINDS[kind]) > 4:
        # two rows of black and white squares
        y0, y1 = KINDS[kind][4]
        sq = (y1 - y0) * h / 2.0
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        white = (np.floor(xx / sq) + np.floor((yy - y0 * h) / sq)) % 2 == 0
        m = rect_mask(w, h, -10, y0 * h, w + 10, y1 * h, 0.8)
        sqc = np.where(white[..., None], srgb((222, 222, 218))[None, None, :], srgb((20, 20, 22))[None, None, :])
        col = lerp(col, sqc, m * (1.0 - 0.6 * worn))
        stripes = np.maximum(stripes, m)
    scuff = grime(w, h, seed + 3, 0.7, 2.0)
    col = lerp(col, srgb((70, 68, 64))[None, None, :], scuff * 0.25)
    joint = np.zeros((h, w), np.float32)
    if joints:
        # a light metal strip 4 cm wide, a dark seam either side
        for r in range(repeats + 1):
            x = r * w / repeats
            joint = np.maximum(joint, rect_mask(w, h, x - 0.02 * ppm, -10, x + 0.02 * ppm, h + 10, 0.8))
            seam = rect_mask(w, h, x - 0.035 * ppm, -10, x + 0.035 * ppm, h + 10, 0.8) - joint
            col = lerp(col, srgb((14, 14, 16))[None, None, :], np.clip(seam, 0, 1) * 0.8)
        col = lerp(col, srgb((150, 152, 156))[None, None, :] * (1.0 + 0.08 * n2)[..., None], joint)
    hgt = 0.6 * ribs + 0.3 * n2 + 1.2 * txt + 0.8 * stripes + 1.5 * joint
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.72 - 0.15 * txt - 0.3 * joint
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(w // 2, h // 2))


# TMNF's start and finish roads (its RoadRace texture's layout and colours, measured; our own art):
# the paint toward the edge and at the centre line, the edge's tinted light line, the dark band
RACE = {
    'start': ((40, 120, 60), (37, 135, 60), (35, 147, 64), (149, 169, 151), (56, 93, 62)),
    'finish': ((140, 41, 40), (152, 35, 35), (165, 31, 33), (176, 153, 150), (102, 64, 58)),
}


def race_road(kind, name, w=256, h=512, seed=91):
    """A start or finish road: u along the road (6 m a tile), v from the road's edge (row 0) to its
    centre line (row h, 10.46 m; mirrored on the other half). From the edge: a dark rim, a light
    line, a dark band, a chequered strip two squares wide (0.65 m squares, eight a tile), a dark
    line, three of our chevrons pointing down the road, then the paint (darker toward the edge,
    lighter in the middle 3 m), with tyre streaks along the road."""
    edge_c, mid_c, centre_c, light_c, band_c = RACE[kind]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    s = h / 512.0
    r = yy / s                      # the row on a 512-row half
    fine = fbm(w, h, seed, beta=0.7, lo=60.0)
    mott = fbm(w, h, seed + 1, beta=2.2, lo=2.0, hi=40.0)
    paint = lerp(srgb(edge_c)[None, None, :] * np.ones((h, w, 1)), srgb(mid_c)[None, None, :] * np.ones((h, w, 1)),
                 smoothstep(116.0, 170.0, r))
    paint = lerp(paint, srgb(centre_c)[None, None, :] * np.ones((h, w, 1)), smoothstep(412.0, 428.0, r))
    col = paint * (1.0 + 0.05 * mott + 0.04 * fine)[..., None]
    def stripe(r0, r1, c):
        m = rect_mask(w, h, -10, r0 * s, w + 10, r1 * s, 0.8)
        return lerp(col, srgb(c)[None, None, :] * (1.0 + 0.05 * fine)[..., None], m)
    col = stripe(-10, 4, (59, 56, 55))
    col = stripe(4, 14, light_c)
    col = stripe(14, 30, band_c)
    sq = w / 8.0
    chk = ((np.floor(xx / sq) + np.floor((r - 30.0) / 32.0)) % 2 == 0).astype(np.float32)
    strip = rect_mask(w, h, -10, 30 * s, w + 10, 94 * s, 0.6)
    squares = lerp(srgb((37, 38, 36))[None, None, :] * np.ones((h, w, 1)),
                   srgb((186, 187, 184))[None, None, :] * np.ones((h, w, 1)), chk)
    col = lerp(col, squares * (1.0 + 0.05 * fine)[..., None], strip)
    col = stripe(94, 100, (69, 64, 62))
    # our chevrons, white, once a tile (where TMNF has its small mark)
    polys = []
    for i in range(3):
        x0 = (90 + i * 30) * w / 256.0
        y0, y1 = 102 * s, 120 * s
        cy = 0.5 * (y0 + y1)
        polys.append([(x0, y0), (x0 + 8 * w / 256.0, y0), (x0 + 20 * w / 256.0, cy), (x0 + 8 * w / 256.0, y1),
                      (x0, y1), (x0 + 12 * w / 256.0, cy)])
    mark = poly_mask(w, h, polys, blur_px=0.6)
    col = lerp(col, srgb((198, 194, 192))[None, None, :] * (1.0 + 0.04 * fine)[..., None], mark)
    # tyre streaks along the road (rows of dark and light), stronger toward the driving lines
    g = rng(seed + 2)
    rows = blur(np.tile(g.standard_normal((h, 1)).astype(np.float32), (1, w)), 0.6)
    along = 0.5 + 0.5 * fbm(w, h, seed + 3, beta=2.0, lo=1.0, hi=6.0)
    streak = np.clip(rows * along, -2.5, 2.5)
    col *= (1.0 + 0.045 * streak)[..., None]
    dirt = grime(w, h, seed + 4, amount=0.6)
    col = lerp(col, srgb((60, 58, 54))[None, None, :] * np.ones((h, w, 1)), dirt * 0.18)
    hgt = 0.3 * fine + 0.2 * streak + 0.4 * strip + 0.4 * mark
    nrm = normal_from_height(hgt, 0.25)
    orm = np.stack([np.ones((h, w), np.float32), 0.78 - 0.1 * strip - 0.08 * mark + 0.04 * dirt,
                    np.zeros((h, w), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


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


if __name__ == '__main__':
    for k in KINDS:
        # the arch's faces: the word along the arch every 3.08 m (TMNF's), condensed as TMNF's;
        # the arch 1.25 m deep at its faces
        band(k, 'gate_%s' % k, length=3.08, height=1.25, repeats=1, fit=0.94)
        # the gate block's curb faces (both: towards the road and outside), as TMNF's RaceSigns:
        # the word every 4 m on its panel (16 m a tile, UV-mapped as the border atlas: road.gd
        # _entry), the band across the face (1.15 m)
        band(k, 'curb_%s' % k, length=16.0, height=1.15, seed=57, word_h=0.6, repeats=4, fit=0.9, joints=True)
    race_road('start', 'race_start')
    race_road('finish', 'race_finish')
    lamp_panel()
