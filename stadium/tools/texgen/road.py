"""Road (Road/Main) textures, our own art in the Stadium's style: light weathered concrete, the curb's
dark rubber face with our emblem, the green shoulder with a blue line, the curb's light top, the
road's edge lip. Sizes in metres are what one texture covers (TmMaterials uv scales).
usage: python3 stadium/tools/texgen/road.py"""
import math
import numpy as np
from texlib import *


def concrete(name='road_concrete', size=2048, metres=16.0, seed=11, base=(168, 167, 163), joints=True):
    """Light concrete slabs: macro tone variation, stains, aggregate, pits, hairline cracks and
    joints every 8 m (both ways)."""
    w = h = size
    px = size / metres
    macro = fbm(w, h, seed, beta=2.8, lo=1.0, hi=24.0)
    mid = fbm(w, h, seed + 1, beta=2.0, lo=4.0, hi=96.0)
    fine = fbm(w, h, seed + 2, beta=0.6, lo=64.0)
    stains = grime(w, h, seed + 3, 1.0, 1.5)
    pits = speckles(w, h, seed + 4, 0.0009, 0.8, 2.2)
    light = speckles(w, h, seed + 5, 0.0006, 0.6, 1.6)
    crk = blur(cracks(w, h, seed + 6, 5, 40, jitter=0.22), 0.8) * 0.35
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    jw = 0.012 * px
    joint = np.zeros((h, w), np.float32)
    if joints:
        for k in range(int(metres / 8.0)):
            c = (k * 8.0 + 0.0) * px
            joint = np.maximum(joint, 1 - smoothstep(0, jw, np.abs(xx - c)))
            joint = np.maximum(joint, 1 - smoothstep(0, jw, np.abs(yy - c)))
    tone = 1.0 + 0.03 * macro + 0.018 * mid + 0.045 * fine
    tone *= 1.0 - 0.045 * stains - 0.22 * pits + 0.10 * light
    tone *= 1.0 - 0.35 * crk - 0.45 * joint
    col = srgb(base)[None, None, :] * tone[..., None]
    # a faint warm/cool drift
    col[..., 0] *= 1.0 + 0.012 * macro
    col[..., 2] *= 1.0 - 0.012 * macro
    height = 0.6 * fine + 0.25 * mid - 2.5 * pits - 3.0 * crk - 4.0 * joint
    nrm = normal_from_height(height, 0.35)
    rough = 0.84 + 0.05 * fine - 0.10 * stains + 0.08 * joint
    orm = np.stack([1.0 - 0.35 * joint - 0.25 * crk - 0.2 * pits, rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(1024, 1024))


def emblem(w, h, cx, cy, s):
    """Our emblem: a slanted parallelogram frame with 'SF' inside (as in the game's icon); mask."""
    k = 0.42                                # slant
    outer = [(cx - s * 1.0 + k * s * 0.5, cy - s * 0.5), (cx + s * 1.0 + k * s * 0.5, cy - s * 0.5),
             (cx + s * 1.0 - k * s * 0.5, cy + s * 0.5), (cx - s * 1.0 - k * s * 0.5, cy + s * 0.5)]
    t = s * 0.13
    inner = [(x + (t if i in (0, 3) else -t) * (1 if i in (0, 3) else 1), y + (t if i < 2 else -t))
             for i, (x, y) in enumerate(outer)]
    inner = [(outer[0][0] + t * 1.4, outer[0][1] + t), (outer[1][0] - t * 0.6, outer[1][1] + t),
             (outer[2][0] - t * 1.4, outer[2][1] - t), (outer[3][0] + t * 0.6, outer[3][1] - t)]
    frame = np.clip(poly_mask(w, h, [outer]) - poly_mask(w, h, [inner]), 0, 1)
    letters = text_mask(w, h, 'SF', font('orbitron-latin-900-normal', int(s * 0.78)), (cx, cy), 'mm', italic=0.32)
    return np.clip(frame + letters, 0, 1)


def curb_face(name='road_curb_face', ppm=256, length=8.0, height=1.25, seed=21):
    """The curb's face toward the road: dark moulded rubber with fine horizontal ribs, our emblem
    and SPEEDFEST every 8 m, a blue stripe low down, tyre scuffs and dust at the foot.
    v = 0 at the top of the face (where the light top ends), down to the road."""
    w = int(length * ppm)
    h = int(height * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = yy / ppm
    base = srgb((34, 35, 38))
    n1 = fbm(w, h, seed, beta=2.2, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.8, lo=40.0)
    ribs = 0.5 + 0.5 * np.cos(v * 2 * math.pi / 0.035)
    tone = 1.0 + 0.08 * n1 + 0.06 * n2 + 0.05 * ribs
    col = base[None, None, :] * tone[..., None]
    # the emblem and the wordmark, light grey, centred on the face, once per tile
    logo = emblem(w, h, 0.62 * ppm, 0.50 * ppm, 0.34 * ppm)
    word = text_mask(w, h, 'SPEEDFEST', font('orbitron-latin-900-normal', int(0.26 * ppm)), (1.0 * ppm, 0.50 * ppm),
                     'lm', italic=0.25, tracking=int(0.02 * ppm))
    word2 = text_mask(w, h, 'STADIUM', font('rajdhani-latin-700-normal', int(0.20 * ppm)), (4.6 * ppm, 0.50 * ppm),
                      'lm', tracking=int(0.06 * ppm))
    paint = np.clip(logo + word + 0.85 * word2, 0, 1)
    wear = smoothstep(0.3, 1.5, fbm(w, h, seed + 2, beta=1.0, lo=12.0))
    paint *= 1.0 - 0.45 * wear
    col = lerp(col, srgb((196, 198, 200))[None, None, :], paint)
    # the blue stripe low on the face, and a thin light line under the top
    stripe = rect_mask(w, h, -10, 0.94 * ppm, w + 10, 1.02 * ppm, 1.2)
    top = rect_mask(w, h, -10, 0.02 * ppm, w + 10, 0.045 * ppm, 1.0)
    col = lerp(col, srgb((28, 92, 196))[None, None, :], stripe * (1.0 - 0.35 * wear))
    col = lerp(col, srgb((150, 152, 156))[None, None, :], top)
    # scuffs and dust towards the road
    foot = smoothstep(0.85, 1.22, v)
    dust = grime(w, h, seed + 3, 1.0, 2.0) * foot
    scuff = smoothstep(0.6, 1.8, fbm(w, h, seed + 4, beta=1.6, lo=3.0)) * smoothstep(0.55, 1.1, v) * 0.6
    col = lerp(col, srgb((96, 92, 86))[None, None, :], np.clip(dust * 0.7, 0, 1))
    col *= (1.0 - 0.35 * scuff)[..., None]
    height_map = 0.8 * ribs + 0.3 * n2 + 1.5 * paint
    nrm = normal_from_height(height_map, 0.6)
    rough = 0.78 - 0.18 * paint + 0.1 * dust - 0.05 * ribs
    orm = np.stack([1.0 - 0.15 * (1 - ribs), rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(w // 2, h // 2))


def shoulder(name='road_shoulder', ppm=256, length=8.0, width=2.0, seed=31):
    """The shoulder between the curb and the road: painted green concrete, a blue line along the
    curb, paint worn through to the concrete in patches, dust. v = 0 at the curb, towards the road."""
    w = int(length * ppm)
    h = int(width * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = yy / ppm
    conc = srgb((150, 149, 145))
    green = srgb((54, 132, 64))
    blue = srgb((30, 92, 200))
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.7, lo=48.0)
    worn = smoothstep(1.3, 2.2, fbm(w, h, seed + 2, beta=2.2, lo=2.0) + 0.15 * n2) * 0.8
    line = rect_mask(w, h, -10, 0.06 * ppm, w + 10, 0.24 * ppm, 1.2)
    col = lerp(green[None, None, :] * (1.0 + 0.07 * n1 + 0.05 * n2)[..., None],
               blue[None, None, :] * (1.0 + 0.05 * n2)[..., None], line)
    col = lerp(col, conc[None, None, :] * (1.0 + 0.06 * n2)[..., None], worn)
    dust = grime(w, h, seed + 3, 0.8, 2.0)
    col = lerp(col, srgb((120, 116, 104))[None, None, :], dust * 0.45)
    # the drain slots along the curb's foot, every 0.5 m
    slot = np.zeros((h, w), np.float32)
    for k in range(int(length / 0.5)):
        slot = np.maximum(slot, rect_mask(w, h, (k * 0.5 + 0.1) * ppm, 0.005 * ppm, (k * 0.5 + 0.38) * ppm, 0.045 * ppm, 1.0))
    col *= (1.0 - 0.75 * slot)[..., None]
    hgt = 0.4 * n2 - 3.0 * slot - 0.4 * worn
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.72 + 0.12 * worn + 0.08 * dust
    orm = np.stack([1.0 - 0.5 * slot, rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(w // 2, h // 2))


def curb_top(name='road_curb_top', ppm=256, length=8.0, width=1.5, seed=41):
    """The curb's rounded top and outer lip: light concrete, cast in 2 m sections (joints), a row
    of anchor bolts, weathering. v = 0 at the outer edge."""
    w = int(length * ppm)
    h = int(width * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.7, lo=48.0)
    stains = grime(w, h, seed + 2, 1.0, 2.0)
    joint = np.zeros((h, w), np.float32)
    for k in range(int(length / 2.0) + 1):
        joint = np.maximum(joint, 1 - smoothstep(0, 0.01 * ppm, np.abs(xx - k * 2.0 * ppm)))
    bolts = np.zeros((h, w), np.float32)
    for k in range(int(length / 1.0)):
        cx = (k + 0.5) * ppm
        cy = 0.62 * ppm
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        bolts = np.maximum(bolts, 1 - smoothstep(0.018 * ppm, 0.024 * ppm, d))
    tone = (1.0 + 0.05 * n1 + 0.05 * n2) * (1 - 0.12 * stains) * (1 - 0.5 * joint)
    col = srgb((206, 206, 203))[None, None, :] * tone[..., None]
    col = lerp(col, srgb((92, 94, 98))[None, None, :], bolts)
    # rain streaks down the outer side (v small), darker
    streak = smoothstep(0.2, 1.4, fbm(w, h, seed + 3, beta=2.0, lo=2.0) * 0.5 + blur(fbm(w, h, seed + 4, beta=0.5, lo=30.0), 3) * 0.0 + 0.3) * (1 - smoothstep(0.0, 0.5, yy / ppm))
    col *= (1.0 - 0.18 * streak)[..., None]
    hgt = 0.4 * n2 - 3.0 * joint + 2.0 * bolts
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.80 - 0.3 * bolts + 0.05 * stains
    orm = np.stack([1.0 - 0.3 * joint, rough, 0.8 * bolts], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(w // 2, h // 2))


if __name__ == '__main__':
    concrete()
    curb_face()
    shoulder()
    curb_top()
