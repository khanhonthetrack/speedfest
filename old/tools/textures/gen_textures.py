#!/usr/bin/env python3
"""Generate SpeedFest's tileable PBR textures (original, procedural; no third-party material).

Writes 1024x1024 seamless maps to game/assets/textures/<name>/:
  <name>_albedo.jpg   sRGB base color
  <name>_normal.png   tangent-space normal map (OpenGL / Godot convention, +Y up)
  <name>_rough.jpg    roughness (grayscale)
Materials: asphalt (road deck), concrete (decks, walls, pillars, footings), metal (painted,
scratched barrier and gantry steel), rock (layered cliff rock for the coast).

Everything is built from FFT-filtered noise, which is periodic by construction, so every map
tiles without seams. Deterministic (fixed seeds): re-running gives identical files.

usage: python3 tools/textures/gen_textures.py [--size 1024] [--out game/assets/textures]
needs: numpy, Pillow
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


# ---------------------------------------------------------------- noise helpers

def fractal(n, rng, beta=2.0, lo=1.0, hi=None, aniso=(1.0, 1.0)):
    """Periodic 1/f^beta noise in [0, 1]. lo/hi: band limits in cycles per tile.
    aniso stretches the spectrum (e.g. (1, 12) gives streaks along x)."""
    white = rng.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta / 2.0)
    amp[f < lo] = 0.0
    if hi is not None:
        amp *= np.exp(-np.square(f / hi))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    out -= out.min()
    out /= max(out.max(), 1e-9)
    return out


def blur(a, sigma):
    """Periodic gaussian blur via FFT (sigma in pixels)."""
    n = a.shape[0]
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def cells(n, rng, count, jitter=1.0):
    """Periodic Worley distances F1, F2 and cell id for `count` random points."""
    pts = rng.random((count, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    cid = np.zeros((n, n), np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, n - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, i, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid


def normal_from_height(h, strength):
    """Tangent-space normal map (OpenGL, +Y = up in the image = -row direction)."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = dy * strength          # image rows grow downward; OpenGL green points up
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / ln, ny / ln, nz / ln], axis=-1)
    return ((nrm * 0.5 + 0.5) * 255.0 + 0.5).clip(0, 255).astype(np.uint8)


