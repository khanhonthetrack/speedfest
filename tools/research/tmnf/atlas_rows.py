#!/usr/bin/env python3
"""Border-atlas rows, ours against TMNF's, block by block.

The colour check (material_check.py) compares blurred mean colours, so a band laid one segment off
(ribs where TMNF has the black band, both dark) hides from it. This compares the atlas row itself:
at the centroid of each TMNF triangle that uses its border atlas (materials whose diffuse texture
is StadiumRoadBorderD), our triangle at the same spot (in its plane within 3 cm, the normals
agreeing) gives our row there (TMNF's v runs up: row = (1 - v) * 512; ours v * 512). Per shape it
prints TMNF's atlas area, where ours uses the atlas too (matched), the area whose rows differ by
more than 8, and what ours has instead where it doesn't use the atlas ((none): no surface there).
Research only: TMNF's data stays local; this script prints numbers and names.

usage: atlas_rows.py <ours dir> <ref dir> [shape prefix] [--show=N]
  <ours dir>  blocks.bin / blocks.json from stadium/tests/block_dump.tscn
  <ref dir>   ref_visuals.py's output (vis/<Shape>.json, materials.json)
  --show=N    also print the N largest triangles whose rows differ (area, centroid, TMNF's row, ours)
"""
import json, os, sys
import numpy as np

OUR_KEYS = {'border_panel', 'border_blue', 'border_ribs', 'border_black', 'border_orange', 'border_green',
            'gate_line'}
TOLERANCE = 8.0       # rows (of 512)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    show = 0
    for a in sys.argv[1:]:
        if a.startswith('--show='):
            show = int(a.split('=')[1])
    ours_dir, ref = args[0], args[1]
    only = args[2] if len(args) > 2 else ''
    mats = json.load(open(os.path.join(ref, 'materials.json')))
    border = {k for k, v in mats.items() if v.get('D') == 'StadiumRoadBorderD'}
    index = json.load(open(os.path.join(ours_dir, 'blocks.json')))
    raw = np.fromfile(os.path.join(ours_dir, 'blocks.bin'),
                      dtype=np.dtype([('k', '<i4'), ('v', '<f4', (9,)), ('uv', '<f4', (6,))]))
    for ent in index:
        shape = ent['shape']
        path = os.path.join(ref, 'vis', shape.replace('/', '__') + '.json')
        if (only and not shape.startswith(only)) or not os.path.exists(path):
            continue
        tri = raw[ent['first']:ent['first'] + ent['count']]
        if not len(tri):
            continue
        keys = np.array([ent['keys'][k] for k in tri['k']])
        P = tri['v'].reshape(-1, 3, 3).astype(np.float64)
        UV = tri['uv'].reshape(-1, 3, 2).astype(np.float64)
        e1 = P[:, 1] - P[:, 0]
        e2 = P[:, 2] - P[:, 0]
        N = np.cross(e1, e2)
        A = np.linalg.norm(N, axis=1)
        ok = A > 1e-9
        P, UV, e1, e2, keys = P[ok], UV[ok], e1[ok], e2[ok], keys[ok]
        Nn = N[ok] / A[ok][:, None]
        total = matched = off = 0.0
        other = {}
        offs = []
        for m in json.load(open(path))['meshes']:
            if m['mat'] not in border:
                continue
            V = np.asarray(m['verts'], float)
            T = np.asarray(m['tris']).reshape(-1, 3)
            U = np.asarray(m['uvs'][0], float)
            for t in T:
                q = V[t]
                n = np.cross(q[1] - q[0], q[2] - q[0])
                a = np.linalg.norm(n) / 2
                if a < 1e-4:
                    continue
                n /= 2 * a
                c = q.mean(0)
                row_t = ((1 - U[t][:, 1].mean()) % 1.0) * 512
                total += a
                dist = np.abs(((c - P[:, 0]) * Nn).sum(1))
                hit = None
                for i in np.where((dist < 0.03) & (np.abs((Nn * n).sum(1)) > 0.9))[0]:
                    v2 = c - P[i, 0]
                    d00, d01, d11 = e1[i] @ e1[i], e1[i] @ e2[i], e2[i] @ e2[i]
                    d20, d21 = v2 @ e1[i], v2 @ e2[i]
                    den = d00 * d11 - d01 * d01
                    if den == 0:
                        continue
                    b1 = (d11 * d20 - d01 * d21) / den
                    b2 = (d00 * d21 - d01 * d20) / den
                    if min(1 - b1 - b2, b1, b2) > -0.02:
                        hit = (i, 1 - b1 - b2, b1, b2)
                        break
                if hit is None:
                    other['(none)'] = other.get('(none)', 0.0) + a
                    continue
                i, b0, b1, b2 = hit
                if keys[i] not in OUR_KEYS:
                    other[str(keys[i])] = other.get(str(keys[i]), 0.0) + a
                    continue
                row_o = ((b0 * UV[i, 0, 1] + b1 * UV[i, 1, 1] + b2 * UV[i, 2, 1]) % 1.0) * 512
                matched += a
                if abs(row_o - row_t) > TOLERANCE:
                    off += a
                    offs.append((round(a, 2), tuple(np.round(c, 2).tolist()), round(row_t, 1), round(row_o, 1)))
        if total > 0:
            instead = ', '.join('%s %.1f' % (k, v) for k, v in sorted(other.items(), key=lambda t: -t[1])[:4])
            print('%-44s atlas %7.1f  matched %7.1f  rows off %6.1f  | %s' % (shape, total, matched, off, instead))
            for o in sorted(offs, key=lambda x: -x[0])[:show]:
                print('      area %.2f at %s: TMNF row %.1f, ours %.1f' % (o[0], o[1], o[2], o[3]))


if __name__ == '__main__':
    main()
