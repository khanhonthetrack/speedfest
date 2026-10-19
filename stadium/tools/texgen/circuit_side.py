"""Our circuit side (UV-mapped, 2048 x 1024): the sides of the circuit's plates and its walls'
ends, laid out as TMNF's is so the same faces show the same parts (rows measured from TMNF's,
docs/research/m11_check.md). Down the main part (u 0.25..1, 16 m a tile along a side, the whole
height an 8 m side): a light rail at the top and bottom, an orange band below the top rail and one
above the bottom rail, dark steel panels between with their joints; the left quarter a bolted dark
plate (the walls' end caps). Drawn here; only the rows and colours follow TMNF.
Run: python3 stadium/tools/texgen/circuit_side.py"""
import numpy as np
from texlib import fbm, smoothstep, srgb, lerp, normal_from_height, save, grime

W, H = 2048, 1024


def circuit_side(name='circuit_side', seed=421):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    fine = fbm(W, H, seed, beta=0.7, lo=120.0)
    mott = fbm(W, H, seed + 1, beta=2.2, lo=2.0, hi=40.0)
    dirt = np.clip(grime(W, H, seed + 2, amount=1.0), 0, 1)
    # the main part: dark panels, 4 m wide (512 px), joints and a recessed course
    steel = srgb((33, 34, 33))[None, None, :] * (1.0 + 0.08 * mott + 0.06 * fine)[..., None]
    col = steel.copy()
    hgt = 0.3 * fine
    px = xx % 512.0
    joint_v = 1.0 - smoothstep(2.0, 5.0, np.minimum(px, 512.0 - px))
    course = np.zeros((H, W), np.float32)
    for r0, r1 in ((644, 667), (732, 760), (830, 847)):
        course = np.maximum(course, smoothstep(r0 - 1, r0 + 1, yy) * (1.0 - smoothstep(r1 - 1, r1 + 1, yy)))
    col = lerp(col, srgb((40, 41, 42))[None, None, :] * (1.0 + 0.06 * fine)[..., None], (0.8 * course)[..., None])
    col *= (1.0 - 0.35 * joint_v)[..., None]
    hgt += 0.5 * course - 0.8 * joint_v
    # orange bands (not across the left quarter), top and bottom
    def band(r0, r1):
        return smoothstep(r0 - 1.5, r0 + 1.5, yy) * (1.0 - smoothstep(r1 - 1.5, r1 + 1.5, yy))
    orange = np.maximum(band(72, 158), band(864, 952))
    left = 1.0 - smoothstep(516.0, 524.0, xx)
    paint = srgb((198, 104, 8))[None, None, :] * (1.0 + 0.05 * mott + 0.05 * fine - 0.15 * dirt)[..., None]
    col = lerp(col, paint, (orange * (1.0 - left))[..., None])
    # the left quarter (the blocks' ends, the walls' end caps): dark plate, a vented strip where
    # the orange bands run, a bolted plate in the middle
    vent = np.maximum(band(126, 152), band(870, 898))
    holes = (1.0 - smoothstep(10.0, 13.0, np.abs((xx % 64.0) - 32.0))) * vent
    plate_d = srgb((52, 50, 48))[None, None, :] * (1.0 + 0.1 * mott + 0.08 * fine - 0.2 * dirt)[..., None]
    col = lerp(col, plate_d, (left * orange)[..., None])
    col = lerp(col, srgb((146, 143, 140))[None, None, :] * (1.0 + 0.05 * fine)[..., None], (left * vent * (1.0 - holes))[..., None])
    col = lerp(col, srgb((24, 23, 22))[None, None, :], (left * holes)[..., None])
    mid = band(384, 632)
    plate = srgb((46, 43, 42))[None, None, :] * (1.0 + 0.1 * mott + 0.08 * fine - 0.2 * dirt)[..., None]
    col = lerp(col, plate, (left * mid)[..., None])
    edge = left * np.maximum(band(382, 386), band(630, 634))
    col = lerp(col, srgb((70, 66, 64))[None, None, :], edge[..., None])
    bolts = np.zeros((H, W), np.float32)
    for bx in (90.0, 430.0):
        for by in (430.0, 580.0):
            d = np.sqrt((xx - bx) ** 2 + (yy - by) ** 2)
            bolts = np.maximum(bolts, 1.0 - smoothstep(14.0, 18.0, d))
            ring = (1.0 - smoothstep(18.0, 22.0, d)) * smoothstep(14.0, 16.0, d)
            col = lerp(col, srgb((210, 212, 214))[None, None, :], (left * ring)[..., None])
    col = lerp(col, srgb((20, 20, 20))[None, None, :], (left * bolts)[..., None])
    hgt += left * (0.4 * mid - 0.5 * bolts + 0.3 * vent)
    # the light rails along the top and bottom edges (TMNF's rows: light, a rail with its shading)
    top = 1.0 - smoothstep(52.0, 56.0, yy)
    bot = smoothstep(962.0, 966.0, yy)
    metal = srgb((218, 219, 215))[None, None, :] * (1.0 + 0.04 * fine)[..., None]
    shade = 1.0 - 0.45 * (1.0 - smoothstep(0.0, 3.0, np.abs(yy - 33.0))) - 0.25 * band(44, 54) \
        - 0.5 * (1.0 - smoothstep(0.0, 4.0, np.abs(yy - 978.0)))
    col = lerp(col, metal * shade[..., None], np.maximum(top, bot)[..., None])
    gap = np.maximum(band(56, 72), band(952, 962)) * (1.0 - orange)
    col = lerp(col, srgb((140, 110, 70))[None, None, :] * (1.0 - 0.6 * left)[..., None], (0.6 * band(56, 72) * (1.0 - orange))[..., None])
    col = lerp(col, srgb((26, 25, 26))[None, None, :], (band(952, 962) * (1.0 - orange))[..., None])
    rail = np.maximum(top, bot)
    hgt += 0.6 * rail + 0.2 * orange * (1.0 - left) - 0.2 * gap
    nrm = normal_from_height(hgt, 0.5)
    orm = np.stack([np.ones((H, W), np.float32), 0.6 + 0.15 * (1.0 - rail) - 0.1 * orange, 0.3 * rail + 0.2 * (1.0 - orange)], -1)
    save(name, np.clip(col, 0, 1), nrm, orm, size=(1024, 512))


if __name__ == '__main__':
    circuit_side()
