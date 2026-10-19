"""The platform and circuit blocks' surfaces, our own art in the Stadium's look (M9-2): the decks'
light steel plate (one texture per 32 m block, its seam on the block's edge) with a fine tread
pattern as a detail map, the platforms' dark concrete walls, and the circuit walls' white cladding,
blue band with our logo and dark steel truss. Colours measured from TMNF's renders (TmMaterials).
usage: python3 stadium/tools/texgen/decks.py"""
import math
import numpy as np
from PIL import Image, ImageDraw
from texlib import *


def blur_xy(a, sx, sy):
    """Tileable Gaussian blur with its own sigma (pixels) along x and y (streaks)."""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * math.pi ** 2 * ((sx * fx) ** 2 + (sy * fy) ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def lines(w, h, seed, count, lmin, lmax, angle_sd, width=1, ss=2):
    """Short straight scratches, mostly along x (angle spread angle_sd radians), a mask 0..1,
    tileable (drawn at ss times the size, then reduced)."""
    r = rng(seed)
    img = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = r.uniform(0, w), r.uniform(0, h)
        a = r.normal(0.0, angle_sd)
        ln = r.uniform(lmin, lmax)
        x1, y1 = x + math.cos(a) * ln, y + math.sin(a) * ln
        v = int(r.uniform(90, 255))
        for ox in (-w, 0, w):
            for oy in (-h, 0, h):
                d.line([((x + ox) * ss, (y + oy) * ss), ((x1 + ox) * ss, (y1 + oy) * ss)], fill=v, width=width * ss)
    img = img.resize((w, h), Image.LANCZOS)
    return np.asarray(img, np.float32) / 255.0


def platform_plate(name='platform_plate', ppm=64, size_m=32.0, seed=251, base=(170, 169, 166)):
    """The decks' steel plate over one block (32 m; world-mapped, so its edge is the blocks' seam):
    light grey with soft mottling, rubber smears and scratches along x (TMNF's deck reads like a
    worn floor that cars slide across), a few dark spots, the seam a fine groove with a bright lip."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mott = fbm(w, h, seed, beta=2.8, lo=1.0, hi=5.0)
    mid = fbm(w, h, seed + 1, beta=1.8, lo=8.0, hi=120.0)
    fine = fbm(w, h, seed + 2, beta=0.5, lo=200.0)
    # smears: noise stretched along x, kept where it is strong
    smear = smoothstep(0.9, 2.4, blur_xy(fbm(w, h, seed + 3, beta=1.2, lo=6.0), 60.0, 3.0) * 4.0)
    scratch = lines(w, h, seed + 4, 900, 10.0, 90.0, 0.06)
    scratch_dark = lines(w, h, seed + 5, 1400, 4.0, 60.0, 0.15, width=2) * smoothstep(0.0, 1.2, fbm(w, h, seed + 6, beta=2.2, lo=2.0))
    spots = blur(speckles(w, h, seed + 7, 0.000005, 2.0, 5.0), 1.5)
    # the seam on the block's edge (the texture's edge, both axes)
    du = np.minimum(xx, w - 1 - xx) / ppm
    dv = np.minimum(yy, h - 1 - yy) / ppm
    d = np.minimum(du, dv)
    groove = 1.0 - smoothstep(0.004, 0.016, d)
    lip = (1.0 - smoothstep(0.016, 0.05, d)) * (1.0 - groove)
    tone = 1.0 + 0.018 * mott + 0.012 * mid + 0.015 * fine
    tone *= (1.0 - 0.16 * smear) * (1.0 - 0.10 * scratch) * (1.0 - 0.35 * scratch_dark) * (1.0 - 0.3 * spots)
    tone *= (1.0 - 0.55 * groove) * (1.0 + 0.06 * lip)
    col = srgb(base)[None, None, :] * tone[..., None]
    col[..., 2] *= 1.0 - 0.02 * smear      # rubber is a touch warm
    height = 0.2 * fine + 0.1 * mid - 0.6 * scratch - 0.8 * scratch_dark - 4.0 * groove + 0.5 * lip
    nrm = normal_from_height(height, 0.5)
    rough = 0.80 + 0.04 * fine - 0.10 * smear + 0.06 * scratch_dark
    orm = np.stack([1.0 - 0.3 * groove, rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(1024, 1024))


def tread_plate(name='tread_plate', px=256, cells=16, seed=261):
    """The decks' fine tread, a detail map over 1 m (TmMaterials.DETAIL): raised lentils on a
    square grid turned +-45 degrees cell by cell (diamond plate). One RGB map: red and green the
    normal's x and y, blue the albedo factor (0.5 = 1: worn lentil tops a touch lighter)."""
    yy, xx = np.mgrid[0:px, 0:px].astype(np.float32)
    c = px / cells
    i = np.floor(xx / c)
    j = np.floor(yy / c)
    u = (xx + 0.5) / c - i - 0.5
    v = (yy + 0.5) / c - j - 0.5
    s = np.where((i + j) % 2 == 0, 1.0, -1.0)
    a = (u + s * v) / math.sqrt(2.0)
    b = (s * u - v) / math.sqrt(2.0)
    r2 = (a / 0.40) ** 2 + (b / 0.10) ** 2
    lens = np.sqrt(np.clip(1.0 - r2, 0.0, 1.0))
    lens = blur(lens, 0.6)
    n = fbm(px, px, seed, beta=1.0, lo=4.0)
    height = lens * (1.0 + 0.1 * n)
    nrm = normal_from_height(height * 3.0, 1.0)
    alb = 0.5 + 0.10 * smoothstep(0.4, 0.9, lens) - 0.07 * (1.0 - smoothstep(0.0, 0.15, lens)) + 0.01 * n
    out = nrm.copy()
    out[..., 2] = to8(np.clip(alb, 0, 1))
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, '%s_detail.png' % name)
    Image.fromarray(out, 'RGB').save(p, optimize=True)
    write_import(p, False)
    print(name, os.path.basename(p))


