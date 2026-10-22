"""The road cars' features from their specs (tools/assets/roadcar.py builds the body, then asks
this for what to cut out of it and what to add to it).

Spec keys (all optional; outlines in the plane's coordinates: front / rear (x, y), side (d, y),
top (x, d); `mirror` puts a copy on the -x side; radii round an outline's corners):
- arches: {"r": radius, "lift": centre above the wheel's, "x_in": inner end, "shapes": {0|1:
  outline (d, y) instead of a circle}}
- recesses: [{plane, outline, radii, depth, mats: (floor, walls), mirror, ray}] cut following
  the surface (grilles, intakes, vents, scoops' mouths)
- insets: [{plane, outline, radii, depth, mats, cover (a material laid over the opening: "lens",
  "lens_red"; none), elements: [...], mirror, ray}]: lamps, plates, handles. Elements, placed on
  the inset's floor (outline coords): ("patch", outline, radii, mat, lift), ("disc", (u, v), r,
  mat, lift), ("ring", (u, v), r_out, r_in, mat, lift), ("strip", line, width, mat, lift),
  ("projector", (u, v), r, lens_mat) a chrome barrel standing off the floor with a lens on it
- glass: [{plane, outline, radii, mirror, trim (width of the black seal round it), ray}]
- paint: [{plane, outline, radii, mat, mirror, lift, ray}] flat patches (blacked-out pillars,
  side markers, badges' places)
- gaps: [{plane, line, closed, mirror, width, ray}] panel gaps (dark ribbons)
- solids: [{outline, axis, a0, a1, mat, radii, mirror}] extra prisms (blueprint frame: axis "x":
  outline (d, y) from x a0 to a1; "y": outline (x, d) from height a0 to a1; "z": outline (x, y)
  from d a0 to a1): splitters, skirts, diffusers, strakes, fins
- cutters: [{outline, axis, a0, a1, radii, mats, mirror}] prisms cut out (slots, louvres)
- mirrors: [{base: (x, d, y), size: (w, h, depth), reach}]
- wings: [{span, chord, d, y, pitch, elements, plates, uprights, mat}]
- exhausts: [{at: (x, y, d), r | (rx, ry), length, mirror, mat}]
- wipers: {"d": the arms' d at the cowl, "x": [the arms' pivots' x], "len": arm length}
"""
import math
import numpy as np
from mathutils import Vector
import roadcar as rc


def features(car, surf, spec):
    cut, add = [], []
    cut += arches(car, spec)
    for r in spec.get("recesses", []):
        cut += rc.recess(car, surf, "Recess", r["plane"], r["outline"], r.get("depth", 0.05), r.get("mats", ("grille", "trim")),
                         radii=r.get("radii"), ray=r.get("ray"), mirror=r.get("mirror", False))
        if r.get("bars"):
            add += bars(car, surf, r)
    for c in spec.get("cutters", []):
        o = rc.prism("Cutter", c["outline"], c["a0"], c["a1"], c["axis"], c.get("mats", "inlet"), radii=c.get("radii"), car=car)
        cut += rc.both(o, c.get("mirror", False))
    for d, y in spec.get("handles", []):
        # a door handle: a shallow pocket with the grip across it
        c2, a2 = inset(car, surf, {"plane": "side", "outline": [(d - 0.075, y - 0.018), (d + 0.075, y - 0.018), (d + 0.075, y + 0.018),
                                                                    (d - 0.075, y + 0.018)], "radii": [0.016] * 4, "depth": 0.014,
                                     "mats": ("trim", "trim"), "mirror": True,
                                     "elements": [("patch", [(d - 0.065, y + 0.002), (d + 0.065, y + 0.002), (d + 0.065, y + 0.016),
                                                             (d - 0.065, y + 0.016)], [0.006] * 4, spec.get("handle_mat", "chrome"), 0.013)]})
        cut += c2
        add += a2
    for ins in spec.get("insets", []):
        c2, a2 = inset(car, surf, ins)
        cut += c2
        add += a2
    for g in spec.get("glass", []):
        add += glass(car, surf, g)
    for p in spec.get("paint", []):
        if p.get("cabin") and car.g is not None:
            p = dict(p, outline=clip_to_cabin(car, p["outline"], 0.012, 0.012))
        add += rc.patch(car, surf, "Paint", p["plane"], p["outline"], p["mat"], lift=p.get("lift", 0.0025),
                        radii=p.get("radii"), ray=p.get("ray"), mirror=p.get("mirror", False))
    for s in spec.get("solids", []):
        o = rc.prism("Solid", s["outline"], s["a0"], s["a1"], s["axis"], s.get("mat", "trim"), radii=s.get("radii"), car=car)
        add += rc.both(o, s.get("mirror", False))
    add += arch_lips(car, surf, spec)
    if spec.get("splitter"):
        add += splitter(car, spec["splitter"])
    for m in spec.get("mirrors", []):
        for o in rc.mirror_part(car, m):
            add += rc.both(o)
    for w in spec.get("wings", []):
        add += rc.wing_part(car, w)
    for e in spec.get("exhausts", []):
        add += rc.exhaust_part(car, e)
    if spec.get("wipers"):
        add += wipers(car, surf, spec["wipers"])
    return cut, add


