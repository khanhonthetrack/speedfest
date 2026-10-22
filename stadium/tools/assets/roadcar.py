"""Our own road cars for the Stadium game (PLAN M16), built from numbers in Blender and exported
as glTF for car/tm_car_visual.gd, one .glb and one .json manifest per car. Each car is a spec
(tools/assets/roadcars/<id>.py: SPEC) read by the builder here; nothing of any maker's badges,
logos or names is in them.

Frame: the car's visual frame, as TmCarVisual (x to the car's left, y up, z forward, the ground at
y 0), in metres. Specs are written as blueprints: d is the distance back from the nose's tip
(d 0 at the front, d = length at the tail), x the half width (the +x side; everything is mirrored
unless said), y the height. The wheelbase is centred where the game's car has its own (z 0.29), so
z = z_nose - d with z_nose = 0.29 + wheelbase / 2 + front overhang.

How a car is made:
- the lower body: a closed loft through half-sections at many d, each a chain of corners from the
  top centre round to the floor's centre: top (the centre line: bumper, hood, deck, tail), edge
  (the hood's / deck's edge, or a fender's peak), shoulder (where the top turns down the side:
  the belt line), side (the widest point), rocker (the sill tucking under), floor. Every corner's
  x and y is a curve over d (monotone cubic through keys), with a radius; the top's segment is a
  crown (flat at the centre), the others can bow outwards. Nose and tail are rounded off by
  superellipse ends in plan and in height. Rows are spaced by how far the surface moves, so the
  nose's and the tail's faces get as many rows as the flanks;
- the greenhouse: a second loft from the cowl to the backlight's foot (roof crown, roof rail,
  side glass bowing out to its base on the belt), unioned with the body (exact boolean);
- cut out of it (exact booleans; the cutters' faces stay, in their own materials): the wheel
  arches, recesses that follow the surface for lamps, grilles, intakes, vents and plates, slots;
- laid onto it (cast along a direction, lifted a few mm): glass with its black trim, the lamps'
  clear covers, panel gaps, badges' places stay empty;
- added: mirrors, wings, splitters, skirts, diffusers, exhausts, handles, wipers, plates, the
  lamps' insides (reflector, projectors, LED strips and rings);
- wheels (one per axle, the +x side, centred on their own origin, axis x, outer face +x): tyre
  with sidewall bulge and shoulder, rim of the car's style (spokes, barrel, polished lip, lug
  nuts, centre cap), and the brake (ventilated disc, caliper) that doesn't spin.
Materials by name (TmCarVisual dresses each in the game's own): paint, trim, gloss_black, chrome,
glass, lens, lamp, led, amber, light, lens_red, grille, inlet, carbon, gap, mirror, plate, metal,
tyre, rim, rim_lip, disc, caliper.

usage: blender -b -P stadium/tools/assets/roadcar.py -- --car zenith [--out stadium/assets/car]
           [--shots DIR] (a sheet of Workbench views) [--blend FILE] [--all]
"""
import bpy
import bmesh
import importlib
import json
import math
import os
import sys
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(name, default=None):
    return argv[argv.index("--" + name) + 1] if ("--" + name) in argv else default


GAME_MID = 0.29          # the game's wheelbase centre (visual z)
NH = 60                  # points per half section (lower body)
NG = 40                  # points per half section (greenhouse)
ROW = 0.03               # rows every ~3 cm of surface


def B(x, y, z):
    """The car's frame (x left, y up, z forward) -> Blender's (z up; glTF export turns it back)."""
    return Vector((x, -z, y))


# --- materials ----------------------------------------------------------------------------------

MATS = {
    # name: (preview colour, metallic, roughness, emission, alpha)
    "paint": ((0.55, 0.56, 0.60), 0.3, 0.3, 0.0, 1.0),
    "trim": ((0.025, 0.025, 0.028), 0.0, 0.6, 0.0, 1.0),
    "gloss_black": ((0.012, 0.012, 0.014), 0.1, 0.1, 0.0, 1.0),
    "chrome": ((0.9, 0.9, 0.92), 1.0, 0.05, 0.0, 1.0),
    "glass": ((0.03, 0.035, 0.045), 0.2, 0.05, 0.0, 1.0),
    "lens": ((0.8, 0.85, 0.9), 0.0, 0.02, 0.0, 0.15),
    "lamp": ((0.75, 0.76, 0.78), 1.0, 0.15, 0.0, 1.0),
    "proj": ((0.02, 0.022, 0.03), 0.5, 0.02, 0.0, 1.0),
    "led": ((0.92, 0.95, 1.0), 0.0, 0.3, 4.0, 1.0),
    "amber": ((1.0, 0.55, 0.08), 0.0, 0.3, 0.6, 1.0),
    "light": ((0.9, 0.05, 0.03), 0.0, 0.3, 2.0, 1.0),
    "lens_red": ((0.55, 0.02, 0.02), 0.0, 0.05, 0.0, 0.55),
    "grille": ((0.02, 0.02, 0.022), 0.2, 0.5, 0.0, 1.0),
    "inlet": ((0.01, 0.01, 0.012), 0.0, 0.9, 0.0, 1.0),
    "carbon": ((0.03, 0.03, 0.035), 0.3, 0.4, 0.0, 1.0),
    "gap": ((0.005, 0.005, 0.006), 0.0, 0.9, 0.0, 1.0),
    "mirror": ((0.9, 0.92, 0.95), 1.0, 0.02, 0.0, 1.0),
    "plate": ((0.92, 0.92, 0.9), 0.0, 0.4, 0.0, 1.0),
    "metal": ((0.6, 0.6, 0.62), 1.0, 0.25, 0.0, 1.0),
    "tyre": ((0.035, 0.035, 0.04), 0.0, 0.9, 0.0, 1.0),
    "rim": ((0.75, 0.76, 0.78), 1.0, 0.25, 0.0, 1.0),
    "rim_lip": ((0.9, 0.9, 0.92), 1.0, 0.1, 0.0, 1.0),
    "disc": ((0.36, 0.35, 0.34), 0.9, 0.5, 0.0, 1.0),
    "caliper": ((0.8, 0.1, 0.06), 0.2, 0.35, 0.0, 1.0),
}


