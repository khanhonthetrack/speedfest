"""The Stadium's remaining surfaces, our own art in its style (tileable): the field's mown grass,
the loose dirt of berms and hills, the dirt roads' packed track, the structures' painted steel and
the light wall panels (tinted dark by TmMaterials for wall_dark). (The decks: decks.py.) Colours from the
Stadium's measured ones (TmMaterials). Sizes in metres are what one texture covers.
usage: python3 stadium/tools/texgen/surfaces.py"""
import numpy as np
from texlib import *


def grass(name='stadium_grass', ppm=32, size_m=32.0, seed=201, base=(62, 92, 45)):
    """Mown stadium grass: stripes 8 m wide in two shades (the mower's passes, along z), blades and
    clover at the small scale, a few worn and lush patches."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xm = xx / ppm
    stripe = 0.5 + 0.5 * np.cos(2.0 * np.pi * xm / 16.0)
    stripe = smoothstep(0.25, 0.75, stripe)
    blades = fbm(w, h, seed, beta=0.4, lo=200.0)
    clumps = fbm(w, h, seed + 1, beta=1.6, lo=24.0, hi=200.0)
    patches = fbm(w, h, seed + 2, beta=2.6, lo=1.0, hi=10.0)
    tone = 1.0 + 0.10 * stripe - 0.05 + 0.06 * blades + 0.05 * clumps + 0.05 * patches
    col = srgb(base)[None, None, :] * tone[..., None]
    # the light stripes a touch yellower (blades bent away), worn patches browner
    col[..., 0] *= 1.0 + 0.05 * stripe + 0.04 * smoothstep(0.8, 1.8, -patches)
    col[..., 2] *= 1.0 - 0.06 * stripe
    nrm = normal_from_height(0.8 * blades + 0.4 * clumps, 0.25)
    orm = np.stack([1.0 - 0.15 * smoothstep(-0.5, 1.5, -clumps), 0.93 + 0.04 * blades, np.zeros_like(blades)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(512, 512))


def dirt(name='stadium_dirt', ppm=64, size_m=8.0, seed=211, base=(84, 74, 58)):
    """Loose earth (berms, hills): fine grain, pebbles, dry cracks, darker damp hollows."""
    w = h = int(size_m * ppm)
    grain = fbm(w, h, seed, beta=0.6, lo=64.0)
    lumps = fbm(w, h, seed + 1, beta=2.0, lo=4.0, hi=64.0)
    damp = smoothstep(0.4, 1.6, fbm(w, h, seed + 2, beta=2.8, lo=1.0, hi=8.0))
    pebbles = speckles(w, h, seed + 3, 0.0012, 1.0, 3.5)
    crk = blur(cracks(w, h, seed + 4, 8, 60, jitter=0.4), 0.7) * 0.5
    streak = blur(fbm(w, 1, seed + 5, beta=1.2, lo=4.0).repeat(h, 0), 1.0)
    tone = (1.0 + 0.10 * grain + 0.08 * lumps - 0.18 * damp + 0.05 * streak) * (1.0 - 0.3 * crk)
    col = srgb(base)[None, None, :] * tone[..., None]
    col = col * (1 - pebbles[..., None] * 0.5) + srgb((150, 140, 125))[None, None, :] * pebbles[..., None] * 0.5
    height = 0.6 * grain + 0.8 * lumps + 2.0 * pebbles - 2.0 * crk
    nrm = normal_from_height(height, 0.45)
    orm = np.stack([1.0 - 0.3 * crk - 0.1 * damp, 0.92 - 0.25 * damp + 0.03 * grain, np.zeros_like(grain)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(512, 512))


def dirt_road(name='dirt_road', ppm=64, size_m=16.0, seed=215, base=(122, 109, 92)):
    """The dirt roads' packed track (UV-mapped: x across the road, y along it): smoother and
    lighter than the loose dirt, combed by tyres into fine streaks along the road with a few
    darker ruts, damp patches, scattered gravel."""
    w = h = int(size_m * ppm)
    fine = fbm(w, h, seed, beta=0.8, lo=64.0)
    combed = blur_xy(fbm(w, h, seed + 1, beta=0.6, lo=48.0), 0.7, 90.0)
    combed /= combed.std() + 1e-6
    combed *= smoothstep(-0.8, 1.2, fbm(w, h, seed + 6, beta=2.4, lo=2.0, hi=24.0))   # in places
    ruts = blur_xy(fbm(w, h, seed + 2, beta=2.0, lo=3.0, hi=40.0), 5.0, 160.0)
    ruts = smoothstep(0.6, 1.8, ruts / (ruts.std() + 1e-6))
    damp = smoothstep(0.5, 1.8, fbm(w, h, seed + 3, beta=2.8, lo=1.0, hi=8.0))
    gravel = speckles(w, h, seed + 4, 0.0016, 0.6, 1.8)
    gravel_dark = speckles(w, h, seed + 5, 0.0010, 0.6, 1.5)
    tone = (1.0 + 0.05 * fine + 0.035 * combed - 0.09 * ruts - 0.12 * damp) * (1.0 + 0.25 * gravel) * (1.0 - 0.3 * gravel_dark)
    col = srgb(base)[None, None, :] * tone[..., None]
    col[..., 2] *= 1.0 - 0.04 * damp
    height = 0.3 * fine + 0.12 * combed - 0.5 * ruts + 1.2 * gravel + 0.8 * gravel_dark
    nrm = normal_from_height(height, 0.35)
    orm = np.stack([1.0 - 0.15 * ruts, 0.9 - 0.15 * damp + 0.03 * fine, np.zeros_like(fine)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(512, 512))


def road_to_dirt(name='road_to_dirt', w=1024, h=512, seed=217, road=(165, 164, 161), dirt=(112, 99, 80)):
    """Where a dirt road meets the road (blocks/shapes/dirt.gd TO_ROAD), the asphalt half as TMNF
    lays it: one image over the piece (u along it, 0 at the road's end to 1 at the dirt, 15.2 m;
    v across, 0 on the centre line to 1 at the road's edge, 10.8 m; mirrored about the centre):
    clean light asphalt at the road's end, dirt carried onto it by tyres thickening toward the
    dirt, in streaks along the road and a few darker tracks."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = (xx + 0.5) / w
    v = (yy + 0.5) / h
    fine = fbm(w, h, seed, beta=0.8, lo=64.0)
    mott = fbm(w, h, seed + 1, beta=2.4, lo=2.0, hi=24.0)
    streak = blur_xy(fbm(w, h, seed + 2, beta=0.6, lo=32.0), 60.0, 3.0)
    streak /= streak.std() + 1e-6
    tracks = blur_xy(fbm(w, h, seed + 3, beta=1.6, lo=4.0, hi=60.0), 120.0, 3.0)
    tracks = smoothstep(0.5, 1.6, tracks / (tracks.std() + 1e-6))
    # how much dirt: none at the road's end, all of it by the dirt, in streaks and patches
    amount = smoothstep(0.05, 1.0, u) ** 1.2
    amount = np.clip(amount * (0.85 + 0.12 * streak + 0.2 * mott) + 0.15 * tracks * smoothstep(0.3, 0.9, u), 0, 1)
    gravel = speckles(w, h, seed + 4, 0.0012, 0.6, 1.6) * smoothstep(0.2, 0.8, u)
    road_c = srgb(road)[None, None, :] * (1.0 + 0.05 * fine + 0.03 * mott)[..., None]
    dirt_c = srgb(dirt)[None, None, :] * (1.0 + 0.06 * fine + 0.03 * streak - 0.06 * tracks)[..., None]
    col = lerp(road_c, dirt_c, amount[..., None])
    col = col * (1 + 0.2 * gravel[..., None])
    height = 0.3 * fine + 0.4 * amount * (0.5 + 0.3 * streak) + 1.0 * gravel
    nrm = normal_from_height(height, 0.35)
    orm = np.stack([1.0 - 0.1 * amount, 0.85 + 0.05 * amount + 0.03 * fine, np.zeros_like(fine)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def blur_xy(a, sx, sy):
    """Tileable Gaussian blur with its own sigma (pixels) along x and y (streaks)."""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * np.pi ** 2 * ((sx * fx) ** 2 + (sy * fy) ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def steel(name='steel_painted', ppm=64, size_m=8.0, seed=231, base=(78, 81, 88)):
    """The structures' painted steel: plates 2 m wide with welded seams, rows of bolts along them,
    paint wear and rain streaks running down (v is down the world's y on side faces)."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    px = ppm
    n1 = fbm(w, h, seed, beta=2.4, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=0.8, lo=32.0)
    du = np.minimum(xx % (2 * px), 2 * px - xx % (2 * px)) / px
    dv = np.minimum(yy % (2 * px), 2 * px - yy % (2 * px)) / px
    seam = 1.0 - smoothstep(0.0, 0.02, np.minimum(du, dv))
    bolts = np.zeros((h, w), np.float32)
    for k in range(0, int(size_m / 0.25)):
        cy = (k * 0.25 + 0.125) * px
        for cx in np.arange(0.06, size_m, 2.0) * px:
            r = np.hypot(xx - cx, yy - cy)
            bolts = np.maximum(bolts, 1.0 - smoothstep(0.012 * px, 0.02 * px, r))
    streak = smoothstep(0.4, 1.6, blur(fbm(w, h, seed + 2, beta=1.4, lo=6.0), 0.5) * 0.7 + 0.4 * n1)
    wear = smoothstep(1.2, 2.2, fbm(w, h, seed + 3, beta=1.2, lo=8.0) + 1.5 * seam)
    tone = (1.0 + 0.04 * n1 + 0.03 * n2) * (1 - 0.35 * seam) * (1 - 0.12 * streak) * (1 + 0.25 * bolts)
    col = srgb(base)[None, None, :] * tone[..., None]
    col = col * (1 - wear[..., None] * 0.5) + srgb((120, 118, 112))[None, None, :] * wear[..., None] * 0.5
    nrm = normal_from_height(1.5 * bolts - 1.2 * seam + 0.15 * n2, 0.5)
    orm = np.stack([1.0 - 0.3 * seam, 0.55 + 0.1 * n2 + 0.12 * streak - 0.2 * wear, 0.3 + 0.5 * wear], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def wall_panels(name='wall_panels', ppm=48, size_m=16.0, seed=241, base=(226, 228, 232)):
    """Light cladding panels 4 x 2 m on the walls and decks' sides, with dark joints, a few
    replaced (slightly whiter) panels and dirt washing down from the joints."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    px = ppm
    n1 = fbm(w, h, seed, beta=2.2, lo=1.0)
    fine = fbm(w, h, seed + 1, beta=0.8, lo=48.0)
    du = np.minimum(xx % (4 * px), 4 * px - xx % (4 * px)) / px
    dv = np.minimum(yy % (2 * px), 2 * px - yy % (2 * px)) / px
    joint = 1.0 - smoothstep(0.0, 0.025, np.minimum(du, dv))
    r = rng(seed + 2)
    cells = r.uniform(-1, 1, (int(size_m / 2), int(size_m / 4)))
    cell = cells[(yy // (2 * px)).astype(int) % cells.shape[0], (xx // (4 * px)).astype(int) % cells.shape[1]]
    wash = blur(np.clip(joint * (r.uniform(0, 1, (h, w)) > 0.6), 0, 1), 3.0)
    wash = np.clip(blur(np.roll(wash, int(0.3 * px), 0) + wash, 6.0) * 3.0, 0, 1)
    tone = (1.0 + 0.025 * n1 + 0.02 * fine + 0.03 * cell) * (1 - 0.45 * joint) * (1 - 0.1 * wash)
    col = srgb(base)[None, None, :] * tone[..., None]
    nrm = normal_from_height(-2.0 * joint + 0.1 * fine, 0.45)
    orm = np.stack([1.0 - 0.35 * joint, 0.7 + 0.05 * fine + 0.1 * wash, np.zeros_like(fine)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    grass()
    dirt()
    dirt_road()
    road_to_dirt()
    steel()
    wall_panels()
