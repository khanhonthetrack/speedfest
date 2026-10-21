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


def inflatable_banner(name='inflatable_banner', w=512, h=432, seed=125):
    """One pillow of the inflatable billboard walls (TMNF's layout; blocks/shapes/inflatable.gd
    maps it per pillow: u across it, v up its surface from the top of the image = the pillow's top,
    6.65 m): glossy red vinyl with welded seams at its sides, a white banner printed on it (from
    1.2 to 4.95 m up the surface, 8.6% in from each side) with our emblem and SPEEDFEST where TMNF
    prints its own logo, a little grime at the foot."""
    from road import emblem
    from livery import fit_font
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    up = (1.0 - (yy + 0.5) / h) * 6.65        # metres up the surface from the pillow's foot
    u = (xx + 0.5) / w
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=1.0, lo=24.0)
    col = srgb((196, 28, 30))[None, None, :] * (1.0 + 0.04 * n1 + 0.02 * n2)[..., None]
    y0, y1 = (1.0 - 4.95 / 6.65) * h, (1.0 - 1.2 / 6.65) * h
    x0, x1 = 0.086 * w, 0.914 * w
    banner = rect_mask(w, h, x0, y0, x1, y1, 2.0)
    col = lerp(col, srgb((236, 236, 232))[None, None, :] * (1.0 + 0.02 * n2)[..., None], banner)
    # a thin grey keyline inside the banner's edge
    key = np.clip(rect_mask(w, h, x0 + 6, y0 + 6, x1 - 6, y1 - 6, 1.0) - rect_mask(w, h, x0 + 9, y0 + 9, x1 - 9, y1 - 9, 1.0), 0, 1)
    col = lerp(col, srgb((150, 150, 150))[None, None, :], key * 0.6)
    bh = y1 - y0
    word = text_mask(w, h, 'SPEEDFEST', fit_font('orbitron-latin-900-normal', 'SPEEDFEST', int(0.54 * (x1 - x0)), int(0.24 * bh)),
                     (x0 + 0.64 * (x1 - x0), y0 + 0.5 * bh), 'mm', italic=0.22)
    mark = emblem(w, h, x0 + 0.2 * (x1 - x0), y0 + 0.5 * bh, 0.2 * bh)
    col = lerp(col, srgb((24, 24, 28))[None, None, :], word)
    col = lerp(col, srgb((196, 28, 30))[None, None, :], mark)
    seam = np.clip(1 - smoothstep(0.0, 0.012, np.minimum(u, 1.0 - u)), 0, 1)
    col *= (1.0 - 0.35 * seam)[..., None]
    scuff = grime(w, h, seed + 2, 0.8, 2.0) * (1.0 - smoothstep(0.0, 0.9, up))
    col = lerp(col, srgb((90, 70, 60))[None, None, :], scuff * 0.3)
    wr = blur(fbm(w, h, seed + 3, beta=1.6, lo=4.0), 1.5)
    nrm = normal_from_height(-2.0 * seam + 0.5 * wr + 0.3 * banner, 0.5)
    rough = 0.32 + 0.1 * n2 + 0.3 * scuff + 0.2 * seam + 0.25 * banner
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
    inflatable_banner()
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
    v round it from the top, ring point i of n), laid out as TMNF's, measured in the world and
    mapped to the texture through the envelope's rings (blocks/data/sculpt_lofts.json): white vinyl
    in gores, a yellow band round it at a constant height (y 29.6..44.2, so the nose and the tail,
    narrower than it, are all yellow), white round the side fins' roots (from a slanted edge to
    z 170.5, below y 39.5), four coloured lights under the band fore and aft; our name in black in
    the band on each side, our emblem in red toward the nose, both projected flat from the side so
    they read upright from outside (the -x side's viewer has the nose on the right). Our own art
    and names."""
    import json
    import os
    from road import emblem
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'blocks', 'data', 'sculpt_lofts.json')
    rings = json.load(open(path))['shapes']['Other/Airship'][0]['rings']
    zs = np.array([float(r[0]) for r in rings])
    pts = np.array([r[1] for r in rings], np.float32).reshape(len(rings), -1, 2)
    n = pts.shape[1]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # each texel's place on the envelope (as sculpt.gd maps it): X, Y, Z
    zz = zs[0] + (xx + 0.5) / w * (zs[-1] - zs[0])
    kf = np.interp(zz, zs, np.arange(len(zs), dtype=np.float32))
    k0 = np.clip(np.floor(kf).astype(int), 0, len(zs) - 2)
    fk = kf - k0
    fi = (yy + 0.5) / h * n
    i0 = np.floor(fi).astype(int) % n
    i1 = (i0 + 1) % n
    fi = fi - np.floor(fi)

    def at(c):
        a = pts[k0, i0, c] * (1 - fi) + pts[k0, i1, c] * fi
        b = pts[k0 + 1, i0, c] * (1 - fi) + pts[k0 + 1, i1, c] * fi
        return a * (1 - fk) + b * fk
    xw, yw = at(0), at(1)
    n1 = fbm(w, h, seed, beta=2.2, lo=1.0)
    wr = blur(fbm(w, h, seed + 1, beta=1.4, lo=6.0), 1.0)
    # the gores' seams: 16 round it, by angle about its axis (the rings' points twist a little)
    g = (np.arctan2(yw - 37.0, xw - 16.04) / (2 * math.pi) * 16) % 1.0
    gore = np.clip(1 - smoothstep(0.0, 0.064, np.minimum(g, 1 - g)), 0, 1)
    col = srgb((244, 242, 240))[None, None, :] * ((1.0 + 0.015 * n1 + 0.01 * wr) * (1 - 0.06 * gore))[..., None]
    yellow = srgb((250, 238, 76))[None, None, :] * (1.0 + 0.02 * n1)[..., None]
    band = smoothstep(29.45, 29.75, yw) * (1 - smoothstep(44.05, 44.35, yw))
    patch = (1 - smoothstep(39.35, 39.65, yw)) * smoothstep(-0.25, 0.25, zz - 124.0 - 2.0 * (yw - 30.0)) * \
        (1 - smoothstep(170.3, 170.7, zz))
    col = lerp(col, yellow, band * (1 - patch))
    # the lights: green to red toward the tail, fore and aft
    lights = [(46, 160, 60), (250, 220, 40), (240, 130, 20), (210, 20, 16)]
    for z0 in (21.2, 115.6):
        for k, c in enumerate(lights):
            za = z0 + 2.8 * k
            m = smoothstep(za - 0.1, za + 0.1, zz) * (1 - smoothstep(za + 2.3, za + 2.5, zz)) * \
                smoothstep(26.5, 26.7, yw) * (1 - smoothstep(27.9, 28.1, yw))
            col = lerp(col, srgb(c)[None, None, :] * np.ones((h, w, 1)), m)
    # the lettering and the emblem, drawn per side as its viewer sees it (ppm px per metre, the
    # image's top at y 56), then sampled at each texel's (Z, Y)
    ppm = 8
    sw, sh = int(186 * ppm), int(46 * ppm)
    fnt = font('orbitron-latin-900-normal', int(10.6 * ppm))

    def side(nose_left):
        zx = (lambda z: z * ppm) if nose_left else (lambda z: (186 - z) * ppm)
        txt = text_mask(sw, sh, 'SPEEDFEST', fnt, (zx(85.0), (56 - 38.8) * ppm), 'mm', italic=0.18, tracking=int(0.5 * ppm))
        em = emblem(sw, sh, zx(24.0), (56 - 34.2) * ppm, 6.6 * ppm)
        return txt, em
    row = np.clip(((56 - yw) * ppm).astype(int), 0, sh - 1)
    txt = np.zeros((h, w), np.float32)
    em = np.zeros((h, w), np.float32)
    for nose_left in (True, False):
        t, e = side(nose_left)
        cc = np.clip(((zz if nose_left else 186 - zz) * ppm).astype(int), 0, sw - 1)
        on = (xw > 16.04) if nose_left else (xw <= 16.04)
        txt = np.where(on, t[row, cc], txt)
        em = np.where(on, e[row, cc], em)
    col = lerp(col, srgb((22, 22, 24))[None, None, :] * np.ones((h, w, 1)), txt)
    col = lerp(col, srgb((206, 16, 14))[None, None, :] * np.ones((h, w, 1)), em)
    dust = grime(w, h, seed + 3, 0.5, 2.0)
    col = lerp(col, srgb((200, 196, 186))[None, None, :] * np.ones((h, w, 1)), dust * 0.08)
    nrm = normal_from_height(0.08 * wr - 0.6 * gore, 0.4)
    rough = 0.3 + 0.12 * dust + 0.1 * gore
    orm = np.stack([np.ones((h, w), np.float32), rough, np.zeros((h, w), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def dirt_bumper(name='dirt_bumper', w=1024, h=256, seed=161):
    """The dirt roads' inflatable logo bumpers (blocks/shapes/dirt.gd: u along the tube, 8 m a
    tile; v round it, 0.25 and 0.75 its two sides): white vinyl with welded seams every 2 m, our
    name in black and our emblem in red twice a tile on each side, the far side's drawn mirrored so
    both read upright from outside. Our own art and names."""
    from road import emblem
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / w * 8.0
    v = yy / h
    n1 = fbm(w, h, seed, beta=2.2, lo=1.0)
    wr = blur(fbm(w, h, seed + 1, beta=1.4, lo=6.0), 1.0)
    seam = 1 - smoothstep(0.0, 0.03, np.abs(((u + 1.0) % 2.0) - 1.0))
    col = srgb((236, 238, 238))[None, None, :] * ((1.0 + 0.02 * n1 + 0.02 * wr) * (1 - 0.1 * seam))[..., None]
    side_h = h // 2
    fnt = font('orbitron-latin-900-normal', int(0.2 * h))
    txt = np.zeros((side_h, w), np.float32)
    em = np.zeros((side_h, w), np.float32)
    for k in range(2):
        x0 = (k * 0.5 + 0.06) * w
        txt = np.maximum(txt, text_mask(w, side_h, 'SPEEDFEST', fnt, (x0 + 0.26 * w, 0.5 * side_h), 'mm', italic=0.18,
                                        tracking=int(0.003 * w)))
        em = np.maximum(em, emblem(w, side_h, x0, 0.5 * side_h, 0.1 * h))
    # side A (v 0..0.5) as drawn, side B mirrored along u
    txt = np.concatenate([txt, txt[:, ::-1]], 0)
    em = np.concatenate([em, em[:, ::-1]], 0)
    col = lerp(col, srgb((22, 22, 24))[None, None, :] * np.ones((h, w, 1)), txt)
    col = lerp(col, srgb((206, 24, 22))[None, None, :] * np.ones((h, w, 1)), em)
    dust = grime(w, h, seed + 3, 0.5, 2.0) * smoothstep(0.4, 0.5, 1 - np.abs(2 * v - 1))     # toward its foot
    col = lerp(col, srgb((150, 130, 100))[None, None, :] * np.ones((h, w, 1)), dust * 0.2)
    nrm = normal_from_height(0.4 * wr - 0.8 * seam, 0.4)
    orm = np.stack([np.ones((h, w), np.float32), 0.35 + 0.15 * dust, np.zeros((h, w), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def roof_glass(name='roof_glass', s=512, seed=171):
    """The grandstand roofs' glass band (env/tm_stadium_build.gd, its front over the field): 32 m
    square, world-mapped from above; dark steel frames every 16 m, mullions and transoms every 4 m,
    grey-teal panes, partly see-through (alpha), a soft sky sheen varying pane to pane."""
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    u = xx / s * 32.0
    v = yy / s * 32.0
    fine = fbm(s, s, seed, beta=1.0, lo=20.0)
    def lines(c, step, half):
        d = np.abs(((c + step / 2) % step) - step / 2)
        return 1 - smoothstep(half, half + 0.05, d)
    main = np.maximum(lines(u, 16.0, 0.3), lines(v, 16.0, 0.3))
    mull = np.maximum(lines(u, 4.0, 0.08), lines(v, 4.0, 0.08))
    frame = np.maximum(main, mull)
    r = rng(seed)
    pane = r.uniform(0.85, 1.15, (8, 8)).astype(np.float32)[np.clip((v / 4).astype(int), 0, 7), np.clip((u / 4).astype(int), 0, 7)]
    glass = srgb((72, 86, 90))[None, None, :] * (pane * (1.0 + 0.04 * fine))[..., None]
    steel = srgb((40, 44, 48))[None, None, :] * (1.0 + 0.05 * fine)[..., None]
    col = lerp(glass, steel, frame[..., None])
    alpha = np.clip(0.62 + 0.38 * frame, 0, 1)
    rgba = np.concatenate([np.clip(col, 0, 1), alpha[..., None]], -1)
    nrm = normal_from_height(1.2 * main + 0.5 * mull, 0.5)
    orm = np.stack([np.ones((s, s), np.float32), 0.15 + 0.45 * frame, 0.3 + 0.3 * frame], -1)
    save(name, rgba, nrm, orm)

