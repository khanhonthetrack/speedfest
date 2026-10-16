"""Lofts for hand-sculpted pieces (Sculpt rocks, bridge towers): the measured collision mesh
(meas/<name>.json) sliced by horizontal planes every STEP m; each closed loop of the chosen
materials is followed up through the slices (by its centroid), resampled to N points evenly along
its length (counter-clockwise, its start turned to match the ring below, so twisting blades stay
smooth), and ends at an apex (the highest point of those materials above its last ring). The
remake builds each tube from these rings (blocks/shapes/sculpt.gd). Only our own resampled numbers
are written (rounded to cm); no mesh data is kept.
usage: loft_sections.py MEAS_DIR OUT.json KEY=SHAPE:MATERIAL[+MATERIAL]:Y0:Y1:STEP:N[:flat][:z][,...]
  e.g. loft_sections.py meas sculpt_lofts.json "Sculpt/A/Ground=Sculpt/A/Ground:StadiumSculpt:1.05:92:2:32"
  flat: each tube ends in a flat top at the highest point above its last ring ('top_y') instead
  of an apex (pads, plinths). z: slice across z (Y0..Y1 are then z values; rings are (x, y)
  pairs, 'axis': 'z'), for long leaning pieces; such tubes also start at a 'base' point.
"""
import json, sys, os, math


def slice_loops(verts, tris, y, tol=1e-4, close_at=None):
    """Closed loops (lists of (x, z)) where the plane at height y cuts the triangles; close_at:
    also close open chains whose two ends both lie at that second coordinate (a piece standing on
    the ground, open underneath)."""
    segs = []
    for a, b, c in tris:
        t = [verts[a], verts[b], verts[c]]
        pts = []
        for i in range(3):
            p, q = t[i], t[(i + 1) % 3]
            dp, dq = p[1] - y, q[1] - y
            if (dp < 0 <= dq or dq < 0 <= dp) and dp != dq:
                s = dp / (dp - dq)
                pts.append((p[0] + (q[0] - p[0]) * s, p[2] + (q[2] - p[2]) * s))
        if len(pts) == 2 and math.dist(pts[0], pts[1]) > tol:
            segs.append(pts)
    # chain segments by end points within SNAP of each other (grid hash, neighbouring cells)
    snap = 0.005
    cell = lambda p: (int(math.floor(p[0] / snap)), int(math.floor(p[1] / snap)))
    grid = {}
    for i, (p, q) in enumerate(segs):
        grid.setdefault(cell(p), []).append((i, 1))
        grid.setdefault(cell(q), []).append((i, 0))

    def near(p):
        cx, cz = cell(p)
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for j, side in grid.get((cx + dx, cz + dz), []):
                    yield j, side
    used = [False] * len(segs)
    loops = []
    for i in range(len(segs)):
        if used[i]:
            continue
        used[i] = True
        loop = [segs[i][0], segs[i][1]]
        for forward in (True, False):        # grow at both ends (an open chain may start mid-way)
            while True:
                end = loop[-1] if forward else loop[0]
                nxt = None
                for j, side in near(end):
                    if not used[j] and math.dist(segs[j][1 - side], end) <= snap:
                        nxt = (j, side)
                        break
                if nxt is None:
                    break
                used[nxt[0]] = True
                if forward:
                    loop.append(segs[nxt[0]][nxt[1]])
                else:
                    loop.insert(0, segs[nxt[0]][nxt[1]])
            if math.dist(loop[0], loop[-1]) <= snap:
                break
        if len(loop) > 3 and math.dist(loop[0], loop[-1]) <= snap:
            loops.append(loop[:-1])
        elif close_at is not None and len(loop) > 3 and abs(loop[0][1] - close_at) < 0.05 and abs(loop[-1][1] - close_at) < 0.05:
            loops.append(loop)
    return loops


def area(loop):
    return sum(loop[i][0] * loop[(i + 1) % len(loop)][1] - loop[(i + 1) % len(loop)][0] * loop[i][1]
               for i in range(len(loop))) / 2


def centroid(loop):
    return (sum(p[0] for p in loop) / len(loop), sum(p[1] for p in loop) / len(loop))


