"""Summarise a measured collision mesh (meas/<name>.json): materials, bounds, and the faces
grouped by material and normal with their extents."""
import sys, json, collections
s = json.load(open(sys.argv[1]))
v = s['verts']; mats = s['mats']
lo = [min(x[i] for x in v) for i in range(3)]; hi = [max(x[i] for x in v) for i in range(3)]
print('mats', mats, 'bounds', [round(x, 2) for x in lo], [round(x, 2) for x in hi], 'tris', len(s['tris']), 'loc', s.get('loc'))
def nrm(a, b, c):
    u = [b[i] - a[i] for i in range(3)]; w = [c[i] - a[i] for i in range(3)]
    n = [u[1]*w[2]-u[2]*w[1], u[2]*w[0]-u[0]*w[2], u[0]*w[1]-u[1]*w[0]]
    l = sum(x*x for x in n) ** 0.5 or 1
    return tuple(round(x / l, 2) for x in n)
groups = collections.defaultdict(list)
for a, b, c, m in s['tris']:
    groups[(mats[m] if 0 <= m < len(mats) else m, nrm(v[a], v[b], v[c]))].append((v[a], v[b], v[c]))
for (m, n), tris in sorted(groups.items(), key=lambda kv: (str(kv[0][0]), kv[0][1])):
    pts = [p for t in tris for p in t]
    ext = ['%.2f..%.2f' % (min(p[i] for p in pts), max(p[i] for p in pts)) for i in range(3)]
    print('  %-28s n=%-22s %3d tris  x %s  y %s  z %s' % (m, n, len(tris), *ext))
