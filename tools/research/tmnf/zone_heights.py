"""Zone (terrain) block control heights for the remake: for each measured Zone/* collision mesh
(meas/<name>.json from extract_surf.py), the surface's top height on a 9 x 9 grid 4 m apart (a coarse
survey; the remake interpolates its own surface through these points). Also reports how well a
bicubic surface through an n x n grid reproduces the measurement (share within 0.15 m).
usage: zone_heights.py MEAS_DIR OUT.json [--check]"""
import json, sys, os


SKIP = {'StadiumWater'}   # the water surface: the remake adds its own plane; survey the ground below


def height(s, x, z):
    """Top surface height of a mesh at (x, z) (vertical ray, water ignored), None if no hit."""
    v = s['verts']
    mats = s.get('mats', [])
    best = None
    for a, b, c, m in s['tris']:
        if 0 <= m < len(mats) and mats[m] in SKIP:
            continue
        A, B, C = v[a], v[b], v[c]
        den = (B[2] - C[2]) * (A[0] - C[0]) + (C[0] - B[0]) * (A[2] - C[2])
        if abs(den) < 1e-9:
            continue
        l1 = ((B[2] - C[2]) * (x - C[0]) + (C[0] - B[0]) * (z - C[2])) / den
        l2 = ((C[2] - A[2]) * (x - C[0]) + (A[0] - C[0]) * (z - C[2])) / den
        l3 = 1 - l1 - l2
        if min(l1, l2, l3) < -1e-6:
            continue
        y = l1 * A[1] + l2 * B[1] + l3 * C[1]
        best = y if best is None else max(best, y)
    return best


def grid(s, n):
    at = lambda t: min(31.999, max(0.001, 32.0 * t / (n - 1)))
    return [[height(s, at(i), at(j)) for i in range(n)] for j in range(n)]


def _cr(p0, p1, p2, p3, t):
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)


def bicubic(g, x, z):
    n = len(g)
    fx, fz = x / 32 * (n - 1), z / 32 * (n - 1)
    i, j = min(int(fx), n - 2), min(int(fz), n - 2)
    at = lambda jj, ii: g[max(0, min(n - 1, jj))][max(0, min(n - 1, ii))]
    rows = [_cr(at(j + k, i - 1), at(j + k, i), at(j + k, i + 1), at(j + k, i + 2), fx - i) for k in (-1, 0, 1, 2)]
    return _cr(*rows, fz - j)


def main():
    meas, outp = sys.argv[1], sys.argv[2]
    out = {"_doc": "Zone (terrain) block surfaces: control heights (block-local TMNF y) on a 9 x 9 grid 4 m apart "
           "(rows along z from 0, columns along x from 0), measured from a TMNF install by "
           "tools/research/tmnf/zone_heights.py; the remake interpolates its own surface through them.", "shapes": {}}
    for f in sorted(os.listdir(meas)):
        if not f.startswith('Zone__') or f.startswith(('Zone__Water', 'Zone__Dirt__')):
            continue
        s = json.load(open(os.path.join(meas, f)))
        g = [[round(h if h is not None else 9.0, 2) for h in row] for row in grid(s, 9)]
        out["shapes"][f[:-5].replace('__', '/')] = g
        if '--check' in sys.argv:
            ok = tot = 0
            for xi in range(32):
                for zi in range(32):
                    h = height(s, xi + 0.5, zi + 0.5)
                    if h is not None:
                        tot += 1
                        ok += abs(bicubic(g, xi + 0.5, zi + 0.5) - h) <= 0.15
            print('%-40s %.0f%%' % (f[:-5], 100.0 * ok / max(1, tot)))
    json.dump(out, open(outp, 'w'), separators=(',', ':'))


main()
