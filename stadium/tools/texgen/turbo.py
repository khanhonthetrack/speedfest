"""Our turbo pad (UV-mapped, 1024 x 512: u along the road, 16 m a tile; v across, mirrored about
the pad's centreline by the UVs), laid out as TMNF's pad is (measured, docs/research/m11_check.md):
dark ribbed steel panels in a 2 x 4 grid of light seams, a big yellow arrow pointing along u in
each half (the lower one mirrored), a few red scrapes. Drawn here; only the layout follows TMNF.
Run: python3 stadium/tools/texgen/turbo.py"""
import numpy as np
from texlib import fbm, smoothstep, srgb, lerp, normal_from_height, save, poly_mask, grime

W, H = 1024, 512


def turbo_pad(name='turbo_pad', seed=411):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    fine = fbm(W, H, seed, beta=0.7, lo=80.0)
    mott = fbm(W, H, seed + 1, beta=2.2, lo=2.0, hi=30.0)
    dirt = np.clip(grime(W, H, seed + 2, amount=1.0), 0, 1)
    # panels: 2 across (u), 4 down (v), their left edges slanting, light seams between
    shear = 0.16
    ux = (xx - shear * (yy % 128.0)) % 512.0
    seam_u = 1.0 - smoothstep(6.0, 11.0, np.minimum(ux, 512.0 - ux))
    vy = yy % 128.0
    seam_v = 1.0 - smoothstep(3.0, 6.0, np.minimum(vy, 128.0 - vy))
    seam = np.clip(seam_u + seam_v, 0, 1)
    # the ribs: fine grooves slanting a little off v
    rib = 0.5 + 0.5 * np.cos(((xx + 0.12 * yy) / 11.0) * 2 * np.pi)
    steel = srgb((48, 46, 40))[None, None, :] * (0.78 + 0.32 * rib + 0.06 * mott + 0.05 * fine)[..., None]
    col = lerp(steel, srgb((196, 190, 172))[None, None, :] * (1.0 + 0.06 * fine)[..., None], seam[..., None])
    # the arrows (top one, its mirror below), yellow paint over the ribs, worn by tyres
    top = [(60, 40), (100, 40), (985, 222), (135, 222)]
    arrow = poly_mask(W, H, [top, [(x, H - 1 - y) for x, y in top]], blur_px=1.0)
    paint = srgb((214, 184, 6))[None, None, :] * (0.9 + 0.12 * rib + 0.05 * fine)[..., None]
    wear = smoothstep(0.8, 1.0, dirt) * 0.3
    col = lerp(col, paint, (arrow * (1.0 - wear) * (1.0 - 0.8 * seam))[..., None])
    # red scrapes near the arrows' tails
    scr = np.zeros((H, W), np.float32)
    for k, (x0, y0) in enumerate([(22, 100), (34, 108), (44, 118), (24, 300), (38, 310)]):
        d = np.abs((xx - x0) - 0.12 * (yy - y0))
        scr = np.maximum(scr, (1.0 - smoothstep(1.0, 2.5, d)) * ((yy > y0) & (yy < y0 + 110 - 10 * k)))
    col = lerp(col, srgb((150, 20, 18))[None, None, :], (0.8 * scr)[..., None])
    col *= (1.0 - 0.12 * dirt)[..., None]
    hgt = 0.6 * rib * (1.0 - seam) - 0.8 * seam + 0.3 * fine
    nrm = normal_from_height(hgt, 0.5)
    orm = np.stack([np.ones((H, W), np.float32), 0.55 + 0.2 * (1.0 - arrow) + 0.1 * seam,
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


if __name__ == '__main__':
    turbo_pad()
    freewheel_pad()
