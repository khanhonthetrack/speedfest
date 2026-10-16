"""Centre of a material's extent across x at each z (the road's centre line), with its width.
usage: center.py meas/X.json MATERIAL X1 Z1 DZ   (prints (z, centre x, width) per z)"""
import sys, json
s = json.load(open(sys.argv[1])); v = s['verts']; mats = s['mats']; want = sys.argv[2]
X1, Z1, dz = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
tris = [(v[a], v[b], v[c]) for a, b, c, m in s['tris'] if 0 <= m < len(mats) and mats[m] == want]
def hit(x, z):
    for A, B, C in tris:
        if max(A[0], B[0], C[0]) < x or min(A[0], B[0], C[0]) > x or max(A[2], B[2], C[2]) < z or min(A[2], B[2], C[2]) > z: continue
        d = (B[2]-C[2])*(A[0]-C[0]) + (C[0]-B[0])*(A[2]-C[2])
        if abs(d) < 1e-12: continue
        l1 = ((B[2]-C[2])*(x-C[0]) + (C[0]-B[0])*(z-C[2])) / d
        l2 = ((C[2]-A[2])*(x-C[0]) + (A[0]-C[0])*(z-C[2])) / d
        if min(l1, l2, 1 - l1 - l2) >= -1e-6: return True
    return False
z = 0.0
out = []
while z <= Z1 + 1e-6:
    zz = min(max(z, 0.01), Z1 - 0.01)
    xs = [i * 0.1 for i in range(int(X1 * 10) + 1) if hit(i * 0.1, zz)]
    if xs: out.append((round(z, 1), round((xs[0] + xs[-1]) / 2, 2), round(xs[-1] - xs[0], 2)))
    z += dz
print(out)
