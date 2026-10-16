"""Asphalt height along a road centre line (arc about c or straight), and the bank across it.
usage: bank.py meas/X.json arc CX CZ R N | bank.py meas/X.json line X0 LENGTH N"""
import sys, json, math
s = json.load(open(sys.argv[1])); v = s['verts']; mats = s['mats']
tris = [(v[a], v[b], v[c]) for a, b, c, m in s['tris'] if 0 <= m < len(mats) and mats[m] in ('StadiumRoad',)]
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
mode = sys.argv[2]
if mode == 'arc':
    cx, cz, r = map(float, sys.argv[3:6]); n = int(sys.argv[6])
    for i in range(n + 1):
        a = math.radians(-90 + 90 * i / n)
        dx, dz = math.cos(a), math.sin(a)
        hs = [hit(cx + dx * (r + o), cz + dz * (r + o)) for o in (-8, 0, 8)]
        bank = (hs[2] - hs[0]) / 16 if None not in hs else None
        print('a=%6.1f h=%s bank(out)=%s' % (math.degrees(a), None if hs[1] is None else round(hs[1], 3), None if bank is None else round(bank, 4)))
else:
    x0, = map(float, sys.argv[3:4]); L = float(sys.argv[4]); n = int(sys.argv[5])
    for i in range(n + 1):
        z = min(L - 0.01, max(0.01, L * i / n))
        hs = [hit(x0 + o, z) for o in (-8, 0, 8)]
        bank = (hs[2] - hs[0]) / 16 if None not in hs else None
        print('z=%5.1f h=%s bank(+x)=%s' % (z, None if hs[1] is None else round(hs[1], 3), None if bank is None else round(bank, 4)))
