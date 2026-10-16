"""Closed cross-section loops of a measured collision mesh (meas/<name>.json, from extract_surf.py):
intersect with the plane axis=value, chain the segments of all materials into closed loops, merge
collinear runs of one material, and print each loop as a GDScript table of
[Vector2-able (u, v), material] points, where (u, v) are the other two axes in order (x: (y, z),
y: (x, z), z: (x, y)) and each point's material is that of the segment starting at it.
Only numbers and material names are printed (for our own generators); no mesh data is kept.
usage: section_loop.py meas/X.json z 16 [--tol 0.002] [--min-seg 0.01]"""
import sys, json, math


def main():
    path, axis_s, val_s = sys.argv[1:4]
    tol = float(sys.argv[sys.argv.index('--tol') + 1]) if '--tol' in sys.argv else 0.002
    min_seg = float(sys.argv[sys.argv.index('--min-seg') + 1]) if '--min-seg' in sys.argv else 0.01
    s = json.load(open(path))
    axis = 'xyz'.index(axis_s)
    val = float(val_s)
    v, mats = s['verts'], s['mats']
    oth = [i for i in range(3) if i != axis]
    segs = []
    for a, b, c, m in s['tris']:
        tri = [v[a], v[b], v[c]]
        pts = []
        for i in range(3):
            p, q = tri[i], tri[(i + 1) % 3]
            dp, dq = p[axis] - val, q[axis] - val
            if (dp <= 0 <= dq or dq <= 0 <= dp) and dp != dq:
                t = dp / (dp - dq)
                pts.append(tuple(p[k] + (q[k] - p[k]) * t for k in oth))
        uniq = []
        for p in pts:
            if all(math.dist(p, u) > tol for u in uniq):
                uniq.append(p)
        if len(uniq) == 2:
            segs.append([uniq[0], uniq[1], mats[m] if 0 <= m < len(mats) else str(m)])
    # drop duplicates (the plane through a mesh edge yields the same segment from both triangles)
    uniq_segs = []
    for a, b, m in segs:
        if math.dist(a, b) <= tol:
            continue
        if any((math.dist(a, p) <= tol and math.dist(b, q) <= tol) or (math.dist(a, q) <= tol and math.dist(b, p) <= tol)
               for p, q, _ in uniq_segs):
            continue
        uniq_segs.append([a, b, m])
    segs = uniq_segs
    # chain into loops, growing at both ends; loop items: (point, material of the segment from it)
    loops = []
    used = [False] * len(segs)

    def take(end):
        for j in range(len(segs)):
            if not used[j]:
                p, q, mj = segs[j]
                if math.dist(p, end) <= tol:
                    used[j] = True
                    return q, mj
                if math.dist(q, end) <= tol:
                    used[j] = True
                    return p, mj
        return None

    for i in range(len(segs)):
        if used[i]:
            continue
        used[i] = True
        a, b, m = segs[i]
        loop = [(a, m), (b, None)]
        while True:
            t = take(loop[-1][0])
            if t is None:
                break
            loop[-1] = (loop[-1][0], t[1])
            loop.append((t[0], None))
        while True:
            t = take(loop[0][0])
            if t is None:
                break
            loop.insert(0, (t[0], t[1]))
        closed = len(loop) > 3 and math.dist(loop[0][0], loop[-1][0]) <= tol
        if closed:
            loop.pop()
        loops.append((closed, loop))
    for closed, loop in loops:
        pts = simplify(loop, min_seg) if closed else loop
        area = sum(pts[i][0][0] * pts[(i + 1) % len(pts)][0][1] - pts[(i + 1) % len(pts)][0][0] * pts[i][0][1] for i in range(len(pts))) / 2
        print('# loop: %s, %d points, area %.3f' % ('closed' if closed else 'OPEN', len(pts), area))
        print('[' + ', '.join('[%.3f, %.3f, "%s"]' % (p[0], p[1], m or '') for p, m in pts) + ']')


def simplify(loop, min_seg):
    """Drop points between collinear segments of the same material, and very short segments."""
    pts = list(loop)
    changed = True
    while changed and len(pts) > 3:
        changed = False
        for i in range(len(pts)):
            p0, m0 = pts[i - 1]
            p1, m1 = pts[i]
            p2, _ = pts[(i + 1) % len(pts)]
            d1 = (p1[0] - p0[0], p1[1] - p0[1])
            d2 = (p2[0] - p1[0], p2[1] - p1[1])
            l1, l2 = math.hypot(*d1), math.hypot(*d2)
            cross = abs(d1[0] * d2[1] - d1[1] * d2[0])
            if (m0 == m1 and l1 > 0 and l2 > 0 and cross / (l1 * l2) < 1e-3) or l1 < min_seg:
                pts.pop(i)
                changed = True
                break
    return pts


main()