def resample(loop, n):
    if area(loop) < 0:
        loop = loop[::-1]
    lens = [math.dist(loop[i], loop[(i + 1) % len(loop)]) for i in range(len(loop))]
    total = sum(lens)
    out, i, acc = [], 0, 0.0
    for k in range(n):
        target = total * k / n
        while acc + lens[i] < target:
            acc += lens[i]
            i += 1
        t = (target - acc) / lens[i] if lens[i] > 0 else 0
        p, q = loop[i], loop[(i + 1) % len(loop)]
        out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def align(ring, prev):
    """Rotate ring's start so it best matches prev (same point count)."""
    n = len(ring)
    best = min(range(n), key=lambda s: sum(math.dist(ring[(s + k) % n], prev[k]) ** 2 for k in range(n)))
    return ring[best:] + ring[:best]


def loft(path, mats, y0, y1, step, n, flat=False, axis='y'):
    s = json.load(open(path))
    v, mlist = s['verts'], s['mats']
    if axis == 'z':
        # slice across z instead: work on (x, z, y), so the rings are (x, y) pairs
        v = [(p[0], p[2], p[1]) for p in v]
    tris = [(a, b, c) for a, b, c, m in s['tris'] if 0 <= m < len(mlist) and mlist[m] in mats]
    tubes = []          # {'rings': [[y, ring]], 'open': bool}
    ground = min(v[i][2] for tri in tris for i in tri) if axis == 'z' and tris else None
    y = y0
    while y <= y1 + 1e-6:
        loops = [l for l in slice_loops(v, tris, y, close_at=ground) if abs(area(l)) > 0.05]
        open_tubes = [t for t in tubes if t['open']]
        taken = set()
        for loop in loops:
            c = centroid(loop)
            best = None
            for t in open_tubes:
                if id(t) in taken:
                    continue
                d = math.dist(c, centroid(t['rings'][-1][1]))
                if d < 8.0 and (best is None or d < best[0]):
                    best = (d, t)
            ring = resample(loop, n)
            if best is None:
                tubes.append({'rings': [[y, ring]], 'open': True})
                taken.add(id(tubes[-1]))
            else:
                t = best[1]
                t['rings'].append([y, align(ring, t['rings'][-1][1])])
                taken.add(id(t))
        for t in open_tubes:
            if id(t) not in taken:
                t['open'] = False
        y = round(y + step, 6)
    out = []
    pts = [v[i] for tri in tris for i in tri]
    real = (lambda p: (p[0], p[2], p[1])) if axis == 'z' else (lambda p: tuple(p))

    def end_point(ring, ly, sign):
        xs = [p[0] for p in ring]
        zs = [p[1] for p in ring]
        # the tube ends before the next slice that missed it: look no further than two slices on
        near = [p for p in pts if 0 <= (p[1] - ly) * sign <= 2 * step and min(xs) - 3 <= p[0] <= max(xs) + 3
                and min(zs) - 3 <= p[2] <= max(zs) + 3]
        if not near:
            return (sum(xs) / n, ly, sum(zs) / n)
        return max(near, key=lambda p: p[1] * sign)

    for t in tubes:
        if len(t['rings']) < 2:
            continue                # a sliver one slice thick: not worth a tube
        ly, last = t['rings'][-1]
        top = end_point(last, ly, 1)
        tube = {'rings': [[round(yy, 2), [round(c, 2) for p in r for c in p]] for yy, r in t['rings']]}
        if axis == 'z':
            tube['axis'] = 'z'
            b = real(end_point(t['rings'][0][1], t['rings'][0][0], -1))
            tube['base'] = [round(b[0], 2), round(b[1], 2), round(b[2], 2)]
        if flat:
            tube['top_y'] = round(top[1], 2)
        else:
            a = real(top)
            tube['apex'] = [round(a[0], 2), round(a[1], 2), round(a[2], 2)]
        out.append(tube)
    return out


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    meas, out_path = sys.argv[1], sys.argv[2]
    data = json.load(open(out_path)) if os.path.exists(out_path) else {'source': 'tools/research/tmnf/loft_sections.py', 'shapes': {}}
    for item in sys.argv[3].split(','):
        key, spec = item.split('=')
        f = spec.split(':')
        shape, mats, y0, y1, step, n = f[:6]
        tubes = loft(os.path.join(meas, shape.replace('/', '__') + '.json'), set(mats.split('+')), float(y0), float(y1),
                     float(step), int(n), 'flat' in f[6:], 'z' if 'z' in f[6:] else 'y')
        data['shapes'][key] = tubes
        print('%s: %d tubes, rings %s' % (key, len(tubes), [len(t['rings']) for t in tubes]))
    json.dump(data, open(out_path, 'w'), separators=(',', ':'))


if __name__ == '__main__':
    main()
