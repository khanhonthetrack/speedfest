"""Height map of a measured mesh's top surface: one char per cell by height band.
usage: hmap.py meas/X.json STEP BAND1,BAND2,... CHARS [YMAX]   (one char per cell: CHARS[k] for the k-th band)"""
import sys, json
s = json.load(open(sys.argv[1])); v = s['verts']
step = float(sys.argv[2]); bands = [float(b) for b in sys.argv[3].split(',')]; chars = sys.argv[4]
ymax = float(sys.argv[5]) if len(sys.argv) > 5 else 1e9
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
n = int(round(32 / step))
for j in range(n, -1, -1):
    z = min(j * step, 31.99) + 0.005
    row = ''
    for i in range(n + 1):
        x = min(i * step, 31.99) + 0.005
        h = hit(x, z)
        if h is None: row += ' '; continue
        k = sum(1 for b in bands if h > b)
        row += chars[k]
    print('%5.1f %s' % (z, row))
