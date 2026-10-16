"""Cross-section of a measured collision mesh: intersect with the plane axis=value (x, y or z) and
print the segments grouped by material, chained into polylines (2D coords in the other two axes).
usage: section.py meas/X.json z 16 [--surf material_surfaces.json]"""
import sys, json, collections
s = json.load(open(sys.argv[1])); axis = 'xyz'.index(sys.argv[2]); val = float(sys.argv[3])
v = s['verts']; mats = s['mats']
oth = [i for i in range(3) if i != axis]
segs = collections.defaultdict(list)
for a, b, c, m in s['tris']:
    pts = []
    tri = [v[a], v[b], v[c]]
    for i in range(3):
        p, q = tri[i], tri[(i + 1) % 3]
        dp, dq = p[axis] - val, q[axis] - val
        if abs(dp) < 1e-6 and abs(dq) < 1e-6: continue
        if (dp <= 0 <= dq or dq <= 0 <= dp) and dp != dq:
            t = dp / (dp - dq)
            pts.append(tuple(round(p[k] + (q[k] - p[k]) * t, 3) for k in oth))
    pts = sorted(set(pts))
    if len(pts) == 2:
        segs[mats[m] if 0 <= m < len(mats) else m].append((pts[0], pts[1]))
for m, ss in segs.items():
    # chain segments into polylines
    chains = []
    rest = list(ss)
    while rest:
        a, b = rest.pop()
        chain = [a, b]
        grown = True
        while grown:
            grown = False
            for k, (p, q) in enumerate(rest):
                if p == chain[-1]: chain.append(q)
                elif q == chain[-1]: chain.append(p)
                elif q == chain[0]: chain.insert(0, p)
                elif p == chain[0]: chain.insert(0, q)
                else: continue
                rest.pop(k); grown = True; break
        chains.append(chain)
    for ch in chains:
        print('%-26s %s' % (m, ' '.join('(%g,%g)' % p for p in ch)))