def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    col, metal, rough, emit, alpha = MATS[name]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*col, 1.0)
    m.metallic = metal
    m.roughness = rough
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    if emit > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*col, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def new_object(name, bm, mats):
    """An object from a bmesh whose faces' material_index index `mats` (names)."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for k in mats:
        me.materials.append(material(k))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# --- curves and 2D helpers ---------------------------------------------------------------------

def pchip(xs, ys, xq):
    """Monotone cubic (Fritsch-Carlson) through (xs, ys), xs increasing: no overshoot between
    keys; constant outside them."""
    xs = np.asarray(xs, float)
    ys = np.asarray(ys, float)
    xq = np.clip(np.atleast_1d(np.asarray(xq, float)), xs[0], xs[-1])
    if len(xs) == 1:
        return np.full_like(xq, ys[0])
    h = np.diff(xs)
    d = np.diff(ys) / h
    m = np.zeros_like(ys)
    for k in range(1, len(xs) - 1):
        if d[k - 1] * d[k] > 0:
            w1 = 2 * h[k] + h[k - 1]
            w2 = h[k] + 2 * h[k - 1]
            m[k] = (w1 + w2) / (w1 / d[k - 1] + w2 / d[k])
    m[0] = d[0]
    m[-1] = d[-1]
    if len(xs) > 2:
        # ends: a three-point estimate kept monotone
        for i0, i1, s in ((0, 1, 1), (len(xs) - 1, len(xs) - 2, -1)):
            pass
    k = np.clip(np.searchsorted(xs, xq) - 1, 0, len(xs) - 2)
    t = (xq - xs[k]) / h[k]
    h00 = 2 * t ** 3 - 3 * t ** 2 + 1
    h10 = t ** 3 - 2 * t ** 2 + t
    h01 = -2 * t ** 3 + 3 * t ** 2
    h11 = t ** 3 - t ** 2
    return h00 * ys[k] + h10 * h[k] * m[k] + h01 * ys[k + 1] + h11 * h[k] * m[k + 1]


class Curve:
    """A value along the car: a number, or keys [(d, v), ...] joined by a monotone cubic."""

    def __init__(self, c):
        if isinstance(c, (int, float)):
            self.ds, self.vs = [0.0], [float(c)]
        else:
            c = sorted(c)
            self.ds = [float(a) for a, _ in c]
            self.vs = [float(b) for _, b in c]

    def __call__(self, d):
        return float(pchip(self.ds, self.vs, d)[0])


def smooth_keys(pts, sigma, ends=0.0):
    """Measured keys [(d, v)] (a drawing's pixel steps) smoothed by a Gaussian of sigma metres,
    narrowing within ends of either end so a nose's or tail's quick turn stays."""
    pts = np.array(sorted(pts), float)
    if len(pts) < 3 or sigma <= 0:
        return [tuple(p) for p in pts]
    d, v = pts[:, 0], pts[:, 1]
    out = []
    for di in d:
        s = sigma
        if ends > 0:
            s *= min(max(min(di - d[0], d[-1] - di) / ends, 0.25), 1.0)
        w = np.exp(-0.5 * ((d - di) / s) ** 2)
        out.append((float(di), float(np.sum(w * v) / np.sum(w))))
    return out


def endcap(t, p):
    """A superellipse's quarter: 0 at t 0, rising with a vertical tangent, 1 from t 1 on."""
    t = min(max(t, 0.0), 1.0)
    return (1.0 - (1.0 - t) ** p) ** (1.0 / p)


def polyline_len(pts):
    return float(np.sum(np.linalg.norm(np.diff(pts, axis=0), axis=1)))


def resample(pts, n, weight=None):
    """n + 1 points along the polyline pts, evenly by (weighted) length."""
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    w = seg if weight is None else seg * weight
    cum = np.concatenate([[0.0], np.cumsum(w)])
    if cum[-1] <= 1e-12:
        return np.repeat(pts[:1], n + 1, axis=0)
    t = np.linspace(0.0, cum[-1], n + 1)
    x = np.interp(t, cum, pts[:, 0])
    y = np.interp(t, cum, pts[:, 1])
    return np.stack([x, y], axis=1)


def rounded(poly, radii, closed=True, step=0.004):
    """A polygon [(a, b)] with each corner rounded by its radius (circular arcs), densely sampled."""
    n = len(poly)
    out = []
    for i in range(n):
        p = np.array(poly[i], float)
        r = radii[i] if radii is not None else 0.0
        if not closed and (i == 0 or i == n - 1) or r <= 0.0:
            out.append(p)
            continue
        a = np.array(poly[i - 1], float) - p
        b = np.array(poly[(i + 1) % n], float) - p
        la, lb = np.linalg.norm(a), np.linalg.norm(b)
        if la < 1e-6 or lb < 1e-6:
            out.append(p)
            continue
        a /= la
        b /= lb
        theta = math.acos(np.clip(np.dot(a, b), -1.0, 1.0))
        if theta < 1e-3 or theta > math.pi - 1e-3:
            out.append(p)
            continue
        d = r / math.tan(theta * 0.5)
        dmax = 0.48 * min(la, lb)
        if d > dmax:
            d = dmax
            r = d * math.tan(theta * 0.5)
        t1 = p + a * d
        t2 = p + b * d
        bis = a + b
        bis /= np.linalg.norm(bis)
        c = p + bis * (r / math.sin(theta * 0.5))
        a1 = math.atan2(t1[1] - c[1], t1[0] - c[0])
        a2 = math.atan2(t2[1] - c[1], t2[0] - c[0])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        k = max(2, int(abs(da) * r / step) + 1)
        for j in range(k + 1):
            t = a1 + da * j / k
            out.append(c + r * np.array([math.cos(t), math.sin(t)]))
    return np.array(out)


def closed_outline(outline, radii=None, n=None):
    """A closed outline's points (rounded corners), evenly resampled (no repeated end)."""
    pts = rounded(outline, radii) if radii else np.array(outline, float)
    if n is None:
        n = max(24, int(polyline_len(np.vstack([pts, pts[:1]])) / 0.012))
    return resample(np.vstack([pts, pts[:1]]), n)[:-1]


def chain(corners, kinds, radii, step=0.003):
    """An open chain through corners [(x, y)]: segment i (corner i -> i + 1) is ("crown", q): flat
    at corner i (the mirror axis), ("bow", b): straight bowed out by b at its middle, or
    ("line",); inner corners rounded by a quadratic Bezier trimmed `radius` along each side.
    Returns dense points."""
    segs = []
    for i in range(len(corners) - 1):
        a = np.array(corners[i], float)
        b = np.array(corners[i + 1], float)
        L = max(np.linalg.norm(b - a), 1e-6)
        k = max(2, int(L / step) + 1)
        t = np.linspace(0.0, 1.0, k + 1)
        kind = kinds[i]
        if kind[0] == "crown":
            q = kind[1]
            xs = a[0] + (b[0] - a[0]) * t
            ys = b[1] + (a[1] - b[1]) * (1.0 - t ** q)
            pts = np.stack([xs, ys], axis=1)
        else:
            pts = a[None, :] + (b - a)[None, :] * t[:, None]
            bow = kind[1] if len(kind) > 1 else 0.0
            if bow != 0.0:
                dvec = (b - a) / L
                nrm = np.array([-dvec[1], dvec[0]])    # outward for a clockwise chain
                pts = pts + nrm[None, :] * (bow * 4.0 * t * (1.0 - t))[:, None]
        segs.append(pts)
    # round the inner corners
    for i in range(1, len(corners) - 1):
        r = radii[i]
        if r <= 0.0:
            continue
        s0, s1 = segs[i - 1], segs[i]
        l0 = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(s0[::-1], axis=0), axis=1))])
        l1 = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(s1, axis=0), axis=1))])
        tr = min(r, 0.45 * l0[-1], 0.45 * l1[-1])
        if tr < 1e-4:
            continue
        j0 = int(np.searchsorted(l0, tr))
        j1 = int(np.searchsorted(l1, tr))
        A = s0[::-1][j0]
        C = s1[j1]
        P = s0[-1]
        k = max(4, int(2.0 * tr / step))
        t = np.linspace(0.0, 1.0, k + 1)[:, None]
        bez = (1 - t) ** 2 * A + 2 * (1 - t) * t * P + t ** 2 * C
        segs[i - 1] = s0[: len(s0) - j0]
        segs[i] = np.vstack([bez[1:-1], s1[j1:]])
    out = [segs[0]]
    for s in segs[1:]:
        out.append(s if np.linalg.norm(s[0] - out[-1][-1]) > 1e-7 else s[1:])
    return np.vstack(out)


def by_curvature(half, n, dense_floor=True, floor_y=None):
    """n + 1 points along a half section, denser where it turns, sparser along the floor."""
    seg = np.diff(half, axis=0)
    ln = np.linalg.norm(seg, axis=1)
    keep = ln > 1e-7
    if not keep.all():
        half = np.vstack([half[:1], half[1:][keep]])
        seg = np.diff(half, axis=0)
        ln = np.linalg.norm(seg, axis=1)
    if len(half) < 3:
        return resample(half, n)
    ang = np.arctan2(seg[:, 1], seg[:, 0])
    turn = np.abs((np.diff(ang) + math.pi) % (2 * math.pi) - math.pi)
    curv = (np.concatenate([[0.0], turn / np.maximum(ln[1:], 1e-4)]) * 0.5
            + np.concatenate([turn / np.maximum(ln[:-1], 1e-4), [0.0]]) * 0.5)
    w = 1.0 + 0.05 * np.minimum(curv, 60.0)
    if floor_y is not None:
        flat = (half[:-1, 1] < floor_y + 0.004) & (half[1:, 1] < floor_y + 0.004)
        w = w * np.where(flat, 0.25, 1.0)
    return resample(half, n, w)


# --- lofts ----------------------------------------------------------------------------------------

def rows_by_surface(section, d0, d1, step=ROW, fine=0.002, max_gap=0.08):
    """Distances d from d0 to d1 where rows of section(d) (an (N, 2) array) are about `step`
    apart on the surface: dense where the section changes fast (the nose, the tail)."""
    n = max(2, int((d1 - d0) / fine))
    ds = np.linspace(d0, d1, n + 1)
    secs = [section(d) for d in ds]
    out = [d0]
    acc = 0.0
    last = d0
    for k in range(1, len(ds)):
        mv = np.max(np.sqrt(np.sum((secs[k] - secs[k - 1]) ** 2, axis=1) + (ds[k] - ds[k - 1]) ** 2))
        acc += mv
        if acc >= step or ds[k] - last >= max_gap:
            out.append(ds[k])
            acc = 0.0
            last = ds[k]
    if out[-1] < d1 - 1e-6:
        if d1 - out[-1] < 0.3 * step and len(out) > 1:
            out[-1] = d1
        else:
            out.append(d1)
    return out, {d: s for d, s in zip(ds, secs)}


def loft(name, section, ds, zof, mat, caps=True):
    """A closed loft: rows of the half section(d) mirrored into rings, at z = zof(d); the ends
    capped with fans."""
    bm = bmesh.new()
    rings = []
    for d in ds:
        h = section(d)
        ring = [(x, y) for x, y in h] + [(-x, y) for x, y in h[-2:0:-1]]
        z = zof(d)
        rings.append([bm.verts.new(B(x, y, z)) for x, y in ring])
    m = len(rings[0])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps:
        for ring, flip in ((rings[0], True), (rings[-1], False)):
            c = sum((v.co for v in ring), Vector()) / len(ring)
            cv = bm.verts.new(c)
            for i in range(m):
                j = (i + 1) % m
                f = (ring[i], ring[j], cv) if not flip else (ring[j], ring[i], cv)
                bm.faces.new(f)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, [mat])


# --- the car ------------------------------------------------------------------------------------

