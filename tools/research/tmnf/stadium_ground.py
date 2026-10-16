"""The stadium surround's outer ground as a coarse grid (our own numbers): for each cell centre of
one quarter (x >= 0, z <= 0, centred on the field), the highest ground-material surface below 5 m
in a visual_mesh.py measurement of Zone/Square32 and its class: p forecourt, r road, g grass,
k parking, . none (under a building, the field, or only the -100 m base). Heights in decimetres
on the cell corners, classes at the cell centres.
usage: python3 -I stadium_ground.py VIS.json OUT.json [CELL] [CLASS_CELL]"""
import sys, json
from collections import defaultdict

CLASSES = {'StadiumWarpParvis': 'p', 'StadiumWarpRoute': 'r', 'StadiumWarpGrass': 'g',
           'StadiumWarpGrassPreLightGen': 'g', 'StadiumWarpParking': 'k'}
vis, out = sys.argv[1], sys.argv[2]
cell = float(sys.argv[3]) if len(sys.argv) > 3 else 16.0
ccell = float(sys.argv[4]) if len(sys.argv) > 4 else cell / 2.0   # classes on a finer grid
ex, ez = 1728.0, 1248.0
nx, nz = int(ex / cell), int(ez / cell)
tris = []
for m in json.load(open(vis))['meshes']:
    if '/High/' not in m['name'] or m['mat'] not in CLASSES:
        continue
    vs = [(v[0] - 512.0, v[1], v[2] - 512.0) for v in m['verts']]
    for t in m['tris']:
        a, b, c = vs[t[0]], vs[t[1]], vs[t[2]]
        if max(a[1], b[1], c[1]) > 5.0:
            continue
        tris.append((a, b, c, CLASSES[m['mat']]))
grid = defaultdict(list)
for k, (a, b, c, _) in enumerate(tris):
    x0, x1 = min(a[0], b[0], c[0]), max(a[0], b[0], c[0])
    z0, z1 = min(a[2], b[2], c[2]), max(a[2], b[2], c[2])
    for i in range(int(x0 // cell), int(x1 // cell) + 1):
        for j in range(int(z0 // cell), int(z1 // cell) + 1):
            grid[(i, j)].append(k)

def hit(px, pz):
    best = None
    for k in grid[(int(px // cell), int(pz // cell))]:
        a, b, c, cls = tris[k]
        d = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
        if abs(d) < 1e-9:
            continue
        l1 = ((b[2] - c[2]) * (px - c[0]) + (c[0] - b[0]) * (pz - c[2])) / d
        l2 = ((c[2] - a[2]) * (px - c[0]) + (a[0] - c[0]) * (pz - c[2])) / d
        l3 = 1.0 - l1 - l2
        if min(l1, l2, l3) < -1e-6:
            continue
        y = l1 * a[1] + l2 * b[1] + l3 * c[1]
        if best is None or y > best[0]:
            best = (y, cls)
    return best

heights, classes = [], []
for j in range(nz + 1):          # heights on the cell corners, rows from z = 0 outwards (z < 0)
    row = []
    for i in range(nx + 1):      # columns from x = 0 outwards
        h = hit(i * cell + 0.01, -(j * cell + 0.01))
        row.append(round(h[0] * 10) if h and h[0] > -30.0 else -9999)   # the -100 m base: none
    heights.append(row)
cnx, cnz = int(ex / ccell), int(ez / ccell)
for j in range(cnz):             # classes at the (finer) class cells' centres
    row = ''
    for i in range(cnx):
        h = hit(i * ccell + ccell * 0.5, -(j * ccell + ccell * 0.5))
        row += h[1] if h and h[0] > -30.0 else '.'
    classes.append(row)
json.dump({'cell': cell, 'nx': nx, 'nz': nz, 'class_cell': ccell, 'cnx': cnx, 'cnz': cnz, 'heights_dm': heights, 'classes': classes,
           'about': 'Our coarse grid of the Stadium surround\'s outer ground (one quarter, x >= 0, z <= 0 from the field centre; heights in dm on the (nx + 1) x (nz + 1) cell corners, -9999 none; classes at the centres of the cnx x cnz class cells, class_cell m), measured locally from TMNF\'s Zone/Square32 visual meshes with tools/research/tmnf/stadium_ground.py; classes p forecourt, r road, g grass, k parking, . none.'},
          open(out, 'w'), separators=(',', ':'))
from collections import Counter
print('cells', nx, 'x', nz, Counter(''.join(classes)))