def platform_wall(name='platform_wall', ppm=64, size_m=8.0, seed=271, base=(50, 51, 53)):
    """The platforms' walls and wall borders: dark charcoal concrete panels 8 x 4 m (world-mapped:
    a joint halfway up each 8 m level), rain streaks running down (v is down the world's y on side
    faces), scuffs."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mott = fbm(w, h, seed, beta=2.6, lo=1.0, hi=6.0)
    fine = fbm(w, h, seed + 1, beta=0.7, lo=64.0)
    streak = blur_xy(fbm(w, h, seed + 2, beta=1.0, lo=8.0), 1.2, 40.0)
    streak = smoothstep(0.3, 1.5, streak * 2.5)
    du = np.minimum(xx, w - 1 - xx) / ppm
    dv = np.minimum(yy % (4 * ppm), 4 * ppm - yy % (4 * ppm)) / ppm
    seam = 1.0 - smoothstep(0.004, 0.02, np.minimum(du, dv))
    scuff = lines(w, h, seed + 3, 80, 6.0, 40.0, 0.25) * smoothstep(0.2, 1.2, fbm(w, h, seed + 4, beta=2.0, lo=2.0))
    pits = speckles(w, h, seed + 5, 0.0004, 0.6, 1.6)
    tone = (1.0 + 0.035 * mott + 0.04 * fine) * (1.0 - 0.10 * streak) * (1.0 - 0.45 * seam) * (1.0 + 0.35 * scuff) * (1.0 - 0.3 * pits)
    col = srgb(base)[None, None, :] * tone[..., None]
    nrm = normal_from_height(0.3 * fine - 1.5 * seam - 1.0 * pits, 0.45)
    orm = np.stack([1.0 - 0.2 * seam, 0.82 + 0.05 * fine - 0.12 * streak, np.zeros_like(fine)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(512, 512))


def circuit_panel(name='circuit_panel', ppm=64, size_u=16.0, size_v=8.0, seed=281, base=(222, 223, 221)):
    """The circuit walls' white cladding (UV-mapped: u along the wall, v down it): smooth panels
    8 m long with fine vertical joints, a little dirt washing down from the top."""
    w, h = int(size_u * ppm), int(size_v * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mott = fbm(w, h, seed, beta=2.6, lo=1.0, hi=8.0)
    fine = fbm(w, h, seed + 1, beta=0.7, lo=64.0)
    wash = blur_xy(fbm(w, h, seed + 2, beta=1.2, lo=6.0), 1.5, 30.0)
    wash = smoothstep(0.5, 2.0, wash * 2.5) * (0.4 + 0.6 * (1.0 - yy / h))
    du = np.minimum(xx % (8 * ppm), 8 * ppm - xx % (8 * ppm)) / ppm
    joint = 1.0 - smoothstep(0.0, 0.015, du)
    tone = (1.0 + 0.012 * mott + 0.01 * fine) * (1.0 - 0.07 * wash) * (1.0 - 0.35 * joint)
    col = srgb(base)[None, None, :] * tone[..., None]
    nrm = normal_from_height(0.1 * fine - 2.0 * joint, 0.45)
    orm = np.stack([1.0 - 0.3 * joint, 0.55 + 0.03 * fine + 0.1 * wash, np.zeros_like(fine)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def road_under(name='road_under', ppm=64, size_u=8.0, size_v=4.0, seed=301, base=(146, 141, 137)):
    """The road keel's underside (UV-mapped: u along the road, v across it), as TMNF's light steel
    plates: rows 1 m wide, 4 m long, staggered, dark joints with rivets along them, grime."""
    w, h = int(size_u * ppm), int(size_v * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mott = fbm(w, h, seed, beta=2.4, lo=1.0, hi=10.0)
    fine = fbm(w, h, seed + 1, beta=0.7, lo=64.0)
    dirt = np.clip(grime(w, h, seed + 2, amount=1.0), 0, 1)
    row = np.floor(yy / ppm)
    dv = np.minimum(yy % ppm, ppm - yy % ppm) / ppm
    ux = (xx + (row % 2) * 2 * ppm) % (4 * ppm)
    du = np.minimum(ux, 4 * ppm - ux) / ppm
    joint = np.maximum(1.0 - smoothstep(0.0, 0.02, dv), 1.0 - smoothstep(0.0, 0.02, du))
    rv = (yy % ppm) / ppm
    rivet = np.zeros((h, w), np.float32)
    for c in (0.08, 0.92):
        d = np.sqrt(((xx % (0.5 * ppm)) - 0.25 * ppm) ** 2 + ((rv - c) * ppm) ** 2) / ppm
        rivet = np.maximum(rivet, 1.0 - smoothstep(0.02, 0.035, d))
    tone = (1.0 + 0.04 * mott + 0.03 * fine) * (1.0 - 0.12 * dirt) * (1.0 - 0.55 * joint)
    col = srgb(base)[None, None, :] * tone[..., None]
    col = lerp(col, srgb((110, 106, 102))[None, None, :], (0.7 * rivet)[..., None])
    nrm = normal_from_height(0.15 * fine - 1.5 * joint + 0.8 * rivet, 0.45)
    orm = np.stack([1.0 - 0.3 * joint, 0.6 + 0.05 * fine + 0.1 * dirt, 0.25 * (1.0 - joint)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def circuit_band(name='circuit_band', ppm=64, size_u=16.0, size_v=3.5, seed=291):
    """The blue band along the circuit walls' outside (UV-mapped; 3.5 m high): deep blue lighter
    toward its lower edge, a field of small lit squares fading in from below, our name in the
    middle of each 16 m. Turned round at the end: the walls' outer faces map it upside down."""
    w, h = int(size_u * ppm), int(round(size_v * ppm / 4.0)) * 4
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = yy / h
    top, bottom = srgb((6, 52, 140)), srgb((12, 86, 190))
    col = top[None, None, :] * (1.0 - t[..., None]) + bottom[None, None, :] * t[..., None]
    col *= (1.0 + 0.05 * fbm(w, h, seed, beta=2.4, lo=1.0, hi=10.0))[..., None]
    pitch = 0.09 * ppm
    gx = np.abs((xx % pitch) - pitch / 2) / pitch
    gy = np.abs((yy % pitch) - pitch / 2) / pitch
    square = (1.0 - smoothstep(0.28, 0.36, gx)) * (1.0 - smoothstep(0.28, 0.36, gy))
    fade = smoothstep(0.35, 0.95, t) * (0.6 + 0.4 * smoothstep(-0.5, 1.0, fbm(w, h, seed + 1, beta=2.0, lo=2.0)))
    dots = square * fade
    col = lerp(col, srgb((70, 150, 235))[None, None, :], dots * 0.55)
    # edge trims: thin light lines at the top and bottom
    trim = (1.0 - smoothstep(0.012 * ppm, 0.03 * ppm, yy)) + smoothstep(h - 0.03 * ppm, h - 0.012 * ppm, yy)
    col = lerp(col, srgb((200, 210, 225))[None, None, :], np.clip(trim, 0, 1) * 0.8)
    logo = text_mask(w, h, 'SPEEDFEST', font('orbitron-latin-900-normal', int(0.62 * ppm)), (w / 2, h * 0.42),
                     italic=-0.18, tracking=int(0.06 * ppm))
    col = lerp(col, srgb((245, 247, 250))[None, None, :], logo)
    nrm = normal_from_height(0.6 * dots + 1.0 * logo, 0.4)
    orm = np.stack([np.ones_like(t), 0.62 - 0.15 * logo, np.zeros_like(t)], -1)
    turn = lambda a: np.ascontiguousarray(a[::-1, ::-1])
    nrm = turn(nrm)
    nrm[..., :2] = 255 - nrm[..., :2]      # a normal map turned round: its x and y flip too
    save(name, turn(np.clip(col, 0, 1)), nrm, turn(orm))