class Car:
    def __init__(self, spec):
        self.s = spec
        self.L = spec["length"]
        self.wb = spec["wheelbase"]
        self.foh = spec["front_overhang"]
        self.z_nose = GAME_MID + self.wb * 0.5 + self.foh
        self.d_front = self.foh                 # the axles' d
        self.d_rear = self.foh + self.wb
        self.F = spec["body"].get("floor", 0.13)
        b = spec["body"]
        prof = self._profile(spec)
        self.c = {k: Curve(self._measured(v, prof, spec, k)) for k, v in b["curves"].items()}
        self.r = {k: Curve(v) for k, v in b.get("radii", {}).items()}
        self.bows = {k: Curve(v) for k, v in b.get("bows", {}).items()}
        self.front = b.get("front", {})
        self.rear = b.get("rear", {})
        g = spec.get("cabin")
        self.g = {k: Curve(self._measured(v, prof, spec, "cabin." + k)) for k, v in g["curves"].items()} if g else None
        # the plan from the measured silhouette (when the spec asks): every x along the car scaled so
        # the widest corner follows the drawing's half width
        self.plan = None
        if prof and spec.get("profile", {}).get("plan") and "plan_hw" in prof:
            pts = smooth_keys([(a * self.L / prof["length"], b) for a, b in prof["plan_hw"]], 0.08, ends=0.5)
            self.plan = Curve(pts[::2] + ([pts[-1]] if len(pts) % 2 == 0 else []))
        self.gr = {k: Curve(v) for k, v in g.get("radii", {}).items()} if g else {}
        self.gd = (g["d0"], g["d1"]) if g else None
        self.wheels = []
        for i, (dz, tr) in enumerate(((self.d_front, spec["track"][0]), (self.d_rear, spec["track"][1]))):
            r = spec["tyre"]["r"][i]
            self.wheels.append((tr * 0.5, r - 0.01, self.z(dz)))

    def z(self, d):
        return self.z_nose - d

    @staticmethod
    def _profile(spec):
        """The car's measured silhouettes (roadcars/profiles/<id>.json, blueprint_fit.py curves),
        if the spec uses them. A spec's "fit" {cowl, deck, front, rear, wing: [d0, d1], plan} is
        turned into its "profile": the hood's line (and its edge's) from the side's top line ahead
        of the windscreen's foot (cowl), the glasshouse's top between the cowl and the backlight's
        foot (deck), the deck's line behind it (but over a wing), the plan. top_add, edge_add and
        hood_add (the hood's edge, for specs with one) offset those lines from the silhouette: a
        number, or (ahead of the cowl, behind the deck) where raised fenders make the silhouette's
        top line the fenders' rather than the hood's."""
        f = spec.get("fit")
        if f:
            cowl, deck = f["cowl"], f["deck"]
            a, b = f.get("front", 0.15), f.get("rear", spec["length"] - 0.06)
            w0, w1 = f.get("wing", (b, b))
            ranges = [[a, cowl - 0.03], [deck + 0.04, min(w0, b)], [max(w1, deck + 0.04), b]]

            def adds(v):
                return [v[0], v[1], v[1]] if isinstance(v, (list, tuple)) else v

            prof = {"plan": f.get("plan", True),
                    "top": {"from": "side_top", "ranges": ranges, "add": adds(f.get("top_add", -0.004))},
                    "edge_y": {"from": "side_top", "ranges": ranges, "add": adds(f.get("edge_add", -0.016))},
                    "cabin.top": {"from": "side_top", "ranges": [[cowl + 0.03, deck - 0.03]], "add": 0.0, "smooth": 0.10, "every": 0.1}}
            if "hood_add" in f:
                prof["hood_y"] = {"from": "side_top", "ranges": ranges, "add": adds(f["hood_add"])}
            prof.update(spec.get("profile", {}))
            spec["profile"] = prof
        if not spec.get("profile"):
            return None
        path = os.path.join(HERE, "roadcars", "profiles", spec["id"] + ".json")
        if not os.path.exists(path):
            return None
        with open(path) as f:
            return json.load(f)

    def _measured(self, keys, prof, spec, name):
        """A curve's keys with a measured stretch in place of the spec's own (spec["profile"][name]:
        {"from": silhouette, "range": [d0, d1], "add": dy, "every": step}); its keys outside the
        stretch stay."""
        use = spec.get("profile", {}).get(name) if prof else None
        if not use or use["from"] not in prof:
            return keys
        ranges = use.get("ranges", [use.get("range")])
        add = use.get("add", 0.0)
        add = list(add) if isinstance(add, (list, tuple)) else [add] * len(ranges)
        keep = [i for i, r in enumerate(ranges) if r and r[1] - r[0] > 0.02]
        ranges, add = [ranges[i] for i in keep], [add[i] for i in keep]
        k = self.L / prof["length"]
        step = max(1, int(round(use.get("every", 0.05) / 0.025)))
        out = [] if isinstance(keys, (int, float)) else [(d, v) for d, v in keys
                                                          if not any(a - 1e-6 <= d <= b + 1e-6 for a, b in ranges)]
        if isinstance(keys, (int, float)) and not out:
            pass
        for (a, b), dy in zip(ranges, add):
            pts = [(d * k, y + dy) for d, y in prof[use["from"]] if a <= d * k <= b]
            pts = smooth_keys(pts, use.get("smooth", 0.04))
            thin = [p for i, p in enumerate(pts) if i % step == 0]
            if thin and thin[-1] != pts[-1]:
                thin.append(pts[-1])
            out += thin
        return sorted(out)

    def P(self, x, d, y):
        """A blueprint point (half width x, distance back d, height y) in Blender."""
        return B(x, y, self.z(d))

    # the lower body's half section ------------------------------------------------------------

    def _ends(self, d):
        f, r = self.front, self.rear
        fp = endcap(d / f.get("plan", (0.4, 2.0))[0], f.get("plan", (0.4, 2.0))[1])
        if self.plan is not None:
            # the measured plan in place of the superellipse ends
            c = self.c
            wide = max(c["side_x"](d), c["sh_x"](d), 1e-3)
            fp = min(self.plan(d) / wide, 1.25)
        ft = endcap(d / f.get("top", (0.12, 2.0))[0], f.get("top", (0.12, 2.0))[1])
        fb = endcap(d / f.get("bottom", (0.12, 2.0))[0], f.get("bottom", (0.12, 2.0))[1])
        e = self.L - d
        rp = endcap(e / r.get("plan", (0.4, 2.0))[0], r.get("plan", (0.4, 2.0))[1]) if self.plan is None else 1.0
        rt = endcap(e / r.get("top", (0.12, 2.0))[0], r.get("top", (0.12, 2.0))[1])
        rb = endcap(e / r.get("bottom", (0.12, 2.0))[0], r.get("bottom", (0.12, 2.0))[1])
        yc = f.get("yc", 0.45) if d < self.L * 0.5 else r.get("yc", 0.6)
        return fp * rp, ft * rt, fb * rb, yc

    def corners(self, d, named=False):
        """The lower body's corners at d: [(x, y)] top, (hood: the hood's edge, when the spec has
        it, before a fender rises), edge, shoulder, side, rocker, floor, floor centre (ends
        applied); named: also their names."""
        c = self.c
        ep, et, eb, yc = self._ends(d)
        top = c["top"](d)
        fy = c["floor_y"](d) if "floor_y" in c else self.F
        names = ["top", "edge", "sh", "side", "rk", "fl", "centre"]
        pts = [(0.0, top), (c["edge_x"](d), c["edge_y"](d)), (c["sh_x"](d), c["sh_y"](d)),
               (c["side_x"](d), c["side_y"](d)), (c["rk_x"](d), c["rk_y"](d)), (c["fl_x"](d), fy), (0.0, fy)]
        if "hood_x" in c:
            names.insert(1, "hood")
            pts.insert(1, (c["hood_x"](d), c["hood_y"](d)))
        out = []
        for nm, (x, y) in zip(names, pts):
            e = et if nm in ("top", "hood", "edge", "sh") or (nm == "side" and y > yc) else eb
            out.append((x * ep, yc + (y - yc) * e))
        return (out, names) if named else out

    def corner(self, d, name):
        pts, names = self.corners(d, True)
        return pts[names.index(name)]

    def body_half(self, d):
        k, names = self.corners(d, True)
        r = self.r
        default = {"top": 0.0, "hood": 0.03, "edge": 0.03, "sh": 0.04, "side": 0.15, "rk": 0.04, "fl": 0.01, "centre": 0.0}
        rad = [r[nm](d) if nm in r else default[nm] for nm in names]
        ep, et, eb, _ = self._ends(d)
        s = min(ep, 1.0, 0.5 + 0.5 * min(et, eb))
        rad = [a * s for a in rad]
        bw = self.bows

        def bow(key):
            return ("bow", (bw[key](d) if key in bw else 0.0) * ep)

        q = bw["crown_q"](d) if "crown_q" in bw else 2.0
        kinds = [("crown", q)]
        if "hood" in names:
            kinds.append(bow("hood_edge"))
        kinds += [bow("edge_sh"), bow("sh_side"), bow("side_rk"), ("bow", 0.0), ("line",)]
        dense = chain(k, kinds, rad)
        return by_curvature(dense, NH, floor_y=k[-1][1])

    # the greenhouse -----------------------------------------------------------------------------

    def base_y(self, d):
        """The greenhouse's foot (where the side glass meets the body) at d."""
        g = self.g
        bx = g["base_x"](d)
        return g["base_y"](d) if "base_y" in g else self.top_at(d, bx) - 0.012

    def rail_y(self, d):
        """The roof rail's height (the side glass's top) at d."""
        g = self.g
        top = g["top"](d)
        bx = g["base_x"](d)
        by = g["base_y"](d) if "base_y" in g else self.top_at(d, bx) - 0.012
        crown = min(g["crown"](d) if "crown" in g else 0.04, max(top - by, 0.004) * 0.45)
        return top - crown

    def top_at(self, d, x):
        """The lower body's top surface height at half width x (from the centre outwards)."""
        h = self.body_half(d)
        for i in range(len(h) - 1):
            x0, x1 = h[i][0], h[i + 1][0]
            if x0 <= x <= x1 and x1 > x0:
                t = (x - x0) / (x1 - x0)
                return float(h[i][1] + (h[i + 1][1] - h[i][1]) * t)
            if x1 < x0:
                break
        return float(h[i][1])

    def cabin_half(self, d):
        g = self.g
        top = g["top"](d)
        bx = g["base_x"](d)
        # the glass's foot just under the body's top where it stands (unless the spec says)
        by = g["base_y"](d) if "base_y" in g else self.top_at(d, bx) - 0.012
        rx = g["rail_x"](d)
        crown = g["crown"](d) if "crown" in g else 0.04
        h = max(top - by, 0.004)
        crown = min(crown, h * 0.45)
        ry = top - crown
        rx = min(rx, bx - 0.01)
        corners = [(0.0, top), (rx, ry), (bx, by), (bx * 0.6, by - 0.18), (0.0, by - 0.18)]
        rr = self.gr
        r_rail = (rr["rail"](d) if "rail" in rr else 0.05) * min(1.0, h / 0.2)
        rad = [0.0, r_rail, 0.005, 0.02, 0.0]
        bow = (g["glass_bow"](d) if "glass_bow" in g else 0.012) * min(1.0, h / 0.2)
        q = g["crown_q"](d) if "crown_q" in g else 2.0
        kinds = [("crown", q), ("bow", bow), ("line",), ("line",)]
        dense = chain(corners, kinds, rad)
        return by_curvature(dense, NG)

    # build ----------------------------------------------------------------------------------------

    def build_body(self):
        d0, d1 = self.s["body"].get("d_min", 0.004), self.L - self.s["body"].get("d_min_rear", 0.004)
        ds, _ = rows_by_surface(self.body_half, d0, d1)
        print("ROADCAR body rows: %d" % len(ds))
        body = loft("Body", self.body_half, ds, self.z, "paint")
        if self.g is not None:
            a, b = self.gd
            gs, _ = rows_by_surface(self.cabin_half, a, b, step=0.035)
            cab = loft("Cabin", self.cabin_half, gs, self.z, "paint")
            boolean(body, [cab], "UNION")
        return body


