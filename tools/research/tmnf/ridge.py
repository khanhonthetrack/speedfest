"""Ridge (highest point) of a measured mesh along x for each z row, within a height window.
usage: ridge.py meas/X.json Z0 Z1 ZSTEP X0 X1 XSTEP YMAX"""
import sys, json
s = json.load(open(sys.argv[1])); v = s['verts']
Z0, Z1, zstep, X0, X1, xstep, ymax = map(float, sys.argv[2:9])
tris = [(v[a], v[b], v[c]) for a, b, c, m in s['tris']]
def hit(x, z):
    best = None
    for A, B, C in tris:
        if max(A[0], B[0], C[0]) < x or min(A[0], B[0], C[0]) > x or max(A[2], B[2], C[2]) < z or min(A[2], B[2], C[2]) > z: continue
        d = (B[2]-C[2])*(A[0]-C[0]) + (C[0]-B[0])*(A[2]-C[2])
        if abs(d) < 1e-12: continue
        l1 = ((B[2]-C[2])*(x-C[0]) + (C[0]-B[0])*(z-C[2])) / d
        l2 = ((C[2]-A[2])*(x-C[0]) + (A[0]-C[0])*(z-C[2])) / d
        l3 = 1 - l1 - l2
        if min(l1, l2, l3) < -1e-6: continue
        y = l1*A[1] + l2*B[1] + l3*C[1]
        if y <= ymax and (best is None or y > best): best = y
    return best
out = []
z = Z0
while z <= Z1 + 1e-9:
    bx, bh = None, -1
    x = X0
    while x <= X1 + 1e-9:
        h = hit(x, z)
        if h is not None and h > bh + 1e-4: bx, bh = x, h
        x += xstep
    out.append((round(z, 2), round(bx, 2) if bx is not None else None, round(bh, 3)))
    z += zstep
print(out)
