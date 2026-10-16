"""Top surface height of a measured mesh along a line: vertical rays at (x, z) for z (or x) steps.
usage: vprofile.py meas.json x0 z0 x1 z1 n [ymax]"""
import sys, json
s = json.load(open(sys.argv[1])); v = s['verts']
x0, z0, x1, z1 = map(float, sys.argv[2:6]); n = int(sys.argv[6]); ymax = float(sys.argv[7]) if len(sys.argv) > 7 else 1e9
def hit(x, z):
    best = None
    for a, b, c, m in s['tris']:
        A, B, C = v[a], v[b], v[c]
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
for i in range(n + 1):
    t = i / n
    x = x0 + (x1 - x0) * t; z = z0 + (z1 - z0) * t
    h = hit(x, z)
    out.append(round(h, 3) if h is not None else None)
print(out)