def boolean(ob, others, op):
    coll = bpy.data.collections.new("Ops")
    bpy.context.scene.collection.children.link(coll)
    for c in others:
        for col in c.users_collection:
            col.objects.unlink(c)
        coll.objects.link(c)
    mod = ob.modifiers.new("Op", "BOOLEAN")
    mod.operation = op
    mod.solver = "EXACT"
    mod.operand_type = "COLLECTION"
    mod.collection = coll
    if hasattr(mod, "material_mode"):
        mod.material_mode = "TRANSFER"
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for c in list(coll.objects):
        bpy.data.objects.remove(c, do_unlink=True)
    bpy.data.collections.remove(coll)


# --- solids from outlines -------------------------------------------------------------------------

def prism(name, outline, a0, a1, axis, mats, radii=None, car=None, n=None):
    """An outline (2D, closed) extruded along an axis from a0 to a1 (blueprint frame when car is
    given: axis "x": outline (d, y) across x; "y": (x, d) up; "z": (x, y) along d). mats: one
    name, or (sides, caps)."""
    pts = closed_outline(outline, radii, n) if (radii or n) else np.array(outline, float)
    if isinstance(mats, str):
        mats = (mats, mats)
    bm = bmesh.new()

    def P(u, v, a):
        if car is None:
            return {"x": B(a, v, u), "y": B(u, a, v), "z": B(u, v, a)}[axis]
        return {"x": car.P(a, u, v), "y": car.P(u, v, a), "z": car.P(u, a, v)}[axis]

    lo = [bm.verts.new(P(u, v, a0)) for u, v in pts]
    hi = [bm.verts.new(P(u, v, a1)) for u, v in pts]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    f = bm.faces.new(lo[::-1])
    f.material_index = 1
    f = bm.faces.new(hi)
    f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, list(mats))


def mirror_copy(ob):
    """The same solid on the other side (x -> -x)."""
    me = ob.data.copy()
    for v in me.vertices:
        v.co.x = -v.co.x
    me.flip_normals()
    o2 = bpy.data.objects.new(ob.name + "_m", me)
    bpy.context.scene.collection.objects.link(o2)
    return o2


def both(o, mirror=True):
    return [o, mirror_copy(o)] if mirror else [o]


def revolve(name, profile, mats, seg=64, axis_x=True):
    """A solid of revolution about the x axis (Blender x = the car's x): profile [(x, r, mat)] an
    open chain, closed at the axis if it starts/ends at r 0."""
    bm = bmesh.new()
    rings = []
    for x, r, _ in profile:
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            ring.append(bm.verts.new(Vector((x, r * math.cos(a), r * math.sin(a)))))
        rings.append(ring)
    names = []
    for _, _, m in profile:
        if m not in names:
            names.append(m)
    for i in range(len(rings) - 1):
        mi = names.index(profile[i][2])
        for k in range(seg):
            j = (k + 1) % seg
            f = bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
            f.material_index = mi
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, names)


# --- patches laid onto the body -------------------------------------------------------------------

class Surface:
    """Ray casts against a mesh (the car's frame)."""

    def __init__(self, ob):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        self.bvh = BVHTree.FromBMesh(bm)
        bm.free()

    def cast(self, o, d):
        hit = self.bvh.ray_cast(o, d)
        return hit if hit[0] is not None else None


def proj_start(car, plane, u, v, ray):
    """Where a ray for outline point (u, v) starts: planes "front" (x, y; cast towards -d... i.e.
    from in front of the nose backwards), "rear" (x, y; from behind), "side" (d, y; from +x),
    "top" (x, d; from above)."""
    if plane == "front":
        return car.P(u, -3.0, v)
    if plane == "rear":
        return car.P(u, car.L + 3.0, v)
    if plane == "side":
        return car.P(3.0, u, v)
    if plane == "top":
        return car.P(u, v, 4.0)
    raise ValueError(plane)


def start_for(car, plane, u, v, d, ray):
    """The ray's start for outline point (u, v): on the plane's far side; an oblique ray starts
    where it passes through the outline's point on a reference surface (x 0 for front/rear, the
    car's mid plane d for side, y 0.8 for top), stepped back 3 m along itself."""
    if ray is None:
        return proj_start(car, plane, u, v, ray)
    if plane in ("front", "rear"):
        ref = car.P(u, 0.0 if plane == "front" else car.L, v)
    elif plane == "side":
        ref = car.P(0.0, u, v)
    else:
        ref = car.P(u, v, 0.8)
    return ref - d * 3.0


RAYS = {"front": (0, 0, -1), "rear": (0, 0, 1), "side": (-1, 0, 0), "top": (0, -1, 0)}


def ray_dir(plane, ray=None):
    return B(*(ray or RAYS[plane])).normalized()


def tri_points(outline, radii, spacing=0.022):
    """An outline filled with triangles: its boundary every ~spacing / 2 and a grid of points
    inside (constrained Delaunay): (points (N, 2), triangles [(i, j, k)], boundary indices)."""
    from mathutils.geometry import delaunay_2d_cdt
    from mathutils import Vector as V2
    pts = rounded(outline, radii) if radii else np.array(outline, float)
    per = polyline_len(np.vstack([pts, pts[:1]]))
    bnd = resample(np.vstack([pts, pts[:1]]), max(16, int(per / (spacing * 0.6))))[:-1]
    lo = bnd.min(axis=0)
    hi = bnd.max(axis=0)
    inner = []
    xs = np.arange(lo[0] + spacing * 0.5, hi[0], spacing)
    ys = np.arange(lo[1] + spacing * 0.5, hi[1], spacing * 0.866)
    cand = np.array([(x + (spacing * 0.5 if j % 2 else 0.0), y) for j, y in enumerate(ys) for x in xs]) if len(xs) and len(ys) else np.zeros((0, 2))
    if len(cand):
        inside = inside_poly(cand, bnd)
        # keep clear of the boundary
        far = np.array([np.min(np.linalg.norm(bnd - c, axis=1)) > spacing * 0.45 for c in cand]) if len(cand) else []
        inner = cand[inside & far]
    allp = np.vstack([bnd, inner]) if len(inner) else bnd
    nb = len(bnd)
    edges = [(i, (i + 1) % nb) for i in range(nb)]
    res = delaunay_2d_cdt([V2((float(x), float(y))) for x, y in allp], edges, [list(range(nb))], 1, 1e-7)
    verts = np.array([(v.x, v.y) for v in res[0]])
    tris = [tuple(f) for f in res[2]]
    return verts, tris, nb


