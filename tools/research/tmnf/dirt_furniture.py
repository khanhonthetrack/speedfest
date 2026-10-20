"""The dirt roads' furniture (TMNF's Road/Dirt* and Road/DirtHigh* pieces: advert boards, low advert
bands, kiosks on legs, inflatable logo bumpers with rubber ends), measured from the local reference
visuals (ref_visuals.py: vis/<shape>.json) as placements for the remake to build its own furniture
at: each board's four corners (a sign's also the way it faces), each bumper's centre line (a point
every ~2 m) with its width and height, each kiosk's legs (the ring of cut-out cards round them: its
corners x, z and height). Only these numbers are written; no mesh, texture or UV data.
usage: dirt_furniture.py REF_DIR OUT.json"""
import glob, json, math, os, sys

BOARDS = {'StadiumDirtPub2x1': 'board', 'StadiumDirtRacePub8x1A': 'board8x1', 'StadiumDirtPubNvidiaWorldcup': 'band',
          'StadiumScreenArrow2x1': 'sign'}
BUMPERS = {'StadiumDirtLogos': 'logo', 'StadiumDirtRaceSignsRubber': 'rubber', 'StadiumRaceSignsRubber': 'rubber'}
# the border atlas' tubes (orange, or dark): only parts shaped as one (TUBE_LEN long, TUBE_W thick)
TUBES = {'StadiumDirtRoadBorder': 'border'}
TUBE_LEN = 3.0
TUBE_W = (0.8, 2.0)
CARDS = {'StadiumDirtStructureGeneric': 'legs'}
KIOSK_Y = 3.5          # a band this high up is a kiosk's face


