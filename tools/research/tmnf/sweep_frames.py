"""The sweep frames of swept Road/Main pieces (GT diagonals) for the remake: TMNF sweeps the road
section along a centre line, and each frame leaves three asphalt vertices on the road surface (left
edge, centre, right edge). For each selected measured collision mesh (meas/<name>.json from
extract_surf.py) this finds those triples and writes, per frame in path order, the centre (x, z),
the angle of the lateral (left -> right, degrees from +x toward +z) and the section's width scale
(edge distance / 20.92 m). Only numbers are written; no mesh data is kept.
usage: sweep_frames.py MEAS_DIR OUT.json KEY=SHAPE[,KEY=SHAPE...]
  e.g. sweep_frames.py meas gt_diag_frames.json 2x2=Road/Main/GTDiag/2x2Air,3x2=...,4x3=..."""
import json, sys, os, math

WIDTH = 20.92        # the asphalt between the shoulders (road.gd: 2 * (16 - ROAD_EDGE))


def frames(path):
    s = json.load(open(path))
    v, mats = s['verts'], s['mats']
    ids = set()
    for a, b, c, m in s['tris']:
        if 0 <= m < len(mats) and mats[m] == 'StadiumRoad':
            ids |= {a, b, c}
    pts = sorted({(round(v[i][0], 4), round(v[i][1], 4), round(v[i][2], 4)) for i in ids})
    centres = {(round(p[0], 2), round(p[2], 2)): p for p in pts}
    best = {}           # centre vertex -> the frame whose edge distance is nearest the road's width
    for l in pts:
        for r in pts:
            d = math.dist((l[0], l[2]), (r[0], r[2]))
            if abs(d - WIDTH) > 0.2 or r[0] <= l[0] - 1.0 or abs(r[1] - l[1]) > 0.01:
                continue
            m = (round((l[0] + r[0]) / 2, 2), round((l[2] + r[2]) / 2, 2))
            # the centre vertex, allowing for rounding
            keys = [(m[0] + dx, m[1] + dz) for dx in (-0.01, 0, 0.01) for dz in (-0.01, 0, 0.01)]
            key = next((k for k in keys if k in centres), None)
            ang = math.degrees(math.atan2(r[2] - l[2], r[0] - l[0]))
            if key is None or abs(ang) > 80.0:
                continue
            f = [round((l[0] + r[0]) / 2, 3), round((l[2] + r[2]) / 2, 3), round(ang, 3), round(d / WIDTH, 4)]
            if key not in best or abs(d - WIDTH) < abs(best[key][3] * WIDTH - WIDTH):
                best[key] = f
    out = sorted(best.values(), key=lambda f: f[1])
    dedup = []
    for f in out:
        if not dedup or abs(f[1] - dedup[-1][1]) > 1e-3 or abs(f[0] - dedup[-1][0]) > 1e-3:
            dedup.append(f)
    return dedup


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    meas, out_path = sys.argv[1], sys.argv[2]
    result = {}
    for item in sys.argv[3].split(','):
        key, shape = item.split('=')
        fr = frames(os.path.join(meas, shape.replace('/', '__') + '.json'))
        result[key] = fr
        print('%s: %d frames, z %.2f..%.2f, scale %.4f..%.4f' % (key, len(fr), fr[0][1], fr[-1][1],
              min(f[3] for f in fr), max(f[3] for f in fr)))
    json.dump({'source': 'tools/research/tmnf/sweep_frames.py', 'columns': ['x', 'z', 'lateral_deg', 'width_scale'],
               'frames': result}, open(out_path, 'w'), separators=(',', ':'))


if __name__ == '__main__':
    main()