def inside_poly(pts, poly):
    """Even-odd test of points against a closed polygon."""
    x, y = pts[:, 0], pts[:, 1]
    inside = np.zeros(len(pts), bool)
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        cond = (y1 > y) != (y2 > y)
        xi = (x2 - x1) * (y - y1) / ((y2 - y1) if y2 != y1 else 1e-12) + x1
        inside ^= cond & (x < xi)
    return inside


def cast_points(car, surf, plane, pts, ray=None, side=1.0, min_dot=0.2):
    """Outline-plane points cast onto the surface: [(hit point, normal, hit?)] (a miss: the ray's
    start) and the ray."""
    d0 = ray_dir(plane, ray)
    d = Vector((-d0.x, d0.y, d0.z)) if side < 0 else d0
    out = []
    miss = 0
    for u, v in pts:
        o = start_for(car, plane, u, v, d0, ray)
        if side < 0:
            o = Vector((-o.x, o.y, o.z))
        hit = surf.cast(o, d)
        # a grazing hit (the ray skimming a surface that doesn't face it: a roof seen from the
        # side) counts as a miss, so a patch doesn't wrap round onto it
        if hit is None or -hit[1].dot(d) < min_dot:
            miss += 1
            out.append((o, -d, False))
        else:
            out.append((hit[0], hit[1], True))
    if miss:
        # a missed point takes its nearest hit's place (a sheet, a cutter stays whole)
        P = np.asarray(pts, float)
        good = np.array([h[2] for h in out])
        if good.any():
            gi = np.nonzero(good)[0]
            for i in np.nonzero(~good)[0]:
                j = gi[np.argmin(np.sum((P[gi] - P[i]) ** 2, axis=1))]
                out[i] = (out[j][0], out[j][1], False)
    return out, d, miss


def tri_mesh(bm, hits, tris, f_point, mat_index=0, flip_to=None, skip_missed=False):
    vs = [bm.verts.new(f_point(h[0], h[1])) for h in hits]
    faces = []
    for t in tris:
        if skip_missed and not all(hits[i][2] for i in t):
            continue
        try:
            f = bm.faces.new([vs[i] for i in t])
        except ValueError:
            continue
        f.material_index = mat_index
        if flip_to is not None:
            f.normal_update()
            if f.normal.dot(flip_to) > 0:
                f.normal_flip()
        faces.append(f)
    return vs, faces


def patch(car, surf, name, plane, outline, mat, lift=0.003, radii=None, rings=5, ray=None, mirror=False, spacing=0.022):
    """A flat outline laid onto the body (cast along the plane's ray), lifted off it: an evenly
    triangulated sheet, so it follows the surface closely."""
    obs = []
    pts, tris, nb = tri_points(outline, radii, spacing)
    for side in ((1.0, -1.0) if mirror else (1.0,)):
        hits, d, miss = cast_points(car, surf, plane, pts, ray, side)
        if miss:
            print("PATCH %s: %d points missed the body" % (name, miss))
        bm = bmesh.new()
        tri_mesh(bm, hits, tris, lambda p, n: p + n * lift, 0, flip_to=d, skip_missed=True)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        obs.append(new_object(name, bm, [mat]))
    return obs


def recess(car, surf, name, plane, outline, depth, mats, radii=None, ray=None, mirror=False, rings=4, spacing=0.03):
    """A cutter for a recess that follows the surface: the outline cast onto the body, pushed in
    along the ray by `depth` (its floor, mats[0]) with walls (mats[1]); the cutter's top stands
    2 cm out of the body."""
    obs = []
    pts, tris, nb = tri_points(outline, radii, spacing)
    for side in ((1.0, -1.0) if mirror else (1.0,)):
        hits, d, miss = cast_points(car, surf, plane, pts, ray, side)
        bm = bmesh.new()
        top, _ = tri_mesh(bm, hits, tris, lambda p, n: p - d * 0.02, 1)
        bot, faces = tri_mesh(bm, hits, tris, lambda p, n: p + d * depth, 0)
        for f in faces:
            f.normal_flip()
        for i in range(nb):
            j = (i + 1) % nb
            f = bm.faces.new((top[i], top[j], bot[j], bot[i]))
            f.material_index = 1
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obs.append(new_object(name, bm, [mats[0], mats[1]]))
    return obs


def ribbon(car, surf, name, plane, line, width, mat, lift=0.0015, closed=False, mirror=False, ray=None, step=0.01):
    """A strip `width` wide along a polyline (outline coords) laid onto the body: panel gaps,
    pinstripes, glass seals. Where the surface turns away from the ray the strip stops."""
    pts = np.array(line, float)
    if closed:
        pts = np.vstack([pts, pts[:1]])
    pts = resample(pts, max(2, int(polyline_len(pts) / step)))
    tan = np.gradient(pts, axis=0)
    tan /= np.maximum(np.linalg.norm(tan, axis=1)[:, None], 1e-9)
    nrm = np.stack([-tan[:, 1], tan[:, 0]], axis=1)
    obs = []
    two = [tuple(p + nm * width * s_) for p, nm in zip(pts, nrm) for s_ in (-0.5, 0.5)]
    for side in ((1.0, -1.0) if mirror else (1.0,)):
        hits, dd, _ = cast_points(car, surf, plane, two, ray, side)
        bm = bmesh.new()
        vs = [bm.verts.new(h[0] + h[1] * lift) for h in hits]
        for k in range(len(pts) - 1):
            a0, a1, b0, b1 = 2 * k, 2 * k + 1, 2 * k + 2, 2 * k + 3
            if not (hits[a0][2] and hits[a1][2] and hits[b0][2] and hits[b1][2]):
                continue
            f = bm.faces.new((vs[a0], vs[b0], vs[b1], vs[a1]))
            f.normal_update()
            if f.normal.dot(dd) > 0:
                f.normal_flip()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        obs.append(new_object(name, bm, [mat]))
    return obs


# --- parts ----------------------------------------------------------------------------------------

def airfoil(chord, thick, camber, le, pitch, n=14):
    """A cambered section (d, y): leading edge at le (front), trailing edge towards +d."""
    up, lo = [], []
    for k in range(n + 1):
        x = (1.0 - math.cos(math.pi * k / n)) * 0.5
        yt = 5.0 * thick * (0.2969 * math.sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x ** 3 - 0.1036 * x ** 4)
        yc = camber * 4.0 * x * (1.0 - x)
        up.append((x, yc + yt))
        lo.append((x, yc - yt))
    pts = up + lo[-2:0:-1]
    out = []
    c, s = math.cos(pitch), math.sin(pitch)
    for x, y in pts:
        u, v = x * chord, y * chord
        out.append((le[0] + u * c + v * s, le[1] - u * s + v * c))
    return out


def tube(name, path, r, mat, seg=12, caps=True):
    """A round tube along a 3D polyline (Blender points)."""
    bm = bmesh.new()
    rings = []
    pts = [Vector(p) for p in path]
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized()
        b = t.cross(a)
        rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg)) * r)
                      for k in range(seg)])
    for ra, rb in zip(rings[:-1], rings[1:]):
        for k in range(seg):
            j = (k + 1) % seg
            bm.faces.new((ra[k], ra[j], rb[j], rb[k]))
    if caps:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, [mat])


def ellipsoid(name, c, r, mat, seg=20, rings=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((c.x + v.co.x * r[0], c.y + v.co.y * r[1], c.z + v.co.z * r[2]))
    return new_object(name, bm, [mat])


def cylinder(name, c, axis, r, length, mats, seg=32, r2=None):
    """A cylinder (or cone, r2) from c along axis (Blender vectors); mats (sides, caps)."""
    axis = Vector(axis).normalized()
    a = axis.orthogonal().normalized()
    b = axis.cross(a)
    if isinstance(mats, str):
        mats = (mats, mats)
    bm = bmesh.new()
    r2 = r if r2 is None else r2
    lo = [bm.verts.new(c + (a * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg)) * r) for k in range(seg)]
    hi = [bm.verts.new(c + axis * length + (a * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg)) * r2)
          for k in range(seg)]
    for k in range(seg):
        j = (k + 1) % seg
        bm.faces.new((lo[k], lo[j], hi[j], hi[k]))
    f = bm.faces.new(lo[::-1])
    f.material_index = 1
    f = bm.faces.new(hi)
    f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, list(mats))