def parts(verts, tris):
    """Connected parts of a mesh (vertices merged by position): lists of vertex positions."""
    key = {}
    canon = []
    for v in verts:
        k = (round(v[0], 3), round(v[1], 3), round(v[2], 3))
        canon.append(key.setdefault(k, len(key)))
    parent = list(range(len(key)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for t in tris:
        a, b, c = (canon[i] for i in t)
        for x, y in ((a, b), (b, c)):
            ra, rb = find(x), find(y)
            if ra != rb:
                parent[ra] = rb
    groups = {}
    for t in tris:
        groups.setdefault(find(canon[t[0]]), set()).update(t)
    return [[verts[i] for i in sorted(g)] for g in groups.values()]


def rnd(p):
    return [round(p[0], 2), round(p[1], 2), round(p[2], 2)]


def quad_corners(pts):
    """A flat rectangle's four corners (deduplicated): bottom edge first, then the top, going the
    same way along."""
    uniq = []
    for p in pts:
        if all(math.dist(p, q) > 0.02 for q in uniq):
            uniq.append(p)
    if len(uniq) != 4:
        return None
    uniq.sort(key=lambda p: p[1])
    b0, b1 = uniq[0], uniq[1]
    t0, t1 = uniq[2], uniq[3]
    # the top corner over each bottom one (horizontal distance)
    hd = lambda a, b: math.hypot(a[0] - b[0], a[2] - b[2])
    if hd(b0, t0) + hd(b1, t1) > hd(b0, t1) + hd(b1, t0):
        t0, t1 = t1, t0
    return [rnd(b0), rnd(b1), rnd(t1), rnd(t0)]


def facing(verts, tris, part):
    """The unit normal of the first triangle lying on a part (its vertices among the part's)."""
    on = {(round(v[0], 3), round(v[1], 3), round(v[2], 3)) for v in part}
    for t in tris:
        a, b, c = (verts[i] for i in t)
        if all((round(q[0], 3), round(q[1], 3), round(q[2], 3)) in on for q in (a, b, c)):
            u = [b[k] - a[k] for k in range(3)]
            w = [c[k] - a[k] for k in range(3)]
            n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
            ln = math.sqrt(sum(x * x for x in n)) or 1.0
            return [x / ln for x in n]
    return [0.0, 0.0, 0.0]


def axis_of(pts):
    """The main horizontal direction of a set of points (2D PCA on x, z)."""
    n = len(pts)
    mx = sum(p[0] for p in pts) / n
    mz = sum(p[2] for p in pts) / n
    sxx = sum((p[0] - mx) ** 2 for p in pts)
    szz = sum((p[2] - mz) ** 2 for p in pts)
    sxz = sum((p[0] - mx) * (p[2] - mz) for p in pts)
    ang = 0.5 * math.atan2(2 * sxz, sxx - szz)
    return (mx, mz), (math.cos(ang), math.sin(ang))


def bumper(pts):
    """A tube's centre line (its ends at its extremes along it, the centres of ~2 m slices between),
    width and height."""
    (mx, mz), (ax, az) = axis_of(pts)
    s = [(p[0] - mx) * ax + (p[2] - mz) * az for p in pts]
    s0, s1 = min(s), max(s)
    n = max(1, round((s1 - s0) / 2.0))
    cen = []
    for k in range(n):
        lo = s0 + (s1 - s0) * k / n
        hi = s0 + (s1 - s0) * (k + 1) / n
        sel = [p for p, t in zip(pts, s) if lo - 1e-6 <= t <= hi + 1e-6]
        if sel:
            cen.append([sum(p[0] for p in sel) / len(sel), (min(p[1] for p in sel) + max(p[1] for p in sel)) / 2,
                        sum(p[2] for p in sel) / len(sel)])

    def at(p, t):
        d = (p[0] - mx) * ax + (p[2] - mz) * az
        return [p[0] + (t - d) * ax, p[1], p[2] + (t - d) * az]
    line = [at(cen[0], s0)] + cen + [at(cen[-1], s1)]
    across = []
    for p in pts:
        c = min(line, key=lambda q: (q[0] - p[0]) ** 2 + (q[2] - p[2]) ** 2)
        across.append(math.hypot(p[0] - c[0], p[2] - c[2]))
    w = 2 * sorted(across)[int(0.95 * (len(across) - 1))]
    h = max(p[1] for p in pts) - min(p[1] for p in pts)
    return [round(w, 2), round(h, 2), [rnd(p) for p in line]]


def main():
    ref, out = sys.argv[1], sys.argv[2]
    res = {}
    for f in sorted(glob.glob(os.path.join(ref, 'vis', 'Road__Dirt*.json'))):
        shape = os.path.basename(f)[:-5].replace('__', '/')
        d = json.load(open(f))
        boards, bumpers, cards = [], [], []
        for m in d['meshes']:
            mat = m['mat']
            if mat in CARDS:
                # a ring of cards round a box (a kiosk's legs): its corners (x, z) and height
                for p in parts(m['verts'], m['tris']):
                    xz = []
                    for q in p:
                        if all(math.hypot(q[0] - a[0], q[2] - a[1]) > 0.05 for a in xz):
                            xz.append([round(q[0], 2), round(q[2], 2)])
                    cx = sum(a[0] for a in xz) / len(xz)
                    cz = sum(a[1] for a in xz) / len(xz)
                    xz.sort(key=lambda a: math.atan2(a[1] - cz, a[0] - cx))
                    cards.append([CARDS[mat], xz, round(min(q[1] for q in p), 2), round(max(q[1] for q in p), 2)])
            elif mat in BOARDS:
                for p in parts(m['verts'], m['tris']):
                    c = quad_corners(p)
                    if c is None:
                        continue
                    kind = BOARDS[mat]
                    if kind == 'band' and min(q[1] for q in c) > KIOSK_Y:
                        kind = 'kiosk'
                    # the same panel's other face (TMNF draws both): kept once
                    if any(b[0] == kind and all(min(math.dist(a, q) for q in b[1]) < 0.3 for a in c) for b in boards):
                        continue
                    if kind == 'sign':
                        # a sign shows one way: its face's normal (x, z) from a triangle on it
                        n = facing(m['verts'], m['tris'], p)
                        boards.append([kind, c, [round(n[0], 2), round(n[2], 2)]])
                    else:
                        boards.append([kind, c])
            elif mat in BUMPERS:
                for p in parts(m['verts'], m['tris']):
                    if len(p) < 8:
                        continue
                    bumpers.append([BUMPERS[mat]] + bumper(p))
            elif mat in TUBES:
                # with the atlas rows they show (5th and 95th percentile; TMNF's v runs up)
                rows = {}
                for v, uv in zip(m['verts'], m['uvs'][0]):
                    rows.setdefault((round(v[0], 3), round(v[1], 3), round(v[2], 3)), []).append((1.0 - uv[1]) * 512.0)
                for p in parts(m['verts'], m['tris']):
                    if len(p) < 8:
                        continue
                    b = bumper(p)
                    ln = math.dist(b[2][0], b[2][-1])
                    if ln < TUBE_LEN or not (TUBE_W[0] <= b[0] <= TUBE_W[1] and TUBE_W[0] <= b[1] <= TUBE_W[1]):
                        continue
                    r = sorted(x for q in p for x in rows.get((round(q[0], 3), round(q[1], 3), round(q[2], 3)), []))
                    bumpers.append([TUBES[mat]] + b + [[round(r[len(r) // 20]), round(r[len(r) * 19 // 20])]])
        if boards or bumpers or cards:
            res[shape] = {'boards': boards, 'bumpers': bumpers, 'cards': cards}
    json.dump({'about': __doc__.split('\n')[0], 'shapes': res}, open(out, 'w'), separators=(',', ':'))
    for s, v in res.items():
        print('%-50s boards %2d bumpers %2d cards %d' % (s, len(v['boards']), len(v['bumpers']), len(v['cards'])))


if __name__ == '__main__':
    main()
