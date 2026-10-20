"""The Stadium around the field (env/tm_stadium_build.gd), our own art: the grandstands' facades
(precast panels, a band of dark glass boxes per floor, railings) and their concrete decks. Both
are mapped in world space (triplanar), so they repeat every tile in every direction.
usage: python3 stadium/tools/texgen/stadium.py"""
import math
import numpy as np
from texlib import *


def facade(name='stadium_facade', ppm=48, size_m=16.0, seed=101):
    """16 m x 16 m: two floors of 8 m; each a glazed band (boxes) over precast panels 4 m x 2 m,
    a railing in front of the glass, rain streaks under the sills."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    um = xx / ppm
    vm = yy / ppm
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.8, lo=32.0)
    fl = vm % 8.0                       # height within a floor, from its top
    conc = srgb((196, 196, 192))[None, None, :] * (1.0 + 0.025 * n1 + 0.03 * n2)[..., None]
    joint_v = 1 - smoothstep(0.0, 0.03, np.abs(((um + 2.0) % 4.0) - 2.0) - 1.985 + 0.0)
    joint_v = np.clip(1 - smoothstep(0.0, 0.04, np.minimum(um % 4.0, 4.0 - um % 4.0)), 0, 1)
    joint_h = np.clip(1 - smoothstep(0.0, 0.04, np.minimum(fl % 2.0, 2.0 - fl % 2.0)), 0, 1)
    glass = ((fl > 1.0) & (fl < 3.4)).astype(np.float32)
    glass = blur(glass, 0.6)
    mull = np.clip(1 - smoothstep(0.0, 0.05, np.minimum(um % 2.0, 2.0 - um % 2.0)), 0, 1) * glass
    rail = np.clip(1 - smoothstep(0.0, 0.03, np.abs(fl - 2.6)), 0, 1) + np.clip(1 - smoothstep(0.0, 0.025, np.abs(fl - 3.35)), 0, 1)
    posts = np.clip(1 - smoothstep(0.0, 0.03, np.minimum(um % 1.0, 1.0 - um % 1.0)), 0, 1) * ((fl > 2.6) & (fl < 3.35))
    # inside the boxes: dark glass with a hint of rooms (lights, people as blobs)
    room = 0.5 + 0.5 * blur(fbm(w, h, seed + 2, beta=2.6, lo=1.0), 2.0)
    sky = 1.0 - (fl - 1.0) / 2.4          # the glass reflects the sky brighter towards its top
    gl = srgb((26, 36, 50))[None, None, :] * (0.85 + 0.15 * room + 0.35 * np.clip(sky, 0, 1))[..., None]
    r = rng(seed + 9)
    bay_lit = r.random((int(size_m / 8.0) + 1, int(size_m / 2.0) + 1)) < 0.3
    lit = bay_lit[np.clip((vm // 8.0).astype(int), 0, bay_lit.shape[0] - 1), np.clip((um // 2.0).astype(int), 0, bay_lit.shape[1] - 1)]
    lit = lit.astype(np.float32) * glass * smoothstep(1.6, 2.2, fl) * (1 - smoothstep(3.0, 3.3, fl))
    gl = lerp(gl, srgb((170, 160, 130))[None, None, :], lit * 0.35)
    col = conc * (1.0 - 0.25 * np.maximum(joint_v, joint_h))[..., None]
    streak = smoothstep(0.4, 1.4, blur(fbm(w, h, seed + 3, beta=1.8, lo=4.0), 1.0) + 0.6 * (1 - smoothstep(3.4, 6.0, fl))) * (fl > 3.4)
    col *= (1.0 - 0.06 * streak)[..., None]
    col = lerp(col, gl, glass)
    col = lerp(col, srgb((60, 62, 66))[None, None, :], np.clip(mull + rail + posts, 0, 1))
    hgt = -1.5 * np.maximum(joint_v, joint_h) - 1.0 * glass + 0.8 * np.clip(mull + rail, 0, 1) + 0.2 * n2
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.82 - 0.75 * glass * (1 - np.clip(mull, 0, 1)) - 0.3 * np.clip(rail + posts, 0, 1)
    metal = 0.3 * glass + 0.6 * np.clip(mull + rail + posts, 0, 1)
    orm = np.stack([1.0 - 0.3 * np.maximum(joint_v, joint_h), np.clip(rough, 0.05, 1), np.clip(metal, 0, 1)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def concrete(name='stadium_concrete', ppm=48, size_m=16.0, seed=111):
    """Decks and tops: light concrete in 4 m slabs, stains, a few drains."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    um = xx / ppm
    vm = yy / ppm
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.8, lo=32.0)
    st = grime(w, h, seed + 2, 1.0, 1.0)
    joint = np.clip(1 - smoothstep(0.0, 0.04, np.minimum(np.minimum(um % 4.0, 4.0 - um % 4.0), np.minimum(vm % 4.0, 4.0 - vm % 4.0))), 0, 1)
    col = srgb((186, 186, 182))[None, None, :] * ((1.0 + 0.04 * n1 + 0.04 * n2) * (1 - 0.08 * st) * (1 - 0.3 * joint))[..., None]
    nrm = normal_from_height(-1.5 * joint + 0.3 * n2, 0.5)
    orm = np.stack([1.0 - 0.3 * joint, 0.85 + 0.05 * n2, np.zeros((h, w))], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    facade()
    concrete()


def inflatable(name='inflatable_vinyl', ppm=48, size_m=8.0, seed=121):
    """The cushion walls' vinyl: one 8 m x 8 m pillow (world-mapped; pillows sit on the 8 m grid):
    glossy red with welded seams at its edges, a white band with a darker pinstripe, scuffs at the
    bottom. No lettering (world mapping would mirror it on one side)."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    um = xx / ppm
    vm = yy / ppm
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=1.0, lo=24.0)
    red = srgb((196, 28, 30))
    col = red[None, None, :] * (1.0 + 0.04 * n1 + 0.02 * n2)[..., None]
    band = rect_mask(w, h, -10, 2.6 * ppm, w + 10, 3.6 * ppm, 1.5)
    pin = rect_mask(w, h, -10, 3.05 * ppm, w + 10, 3.15 * ppm, 1.0)
    col = lerp(col, srgb((238, 238, 236))[None, None, :], band)
    col = lerp(col, srgb((30, 30, 34))[None, None, :], pin)
    seam_v = np.clip(1 - smoothstep(0.0, 0.05, np.minimum(um, size_m - um)), 0, 1)
    seam_h = np.clip(1 - smoothstep(0.0, 0.04, np.minimum(vm, size_m - vm)), 0, 1)
    seam = np.maximum(seam_v, seam_h)
    col *= (1.0 - 0.35 * seam)[..., None]
    scuff = grime(w, h, seed + 2, 0.8, 2.0) * smoothstep(5.5, 8.0, vm)
    col = lerp(col, srgb((90, 70, 60))[None, None, :], scuff * 0.3)
    wr = blur(fbm(w, h, seed + 3, beta=1.6, lo=4.0), 1.5)
    hgt = -2.0 * seam + 0.5 * wr
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.32 + 0.1 * n2 + 0.3 * scuff + 0.2 * seam
    orm = np.stack([1.0 - 0.4 * seam, rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def pillar(name='pillar_steel', ppm=64, size_m=8.0, seed=131):
    """The tube network's pillars and pipes: light grey painted steel, welded rings every 2 m,
    bolts, rain streaks (world-mapped)."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    vm = yy / ppm
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.8, lo=32.0)
    ring = np.clip(1 - smoothstep(0.0, 0.03, np.minimum(vm % 2.0, 2.0 - vm % 2.0)), 0, 1)
    streak = smoothstep(0.5, 1.6, blur(fbm(w, h, seed + 2, beta=1.4, lo=6.0), 0.5) * 0.7 + 0.4 * fbm(w, h, seed + 3, beta=2.0, lo=1.0))
    col = srgb((200, 202, 206))[None, None, :] * ((1.0 + 0.03 * n1 + 0.03 * n2) * (1 - 0.3 * ring) * (1 - 0.08 * streak))[..., None]
    nrm = normal_from_height(1.5 * ring + 0.2 * n2, 0.5)
    orm = np.stack([1.0 - 0.2 * ring, 0.42 + 0.1 * n2 + 0.1 * streak, 0.75 * np.ones_like(n1)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    inflatable()
    pillar()


def inflatable_skin(name='inflatable_skin', ppm=64, size_m=4.0, seed=141):
    """The inflatable decorations' vinyl (world-mapped, tinted per part: TmMaterials): near-white
    glossy skin with soft wrinkles and faint welded seams every 2 m, a little dust."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    um = xx / ppm
    vm = yy / ppm
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=1.0, lo=24.0)
    wr = blur(fbm(w, h, seed + 2, beta=1.6, lo=3.0), 1.5)
    seam = np.clip(1 - smoothstep(0.0, 0.03, np.minimum(vm % 2.0, 2.0 - vm % 2.0)), 0, 1)
    col = srgb((236, 236, 234))[None, None, :] * ((1.0 + 0.025 * n1 + 0.015 * n2 + 0.03 * wr) * (1 - 0.12 * seam))[..., None]
    dust = grime(w, h, seed + 3, 0.6, 2.0)
    col = lerp(col, srgb((200, 196, 186))[None, None, :], dust * 0.15)
    nrm = normal_from_height(0.8 * wr - 1.2 * seam + 0.1 * n2, 0.5)
    rough = 0.3 + 0.08 * n2 + 0.2 * dust + 0.1 * seam
    orm = np.stack([1.0 - 0.2 * seam, rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def airship_skin(name='airship_skin', w=1024, h=512, seed=151):
    """The airship's envelope, UV-mapped (blocks/shapes/sculpt.gd: u along it, nose 0 -> tail 1;
    v round it from the top: 0.25 the -x side, 0.5 the bottom, 0.75 the +x side), laid out as
    TMNF's: white vinyl in gores, a yellow nose cap, a yellow band along each upper flank, our
    name in black on each side with our emblem in red toward the nose. Our own art and names; each
    side's lettering drawn so it reads upright from outside (the +x side's rows run upward, the -x
    side's u toward the nose)."""
    from road import emblem
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / w
    v = yy / h
    n1 = fbm(w, h, seed, beta=2.2, lo=1.0)
    wr = blur(fbm(w, h, seed + 1, beta=1.4, lo=6.0), 1.0)
    gore = np.clip(1 - smoothstep(0.0, 0.004, np.minimum(v % (1 / 16), 1 / 16 - v % (1 / 16))), 0, 1)
    col = srgb((238, 238, 236))[None, None, :] * ((1.0 + 0.02 * n1 + 0.02 * wr) * (1 - 0.08 * gore))[..., None]
    yellow = srgb((236, 214, 22))[None, None, :] * (1.0 + 0.03 * n1)[..., None]
    # the nose cap, its edge a little further back on the flanks than on top and bottom
    nose = 1 - smoothstep(0.0, 0.006, u - (0.100 + 0.018 * np.abs(np.sin(2 * math.pi * v))))
    # the band along each upper flank, from near the top down to above the lettering (-x side:
    # v 0.03..0.165; +x side: v 0.835..0.97), thinning aft
    taper = np.clip(1.0 - (u - 0.10) / 0.85, 0.3, 1.0)
    band = np.zeros((h, w), np.float32)
    for c in (0.0975, 0.9025):
        half = 0.0675 * taper
        band = np.maximum(band, (1 - smoothstep(half - 0.002, half + 0.002, np.abs(v - c))) *
                          smoothstep(0.095, 0.105, u) * (1 - smoothstep(0.86, 0.88, u)))
    col = lerp(col, yellow, np.clip(nose + band, 0, 1))
    # the lettering and the emblem per side, drawn as its viewer sees it, then turned to the texture
    side_h = h // 2
    fnt = font('orbitron-latin-900-normal', int(0.11 * h))

    def side(nose_left):
        word_x = (0.52 if nose_left else 0.48) * w
        em_x = (0.2 if nose_left else 0.8) * w
        txt = text_mask(w, side_h, 'SPEEDFEST', fnt, (word_x, 0.44 * side_h), 'mm', italic=0.18, tracking=int(0.004 * w))
        em = emblem(w, side_h, em_x, 0.44 * side_h, 0.05 * h)
        return txt, em
    t_a, e_a = side(True)            # the +x side's viewer: the nose on the left
    t_b, e_b = side(False)           # the -x side's: the nose on the right
    txt = np.concatenate([t_b[:, ::-1], t_a[::-1, :]], 0)
    em = np.concatenate([e_b[:, ::-1], e_a[::-1, :]], 0)
    col = lerp(col, srgb((22, 22, 24))[None, None, :] * np.ones((h, w, 1)), txt)
    col = lerp(col, srgb((206, 24, 22))[None, None, :] * np.ones((h, w, 1)), em)
    dust = grime(w, h, seed + 3, 0.5, 2.0)
    col = lerp(col, srgb((200, 196, 186))[None, None, :] * np.ones((h, w, 1)), dust * 0.12)
    nrm = normal_from_height(0.6 * wr - 0.8 * gore, 0.4)
    rough = 0.3 + 0.15 * dust + 0.1 * gore
    orm = np.stack([np.ones((h, w), np.float32), rough, np.zeros((h, w), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)
