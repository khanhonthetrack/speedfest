"""Vertical section of a visual_mesh.py measurement: cuts every triangle by the plane through
(cx, cz) at the given heading and draws the cut (horizontal distance along the plane, height) into
a PNG, one colour per mesh; --print lists the segments too. Our own plots of local measurements.
usage: python3 -I vsection.py VIS.json OUT.png --at CX,CZ --deg A [--range U0,U1,Y0,Y1] [--px M] [--y H]
       [--only TEXT] [--skip TEXT] [--print]"""
import sys, json, math, zlib, struct, argparse

ap = argparse.ArgumentParser()
ap.add_argument('vis'); ap.add_argument('out')
ap.add_argument('--at', default='512,512'); ap.add_argument('--deg', type=float, default=0.0)
ap.add_argument('--range', default='0,1300,-110,300'); ap.add_argument('--px', type=float, default=1.0)
ap.add_argument('--only', default=''); ap.add_argument('--skip', default='/Low/')
ap.add_argument('--print', action='store_true')
ap.add_argument('--y', type=float, default=None, help='cut by the horizontal plane at this height instead (plan view: u = x, second axis = z)')
a = ap.parse_args()
cx, cz = map(float, a.at.split(','))
u0, u1, y0, y1 = map(float, a.range.split(','))
th = math.radians(a.deg)
dx, dz = math.cos(th), math.sin(th)      # along the plane
nx, nz = -dz, dx                          # plane normal
W, H = int((u1 - u0) / a.px) + 1, int((y1 - y0) / a.px) + 1
img = bytearray(b'\xff' * (W * H * 3))
def plot(u, y, c):
    i, j = int((u - u0) / a.px), int((y1 - y) / a.px)
    if 0 <= i < W and 0 <= j < H:
        k = 3 * (j * W + i); img[k:k + 3] = c
def line(p, q, c):
    n = int(max(abs(q[0] - p[0]), abs(q[1] - p[1])) / a.px) + 1
    for s in range(n + 1):
        t = s / n; plot(p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, c)
for y in range(int(y0 // 50) * 50, int(y1) + 1, 50):          # grid every 50 m
    for u in range(int(u0), int(u1) + 1, 2): plot(u, y, (225, 225, 225))
for u in range(int(u0 // 50) * 50, int(u1) + 1, 50):
    for y in range(int(y0), int(y1) + 1, 2): plot(u, y, (225, 225, 225))
d = json.load(open(a.vis))
for k, m in enumerate(d['meshes']):
    if (a.only and a.only not in m['name'] + str(m['mat'])) or (a.skip and a.skip in m['name']): continue
    h = (k * 2654435761) & 0xFFFFFF
    col = bytes([((h >> 16) & 0xFF) // 2 + 20, ((h >> 8) & 0xFF) // 2 + 20, (h & 0xFF) // 2 + 20])
    vs = m['verts']
    for t in m['tris']:
        ps = [vs[i] for i in t]
        s = [(p[1] - a.y) if a.y is not None else (p[0] - cx) * nx + (p[2] - cz) * nz for p in ps]
        cut = []
        for i in range(3):
            j = (i + 1) % 3
            if (s[i] < 0) != (s[j] < 0):
                f = s[i] / (s[i] - s[j])
                p = [ps[i][c] + (ps[j][c] - ps[i][c]) * f for c in range(3)]
                cut.append((p[0] - cx, p[2] - cz) if a.y is not None else ((p[0] - cx) * dx + (p[2] - cz) * dz, p[1]))
        if len(cut) == 2:
            line(cut[0], cut[1], col)
            if a.print: print(m['name'], '%.2f %.2f  %.2f %.2f' % (cut[0] + cut[1]))
def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
raw = b''.join(b'\x00' + bytes(img[r * W * 3:(r + 1) * W * 3]) for r in range(H))
open(a.out, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
                        + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))
print('section', a.out, W, 'x', H)
