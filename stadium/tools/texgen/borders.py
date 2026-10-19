"""Our road and platform border atlas (UV-mapped, 1024 x 512: u along the border, 16 m per tile;
v picks a band), laid out as TMNF's border texture is so the same faces show the same band
(rows measured from TMNF's, docs/research/m11_check.md): a light grey panel, a dark ribbed rubber
strip, a black band with a white line and our emblem, a blue line, the orange band with our emblem
twice, a blue line, the green band with a white line. Everything drawn here; only the bands'
rows and colours follow TMNF.
Run: python3 stadium/tools/texgen/borders.py"""
import numpy as np
from texlib import (fbm, smoothstep, srgb, lerp, normal_from_height, save, font, text_mask, grime)

W, H = 1024, 512
# (first row, last row, sRGB colour, kind)
BANDS = [
    (0, 5, (64, 62, 60), 'edge'),
    (6, 140, (179, 171, 168), 'panel'),
    (141, 150, (92, 88, 84), 'edge'),
    (151, 215, (36, 35, 31), 'ribs'),
    (216, 282, (16, 15, 15), 'black'),
    (283, 298, (62, 133, 254), 'blue'),
    (299, 364, (190, 99, 8), 'orange'),
    (365, 389, (62, 133, 254), 'blue'),
    (390, 504, (58, 128, 66), 'green'),
    (505, 511, (60, 66, 62), 'edge'),
]


def border_atlas(name='border_atlas', seed=401):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    col = np.zeros((H, W, 3), np.float32)
    hgt = np.zeros((H, W), np.float32)
    rough = np.full((H, W), 0.7, np.float32)
    mott = fbm(W, H, seed, beta=2.2, lo=2.0, hi=40.0)
    fine = fbm(W, H, seed + 1, beta=0.7, lo=80.0)
    dirt = grime(W, H, seed + 2, amount=1.0)
    for r0, r1, rgb, kind in BANDS:
        m = ((yy >= r0) & (yy <= r1)).astype(np.float32)
        base = srgb(rgb)[None, None, :]
        if kind == 'panel':
            # painted panel, streaks along u, grime gathering toward its lower edge
            streak = fbm(W, H, seed + 3, beta=1.6, lo=1.0, hi=6.0) * 0.6 + fbm(W, H, seed + 4, beta=0.4, lo=120.0) * 0.4
            down = smoothstep(90, 140, yy)
            tone = 1.0 + 0.04 * mott + 0.03 * streak - 0.08 * down - 0.10 * np.clip(dirt, 0, 1)
            c = base * tone[..., None]
            rough = np.where(m > 0, 0.75, rough)
        elif kind == 'ribs':
            rib = 0.5 + 0.5 * np.cos((xx / 8.0) * 2 * np.pi)
            c = base * (0.8 + 0.4 * rib + 0.05 * fine)[..., None]
            hgt += m * rib * 0.6
            rough = np.where(m > 0, 0.9, rough)
        elif kind == 'black':
            c = base * (1.0 + 0.2 * fine)[..., None]
            line = 1.0 - smoothstep(0.0, 1.5, np.abs(yy - 231))
            c = lerp(c, srgb((118, 122, 121))[None, None, :], line[..., None])
            rough = np.where(m > 0, 0.85, rough)
        elif kind == 'blue':
            c = base * (1.0 + 0.04 * mott + 0.03 * fine)[..., None]
            rough = np.where(m > 0, 0.5, rough)
        elif kind == 'orange':
            c = base * (1.0 + 0.06 * mott + 0.05 * fine - 0.12 * np.clip(dirt, 0, 1))[..., None]
            rough = np.where(m > 0, 0.6, rough)
        elif kind == 'green':
            c = base * (1.0 + 0.05 * mott + 0.04 * fine - 0.1 * np.clip(dirt, 0, 1))[..., None]
            line = 1.0 - smoothstep(2.5, 4.0, np.abs(yy - 409.5))
            c = lerp(c, srgb((176, 176, 170))[None, None, :] * (1.0 + 0.05 * fine)[..., None], line[..., None])
            rough = np.where(m > 0, 0.65, rough)
        else:
            c = base * (1.0 + 0.1 * fine)[..., None]
        col = col * (1 - m[..., None]) + c * m[..., None]
    # our emblem: white on the black band, black twice on the orange band
    f = font('orbitron-latin-900-normal', 17)
    logo_b = text_mask(W, H, 'SPEEDFEST', f, (W * 0.5, 256), italic=-0.18, tracking=2)
    col = lerp(col, srgb((226, 228, 230))[None, None, :], logo_b[..., None])
    for u in (0.25, 0.78):
        logo_o = text_mask(W, H, 'SPEEDFEST', f, (W * u, 332), italic=-0.18, tracking=2)
        col = lerp(col, srgb((14, 12, 10))[None, None, :], logo_o[..., None])
    hgt += 0.4 * fine
    nrm = normal_from_height(hgt, 0.5)
    orm = np.stack([np.ones((H, W), np.float32), rough, np.zeros((H, W), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    border_atlas()