def plan_outline(car, d0, d1, y_max, n=40, rear=False):
    """The body's outline in plan (x, d) up to height y_max, from d0 to d1 (the +x side)."""
    out = []
    for k in range(n + 1):
        d = d0 + (d1 - d0) * k / n
        h = car.body_half(d)
        low = [x for x, y in h if y <= y_max]
        out.append((max(low) if low else 0.0, d))
    return out


def splitter(car, sp):
    """A blade under the nose (or the tail: rear) that follows the bumper's plan, standing out by
    `reach`, from the tip back to d1."""
    reach = sp.get("reach", 0.04)
    d1 = sp.get("d1", 0.5)
    y = sp.get("y", car.F)
    t = sp.get("t", 0.018)
    half = plan_outline(car, 0.002, d1, y + 0.12)
    pts = []
    for i, (x, d) in enumerate(half):
        # pushed out across and forwards
        pts.append((x + reach, d - reach * (1.0 - i / len(half))))
    outline = [(-x, d) for x, d in pts[::-1]] + [(x, d) for x, d in pts]
    outline = [(x, d) for x, d in outline]
    # back edge inside the body
    inner = sp.get("inner", 0.15)
    outline += [(pts[-1][0] - inner, d1), (-(pts[-1][0] - inner), d1)]
    o = rc.prism("Splitter", outline, y, y + t, "y", sp.get("mat", "carbon"), car=car)
    return [o]


