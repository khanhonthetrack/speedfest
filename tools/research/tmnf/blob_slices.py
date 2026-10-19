"""Slices a TMNF visual mesh (ref_visuals.py's local JSON) into horizontal cuts, one object at a
time: the material's triangles sampled densely, split into connected parts (shared corners), each
part cut every --dy metres, each cut's points grouped (single linkage, --link m) and printed as
centre (x, z) and radius (mean and max distance from the centre). For recreating hand-modelled
decorations (inflatable trees, cacti) as our own lathes and tubes: prints numbers only.
usage: python3 -I tools/research/tmnf/blob_slices.py <ref>/vis/<Shape>.json <material> [--dy=0.5]
       [--link=0.8] [--min=200] [--parts=all|N]"""
import json
import sys
from collections import defaultdict

import numpy as np


def parts_of(V, T):
    n = len(V)
    p = list(range(n))

    def f(a):
        while p[a] != a:
            p[a] = p[p[a]]
            a = p[a]
        return a
    seen = {}
    for i, v in enumerate(V):
        k = tuple(np.round(v, 3))
        if k in seen:
            p[f(i)] = f(seen[k])
        else:
            seen[k] = i
    for t in T:
        a = f(t[0])
        p[f(t[1])] = a
        p[f(t[2])] = a
    g = defaultdict(list)
    for t_i, t in enumerate(T):
        g[f(t[0])].append(t_i)
    return list(g.values())


def sample(P, step=0.12):
    """Points over triangles P (n, 3, 3), about one per step^2 m^2 (at least the corners)."""
    out = [P.reshape(-1, 3)]
    rng = np.random.default_rng(1)
    for tri in P:
        a = 0.5 * np.linalg.norm(np.cross(tri[1] - tri[0], tri[2] - tri[0]))
        k = int(a / (step * step))
        if k <= 0:
            continue
        u = rng.random((k, 2))
        flip = u.sum(1) > 1
        u[flip] = 1 - u[flip]
        out.append(tri[0] + u[:, :1] * (tri[1] - tri[0]) + u[:, 1:] * (tri[2] - tri[0]))
    return np.concatenate(out)


def clusters(S, link):
    lab = -np.ones(len(S), int)
    k = 0
    for i in range(len(S)):
        if lab[i] >= 0:
            continue
        stack = [i]
        lab[i] = k
        while stack:
            j = stack.pop()
            d = np.hypot(S[:, 0] - S[j, 0], S[:, 1] - S[j, 1])
            for q in np.where((d < link) & (lab < 0))[0]:
                lab[q] = k
                stack.append(q)
        k += 1
    return [S[lab == q] for q in range(k)]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opt = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    dy = float(opt.get('dy', 0.5))
    link = float(opt.get('link', 0.8))
    min_n = int(opt.get('min', 200))
    d = json.load(open(args[0]))
    for m in d['meshes']:
        if m['mat'] != args[1]:
            continue
        V = np.asarray(m['verts'], float)
        T = np.asarray(m['tris'], int).reshape(-1, 3)
        parts = sorted(parts_of(V, T), key=len, reverse=True)
        parts = [q for q in parts if len(q) >= min_n] if opt.get('parts', 'all') == 'all' else parts[:int(opt['parts'])]
        for pi, tris in enumerate(parts):
            P = V[T[tris]]
            S = sample(P)
            lo, hi = S.min(0), S.max(0)
            top = S[S[:, 1].argmax()]
            print('part %d: %d triangles, x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f, top (%.2f, %.2f, %.2f)' % (
                pi, len(tris), lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], top[0], top[1], top[2]))
            for y in np.arange(lo[1] + dy * 0.5, hi[1], dy):
                cut = S[np.abs(S[:, 1] - y) < dy * 0.5][:, [0, 2]]
                if len(cut) == 0:
                    continue
                desc = []
                for c in clusters(cut, link):
                    if len(c) < 5:
                        continue
                    ctr = c.mean(0)
                    r = np.hypot(c[:, 0] - ctr[0], c[:, 1] - ctr[1])
                    desc.append('(%.2f, %.2f) r %.2f / %.2f' % (ctr[0], ctr[1], r.mean(), r.max()))
                print('   y %6.2f  %s' % (y, '   '.join(desc)))


if __name__ == '__main__':
    main()
