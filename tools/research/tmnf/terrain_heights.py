"""Terrain-like road blocks (dirt roads, dirt hills) for the remake: for each selected measured
collision mesh (meas/<name>.json from extract_surf.py), the top height of its terrain materials on
a grid `step` m apart over the block's footprint (a survey; the remake interpolates its own bicubic
surface through the points), and each grid cell's surface class (g: grass, d: dirt, r: road) for physics and
looks. Decorations (fences, signs, awnings, arches) are not surveyed: the remake adds its own.
Reports how well the bicubic surface reproduces the measured terrain (share within 0.15 m on a 1 m
grid). Only numbers are written; no mesh data is kept.
usage: terrain_heights.py MEAS_DIR OUT.json PREFIX[,PREFIX...] [--step 2] [--skip NAME,NAME]"""
import json, sys, os, math

TERRAIN = {'StadiumGrassOcc': 'g', 'StadiumGrass': 'g', 'StadiumDirt': 'd', 'StadiumDirtToRoad': 'd',
           'StadiumDirtRoad': 'd', 'StadiumDirtBorder': 'd', 'StadiumRoadDirtToRoadFlat': 'd',
           'StadiumRoadToDirt': 'r', 'StadiumRoadDirtToRoad': 'r'}


def load(path):
    s = json.load(open(path))
    v, mats = s['verts'], s['mats']
    tris = []
    for a, b, c, m in s['tris']:
        name = mats[m] if 0 <= m < len(mats) else ''
        if name in TERRAIN:
            tris.append((v[a], v[b], v[c], TERRAIN[name]))
    return tris


def top(tris, x, z):
    best, cls = None, None
    for A, B, C, k in tris:
        if max(A[0], B[0], C[0]) < x or min(A[0], B[0], C[0]) > x or max(A[2], B[2], C[2]) < z or min(A[2], B[2], C[2]) > z:
            continue
        den = (B[2] - C[2]) * (A[0] - C[0]) + (C[0] - B[0]) * (A[2] - C[2])
        if abs(den) < 1e-9:
            continue
        l1 = ((B[2] - C[2]) * (x - C[0]) + (C[0] - B[0]) * (z - C[2])) / den
        l2 = ((C[2] - A[2]) * (x - C[0]) + (A[0] - C[0]) * (z - C[2])) / den
        l3 = 1 - l1 - l2
        if min(l1, l2, l3) < -1e-6:
            continue
        y = l1 * A[1] + l2 * B[1] + l3 * C[1]
        if best is None or y > best:
            best, cls = y, k
    return best, cls


def _cr(p0, p1, p2, p3, t):
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)


def bicubic(g, step, x, z):
    nz, nx = len(g), len(g[0])
    fx, fz = x / step, z / step
    i, j = min(int(fx), nx - 2), min(int(fz), nz - 2)
    at = lambda jj, ii: g[max(0, min(nz - 1, jj))][max(0, min(nx - 1, ii))]
    rows = [_cr(at(j + k, i - 1), at(j + k, i), at(j + k, i + 1), at(j + k, i + 2), fx - i) for k in (-1, 0, 1, 2)]
    return _cr(*rows, fz - j)


def main():
    meas, outp, prefixes = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
    step = float(sys.argv[sys.argv.index('--step') + 1]) if '--step' in sys.argv else 2.0
    skip = set(sys.argv[sys.argv.index('--skip') + 1].split(',')) if '--skip' in sys.argv else set()
    out = {"_doc": "Terrain-like road blocks: control heights (block-local TMNF y) every 'step' m over the "
           "footprint (rows along z from 0, columns along x from 0) and each grid cell's surface class "
           "(g grass, d dirt, r road), measured from a TMNF install by tools/research/tmnf/terrain_heights.py; "
           "the remake interpolates its own surface through them.", "shapes": {}}
    for f in sorted(os.listdir(meas)):
        name = f[:-5]
        if not f.endswith('.json') or not any(name.startswith(p) for p in prefixes) or name in skip:
            continue
        tris = load(os.path.join(meas, f))
        if not tris:
            continue
        w = 32.0 * math.ceil(max(max(t[0][0], t[1][0], t[2][0]) for t in tris) / 32.0 - 0.01)
        d = 32.0 * math.ceil(max(max(t[0][2], t[1][2], t[2][2]) for t in tris) / 32.0 - 0.01)
        nx, nz = int(round(w / step)) + 1, int(round(d / step)) + 1
        clamp = lambda v, hi: min(hi - 0.001, max(0.001, v))
        g = []
        for j in range(nz):
            row = []
            for i in range(nx):
                h, _ = top(tris, clamp(i * step, w), clamp(j * step, d))
                row.append(round(h, 2) if h is not None else None)
            g.append(row)
        # holes (no terrain there): the nearest surveyed height along the row, else the ground
        for row in g:
            for i in range(nx):
                if row[i] is None:
                    near = [row[k] for k in sorted(range(nx), key=lambda k: abs(k - i)) if row[k] is not None]
                    row[i] = near[0] if near else 1.0
        cls = []
        for j in range(nz - 1):
            line = ''
            for i in range(nx - 1):
                _, k = top(tris, (i + 0.5) * step, (j + 0.5) * step)
                line += k or 'g'
            cls.append(line)
        out["shapes"][name.replace('__', '/')] = {"w": w, "d": d, "step": step, "g": g, "cls": cls}
        ok = tot = 0
        for xi in range(int(w)):
            for zi in range(int(d)):
                h, _ = top(tris, xi + 0.5, zi + 0.5)
                if h is not None:
                    tot += 1
                    ok += abs(bicubic(g, step, xi + 0.5, zi + 0.5) - h) <= 0.15
        print('%-52s %3dx%-3d %5.1f%%' % (name, w, d, 100.0 * ok / max(1, tot)))
    json.dump(out, open(outp, 'w'), separators=(',', ':'))


main()
