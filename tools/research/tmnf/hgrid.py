"""Top-down map of a measured mesh: '#' curb (h > hmin), '.' surface, ' ' nothing; rows = z.
usage: hgrid.py meas/X.json X0 X1 Z0 Z1 STEP HMIN YMAX"""
import sys, json
s = json.load(open(sys.argv[1])); v = s['verts']
X0, X1, Z0, Z1, step = map(float, sys.argv[2:7]); hmin = float(sys.argv[7]); ymax = float(sys.argv[8])
tris = [(v[a], v[b], v[c]) for a, b, c, m in s['tris']]
def hit(x, z):
    best = None
    for A, B, C in tris:
        d = (B[2]-C[2])*(A[0]-C[0]) + (C[0]-B[0])*(A[2]-C[2])
        if abs(d) < 1e-12: continue
        l1 = ((B[2]-C[2])*(x-C[0]) + (C[0]-B[0])*(z-C[2])) / d
        l2 = ((C[2]-A[2])*(x-C[0]) + (A[0]-C[0])*(z-C[2])) / d
        l3 = 1 - l1 - l2
        if min(l1, l2, l3) < -1e-6: continue
        y = l1*A[1] + l2*B[1] + l3*C[1]
        if y <= ymax and (best is None or y > best): best = y
    return best
z = Z0
while z <= Z1 + 1e-9:
    row = ''
    x = X0
    while x <= X1 + 1e-9:
        h = hit(x + 1e-3, z + 1e-3)
        row += ' ' if h is None else ('#' if h > hmin else '.')
        x += step
    print('%6.1f %s' % (z, row))
    z += step
