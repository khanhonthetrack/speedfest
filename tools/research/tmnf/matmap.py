"""Heights of one material's top surface on a grid (numbers), for reading shapes.
usage: matmap.py meas/X.json MATERIAL STEP [X1 Z1]   (e.g. StadiumRoad 4 64 64)"""
import sys, json
s = json.load(open(sys.argv[1])); v = s['verts']; mats = s['mats']
want = sys.argv[2]; step = float(sys.argv[3])
X1 = float(sys.argv[4]) if len(sys.argv) > 4 else 32; Z1 = float(sys.argv[5]) if len(sys.argv) > 5 else 32
tris = [(v[a], v[b], v[c]) for a, b, c, m in s['tris'] if 0 <= m < len(mats) and mats[m] == want]
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
        if best is None or y > best: best = y
    return best
n = int(round(X1 / step)); m = int(round(Z1 / step))
print('      ' + ' '.join('%5.0f' % (i * step) for i in range(n + 1)))
for j in range(m, -1, -1):
    z = min(j * step, Z1 - 0.01) + 0.005
    row = []
    for i in range(n + 1):
        h = hit(min(i * step, X1 - 0.01) + 0.005, z)
        row.append('    .' if h is None else '%5.1f' % h)
    print('%5.1f ' % z + ' '.join(row))