def loft_rings(name, rings, mats, cap0=True, cap1=True):
    """Faces between rings of Blender points (same counts); caps as fans."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    m = len(vs[0])
    for a, b in zip(vs[:-1], vs[1:]):
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for ring, on, flip in ((vs[0], cap0, True), (vs[-1], cap1, False)):
        if not on:
            continue
        c = bm.verts.new(sum((v.co for v in ring), Vector()) / m)
        for i in range(m):
            j = (i + 1) % m
            f = bm.faces.new((ring[j], ring[i], c) if flip else (ring[i], ring[j], c))
            f.material_index = 1 if len(mats) > 1 else 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, list(mats))


def mirror_part(car, m):
    """A side mirror: a housing (paint) lofted outwards from its stalk through D-shaped sections
    (a rounded front, a flat back where its glass is), swept back a little at its outer end and
    closed by a rounded cap; the glass (mirror) on the back; the stalk (paint or trim) to the
    door."""
    x0, d0, y0 = m["base"]               # where the stalk meets the body
    w, h, depth = m["size"]              # housing: across (outwards), height, depth along the car
    reach = m.get("reach", 0.06)         # stalk length outwards
    sweep = m.get("sweep", 0.025)        # its outer end this much further back
    xi = x0 + reach
    yc = y0 + h * 0.5
    rings = []
    backs = []
    n = 14
    for k in range(n + 1):
        t = k / n
        x = xi + w * t
        if t < 0.8:
            sc = 0.78 + 0.22 * math.sin(math.pi * 0.5 * min(1.0, t / 0.5))
        else:
            u = (t - 0.8) / 0.2
            sc = math.sqrt(max(1.0 - u * u, 0.0)) * 0.98 + 0.02
        dz = d0 + sweep * t
        ring = []
        for j in range(24):
            a = 2 * math.pi * j / 24
            ca, sa = math.cos(a), math.sin(a)
            if ca >= 0:
                dd = -depth * 0.7 * sc * ca             # the front, rounded towards the nose
            else:
                dd = depth * 0.3 * sc * abs(ca) ** 0.25  # the back: nearly flat
            yy = yc + h * 0.5 * sc * (abs(sa) ** 0.8) * (1 if sa >= 0 else -1)
            ring.append(car.P(x, dz + dd, yy))
        rings.append(ring)
        backs.append((x, dz + depth * 0.3 * sc, sc))
    obs = [loft_rings("Mirror", rings, ["paint"])]
    # the glass: a flat plate just behind the back, inset from its edge
    bm = bmesh.new()
    pts = []
    for k in range(1, n):
        x, db, sc = backs[k]
        if sc < 0.55:
            continue
        pts.append((x, db + 0.003, yc - h * 0.5 * sc * 0.82))
    top = []
    for k in range(1, n):
        x, db, sc = backs[k]
        if sc < 0.55:
            continue
        top.append((x, db + 0.003, yc + h * 0.5 * sc * 0.82))
    poly = pts + top[::-1]
    if len(poly) >= 3:
        vs = [bm.verts.new(car.P(x, d, y)) for x, d, y in poly]
        f = bm.faces.new(vs)
        f.normal_update()
        if f.normal.dot(B(0, 0, -1)) < 0:
            f.normal_flip()
        obs.append(new_object("MirrorGlass", bm, ["mirror"]))
    else:
        bm.free()
    obs.append(prism("Stalk", [(d0 - 0.035, y0 + 0.012), (d0 + 0.03, y0 + 0.012), (d0 + 0.025, y0 + 0.05), (d0 - 0.025, y0 + 0.045)],
                     x0 - 0.05, xi + 0.03, "x", m.get("stalk_mat", "paint"), radii=[0.01] * 4, car=car))
    return obs


def wing_part(car, w):
    """A rear wing: one or two cambered elements between end plates, on uprights (or a lip
    spoiler on the deck: `uprights` empty)."""
    obs = []
    span = w["span"]                       # half span
    for el in w.get("elements", [dict(chord=w["chord"], thick=0.12, camber=0.06, le=(w["d"], w["y"]), pitch=w.get("pitch", 0.12))]):
        sec = airfoil(el["chord"], el.get("thick", 0.12), el.get("camber", 0.06), el["le"], el.get("pitch", 0.12))
        obs.append(prism("Wing", sec, -span, span, "x", w.get("mat", "paint"), car=car))
    if w.get("plates"):
        p = w["plates"]                    # outline (d, y), thickness
        o = prism("EndPlate", p["outline"], span - p.get("t", 0.012), span + 0.002, "x", w.get("plate_mat", w.get("mat", "paint")),
                  radii=p.get("radii"), car=car)
        obs += both(o)
    for u in w.get("uprights", []):
        o = prism("Upright", u["outline"], u["x"] - u.get("t", 0.012), u["x"] + u.get("t", 0.012), "x",
                  u.get("mat", w.get("mat", "paint")), radii=u.get("radii"), car=car)
        obs += both(o)
    return obs


def exhaust_part(car, e):
    """An exhaust tip: a short pipe out of the bumper (metal outside, dark inside), round or oval."""
    obs = []
    x, y, d = e["at"]
    rx, ry = e.get("r", (0.045, 0.045)) if isinstance(e.get("r", 0.045), (tuple, list)) else (e["r"], e["r"])
    length = e.get("length", 0.12)
    for sx in ((1, -1) if e.get("mirror", True) else (1,)):
        outer, inner = [], []
        for k in range(28):
            a = 2 * math.pi * k / 28
            outer.append((x + rx * math.cos(a), y + ry * math.sin(a)))
            inner.append((x + (rx - 0.006) * math.cos(a), y + (ry - 0.006) * math.sin(a)))
        bm = bmesh.new()
        ro = [bm.verts.new(car.P(sx * u, d - 0.01, v)) for u, v in outer]
        ri = [bm.verts.new(car.P(sx * u, d - 0.01, v)) for u, v in inner]
        bo = [bm.verts.new(car.P(sx * u, d - length, v)) for u, v in outer]
        bi = [bm.verts.new(car.P(sx * u, d - 0.04, v)) for u, v in inner]
        n = len(outer)
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((ro[i], ro[j], bo[j], bo[i]))
            f.material_index = 0
            f = bm.faces.new((ro[j], ro[i], ri[i], ri[j]))
            f.material_index = 0
            f = bm.faces.new((ri[j], ri[i], bi[i], bi[j]))
            f.material_index = 1
        f = bm.faces.new(bi)
        f.material_index = 1
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obs.append(new_object("Exhaust", bm, [e.get("mat", "chrome"), "inlet"]))
    return obs


# --- wheels ----------------------------------------------------------------------------------------

def wheel_objects(car, axle):
    """The +x side's wheel of an axle, centred on its origin (Blender: axis x, outer face +x):
    tyre, rim, and (separately) its brake."""
    t = car.s["tyre"]
    R = t["r"][axle]
    W = t["w"][axle]
    rr = t.get("rim_r", R - 0.08)
    rr = rr[axle] if isinstance(rr, (list, tuple)) else rr
    style = t.get("rim", "five")
    hw = W * 0.5
    # the tyre: sidewalls bulging out of the bead, rounded shoulders, a flat tread
    prof = [(-hw + 0.012, rr + 0.004, "tyre"), (-hw + 0.004, rr + 0.02, "tyre"), (-hw - 0.004, rr + (R - rr) * 0.45, "tyre"),
            (-hw + 0.002, R - 0.022, "tyre"), (-hw + 0.012, R - 0.006, "tyre"), (-hw + 0.03, R, "tyre"),
            (hw - 0.03, R, "tyre"), (hw - 0.012, R - 0.006, "tyre"), (hw - 0.002, R - 0.022, "tyre"),
            (hw + 0.004, rr + (R - rr) * 0.45, "tyre"), (hw - 0.004, rr + 0.02, "tyre"), (hw - 0.012, rr + 0.004, "tyre")]
    tyre = revolve("Tyre", prof + [(prof[0][0], prof[0][1], "tyre")], "tyre", seg=72)
    # the rim: barrel inside the tyre, a polished lip at the face, spokes to a hub
    face = hw - 0.012                       # the lip's outer plane
    dish = t.get("dish", 0.035)             # how far the spokes' centre sits back from the lip
    barrel = revolve("Barrel", [(-hw + 0.01, rr - 0.004, "rim"), (-hw + 0.01, rr - 0.018, "rim"), (face - 0.02, rr - 0.018, "rim"),
                                (face - 0.01, rr - 0.03, "rim"), (face - 0.004, rr - 0.03, "rim_lip"), (face, rr - 0.018, "rim_lip"),
                                (face + 0.002, rr + 0.006, "rim_lip"), (face - 0.008, rr + 0.012, "rim_lip"),
                                (hw - 0.03, rr + 0.004, "rim")], "rim", seg=72)
    obs = [tyre, barrel]
    obs += spokes(style, rr - 0.025, face - 0.006, dish, t)
    # hub, centre cap, lug nuts
    hub_x = face - 0.006 - dish
    obs.append(revolve("Hub", [(hub_x - 0.03, 0.0, "rim"), (hub_x - 0.03, 0.085, "rim"), (hub_x + 0.008, 0.085, "rim"),
                               (hub_x + 0.012, 0.07, "rim"), (hub_x + 0.012, 0.035, "rim_lip"), (hub_x + 0.02, 0.028, "rim_lip"),
                               (hub_x + 0.022, 0.0, "rim_lip")], "rim", seg=40))
    nuts = t.get("nuts", 5)
    for k in range(nuts):
        a = 2 * math.pi * (k + 0.5) / nuts
        c = Vector((hub_x + 0.008, math.cos(a) * 0.058, math.sin(a) * 0.058))
        obs.append(cylinder("Nut", c, (1, 0, 0), 0.0095, 0.016, ("rim_lip", "rim_lip"), seg=6))
    wheel = join(obs, "Wheel" + "FR"[axle])
    # the brake: a disc behind the spokes, a caliper over it towards the rear-top
    dr = min(rr - 0.05, t.get("disc_r", rr - 0.05))
    disc = revolve("Disc", [(hub_x - 0.075, 0.09, "disc"), (hub_x - 0.075, dr, "disc"), (hub_x - 0.045, dr, "disc"),
                            (hub_x - 0.045, 0.09, "disc")] + [(hub_x - 0.075, 0.09, "disc")], "disc", seg=48)
    ang = math.radians(t.get("caliper_angle", 35.0))     # from straight up, towards the rear
    sec = []
    for k in range(13):
        a = ang - 0.45 + 0.9 * k / 12
        sec.append((math.cos(a) * (dr + 0.014), math.sin(a) * (dr + 0.014)))
    for k in range(12, -1, -1):
        a = ang - 0.45 + 0.9 * k / 12
        sec.append((math.cos(a) * (dr - 0.06), math.sin(a) * (dr - 0.06)))
    cal_ob = prism_x_local("Caliper", sec, hub_x - 0.1, hub_x - 0.025, "caliper")
    brake = join([disc, cal_ob], "Brake" + "FR"[axle])
    return wheel, brake


def prism_x_local(name, sec, x0, x1, mat):
    """An outline in the wheel's plane, [(up, back)], extruded along the axle (Blender x) from x0
    to x1 (Blender y = -forward = back, z = up)."""
    bm = bmesh.new()
    lo = [bm.verts.new(Vector((x0, b, u))) for u, b in sec]
    hi = [bm.verts.new(Vector((x1, b, u))) for u, b in sec]
    n = len(sec)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bm.faces.new(lo[::-1])
    bm.faces.new(hi)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, [mat])


def spokes(style, r_out, face, dish, t):
    """The rim's spokes (Blender wheel frame: axis x, the face towards +x): each spoke an outline
    in its own plane (radius, across) extruded along x, its face sloping back `dish` from the lip
    to the hub."""
    obs = []
    n = t.get("spokes", 5)
    r_in = 0.075

    def spoke(a, w_in, w_out, thick=0.022, curve=0.0, mat="rim", r0=r_in, r1=r_out, sweep=0.0):
        # a spoke along angle a: outline over radius with widths, the face dished
        k = 10
        rings = []
        for i in range(k + 1):
            s = i / k
            r = r0 + (r1 - r0) * s
            w = w_in + (w_out - w_in) * s
            aa = a + curve * s * s + sweep * s
            xf = face - dish * (1.0 - s) ** 1.6
            ca, sa = math.cos(aa), math.sin(aa)
            # across direction
            cx, sx = -sa, ca
            ring = []
            for u, v in ((-0.5, 0.0), (0.5, 0.0), (0.5, -1.0), (-0.5, -1.0)):
                ring.append(Vector((xf + v * thick, r * ca + cx * w * u, r * sa + sx * w * u)))
            rings.append(ring)
        return loft_rings("Spoke", rings, [mat, mat])

    if style == "five":                      # five broad spokes
        for i in range(n):
            obs.append(spoke(2 * math.pi * i / n, 0.05, 0.065, thick=0.03))
    elif style == "split":                   # twin (Y) spokes
        for i in range(n):
            a = 2 * math.pi * i / n
            obs.append(spoke(a, 0.045, 0.025, r1=r_in + 0.05, thick=0.03))
            for s in (-1, 1):
                obs.append(spoke(a + s * 0.03, 0.022, 0.024, r0=r_in + 0.04, sweep=s * 0.09, thick=0.026))
    elif style == "multi":                   # many thin spokes
        for i in range(n):
            obs.append(spoke(2 * math.pi * i / n, 0.024, 0.03, thick=0.024))
    elif style == "mesh":                    # a crossed mesh (two sets of thin spokes)
        for i in range(n):
            a = 2 * math.pi * i / n
            obs.append(spoke(a, 0.03, 0.02, thick=0.026))
            for s in (-1, 1):
                obs.append(spoke(a, 0.012, 0.014, r0=r_in + 0.06, sweep=s * (math.pi / n), thick=0.016, mat="rim"))
    elif style == "turbine":                 # curved blades
        for i in range(n):
            obs.append(spoke(2 * math.pi * i / n, 0.03, 0.045, thick=0.02, curve=0.5))
    elif style == "star":                    # thin twin spokes in a star (deep dish)
        for i in range(n):
            a = 2 * math.pi * i / n
            for s in (-1, 1):
                obs.append(spoke(a + s * 0.07, 0.016, 0.02, sweep=-s * 0.05, thick=0.024))
    elif style == "disc":                    # a flat aero disc with holes cut by the shader... (plain)
        obs.append(revolve("DiscFace", [(face - dish, 0.0, "rim"), (face - dish, r_out * 0.6, "rim"), (face - 0.004, r_out, "rim")],
                           "rim", seg=64))
    return obs


def join(obs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = obs[0]
    ob.name = name
    ob.data.name = name
    merge_slots(ob)
    return ob


def merge_slots(ob):
    """Each material once (joining keeps one slot per part)."""
    me = ob.data
    seen = {}
    remap = []
    for slot in ob.material_slots:
        nm = slot.material.name.split(".")[0]
        if nm not in seen:
            seen[nm] = len(seen)
        remap.append(seen[nm])
    idx = [remap[p.material_index] for p in me.polygons]
    me.materials.clear()
    for nm in seen:
        me.materials.append(material(nm))
    for p, i in zip(me.polygons, idx):
        p.material_index = i


# --- the whole car --------------------------------------------------------------------------------

def build(spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    car = Car(spec)
    body = car.build_body()
    surf = Surface(body)                 # the uncut body: lenses, glass and gaps sit on it
    feats = importlib.import_module("roadcar_features")
    cut, add = feats.features(car, surf, spec)
    if cut:
        boolean(body, cut, "DIFFERENCE")
    surf2 = Surface(body)
    add += feats.late_features(car, surf2, spec)
    obs = [body] + add
    ob = join(obs, "Body")
    underbody(ob)
    me = ob.data
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(40.0))
    tris = {}
    for p in me.polygons:
        k = me.materials[p.material_index].name
        tris[k] = tris.get(k, 0) + len(p.vertices) - 2
    print("ROADCAR %s body triangles: %d %s" % (spec["id"], sum(tris.values()), tris))
    wheels = []
    for axle in (0, 1):
        w, b = wheel_objects(car, axle)
        for o in (w, b):
            o.data.shade_smooth()
            o.data.set_sharp_from_angle(angle=math.radians(35.0))
        wheels += [w, b]
    return car, ob, wheels


def underbody(ob):
    """The floor and whatever faces the road low down: dark (the paint's livery doesn't go under the
    car)."""
    me = ob.data
    names = [m.name.split(".")[0] for m in me.materials]
    if "paint" not in names:
        return
    if "trim" not in names:
        me.materials.append(material("trim"))
        names.append("trim")
    paint, trim = names.index("paint"), names.index("trim")
    for p in me.polygons:
        if p.material_index != paint:
            continue
        n = p.normal
        y = p.center.z                     # Blender z = the car's height
        if n.z < -0.55 and y < 0.30:
            p.material_index = trim


def anchors(car, n=24):
    """The body's lines along the car for the livery shader: at n stations from nose to tail,
    the top centre, the belt (shoulder), the widest point's height, the sill (rocker) and the half
    width; in visual coordinates."""
    out = {"z": [], "top": [], "belt": [], "mid": [], "sill": [], "hw": []}
    for k in range(n):
        d = car.L * (k + 0.5) / n
        top = car.corner(d, "top")[1]
        if car.g is not None and car.gd[0] < d < car.gd[1]:
            top = max(top, car.g["top"](d))
        sh = car.corner(d, "sh")
        side = car.corner(d, "side")
        out["z"].append(round(car.z(d), 4))
        out["top"].append(round(top, 4))
        out["belt"].append(round(sh[1], 4))
        out["mid"].append(round(side[1], 4))
        out["sill"].append(round(car.corner(d, "rk")[1], 4))
        out["hw"].append(round(max(side[0], sh[0]), 4))
    return out


def export(spec, car, body, wheels, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, spec["id"] + ".glb")
    for o in wheels:
        o.location = (0.0, 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    for o in [body] + wheels:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_normals=True, export_texcoords=False, export_materials="EXPORT")
    tris = sum(len(p.vertices) - 2 for o in [body] + wheels for p in o.data.polygons)
    box_min = [min(v.co[i] for v in body.data.vertices) for i in range(3)]
    box_max = [max(v.co[i] for v in body.data.vertices) for i in range(3)]
    man = {
        "id": spec["id"], "name": spec["name"],
        "wheels": [[round(sx * x, 4), round(y, 4), round(z, 4)] for (x, y, z) in car.wheels for sx in (1, -1)],
        "tyre_r": list(spec["tyre"]["r"]), "tyre_hw": [w * 0.5 for w in spec["tyre"]["w"]],
        "length": spec["length"], "z_nose": round(car.z_nose, 4), "z_tail": round(car.z(car.L), 4),
        # Blender (x, -z, y) -> visual
        "box": [[round(box_min[0], 3), round(box_min[2], 3), round(-box_max[1], 3)],
                [round(box_max[0], 3), round(box_max[2], 3), round(-box_min[1], 3)]],
        "anchors": anchors(car), "triangles": tris,
        "cabin": list(car.gd) if car.gd else [car.L * 0.35, car.L * 0.75],
    }
    with open(os.path.join(out_dir, spec["id"] + ".json"), "w") as f:
        json.dump(man, f, indent=1)
    print("ROADCAR wrote", path, "triangles", tris)


def shots(car, body, wheels, out_path, size=None):
    """One sheet of Workbench views of the car (side, front, rear, top orthographic; two 3/4)."""
    sc = bpy.context.scene
    # place the wheels for the views
    placed = []
    for (x, y, z), axle in zip(car.wheels, (0, 1)):
        w, b = wheels[axle * 2], wheels[axle * 2 + 1]
        for sx in (1, -1):
            for o in (w, b):
                c = o.copy()
                c.data = o.data
                sc.collection.objects.link(c)
                c.location = B(sx * x, y, z)
                if sx < 0:
                    c.scale = (-1, 1, 1)
                placed.append(c)
    for o in wheels:
        o.hide_render = True
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.diffuse_color = (0.42, 0.43, 0.45, 1.0)
    g.data.materials.append(gm)
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.display.shading.show_specular_highlight = True
    size = size or tuple(int(v) for v in opt("size", "640x360").split("x"))
    sc.render.resolution_x, sc.render.resolution_y = size
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    zc = GAME_MID
    views = [("front34", "persp", 32, 8.0, 1.5), ("rear34", "persp", 148, 8.0, 1.7), ("side", "ortho", 90, 10, 0.6),
             ("front", "ortho", 0, 10, 0.6), ("rear", "ortho", 180, 10, 0.6), ("top", "top", 0, 10, 10)]
    if opt("views"):
        # custom: name:yaw:height:dist[:target_d:target_y], persp
        views = []
        for v in opt("views").split(","):
            f = v.split(":")
            views.append((f[0], "persp", float(f[1]), float(f[3]), float(f[2]), float(f[4]) if len(f) > 4 else None,
                          float(f[5]) if len(f) > 5 else 0.5))
    tiles = []
    tmp = os.path.join(os.path.dirname(out_path), "_tile.png")
    for view in views:
        name, kind, yaw, dist, h = view[:5]
        a = math.radians(yaw)
        if kind == "top":
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = car.L * 1.15
            cam.location = B(0, 10, zc)
            cam.rotation_euler = (0, 0, math.pi / 2)
        else:
            cam.data.type = "ORTHO" if kind == "ortho" else "PERSP"
            cam.data.ortho_scale = car.L * 1.15 if yaw == 90 else 2.6
            cam.data.lens = 50
            tz = zc if len(view) < 6 or view[5] is None else car.z(view[5])
            target = B(0, 0.55 if kind == "ortho" else (view[6] if len(view) > 6 else 0.5), tz)
            p = B(math.sin(a) * dist, h, tz + math.cos(a) * dist)
            cam.location = p
            cam.rotation_euler = (target - p).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        px = np.array(img.pixels[:]).reshape(size[1], size[0], 4)
        tiles.append(px)
        bpy.data.images.remove(img)
    if len(tiles) % 2:
        tiles.append(np.zeros_like(tiles[0]))
    rows = [np.concatenate(tiles[i:i + 2], axis=1) for i in range(0, len(tiles), 2)]
    sheet = np.concatenate(rows[::-1], axis=0)       # (images are stored bottom-up)
    h, w = sheet.shape[:2]
    out = bpy.data.images.new("sheet", w, h)
    out.pixels = sheet.ravel()
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    os.remove(tmp)
    for c in placed:
        bpy.data.objects.remove(c, do_unlink=True)
    print("ROADCAR sheet", out_path)


PPM = 300                # orthographic silhouettes: pixels per metre


def ortho(car, body, wheels, out_path):
    """The car's silhouettes, black on transparent, orthographic at PPM pixels a metre: side (nose
    to the left), top (nose to the left), front, rear; one PNG each (out_path_<view>.png) and a
    JSON of the views (for blueprint_fit.py overlay)."""
    sc = bpy.context.scene
    placed = []
    for (x, y, z), axle in zip(car.wheels, (0, 1)):
        w, b = wheels[axle * 2], wheels[axle * 2 + 1]
        for sx in (1, -1):
            for o in (w, b):
                c = o.copy()
                c.data = o.data
                sc.collection.objects.link(c)
                c.location = B(sx * x, y, z)
                if sx < 0:
                    c.scale = (-1, 1, 1)
                placed.append(c)
    for o in wheels:
        o.hide_render = True
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "MATERIAL"
    # each material drawn in its class's code colour: the body black, glass blue, lamps green,
    # openings (grilles, intakes, trim) red
    code = {"glass": (0, 0, 1), "lens": (0, 1, 0), "lamp": (0, 1, 0), "led": (0, 1, 0), "light": (0, 1, 0),
            "lens_red": (0, 1, 0), "amber": (0, 1, 0), "proj": (0, 1, 0), "grille": (1, 0, 0), "inlet": (1, 0, 0)}
    for m in bpy.data.materials:
        m.diffuse_color = (*code.get(m.name.split(".")[0], (0, 0, 0)), 1.0)
    sc.display.shading.show_cavity = False
    sc.display.shading.show_specular_highlight = False
    sc.render.film_transparent = True
    cam = bpy.data.objects.new("Ortho", bpy.data.cameras.new("Ortho"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.sensor_fit = "HORIZONTAL"
    zc = car.z(car.L * 0.5)
    views = {
        # name: (width m, height m, camera position, camera rotation): side from the car's left with
        # the nose to the left, top with the nose to the left, front and rear as seen from them
        "side": (5.2, 1.7, B(8.0, 0.8, zc), (math.pi / 2, 0.0, math.pi / 2)),
        "top": (5.2, 2.4, B(0.0, 8.0, zc), (0.0, 0.0, math.pi / 2)),
        "front": (2.4, 1.7, B(0.0, 0.8, zc + 8.0), (math.pi / 2, 0.0, 0.0)),
        "rear": (2.4, 1.7, B(0.0, 0.8, zc - 8.0), (math.pi / 2, 0.0, math.pi)),
    }
    info = {"ppm": PPM}
    for name, (wm, hm, pos, rot) in views.items():
        sc.render.resolution_x, sc.render.resolution_y = int(wm * PPM), int(hm * PPM)
        cam.data.ortho_scale = wm
        cam.location = pos
        cam.rotation_euler = rot
        path = "%s_%s.png" % (out_path, name)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        info[name] = {"path": path, "width_m": wm, "height_m": hm}
    with open(out_path + ".json", "w") as f:
        json.dump(info, f, indent=1)
    for c in placed:
        bpy.data.objects.remove(c, do_unlink=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    print("ROADCAR ortho", out_path)


def run(car_id):
    mod = importlib.import_module("roadcars." + car_id)
    spec = mod.SPEC
    car, body, wheels = build(spec)
    out = opt("out")
    if out:
        export(spec, car, body, wheels, out)
    if opt("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(opt("blend")))
    if opt("ortho"):
        os.makedirs(opt("ortho"), exist_ok=True)
        ortho(car, body, wheels, os.path.join(opt("ortho"), car_id))
    if opt("shots"):
        os.makedirs(opt("shots"), exist_ok=True)
        shots(car, body, wheels, os.path.join(opt("shots"), car_id + ".png"))


if __name__ == "__main__":
    ids = [opt("car")] if opt("car") else []
    if "--all" in argv:
        ids = importlib.import_module("roadcars").ORDER
    for cid in ids:
        run(cid)
