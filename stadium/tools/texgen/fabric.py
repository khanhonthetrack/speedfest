"""Fabric textures (the grandstands' wave roofs, the platform skirts), our own art in the Stadium's
style: a white membrane stretched in panels (top), and the same membrane seen from below between
steel arch ribs with cross bracing (underside). One tile is 8 m x 8 m (u along the block, v round
the roof's curve).
usage: python3 stadium/tools/texgen/fabric.py"""
import math
import numpy as np
from texlib import *


def membrane(w, h, seed, ppm, panel_m=4.0):
    """White fabric: panels with stitched seams across v every panel_m, stretch wrinkles."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n1 = fbm(w, h, seed, beta=2.6, lo=1.0)
    n2 = fbm(w, h, seed + 1, beta=1.0, lo=24.0)
    # wrinkles: long thin ridges along v, strongest between the seams
    wr = blur(fbm(w, h, seed + 2, beta=1.2, lo=6.0), 1.0)
    wr = np.sin(xx / ppm * 2 * math.pi / 0.9 + wr * 2.5) * 0.5 + 0.5
    seam = np.zeros((h, w), np.float32)
    for k in range(int(w / (panel_m * ppm)) + 1):
        seam = np.maximum(seam, 1 - smoothstep(0.0, 0.035 * ppm, np.abs(xx - k * panel_m * ppm)))
    stitch = seam * (0.5 + 0.5 * np.sign(np.sin(yy / ppm * 2 * math.pi / 0.08)))
    return n1, n2, wr, seam, stitch


def fabric_top(name='fabric_top', ppm=64, size_m=8.0, seed=91):
    w = h = int(size_m * ppm)
    n1, n2, wr, seam, stitch = membrane(w, h, seed, ppm)
    grime_m = grime(w, h, seed + 3, 0.8, 1.5)
    tone = (1.0 + 0.03 * n1 + 0.02 * n2 + 0.025 * (wr - 0.5)) * (1.0 - 0.06 * grime_m) * (1.0 - 0.18 * seam)
    col = srgb((236, 237, 238))[None, None, :] * tone[..., None]
    hgt = 0.6 * wr + 0.3 * n2 + 0.8 * seam
    nrm = normal_from_height(hgt, 0.5)
    rough = 0.62 + 0.05 * n2 + 0.08 * grime_m
    orm = np.stack([1.0 - 0.15 * seam, rough, np.zeros_like(rough)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


def fabric_under(name='fabric_under', ppm=64, size_m=8.0, seed=95):
    """From below: the membrane between steel ribs (along v at u = 0, every 8 m) and purlins
    (along u at v = 0), X bracing in each bay, bolted plates where they meet."""
    w = h = int(size_m * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n1, n2, wr, seam, stitch = membrane(w, h, seed, ppm)
    col = srgb((214, 216, 220))[None, None, :] * (1.0 + 0.03 * n1 + 0.025 * (wr - 0.5))[..., None]
    col *= (1.0 - 0.12 * seam)[..., None]
    um = xx / ppm
    vm = yy / ppm
    du = np.minimum(um, size_m - um)
    dv = np.minimum(vm, size_m - vm)
    rib = 1 - smoothstep(0.26, 0.30, du)
    rib_edge = (1 - smoothstep(0.26, 0.30, du)) * smoothstep(0.18, 0.26, du)
    purlin = 1 - smoothstep(0.13, 0.16, dv)
    brace = np.zeros((h, w), np.float32)
    for sgn in (1, -1):
        # diagonals corner to corner of the bay
        d = np.abs((um - size_m / 2) * sgn - (vm - size_m / 2)) / math.sqrt(2)
        brace = np.maximum(brace, 1 - smoothstep(0.05, 0.075, d))
    brace *= 1 - rib
    plate = (1 - smoothstep(0.42, 0.46, np.sqrt(du ** 2 + dv ** 2)))
    steel = srgb((150, 154, 160))
    col = lerp(col, steel[None, None, :] * (1.0 + 0.05 * n2)[..., None], np.clip(rib + purlin + brace + plate, 0, 1))
    col *= (1.0 - 0.25 * rib_edge)[..., None]
    hgt = 2.0 * rib + 1.2 * purlin + 0.8 * brace + 2.4 * plate + 0.4 * wr
    nrm = normal_from_height(blur(hgt, 0.8), 0.6)
    metal = np.clip(rib + purlin + brace + plate, 0, 1)
    rough = 0.65 - 0.25 * metal
    orm = np.stack([1.0 - 0.3 * blur(metal, 3.0) * (1 - metal), rough, 0.7 * metal], -1)
    save(name, np.clip(col, 0, 1), nrm, orm)


if __name__ == '__main__':
    fabric_top()
    fabric_under()