def steel_truss(name='steel_truss', ppm=64, size_m=8.0, seed=301, base=(40, 40, 41)):
    """The dark steel behind the circuit's screens and under its ledges: posts every 4 m, rails
    every 2 m, X braces between, on a dark panel (world-mapped)."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) / ppm
    def bar(d, half):
        return 1.0 - smoothstep(half, half + 0.02, d)
    post = bar(np.minimum(xx % 4.0, 4.0 - xx % 4.0), 0.12)
    rail = bar(np.minimum(yy % 2.0, 2.0 - yy % 2.0), 0.07)
    lx, ly = xx % 4.0, yy % 2.0
    brace = np.maximum(bar(np.abs(ly - lx * 0.5) / 1.118, 0.04), bar(np.abs(ly - (2.0 - lx * 0.5)) / 1.118, 0.04))
    frame = np.clip(np.maximum(np.maximum(post, rail), brace), 0, 1)
    n = fbm(w, h, seed, beta=2.2, lo=1.0)
    bolts = np.zeros_like(xx)
    for cx in np.arange(0.0, size_m + 0.01, 4.0):
        for cy in np.arange(0.0, size_m + 0.01, 2.0):
            for ox, oy in ((0.08, 0.05), (-0.08, 0.05), (0.08, -0.05), (-0.08, -0.05)):
                r = np.hypot(xx - cx - ox, yy - cy - oy)
                bolts = np.maximum(bolts, 1.0 - smoothstep(0.012, 0.022, r))
    tone = (1.0 + 0.05 * n) * (0.72 + 0.28 * frame) * (1.0 + 0.4 * bolts)
    col = srgb(base)[None, None, :] * tone[..., None]
    nrm = normal_from_height(2.5 * frame + 1.5 * bolts, 0.5)
    orm = np.stack([0.7 + 0.3 * frame, 0.55 - 0.1 * frame, 0.3 + 0.4 * frame], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(512, 512))


def circuit_kerb(name='circuit_kerb', ppm=64, size_m=16.0, seed=311, base=(26, 84, 170)):
    """The blue strip along the circuit walls' foot, at lane level (world-mapped, 16 m): painted
    steel plate with a little wear, two fine grooves along x, a darker joint plate at the tile's
    edge (every 16 m)."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mott = fbm(w, h, seed, beta=2.4, lo=1.0, hi=10.0)
    fine = fbm(w, h, seed + 1, beta=0.6, lo=64.0)
    wear = smoothstep(1.0, 2.2, fbm(w, h, seed + 2, beta=1.4, lo=6.0))
    dv = (yy / ppm) % 2.0
    groove = (1.0 - smoothstep(0.0, 0.012, np.abs(dv - 0.6))) + (1.0 - smoothstep(0.0, 0.012, np.abs(dv - 1.4)))
    du = np.minimum(xx, w - 1 - xx) / ppm
    joint = 1.0 - smoothstep(0.18, 0.2, du)
    jline = 1.0 - smoothstep(0.0, 0.01, np.abs(du - 0.19))
    tone = (1.0 + 0.04 * mott + 0.03 * fine) * (1.0 - 0.35 * groove)
    col = srgb(base)[None, None, :] * tone[..., None]
    col = lerp(col, srgb((150, 158, 170))[None, None, :] * (1.0 + 0.05 * fine)[..., None], wear * 0.5)
    col = lerp(col, srgb((58, 62, 68))[None, None, :] * (1.0 + 0.1 * fine)[..., None], joint)
    col *= (1.0 - 0.5 * jline)[..., None]
    nrm = normal_from_height(0.2 * fine - 1.0 * groove + 0.6 * joint - 1.5 * jline, 0.45)
    orm = np.stack([1.0 - 0.3 * groove, 0.62 + 0.05 * fine + 0.15 * wear, 0.25 + 0.4 * joint], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(512, 512))


