"""Our turbo pad (UV-mapped, 1024 x 512: u along the road, 16 m a tile; v across, mirrored about
the pad's centreline by the UVs), laid out as TMNF's pad is (measured, docs/research/m11_check.md):
dark steel grating panels (round bars slanting at ~72 degrees, a flat plate strip at each panel's
start) in a 2 x 4 grid of thin grey seams, a big yellow arrow pointing along u in each half (the
lower one mirrored), a few red scrapes. Drawn here; only the layout follows TMNF.
Run: python3 stadium/tools/texgen/turbo.py"""
import numpy as np
from texlib import fbm, smoothstep, srgb, lerp, normal_from_height, save, poly_mask, grime, font, text_mask, rect_mask

W, H = 1024, 512


def turbo_pad(name='turbo_pad', seed=411):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    fine = fbm(W, H, seed, beta=0.7, lo=80.0)
    mott = fbm(W, H, seed + 1, beta=2.2, lo=2.0, hi=30.0)
    dirt = np.clip(grime(W, H, seed + 2, amount=1.0), 0, 1)
    # panels: 2 across (u), 4 down (v), slanting as their bars do; each starts with a flat plate
    # strip, then the grating; thin light seams with bolts between
    shear = 0.33
    ux = (xx - shear * (yy % 128.0)) % 512.0
    seam_u = 1.0 - smoothstep(2.0, 4.0, np.minimum(ux, 512.0 - ux))
    vy = yy % 128.0
    seam_v = 1.0 - smoothstep(1.5, 3.0, np.minimum(vy, 128.0 - vy))
    seam = np.clip(seam_u + seam_v, 0, 1)
    plate = 1.0 - smoothstep(58.0, 62.0, ux)
    bolt = np.zeros((H, W), np.float32)
    for k in range(4):
        by = 128.0 * k + 6.0
        for bx in np.arange(10.0, W, 64.0):
            bolt = np.maximum(bolt, 1.0 - smoothstep(1.5, 2.5, np.hypot(xx - bx - shear * 6.0, yy - by)))
    # the grating: round bars ~0.2 m apart along u (12.5 px), dark gaps between
    ph = np.mod((xx - shear * yy) / 12.5, 1.0)
    gap = 1.0 - smoothstep(0.08, 0.16, ph) * (1.0 - smoothstep(0.92, 1.0, ph))
    tube = np.sin(np.pi * np.clip((ph - 0.1) / 0.85, 0, 1))
    rib = (1.0 - gap) * (0.55 + 0.45 * tube) * (1.0 - plate)
    steel = srgb((36, 36, 35))[None, None, :] * (0.55 + 0.9 * rib + 0.05 * mott + 0.04 * fine)[..., None]
    plate_c = srgb((142, 144, 140))[None, None, :] * (1.0 + 0.05 * fine + 0.04 * mott)[..., None]
    col = lerp(steel, plate_c, plate[..., None])
    col = lerp(col, srgb((168, 168, 162))[None, None, :] * (1.0 + 0.06 * fine)[..., None], seam[..., None])
    col = lerp(col, srgb((96, 96, 92))[None, None, :] * np.ones((H, W, 1)), (bolt * seam_v)[..., None])
    # the arrows (top one, its mirror below), yellow paint over the ribs, worn by tyres
    top = [(60, 40), (100, 40), (985, 222), (135, 222)]
    arrow = poly_mask(W, H, [top, [(x, H - 1 - y) for x, y in top]], blur_px=1.0)
    paint = srgb((214, 184, 6))[None, None, :] * (0.72 + 0.3 * rib + 0.28 * plate + 0.05 * fine)[..., None]
    paint *= (1.0 - 0.55 * gap * (1.0 - plate))[..., None]
    wear = smoothstep(0.8, 1.0, dirt) * 0.3
    col = lerp(col, paint, (arrow * (1.0 - wear) * (1.0 - 0.8 * seam))[..., None])
    # red scrapes near the arrows' tails
    scr = np.zeros((H, W), np.float32)
    for k, (x0, y0) in enumerate([(22, 100), (34, 108), (44, 118), (24, 300), (38, 310)]):
        d = np.abs((xx - x0) - 0.12 * (yy - y0))
        scr = np.maximum(scr, (1.0 - smoothstep(1.0, 2.5, d)) * ((yy > y0) & (yy < y0 + 110 - 10 * k)))
    col = lerp(col, srgb((150, 20, 18))[None, None, :], (0.8 * scr)[..., None])
    col *= (1.0 - 0.12 * dirt)[..., None]
    hgt = 2.0 * rib * (1.0 - seam) - 1.2 * gap * (1.0 - plate) + 0.6 * plate - 0.8 * seam + 0.3 * fine
    nrm = normal_from_height(hgt, 0.5)
    orm = np.stack([1.0 - 0.4 * gap * (1.0 - plate), 0.55 + 0.2 * (1.0 - arrow) + 0.1 * seam,
                    0.35 * (1.0 - arrow) * (1.0 - seam)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def freewheel_pad(name='freewheel_pad', seed=413):
    """Our free-wheeling pad (UV-mapped like the turbo pad: u along the road, 16 m a tile; v across,
    mirrored about the centre line), laid out as TMNF's is: red ribbed panels on a grid of light
    seams, in each panel two thick yellow chevrons pointing at each other. Drawn here."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    fine = fbm(W, H, seed, beta=0.7, lo=80.0)
    mott = fbm(W, H, seed + 1, beta=2.2, lo=2.0, hi=30.0)
    dirt = np.clip(grime(W, H, seed + 2, amount=1.0), 0, 1)
    shear = 0.16
    ux = (xx - shear * (yy % 128.0)) % 512.0
    seam_u = 1.0 - smoothstep(6.0, 11.0, np.minimum(ux, 512.0 - ux))
    vy = yy % 128.0
    seam_v = 1.0 - smoothstep(3.0, 6.0, np.minimum(vy, 128.0 - vy))
    seam = np.clip(seam_u + seam_v, 0, 1)
    rib = 0.5 + 0.5 * np.cos(((xx + 0.12 * yy) / 11.0) * 2 * np.pi)
    red = srgb((176, 14, 12))[None, None, :] * (0.8 + 0.3 * rib + 0.06 * mott + 0.05 * fine)[..., None]
    col = lerp(red, srgb((196, 190, 172))[None, None, :] * (1.0 + 0.06 * fine)[..., None], seam[..., None])
    # two chevrons per 512 x 256 panel: '>' on the left half, '<' on the right, tips near the middle
    polys = []
    for px in (0, 512):
        for py in (0, 256):
            cx, cy = px + 256, py + 128
            back, tip, w, h = cx - 210, cx - 74, 60, 100
            right = [(back, cy - h), (back + w, cy - h), (tip + w, cy), (back + w, cy + h), (back, cy + h), (tip, cy)]
            polys.append(right)
            polys.append([(2 * cx - x, y) for x, y in right])
    arrows = poly_mask(W, H, polys, blur_px=1.0)
    paint = srgb((222, 190, 8))[None, None, :] * (0.9 + 0.12 * rib + 0.05 * fine)[..., None]
    col = lerp(col, paint, (arrows * (1.0 - 0.3 * smoothstep(0.8, 1.0, dirt)) * (1.0 - 0.8 * seam))[..., None])
    col *= (1.0 - 0.12 * dirt)[..., None]
    hgt = 0.6 * rib * (1.0 - seam) - 0.8 * seam + 0.3 * fine
    nrm = normal_from_height(hgt, 0.5)
    orm = np.stack([np.ones((H, W), np.float32), 0.55 + 0.2 * (1.0 - arrows) + 0.1 * seam,
                    0.35 * (1.0 - arrows) * (1.0 - seam)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def turbo_rim(name='turbo_rim', w=1024, h=128, seed=417):
    """The turbo deck's rim (u along it, 16 m a tile; v across its bevel, top at row 0), laid out
    as TMNF's: dark moulded rubber, a yellow line near the top, the word TURBO in italic yellow
    every 4 m, a thin light line and a yellow band along the bottom. Drawn here, in our font."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fine = fbm(w, h, seed, beta=0.8, lo=40.0)
    mott = fbm(w, h, seed + 1, beta=2.0, lo=2.0, hi=20.0)
    col = srgb((32, 31, 30))[None, None, :] * (1.0 + 0.08 * mott + 0.05 * fine)[..., None]
    yellow = srgb((226, 160, 18))[None, None, :] * (1.0 + 0.05 * fine)[..., None]
    line = rect_mask(w, h, -10, 0.12 * h, w + 10, 0.17 * h, 0.8)
    band = rect_mask(w, h, -10, 0.86 * h, w + 10, h + 10, 0.8)
    thin = rect_mask(w, h, -10, 0.80 * h, w + 10, 0.82 * h, 0.6)
    fnt = font('orbitron-latin-900-normal', int(0.42 * h))
    word = np.zeros((h, w), np.float32)
    for k in range(4):
        word = np.maximum(word, text_mask(w, h, 'TURBO', fnt, ((k + 0.5) * w / 4, 0.5 * h), 'mm', italic=0.25,
                                          tracking=int(0.02 * h)))
    worn = smoothstep(0.6, 1.8, fbm(w, h, seed + 2, beta=1.2, lo=6.0)) * 0.3
    col = lerp(col, yellow, np.clip(line + band + word, 0, 1) * (1.0 - worn))
    col = lerp(col, srgb((190, 186, 176))[None, None, :] * np.ones((h, w, 1)), thin)
    hgt = 0.4 * mott + 0.8 * word + 0.3 * (line + band)
    nrm = normal_from_height(hgt, 0.4)
    orm = np.stack([np.ones((h, w), np.float32), 0.7 - 0.15 * word, np.zeros((h, w), np.float32)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    turbo_pad()
    freewheel_pad()
    turbo_rim()