def save(name, out_dir, albedo, height, rough, nstrength):
    d = os.path.join(out_dir, name)
    os.makedirs(d, exist_ok=True)
    srgb = np.power(np.clip(albedo, 0.0, 1.0), 1.0 / 2.2)
    Image.fromarray((srgb * 255.0 + 0.5).astype(np.uint8), "RGB").save(
        os.path.join(d, f"{name}_albedo.jpg"), quality=90, optimize=True)
    Image.fromarray(normal_from_height(height, nstrength), "RGB").save(
        os.path.join(d, f"{name}_normal.png"), optimize=True)
    Image.fromarray((np.clip(rough, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "L").save(
        os.path.join(d, f"{name}_rough.jpg"), quality=92, optimize=True)
    print(f"{name}: albedo mean {albedo.mean(axis=(0, 1)).round(3)}, rough mean {rough.mean():.2f}")


def lin(rgb):
    return np.array(rgb, np.float32)


# ---------------------------------------------------------------- materials
# Albedo is linear; the shaders and materials tint it, so keep means near the real material.

def asphalt(n, rng):
    """Dense-graded asphalt: dark bitumen, packed aggregate chips (some light, some dark),
    fines, tar-sealed cracks and a polished wheel-worn look in the roughness. Tile = 2 m."""
    # aggregate: rounded chips around Worley points (random size), binder between them
    f1, f2, cid = cells(n, rng, 3200)
    tone = rng.random(cid.max() + 1)[cid]
    size = (0.35 + 0.45 * rng.random(cid.max() + 1))[cid] * (n / np.sqrt(3200.0))
    rim = np.clip((size - f1) / 2.0, 0.0, 1.0) * np.clip((f2 - f1 - 0.8) / 1.5, 0.0, 1.0)
    chip = rim
    fine = fractal(n, rng, beta=0.6, lo=60)
    mott = fractal(n, rng, beta=2.2, lo=1, hi=12)
    binder = lin([0.035, 0.035, 0.038]) * (0.8 + 0.4 * fine[..., None])
    stone_col = np.where(tone[..., None] > 0.86, lin([0.24, 0.23, 0.22]),
                         np.where(tone[..., None] > 0.45, lin([0.13, 0.13, 0.13]), lin([0.075, 0.07, 0.068])))
    stone_col = stone_col * (0.85 + 0.3 * fine[..., None])
    albedo = binder * (1.0 - chip[..., None]) + stone_col * chip[..., None]
    albedo *= (0.85 + 0.3 * mott[..., None])
    # sealed cracks: thin dark lines along a warped ridged noise
    crack_n = fractal(n, rng, beta=2.4, lo=2, hi=40)
    ridge = 1.0 - np.abs(crack_n - 0.5) * 2.0
    crack = np.clip((ridge - 0.985) / 0.015, 0.0, 1.0) * (fractal(n, rng, beta=2.0, lo=1, hi=6) > 0.55)
    tar = blur(crack.astype(np.float32), 1.6)
    tar = np.clip(tar * 2.5, 0.0, 1.0)
    albedo = albedo * (1.0 - 0.75 * tar[..., None]) + lin([0.02, 0.02, 0.022]) * 0.75 * tar[..., None]
    dome = np.clip(1.0 - f1 / np.maximum(size, 1.0), 0.0, 1.0)
    height = chip * (0.4 + 0.6 * np.sqrt(dome)) + fine * 0.3 - tar * 0.6
    rough = 0.88 - chip * 0.18 * tone - tar * 0.25 + (fine - 0.5) * 0.06
    return albedo, height, rough, 6.0


def concrete(n, rng):
    """Cast concrete: low-frequency mottling, fine sand grain, pinholes, faint form-panel
    seams with tie holes and water stains running down. Tile = 4 m (one seam per tile)."""
    mott = fractal(n, rng, beta=2.6, lo=1, hi=10)
    mid = fractal(n, rng, beta=1.6, lo=8, hi=90)
    grain = fractal(n, rng, beta=0.3, lo=120)
    base = 0.48 + 0.10 * (mott - 0.5) + 0.05 * (mid - 0.5) + 0.05 * (grain - 0.5)
    # pinholes
    holes = (fractal(n, rng, beta=0.0, lo=200) > 0.83).astype(np.float32)
    holes = np.clip(blur(holes, 0.8) * 3.0, 0.0, 1.0) * (fractal(n, rng, beta=2.0, lo=1, hi=5) > 0.4)
    # one horizontal and one vertical seam per tile with tie holes
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    seam = np.exp(-np.square((np.minimum(yy, n - yy)) / 1.6)) + np.exp(-np.square((np.minimum(xx, n - xx)) / 1.6))
    seam = np.clip(seam, 0.0, 1.0)
    ties = np.zeros((n, n), np.float32)
    for ty in (n * 0.25, n * 0.75):
        for tx in (n * 0.25, n * 0.75):
            ties += np.exp(-(np.square(xx - tx) + np.square(yy - ty)) / (2 * 5.0 ** 2))
    ties = np.clip(ties * 1.4, 0.0, 1.0)
    # streaks of water stain: noise stretched vertically, stronger near the top seam
    streak = fractal(n, rng, beta=2.0, lo=2, hi=60, aniso=(1.0, 0.08))
    stain = np.clip((streak - 0.55) * 3.0, 0.0, 1.0) * (0.4 + 0.6 * mott)
    v = base - 0.12 * holes - 0.10 * seam - 0.25 * ties - 0.10 * stain
    warm = lin([1.0, 0.98, 0.94])
    albedo = v[..., None] * warm
    height = 0.6 * mid + 0.25 * grain - 0.8 * holes - 0.6 * seam - 1.0 * ties
    rough = 0.86 + 0.06 * (grain - 0.5) - 0.12 * stain + 0.05 * holes
    return albedo, height, rough, 3.0


def metal(n, rng):
    """Painted structural steel: semi-gloss dark paint, fine brushing under it, scuffs and
    scratches showing bright bare steel, chipped edges of rust. Tile = 2 m."""
    brush = fractal(n, rng, beta=1.2, lo=4, hi=400, aniso=(0.04, 1.0))
    mott = fractal(n, rng, beta=2.4, lo=1, hi=10)
    paint = lin([0.11, 0.115, 0.13]) * (0.85 + 0.3 * mott[..., None])
    # scratches: thin bright lines from very anisotropic ridged noise at a few angles
    scr = np.zeros((n, n), np.float32)
    for ax in [(0.02, 1.0), (1.0, 0.03), (0.05, 1.0)]:
        r = fractal(n, rng, beta=2.0, lo=2, hi=120, aniso=ax)
        ridge = 1.0 - np.abs(r - 0.5) * 2.0
        scr += np.clip((ridge - 0.992) / 0.008, 0.0, 1.0) * (fractal(n, rng, beta=2.0, lo=1, hi=8) > 0.6)
    scr = np.clip(scr, 0.0, 1.0)
    wear = np.clip((fractal(n, rng, beta=1.6, lo=6, hi=90) - 0.84) * 8.0, 0.0, 1.0)
    rust = np.clip((fractal(n, rng, beta=1.8, lo=4, hi=60) - 0.8) * 5.0, 0.0, 1.0) * wear
    steel = lin([0.36, 0.37, 0.39]) * (0.9 + 0.2 * brush[..., None])
    albedo = paint * (1.0 - wear[..., None]) + steel * wear[..., None]
    albedo = albedo * (1.0 - scr[..., None]) + steel * scr[..., None]
    albedo = albedo * (1.0 - rust[..., None]) + lin([0.22, 0.09, 0.04]) * rust[..., None]
    height = 0.2 * brush - 0.5 * scr - 0.4 * wear + 0.3 * rust
    rough = 0.42 + 0.08 * (brush - 0.5) - 0.12 * (scr + wear) * (1.0 - rust) + 0.45 * rust
    return albedo, height, rough, 2.0


def rock(n, rng):
    """Layered sedimentary cliff rock: warped strata, joint cracks, lichen speckles. Tile = 6 m."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
    warp = fractal(n, rng, beta=2.6, lo=1, hi=8)
    warp2 = fractal(n, rng, beta=2.0, lo=2, hi=30)
    # strata are horizontal bands, periodic (integer number of bands per tile)
    phase = (yy * 9.0 + (warp - 0.5) * 1.6 + (warp2 - 0.5) * 0.25) * 2.0 * np.pi
    strata = 0.5 + 0.5 * np.sin(phase)
    layer_tone = 0.5 + 0.5 * np.sin(phase * 0.5 + 1.3)
    detail = fractal(n, rng, beta=1.1, lo=6, hi=300)
    big = fractal(n, rng, beta=2.4, lo=1, hi=6)
    # vertical joints via Worley cell edges stretched
    f1, f2, _ = cells(n, rng, 140)
    joint = np.clip(1.0 - (f2 - f1) / 4.0, 0.0, 1.0)
    c1 = lin([0.36, 0.29, 0.23])
    c2 = lin([0.52, 0.45, 0.36])
    c3 = lin([0.24, 0.20, 0.17])
    albedo = c1 * (1 - layer_tone[..., None]) + c2 * layer_tone[..., None]
    albedo = albedo * (0.55 + 0.7 * detail[..., None]) * (0.8 + 0.4 * big[..., None])
    albedo = albedo * (1 - 0.6 * joint[..., None]) + c3 * 0.6 * joint[..., None]
    lichen = np.clip((fractal(n, rng, beta=1.0, lo=30, hi=300) - 0.72) * 6.0, 0.0, 1.0) * (big > 0.45)
    albedo = albedo * (1 - 0.5 * lichen[..., None]) + lin([0.42, 0.42, 0.30]) * 0.5 * lichen[..., None]
    height = 0.8 * strata + 0.5 * detail + 0.4 * big - 1.2 * joint
    rough = 0.9 - 0.05 * strata + 0.05 * (detail - 0.5)
    return albedo, height, rough, 4.0


MATERIALS = {"asphalt": asphalt, "concrete": concrete, "metal": metal, "rock": rock}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--out", default=os.path.join(ROOT, "game", "assets", "textures"))
    ap.add_argument("only", nargs="*")
    a = ap.parse_args()
    for i, (name, fn) in enumerate(MATERIALS.items()):
        if a.only and name not in a.only:
            continue
        rng = np.random.default_rng(1000 + i)
        albedo, height, rough, ns = fn(a.size, rng)
        height = (height - height.min()) / max(height.max() - height.min(), 1e-9)
        save(name, a.out, albedo.astype(np.float32), height.astype(np.float32), rough, ns * a.size / 1024.0)


if __name__ == "__main__":
    main()