def circuit_bumper(name='circuit_bumper', ppm=64, size_u=16.0, size_v=1.6, seed=321):
    """The black rubber bumper above the lane's blue strip (UV-mapped: u along the wall, v across the
    band): moulded rubber, a light grey line along each edge, our emblem in white every 16 m."""
    w, h = int(size_u * ppm), int(round(size_v * ppm / 4.0)) * 4
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n = fbm(w, h, seed, beta=1.0, lo=16.0)
    edge = smoothstep(0.1 * ppm, 0.06 * ppm, np.minimum(yy, h - 1 - yy))
    line = (1.0 - smoothstep(0.0, 0.02 * ppm, np.abs(yy - 0.16 * ppm))) + \
        (1.0 - smoothstep(0.0, 0.02 * ppm, np.abs(yy - (h - 0.16 * ppm))))
    col = srgb((20, 20, 22))[None, None, :] * (1.0 + 0.15 * n)[..., None]
    col = lerp(col, srgb((150, 152, 156))[None, None, :], np.clip(line, 0, 1) * 0.9)
    col *= (1.0 - 0.3 * edge)[..., None]
    logo = text_mask(w, h, 'SPEEDFEST', font('orbitron-latin-900-normal', int(0.3 * ppm)), (w / 2, h / 2),
                     italic=-0.18, tracking=int(0.03 * ppm))
    col = lerp(col, srgb((236, 238, 240))[None, None, :], logo)
    nrm = normal_from_height(0.3 * n - 1.0 * line + 0.6 * logo, 0.4)
    orm = np.stack([np.ones_like(n), 0.85 - 0.3 * logo - 0.2 * line, np.zeros_like(n)], -1)
    flip = lambda a: np.ascontiguousarray(a[::-1])     # the lane side maps it upside down
    nrm = flip(nrm)
    nrm[..., 1] = 255 - nrm[..., 1]
    save(name, flip(np.clip(col, 0, 1)), nrm, flip(orm))


if __name__ == '__main__':
    platform_plate()
    tread_plate()
    platform_wall()
    circuit_panel()
    circuit_band()
    road_under()
    steel_truss()
    circuit_kerb()
    circuit_bumper()