def bars(car, surf, r):
    """Slats across a recess's opening (front/rear planes: horizontal at heights y; side: upright
    at distances d): a thin box swept a little behind the opening, along the surface."""
    import bmesh
    b = r["bars"]
    pts = rc.closed_outline(r["outline"], r.get("radii"))
    out = []
    t = b.get("t", 0.012)
    depth = r.get("depth", 0.05) * b.get("at", 0.3)
    vertical = b.get("vertical", False)
    for side in ((1.0, -1.0) if r.get("mirror", False) else (1.0,)):
        for c in b.get("y", []):
            # the opening's extent along the bar (crossings of the outline)
            xs = []
            n = len(pts)
            for i in range(n):
                a, q = pts[i], pts[(i + 1) % n]
                ia, ib = (0, 1) if vertical else (1, 0)
                if (a[ib] - c) * (q[ib] - c) <= 0 and a[ib] != q[ib]:
                    xs.append(a[ia] + (q[ia] - a[ia]) * (c - a[ib]) / (q[ib] - a[ib]))
            if len(xs) < 2:
                continue
            lo, hi = min(xs) + 0.004, max(xs) - 0.004
            line = [((lo + (hi - lo) * k / 16, c) if not vertical else (c, lo + (hi - lo) * k / 16)) for k in range(17)]
            hits, d, _ = rc.cast_points(car, surf, r["plane"], line, r.get("ray"), side)
            bm = bmesh.new()
            rings = []
            for k, h in enumerate(hits):
                p = h[0] + d * depth
                a = hits[max(k - 1, 0)][0]
                b_ = hits[min(k + 1, len(hits) - 1)][0]
                w = (b_ - a).cross(d).normalized()        # across the slat, in the opening's plane
                ring = [bm.verts.new(p + w * (t * 0.5 * su) + d * (0.012 * sd)) for su, sd in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                rings.append(ring)
            for ra, rb in zip(rings[:-1], rings[1:]):
                for k in range(4):
                    j = (k + 1) % 4
                    bm.faces.new((ra[k], ra[j], rb[j], rb[k]))
            bm.faces.new(rings[0][::-1])
            bm.faces.new(rings[-1])
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            out.append(rc.new_object("Bar", bm, [b.get("mat", "trim")]))
    return out


def late_features(car, surf, spec):
    """What is laid onto the body once it is cut: panel gaps (they stop at the arches and openings)."""
    add = []
    for g in spec.get("gaps", []):
        add += rc.ribbon(car, surf, "Gap", g["plane"], g["line"], g.get("width", 0.005), g.get("mat", "gap"),
                         lift=g.get("lift", 0.0012), closed=g.get("closed", False), mirror=g.get("mirror", True), ray=g.get("ray"))
    return add


def arches(car, spec):
    a = spec.get("arches", {})
    out = []
    for i, (x, y, z) in enumerate(car.wheels):
        d = car.z_nose - z
        r = a.get("r", [spec["tyre"]["r"][0] + 0.035, spec["tyre"]["r"][1] + 0.035])
        r = r[i] if isinstance(r, (list, tuple)) else r
        lift = a.get("lift", 0.012)
        x_in = a.get("x_in", x - spec["tyre"]["w"][i] * 0.5 - 0.05)
        shape = a.get("shapes", {}).get(i)
        if shape is None:
            pts = [(d + r * math.cos(2 * math.pi * k / 72), y + lift + r * math.sin(2 * math.pi * k / 72)) for k in range(72)]
            o = rc.prism("Arch", pts, x_in, 2.0, "x", "inlet", car=car)
        else:
            o = rc.prism("Arch", [(d + u, y + lift + v) for u, v in shape["outline"]], x_in, 2.0, "x", "inlet",
                         radii=shape.get("radii"), car=car)
        out += rc.both(o)
    return out


def arch_lips(car, surf, spec):
    """A rolled lip round each wheel arch where it meets the body side (a tube following the
    side's surface over the top of the arch), pushed out by `flare` for wide-arched cars."""
    a = spec.get("arches", {})
    lip = a.get("lip", 0.011)
    flare = a.get("flare", 0.0)
    if lip <= 0:
        return []
    out = []
    for i, (x, y, z) in enumerate(car.wheels):
        d = car.z_nose - z
        r = a.get("r", [spec["tyre"]["r"][0] + 0.035, spec["tyre"]["r"][1] + 0.035])
        r = r[i] if isinstance(r, (list, tuple)) else r
        cy = y + a.get("lift", 0.012)
        pts = []
        for k in range(49):
            t = math.radians(-8.0 + 196.0 * k / 48)
            dd, yy = d + (r + lip * 0.3) * math.cos(t), cy + (r + lip * 0.3) * math.sin(t)
            if yy < car.F + 0.06:
                continue
            pts.append((dd, yy))
        hits, ray, miss = rc.cast_points(car, surf, "side", pts, None, 1.0, min_dot=-1.0)
        path = [h[0] + h[1] * (flare - lip * 0.35) for h in hits if h[2]]
        if len(path) > 3:
            o = rc.tube("ArchLip", path, lip + flare * 0.6, "paint", seg=10)
            out += rc.both(o)
    return out


def offset_outline(pts, w):
    """A closed outline (dense) pushed out by w along its normals (counter-clockwise outlines grow;
    either way, by its winding)."""
    pts = np.asarray(pts, float)
    area = 0.5 * np.sum(pts[:, 0] * np.roll(pts[:, 1], -1) - np.roll(pts[:, 0], -1) * pts[:, 1])
    tan = np.roll(pts, -1, axis=0) - np.roll(pts, 1, axis=0)
    tan /= np.maximum(np.linalg.norm(tan, axis=1)[:, None], 1e-9)
    nrm = np.stack([tan[:, 1], -tan[:, 0]], axis=1) * (1.0 if area > 0 else -1.0)
    return pts + nrm * w


def clip_to_cabin(car, outline, top_gap, foot_gap):
    """A side outline (d, y) kept between the greenhouse's foot and its roof rail."""
    a, b = car.gd
    out = []
    for d, y in outline:
        dc = min(max(d, a + 0.01), b - 0.01)
        y = min(y, car.rail_y(dc) - top_gap)
        y = max(y, car.base_y(dc) + foot_gap)
        out.append((d, y))
    return out


def glass(car, surf, g):
    """A window: the glass, and a black seal round its edge (a band half under it). A side
    window's top stays under the roof rail (it would wrap over onto the roof)."""
    out = []
    if g["plane"] == "side" and car.g is not None and g.get("clip_rail", True):
        g = dict(g, outline=clip_to_cabin(car, g["outline"], g.get("rail_gap", 0.022), g.get("belt_gap", 0.02)))
    trim = g.get("trim", 0.012)
    if trim > 0:
        pts = rc.closed_outline(g["outline"], g.get("radii"))
        out += rc.ribbon(car, surf, "GlassTrim", g["plane"], [tuple(p) for p in offset_outline(pts, trim * 0.5)], trim * 1.6,
                         g.get("trim_mat", "trim"), lift=0.002, closed=True, mirror=g.get("mirror", False), ray=g.get("ray"))
    out += rc.patch(car, surf, "Glass", g["plane"], g["outline"], g.get("mat", "glass"), lift=0.0035, radii=g.get("radii"),
                    ray=g.get("ray"), mirror=g.get("mirror", False))
    return out


def inset(car, surf, ins):
    """A recess (cut) with things on its floor (added) and a cover over its opening."""
    plane = ins["plane"]
    depth = ins.get("depth", 0.04)
    mirror = ins.get("mirror", False)
    ray = ins.get("ray")
    cut = rc.recess(car, surf, "Inset", plane, ins["outline"], depth, ins.get("mats", ("lamp", "lamp")), radii=ins.get("radii"),
                    ray=ray, mirror=mirror)
    add = []
    if ins.get("cover"):
        add += rc.patch(car, surf, "Cover", plane, ins["outline"], ins["cover"], lift=0.0005, radii=ins.get("radii"), ray=ray,
                        mirror=mirror, rings=5)
    for el in ins.get("elements", []):
        add += element(car, surf, plane, ray, depth, el, mirror)
    return cut, add


def floor_point(car, surf, plane, ray, depth, u, v, h, side):
    """The point on an inset's floor under outline point (u, v), lifted h off it (Blender), and
    the ray (into the body). A ray that misses the body takes the nearest hit's place."""
    hits, d, _ = rc.cast_points(car, surf, plane, [(u, v)], ray, side, min_dot=-1.0)
    p = hits[0][0]
    if not hits[0][2]:
        # step inwards towards the outline's centre until the ray hits
        for k in range(1, 8):
            q = (u * (1.0 - 0.1 * k), v)
            hh, _, _ = rc.cast_points(car, surf, plane, [q], ray, side, min_dot=-1.0)
            if hh[0][2]:
                p = hh[0][0]
                break
    return p + d * (depth - h), d


def element(car, surf, plane, ray, depth, el, mirror):
    kind = el[0]
    out = []
    for side in ((1.0, -1.0) if mirror else (1.0,)):
        if kind in ("patch", "disc", "ring"):
            if kind == "patch":
                outline, radii, mat, lift = el[1], el[2], el[3], el[4] if len(el) > 4 else 0.003
                polys = [rc.closed_outline(outline, radii)]
            else:
                (cu, cv), r = el[1], el[2]
                circle = [(cu + r * math.cos(2 * math.pi * k / 40), cv + r * math.sin(2 * math.pi * k / 40)) for k in range(40)]
                if kind == "disc":
                    mat, lift = el[3], el[4] if len(el) > 4 else 0.003
                    polys = [np.array(circle)]
                else:
                    r_in, mat, lift = el[3], el[4], el[5] if len(el) > 5 else 0.003
                    polys = [np.array(circle), np.array([(cu + r_in * math.cos(2 * math.pi * k / 40),
                                                           cv + r_in * math.sin(2 * math.pi * k / 40)) for k in range(40)])]
            import bmesh
            bm = bmesh.new()
            if len(polys) == 1:
                pts = polys[0]
                c = pts.mean(axis=0)
                rings = []
                for k in (1.0, 0.66, 0.33):
                    rings.append([bm.verts.new(floor_point(car, surf, plane, ray, depth, *(c + (p - c) * k), lift, side)[0]) for p in pts])
                cv_ = bm.verts.new(floor_point(car, surf, plane, ray, depth, c[0], c[1], lift, side)[0])
                n = len(pts)
                for a, b in zip(rings[:-1], rings[1:]):
                    for i in range(n):
                        j = (i + 1) % n
                        bm.faces.new((a[i], a[j], b[j], b[i]))
                for i in range(n):
                    j = (i + 1) % n
                    bm.faces.new((rings[-1][i], rings[-1][j], cv_))
            else:
                o_ = [bm.verts.new(floor_point(car, surf, plane, ray, depth, u, v, lift, side)[0]) for u, v in polys[0]]
                i_ = [bm.verts.new(floor_point(car, surf, plane, ray, depth, u, v, lift, side)[0]) for u, v in polys[1]]
                n = len(o_)
                for i in range(n):
                    j = (i + 1) % n
                    bm.faces.new((o_[i], o_[j], i_[j], i_[i]))
            _, d = floor_point(car, surf, plane, ray, depth, 0.0, 0.0, 0.0, side)
            for f in bm.faces:
                f.normal_update()
                if f.normal.dot(d) > 0:
                    f.normal_flip()
            out.append(rc.new_object("Element", bm, [mat]))
        elif kind == "strip":
            line, width, mat = el[1], el[2], el[3]
            lift = el[4] if len(el) > 4 else 0.003
            pts = np.array(line, float)
            pts = rc.resample(pts, max(2, int(rc.polyline_len(pts) / 0.006)))
            tan = np.gradient(pts, axis=0)
            tan /= np.maximum(np.linalg.norm(tan, axis=1)[:, None], 1e-9)
            nrm = np.stack([-tan[:, 1], tan[:, 0]], axis=1)
            import bmesh
            bm = bmesh.new()
            rows = []
            for p, nm in zip(pts, nrm):
                rows.append([bm.verts.new(floor_point(car, surf, plane, ray, depth, *(p + nm * width * s), lift, side)[0])
                             for s in (-0.5, 0.5)])
            _, d = floor_point(car, surf, plane, ray, depth, pts[0][0], pts[0][1], 0.0, side)
            for a, b in zip(rows[:-1], rows[1:]):
                f = bm.faces.new((a[0], b[0], b[1], a[1]))
                f.normal_update()
                if f.normal.dot(d) > 0:
                    f.normal_flip()
            out.append(rc.new_object("Strip", bm, [mat]))
        elif kind == "projector":
            (cu, cv), r, lens = el[1], el[2], el[3]
            h = el[4] if len(el) > 4 else min(depth * 0.7, 0.03)
            p, d = floor_point(car, surf, plane, ray, depth, cu, cv, 0.0, side)
            out.append(rc.cylinder("Projector", p, -d, r * 1.3, h, ("chrome", "lamp"), seg=28, r2=r * 1.15))
            out.append(rc.cylinder("ProjectorLens", p - d * h, -d, r, 0.006, (lens, lens), seg=28, r2=r * 0.9))
    return out


def wipers(car, surf, w):
    """Two wiper arms lying along the windscreen's foot."""
    out = []
    d0 = w["d"]
    length = w.get("len", 0.5)
    for x0 in w["x"]:
        path = []
        for k in range(9):
            t = k / 8.0
            x = x0 + length * t * (1 if x0 < 0.2 else -1) * w.get("dir", 1)
            dd = d0 + 0.03 * t
            o = car.P(x, dd, 3.0)
            hit = surf.cast(o, rc.B(0, -1, 0))
            if hit:
                path.append(hit[0] + hit[1] * 0.014)
        if len(path) > 2:
            out.append(rc.tube("Wiper", path, 0.006, "trim", seg=8))
    return out
