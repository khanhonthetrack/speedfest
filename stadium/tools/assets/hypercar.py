"""Our own Le Mans hypercar (a generic modern LMH prototype, no maker's design in it) for the
Stadium game, built from numbers in Blender and exported as glTF for car/tm_car_visual.gd
(model "hyper"). The wheels are the game's own (TmCarVisual builds them); this is everything else.

Frame: the car's visual frame, as TmCarVisual (x to the car's left, y up, z forward, the ground at
y 0), in metres. The wheels where the game's car has them: centres (+-0.863, 0.355, 1.784) and
(+-0.885, 0.355, -1.204), radius 0.364, 0.344 / 0.36 m wide; so the body is 2.2 m wide over them.

How it is made:
- the body: closed cross-sections at stations along the car (a centre nose / canopy / engine cover,
  a valley either side, the fender pods over the wheels, the side down to an undercut floor), each
  a polygon with rounded corners, interpolated smoothly between stations and lofted;
- cut out of it (booleans; what a cut leaves inside is dark): the wheel wells, the vents behind
  the front wheels, louvres over them, the open backs of the rear fenders, the front intakes,
  the diffuser's tunnel, the sidepods' inlets;
- added: splitter, rear wing with end plates, the central fin, a roof scoop, mirrors, diffuser
  strakes; glass, headlights and the tail's light bar laid onto the body (projected patches).
Materials by name (TmCarVisual dresses each in the game's own): paint, carbon, black, glass_dark,
inlet, light (the rear lights: brighter under braking), led (the headlights), mirror.

usage: blender -b -P stadium/tools/assets/hypercar.py -- --out stadium/assets/car/hypercar.glb
           [--shots DIR] (Workbench views of the shape) [--blend FILE] (the scene, to look at)
       blender -b -P stadium/tools/assets/hypercar.py -- --manifest stadium/assets/car/hypercar.json
           (only the body's lines along the car for the livery shader, as tools/assets/roadcar.py
           writes them for the road cars; the model isn't built)
"""
import bpy
import bmesh
import math
import os
import sys
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(name, default=None):
    return argv[argv.index("--" + name) + 1] if ("--" + name) in argv else default


F = 0.085                         # the floor's height
FRONT = (0.863, 0.355, 1.784)     # front wheel centre (x, y, z; +x side)
REAR = (0.885, 0.355, -1.204)


def B(x, y, z):
    """The car's frame (x left, y up, z forward) -> Blender's (z up; glTF export turns it back)."""
    return Vector((x, -z, y))


# --- materials ----------------------------------------------------------------------------------

MATS = {
    # name: (preview colour, metallic, roughness, emission)
    "paint": ((0.75, 0.05, 0.04), 0.1, 0.3, 0.0),
    "carbon": ((0.03, 0.03, 0.035), 0.3, 0.4, 0.0),
    "black": ((0.015, 0.015, 0.018), 0.2, 0.15, 0.0),
    "glass_dark": ((0.02, 0.025, 0.035), 0.4, 0.05, 0.0),
    "inlet": ((0.01, 0.01, 0.012), 0.0, 0.9, 0.0),
    "light": ((0.9, 0.05, 0.03), 0.0, 0.3, 3.0),
    "led": ((0.9, 0.95, 1.0), 0.0, 0.3, 4.0),
    "mirror": ((0.9, 0.92, 0.95), 1.0, 0.02, 0.0),
}


def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    col, metal, rough, emit = MATS[name]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*col, 1.0)
    m.metallic = metal
    m.roughness = rough
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
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


# --- 2D helpers ---------------------------------------------------------------------------------

def rounded(poly, radii, closed=True, step=0.004):
    """A polygon [(a, b)] with each corner rounded by its radius, densely sampled (closed: from the
    first corner's arc round to the last's). Radii are clamped to fit the edges."""
    n = len(poly)
    out = []
    for i in range(n):
        p = np.array(poly[i], float)
        r = radii[i]
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
        cos_t = np.clip(np.dot(a, b), -1.0, 1.0)
        theta = math.acos(cos_t)
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


def resample(pts, n, weight=None):
    """n + 1 points along the polyline pts, evenly by (weighted) length."""
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    w = seg if weight is None else seg * weight
    cum = np.concatenate([[0.0], np.cumsum(w)])
    t = np.linspace(0.0, cum[-1], n + 1)
    x = np.interp(t, cum, pts[:, 0])
    y = np.interp(t, cum, pts[:, 1])
    return np.stack([x, y], axis=1)


def pchip(xs, ys, xq):
    """Monotone cubic (Fritsch-Carlson) through (xs, ys), xs increasing: no overshoot between
    stations."""
    xs = np.asarray(xs, float)
    ys = np.asarray(ys, float)
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
    xq = np.atleast_1d(np.asarray(xq, float))
    k = np.clip(np.searchsorted(xs, xq) - 1, 0, len(xs) - 2)
    t = (xq - xs[k]) / h[k]
    h00 = 2 * t ** 3 - 3 * t ** 2 + 1
    h10 = t ** 3 - 2 * t ** 2 + t
    h01 = -2 * t ** 3 + 3 * t ** 2
    h11 = t ** 3 - t ** 2
    return h00 * ys[k] + h10 * h[k] * m[k] + h01 * ys[k + 1] + h11 * h[k] * m[k + 1]


# --- the body -----------------------------------------------------------------------------------

# Stations, nose to tail: z, then the +x half's corners P0..P8 as (x, y, corner radius):
# P0 centre top (nose, canopy, engine cover), P1 its shoulder, P2 / P3 the valley's floor, P4 / P5
# the fender's inner and outer top, P6 the side's top (widest), P7 its foot (the undercut),
# P8 the floor's edge. The floor's centre (0, F) closes the section.
STATIONS = [
    (2.585, [(0, 0.255, 0.05), (0.19, 0.250, 0.04), (0.30, 0.185, 0.03), (0.45, 0.185, 0.03), (0.57, 0.270, 0.04),
             (0.86, 0.270, 0.05), (0.94, 0.220, 0.04), (0.94, 0.120, 0.02), (0.92, F, 0.01)]),
    (2.560, [(0, 0.285, 0.06), (0.20, 0.280, 0.05), (0.30, 0.200, 0.03), (0.45, 0.200, 0.03), (0.58, 0.300, 0.04),
             (0.88, 0.300, 0.05), (0.96, 0.240, 0.05), (0.96, 0.120, 0.02), (0.94, F, 0.01)]),
    (2.450, [(0, 0.360, 0.08), (0.24, 0.350, 0.06), (0.32, 0.240, 0.04), (0.46, 0.240, 0.04), (0.58, 0.420, 0.05),
             (0.92, 0.420, 0.07), (1.01, 0.330, 0.06), (1.01, 0.140, 0.03), (0.99, F, 0.01)]),
    (2.200, [(0, 0.450, 0.10), (0.26, 0.440, 0.07), (0.33, 0.300, 0.04), (0.50, 0.300, 0.04), (0.60, 0.640, 0.06),
             (0.98, 0.640, 0.10), (1.07, 0.520, 0.07), (1.07, 0.180, 0.03), (1.05, F, 0.01)]),
    (1.780, [(0, 0.530, 0.11), (0.27, 0.520, 0.07), (0.34, 0.360, 0.04), (0.52, 0.360, 0.04), (0.61, 0.840, 0.08),
             (0.99, 0.860, 0.09), (1.08, 0.700, 0.08), (1.08, 0.220, 0.04), (1.06, F, 0.01)]),
    (1.380, [(0, 0.590, 0.12), (0.30, 0.580, 0.08), (0.37, 0.420, 0.04), (0.53, 0.420, 0.04), (0.62, 0.820, 0.08),
             (0.98, 0.820, 0.09), (1.07, 0.680, 0.08), (1.06, 0.220, 0.04), (1.03, F, 0.01)]),
    (1.000, [(0, 0.660, 0.14), (0.36, 0.640, 0.09), (0.42, 0.520, 0.05), (0.56, 0.520, 0.05), (0.65, 0.740, 0.08),
             (0.96, 0.720, 0.10), (1.03, 0.620, 0.08), (1.00, 0.220, 0.04), (0.96, F, 0.01)]),
    (0.600, [(0, 0.860, 0.20), (0.40, 0.820, 0.12), (0.50, 0.600, 0.05), (0.60, 0.570, 0.05), (0.70, 0.620, 0.06),
             (0.94, 0.640, 0.08), (1.00, 0.560, 0.08), (0.95, 0.220, 0.04), (0.90, F, 0.01)]),
    (0.150, [(0, 1.035, 0.26), (0.43, 0.960, 0.14), (0.52, 0.610, 0.05), (0.62, 0.570, 0.05), (0.72, 0.590, 0.06),
             (0.93, 0.600, 0.08), (0.99, 0.520, 0.08), (0.93, 0.220, 0.04), (0.88, F, 0.01)]),
    (-0.300, [(0, 1.040, 0.26), (0.41, 0.960, 0.14), (0.52, 0.620, 0.05), (0.62, 0.590, 0.05), (0.74, 0.630, 0.06),
              (0.96, 0.650, 0.08), (1.02, 0.570, 0.08), (0.97, 0.220, 0.04), (0.92, F, 0.01)]),
    (-0.750, [(0, 0.970, 0.22), (0.32, 0.910, 0.12), (0.44, 0.640, 0.05), (0.56, 0.610, 0.05), (0.66, 0.760, 0.07),
              (0.99, 0.790, 0.09), (1.08, 0.670, 0.08), (1.06, 0.220, 0.04), (1.02, F, 0.01)]),
    (-1.200, [(0, 0.860, 0.16), (0.26, 0.820, 0.09), (0.38, 0.620, 0.05), (0.53, 0.600, 0.05), (0.64, 0.880, 0.08),
              (1.00, 0.900, 0.09), (1.10, 0.750, 0.08), (1.10, 0.220, 0.04), (1.08, F, 0.01)]),
    (-1.650, [(0, 0.770, 0.13), (0.24, 0.740, 0.08), (0.36, 0.600, 0.05), (0.52, 0.600, 0.05), (0.64, 0.860, 0.08),
              (1.00, 0.870, 0.09), (1.10, 0.740, 0.08), (1.10, 0.240, 0.04), (1.08, F, 0.01)]),
    (-2.050, [(0, 0.715, 0.11), (0.24, 0.700, 0.07), (0.35, 0.660, 0.04), (0.52, 0.665, 0.04), (0.64, 0.810, 0.07),
              (1.00, 0.810, 0.10), (1.09, 0.710, 0.07), (1.09, 0.280, 0.04), (1.07, F, 0.01)]),
    (-2.200, [(0, 0.700, 0.10), (0.24, 0.690, 0.06), (0.35, 0.675, 0.04), (0.52, 0.680, 0.04), (0.64, 0.780, 0.06),
              (0.99, 0.780, 0.08), (1.08, 0.700, 0.06), (1.08, 0.300, 0.04), (1.06, F, 0.01)]),
    (-2.215, [(0, 0.685, 0.09), (0.23, 0.675, 0.05), (0.34, 0.662, 0.03), (0.51, 0.667, 0.03), (0.63, 0.765, 0.05),
              (0.975, 0.765, 0.07), (1.065, 0.690, 0.05), (1.065, 0.310, 0.03), (1.045, F, 0.01)]),
]
NH = 60          # points per half section
DZ = 0.035       # rows every 3.5 cm


def station_at(z):
    zs = [s[0] for s in STATIONS][::-1]
    out = []
    for i in range(9):
        cols = []
        for c in range(3):
            vals = [s[1][i][c] for s in STATIONS][::-1]
            cols.append(float(pchip(zs, vals, z)[0]))
        out.append(cols)
    return out


def half_section(z):
    """The +x half of the section at z: NH + 1 points (x, y) from the top centre round to the
    floor's centre, spaced by length (corners denser, the floor sparser)."""
    pts = station_at(z)
    full = [(p[0], p[1]) for p in pts] + [(0.0, F)] + [(-p[0], p[1]) for p in reversed(pts[1:])]
    radii = [p[2] for p in pts] + [0.0] + [p[2] for p in reversed(pts[1:])]
    dense = rounded(full, radii)
    # from the top centre (the middle of corner 0's arc) round to the floor's centre
    top = int(np.argmin(np.abs(dense[: len(dense) // 4, 0]) + (dense[: len(dense) // 4, 1] < 0.3) * 9))
    bot = int(np.argmin(np.abs(dense[:, 0]) + np.abs(dense[:, 1] - F)))
    half = dense[top: bot + 1].copy()
    half[0, 0] = 0.0
    half[-1] = (0.0, F)
    if half[1, 0] < 0:
        half = half[::-1]
    seg = np.diff(half, axis=0)
    ang = np.arctan2(seg[:, 1], seg[:, 0])
    turn = np.abs((np.diff(ang) + math.pi) % (2 * math.pi) - math.pi)
    ln = np.linalg.norm(seg, axis=1)
    curv = np.concatenate([[0.0], turn / np.maximum(ln[1:], 1e-4)]) * 0.5 + np.concatenate([turn / np.maximum(ln[:-1], 1e-4), [0.0]]) * 0.5
    floor = (half[:-1, 1] < F + 0.003) & (half[1:, 1] < F + 0.003)
    w = (1.0 + 0.06 * np.minimum(curv, 60.0)) * np.where(floor, 0.2, 1.0)
    return resample(half, NH, w)


def body():
    z0 = STATIONS[0][0]
    z1 = STATIONS[-1][0]
    n = int(round((z0 - z1) / DZ))
    zs = list(np.linspace(z0, z1, n + 1))
    bm = bmesh.new()
    rings = []
    for z in zs:
        h = half_section(z)
        ring = [(x, y) for x, y in h] + [(-x, y) for x, y in h[-2:0:-1]]
        rings.append([bm.verts.new(B(x, y, z)) for x, y in ring])
    m = len(rings[0])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.material_index = 0
    return new_object("Body", bm, ["paint"])


def top_y(z, x=0.0):
    """The body's top at (x, z) (from the sections; x near the centre)."""
    h = half_section(z)
    i = int(np.argmin(np.abs(h[: NH // 3, 0] - x)))
    return float(h[i, 1])


# --- solids from outlines -------------------------------------------------------------------------

def prism(name, outline, a0, a1, axis="x", mat="inlet", radii=None):
    """An outline (2D, closed) extruded along an axis from a0 to a1. axis x: outline (z, y);
    y: (x, z); z: (x, y)."""
    pts = rounded(outline, radii) if radii else np.array(outline, float)
    bm = bmesh.new()

    def P(u, v, a):
        if axis == "x":
            return B(a, v, u)
        if axis == "y":
            return B(u, a, v)
        return B(u, v, a)

    lo = [bm.verts.new(P(u, v, a0)) for u, v in pts]
    hi = [bm.verts.new(P(u, v, a1)) for u, v in pts]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bm.faces.new(lo[::-1])
    bm.faces.new(hi)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_object(name, bm, [mat])


def cylinder_x(name, c, r, x0, x1, mat="inlet", seg=48):
    pts = [(c[2] + r * math.cos(2 * math.pi * k / seg), c[1] + r * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    return prism(name, pts, x0, x1, "x", mat)


def mirror_copy(ob):
    """The same solid on the other side (x -> -x)."""
    me = ob.data.copy()
    for v in me.vertices:
        v.co.x = -v.co.x
    me.flip_normals()
    o2 = bpy.data.objects.new(ob.name + "_m", me)
    bpy.context.scene.collection.objects.link(o2)
    return o2


def cutters():
    cut = []

    def both(o):
        cut.append(o)
        cut.append(mirror_copy(o))

    # wheel wells
    both(cylinder_x("WellF", FRONT, 0.400, 0.600, 1.40))
    both(cylinder_x("WellR", REAR, 0.410, 0.625, 1.40))
    # the vent behind each front wheel: open from the well back along the side
    both(prism("VentF", [(1.45, 0.22), (1.45, 0.64), (1.20, 0.66), (0.98, 0.50), (0.96, 0.22)], 0.86, 1.40,
               radii=[0.0, 0.05, 0.10, 0.08, 0.04]))
    # louvres over the front wheels, through into the wells
    for k in range(6):
        zc = 1.62 - k * 0.062
        both(prism("Louvre%d" % k, [(0.70, zc - 0.016), (0.97, zc - 0.016), (0.97, zc + 0.016), (0.70, zc + 0.016)],
                   0.70, 1.20, "y", radii=[0.012] * 4))
    # the rear fenders open at the back (the tyre seen from behind) and their sides cut away behind
    # the wheels: the fender a shell over the tyre
    both(prism("OpenR", [(-1.42, 0.02), (-1.42, 0.50), (-1.75, 0.60), (-2.40, 0.60), (-2.40, 0.02)], 0.68, 1.045,
               radii=[0.0, 0.10, 0.10, 0.0, 0.0]))
    both(prism("OpenRS", [(-1.50, 0.02), (-1.50, 0.40), (-1.78, 0.53), (-2.40, 0.57), (-2.40, 0.02)], 0.98, 1.40,
               radii=[0.0, 0.12, 0.15, 0.0, 0.0]))
    # front intakes either side of the nose, under the fenders' fronts
    both(prism("IntakeF", [(0.29, 0.115), (0.56, 0.115), (0.57, 0.27), (0.30, 0.24)], 2.30, 2.80, "z",
               radii=[0.03, 0.03, 0.04, 0.04]))
    # inlets in the rear fenders' leading slopes, over the sidepods
    both(prism("Inlet", [(0.70, -0.30), (0.93, -0.38), (0.93, -0.70), (0.70, -0.62)], 0.585, 1.2, "y",
               radii=[0.03, 0.03, 0.05, 0.05]))
    # the diffuser's tunnel under the tail
    cut.append(prism("Diffuser", [(-1.40, -0.2), (-1.40, F + 0.004), (-1.75, 0.20), (-2.40, 0.44), (-2.40, -0.2)],
                     -0.70, 0.70, radii=[0.0, 0.25, 0.4, 0.0, 0.0]))
    # the tail's grille, recessed under the light bar
    cut.append(prism("Grille", [(-0.60, 0.462), (0.60, 0.462), (0.60, 0.612), (-0.60, 0.612)], -2.80, -2.17, "z",
                     radii=[0.03] * 4))
    return cut


def apply_cuts(ob, cut):
    coll = bpy.data.collections.new("Cutters")
    bpy.context.scene.collection.children.link(coll)
    for c in cut:
        for col in c.users_collection:
            col.objects.unlink(c)
        coll.objects.link(c)
    mod = ob.modifiers.new("Cuts", "BOOLEAN")
    mod.operation = "DIFFERENCE"
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


# --- parts --------------------------------------------------------------------------------------

def airfoil(chord, thick, camber, le, pitch, n=14):
    """A cambered section (z, y): leading edge at le, trailing edge towards -z (NACA thickness)."""
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
        u, v = -x * chord, y * chord
        out.append((le[0] + u * c - v * s, le[1] + u * s + v * c))
    return out


def parts():
    obs = []
    # splitter: a carbon blade under the nose, its edge ahead of the bodywork
    # (cut back round the front tyres, which reach its height up to z 2.04)
    obs.append(prism("Splitter", [(-1.02, 2.08), (-0.64, 2.08), (-0.60, 1.95), (0.60, 1.95), (0.64, 2.08), (1.02, 2.08),
                                  (1.02, 2.36), (0.95, 2.64), (0.0, 2.70), (-0.95, 2.64), (-1.02, 2.36)], 0.064, 0.094, "y",
                     "carbon", radii=[0, 0.02, 0, 0, 0.02, 0, 0.10, 0.25, 0.6, 0.25, 0.10]))
    # dive planes on the front corners
    for y, z0, out in ((0.27, 2.46, 1.11), (0.37, 2.40, 1.09)):        # (clear of the wheel wells)
        o = prism("Canard", [(0.95, z0), (out, z0 - 0.10), (out, z0 - 0.17), (0.95, z0 - 0.20)], y, y + 0.012, "y", "carbon",
                  radii=[0.0, 0.02, 0.02, 0.0])
        obs += [o, mirror_copy(o)]
    # rear wing: one cambered element between the end plates, a gurney on its trailing edge
    wing = airfoil(0.40, 0.11, -0.055, (-1.79, 1.000), -0.20)
    obs.append(prism("Wing", wing, -0.975, 0.975, "x", "carbon"))
    te = wing[len(wing) // 2]
    obs.append(prism("Gurney", [(te[0] + 0.004, te[1] - 0.004), (te[0] + 0.004, te[1] + 0.022),
                                (te[0] - 0.006, te[1] + 0.022), (te[0] - 0.006, te[1] - 0.004)], -0.975, 0.975, "x", "carbon"))
    # end plates, from the rear fenders' tops past the wing; a red light along each trailing edge
    plate = [(-1.42, 0.80), (-1.66, 1.135), (-2.215, 1.135), (-2.235, 1.10), (-2.235, 0.74), (-1.90, 0.74)]
    o = prism("EndPlate", plate, 0.975, 0.993, "x", "paint", radii=[0.04, 0.10, 0.03, 0.02, 0.02, 0.05])
    obs += [o, mirror_copy(o)]
    o = prism("PlateLight", [(-2.226, 0.80), (-2.226, 1.095), (-2.242, 1.095), (-2.242, 0.80)], 0.972, 0.996, "x", "light")
    obs += [o, mirror_copy(o)]
    # the fin along the engine cover, up into the wing
    fin = []
    zs = np.linspace(-0.30, -1.86, 14)
    for z in zs:
        fin.append((z, top_y(z) - 0.03))
    fin += [(-1.86, 1.03), (-1.70, 1.065), (-0.42, 1.045)]
    obs.append(prism("Fin", fin, -0.007, 0.007, "x", "paint"))
    # roof scoop: a low hump on the roof, its mouth dark
    rows = []
    for k, z in enumerate(np.linspace(0.30, -0.42, 10)):
        t = k / 9.0
        hw = 0.105 * (1.0 - 0.75 * t ** 2)
        hh = 0.075 * (1.0 - t ** 1.5)
        yb = top_y(z) - 0.02
        rows.append((z, hw, yb, yb + 0.02 + hh))
    bm = bmesh.new()
    rings = []
    for z, hw, yb, yt in rows:
        sec = rounded([(-hw, yb), (hw, yb), (hw, yt), (-hw, yt)], [0.0, 0.0, 0.04, 0.04])
        sec = resample(np.vstack([sec, sec[:1]]), 20)[:-1]
        rings.append([bm.verts.new(B(x, y, z)) for x, y in sec])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(len(a)):
            j = (i + 1) % len(a)
            bm.faces.new((a[i], a[j], b[j], b[i]))
    f = bm.faces.new(rings[0])
    f.material_index = 1
    bm.faces.new(rings[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obs.append(new_object("Scoop", bm, ["paint", "inlet"]))
    # mirrors on short stalks from the front fenders
    bm = bmesh.new()
    rings = []
    for k in range(7):
        t = k / 6.0
        z = 1.12 - 0.15 * t
        s = 0.15 + 0.85 * math.sqrt(math.sin(math.pi * 0.5 * t))
        ring = []
        for j in range(16):
            a = 2 * math.pi * j / 16
            ring.append(bm.verts.new(B(0.80 + math.cos(a) * 0.10 * s, 0.84 + math.sin(a) * 0.036 * s, z)))
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(16):
            j = (i + 1) % 16
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0][::-1])
    f = bm.faces.new(rings[-1])
    f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = new_object("Mirror", bm, ["paint", "mirror"])
    obs += [o, mirror_copy(o)]
    o = prism("Stalk", [(1.06, 0.70), (1.09, 0.70), (1.06, 0.83), (1.02, 0.83)], 0.785, 0.815, "x", "carbon")
    obs += [o, mirror_copy(o)]
    # diffuser strakes, and its low outer fences behind the rear tyres
    for x in (0.22, 0.46):
        prof = [(-1.45, 0.09), (-2.30, 0.09), (-2.30, 0.43), (-1.75, 0.22), (-1.45, 0.11)]
        o = prism("Strake", prof, x - 0.006, x + 0.006, "x", "carbon")
        obs += [o, mirror_copy(o)]
    o = prism("Fence", [(-1.48, 0.088), (-2.30, 0.088), (-2.30, 0.30), (-1.95, 0.21), (-1.48, 0.11)], 0.688, 0.702, "x",
              "carbon", radii=[0.0, 0.0, 0.02, 0.15, 0.0])
    obs += [o, mirror_copy(o)]
    return obs


# --- patches laid onto the body -------------------------------------------------------------------

def patch(name, outline, ray, start, bvh, mat, lift=0.003, rings=5, radii=None, accept=None):
    """A flat outline (2D, convex) laid onto the body: each point cast along `ray` (a car-frame
    direction) from `start(u, v)` (a car-frame point), then lifted off the surface by `lift`."""
    pts = rounded(outline, radii) if radii else np.array(outline, float)
    pts = resample(np.vstack([pts, pts[:1]]), max(16, len(pts) // 3))[:-1]
    c = pts.mean(axis=0)
    d = B(*ray).normalized()
    bm = bmesh.new()
    grid = []
    miss = 0
    for k in range(rings, -1, -1):
        s = k / rings
        row = []
        for u, v in pts if k > 0 else [c]:
            q = c + (np.array([u, v]) - c) * s
            o = B(*start(q[0], q[1]))
            hit = bvh.ray_cast(o, d)
            if hit[0] is None or (accept and not accept(hit[0])):
                miss += 1
                p = o
            else:
                p = hit[0] + hit[1] * lift
            row.append(bm.verts.new(p))
        grid.append(row)
    n = len(pts)
    for a, b in zip(grid[:-2], grid[1:-1]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    centre = grid[-1][0]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((grid[-2][i], grid[-2][j], centre))
    # face it the way the ray came from
    for f in bm.faces:
        f.normal_update()
        if f.normal.dot(d) > 0:
            f.normal_flip()
    if miss:
        print("PATCH %s: %d points missed the body" % (name, miss))
    return new_object(name, bm, [mat])


def patches(body_ob):
    bm = bmesh.new()
    bm.from_mesh(body_ob.data)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    obs = []
    # windscreen, seen from above
    obs.append(patch("Windscreen", [(-0.345, 0.93), (0.345, 0.93), (0.33, 0.18), (-0.33, 0.18)], (0, -1, 0),
                     lambda u, v: (u, 2.0, v), bvh, "glass_dark", radii=[0.05, 0.05, 0.09, 0.09], rings=6))
    # side windows, seen from the side (cast from just outside the canopy, over the sidepods)
    side = [(0.58, 0.715), (0.25, 0.86), (-0.25, 0.875), (-0.48, 0.82), (-0.42, 0.70), (0.30, 0.67)]
    for sx in (1.0, -1.0):
        obs.append(patch("SideWindow", side, (-sx, 0, 0), lambda u, v, sx=sx: (sx * 0.62, v, u), bvh, "glass_dark",
                         radii=[0.05, 0.12, 0.10, 0.06, 0.06, 0.08], accept=lambda p: abs(p.x) > 0.3))
    # headlights on the fenders' fronts: a dark housing, two LED blades in it
    for sx in (1.0, -1.0):
        st = lambda u, v, sx=sx: (sx * u, v, 3.0)
        obs.append(patch("LampHousing", [(0.645, 0.372), (0.955, 0.372), (0.975, 0.44), (0.935, 0.505), (0.665, 0.488)],
                         (0, 0, -1), st, bvh, "glass_dark", radii=[0.02, 0.03, 0.03, 0.03, 0.02], lift=0.003))
        obs.append(patch("LedTop", [(0.69, 0.462), (0.925, 0.474), (0.925, 0.486), (0.69, 0.474)], (0, 0, -1), st, bvh, "led",
                         radii=[0.005] * 4, lift=0.006, rings=2))
        obs.append(patch("LedLow", [(0.74, 0.418), (0.93, 0.424), (0.93, 0.435), (0.74, 0.429)], (0, 0, -1), st, bvh, "led",
                         radii=[0.005] * 4, lift=0.006, rings=2))
    # the tail's light bar, full width
    obs.append(patch("TailLight", [(-0.95, 0.628), (0.95, 0.628), (0.95, 0.658), (-0.95, 0.658)], (0, 0, 1),
                     lambda u, v: (u, v, -3.0), bvh, "light", radii=[0.008] * 4, lift=0.004, rings=2))
    return obs


# --- the whole car --------------------------------------------------------------------------------

# the rear wing's parts: the car's stock spoiler, its own object (tuning swaps it, PLAN M17)
SPOILER_PARTS = ("Wing", "Gurney", "EndPlate", "PlateLight")


def build():
    """The body (HyperBody) and the stock spoiler (HyperSpoiler), each one object."""
    global SPOILER
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ob = body()
    apply_cuts(ob, cutters())
    obs = [ob] + parts() + patches(ob)
    import roadcar
    spoiler = [o for o in obs if o.name.split("_")[0].split(".")[0] in SPOILER_PARTS]
    obs = [o for o in obs if o not in spoiler]
    SPOILER = roadcar.join(spoiler, "HyperSpoiler")
    SPOILER.data.shade_smooth()
    SPOILER.data.set_sharp_from_angle(angle=math.radians(38.0))
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    ob.name = "HyperBody"
    ob.data.name = "HyperBody"
    me = ob.data
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(38.0))
    # merge each material's slots (joining kept one slot per part)
    seen = {}
    remap = []
    for i, slot in enumerate(ob.material_slots):
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
    tris = {}
    for p in me.polygons:
        k = me.materials[p.material_index].name
        tris[k] = tris.get(k, 0) + len(p.vertices) - 2
    print("HYPERCAR triangles: %d %s" % (sum(tris.values()), tris))
    return ob


def shots(out_dir):
    """Workbench views of the shape (material colours, cavities), wheels as plain discs."""
    os.makedirs(out_dir, exist_ok=True)
    for name, c in (("FL", FRONT), ("RL", REAR)):
        for sx in (1.0, -1.0):
            bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.364, depth=0.344, location=B(sx * c[0], c[1], c[2]),
                                                rotation=(0.0, math.pi / 2, 0.0))
            w = bpy.context.active_object
            w.data.materials.append(material("carbon"))
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.diffuse_color = (0.35, 0.36, 0.38, 1.0)
    g.data.materials.append(gm)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.render.resolution_x = 1400
    sc.render.resolution_y = 800
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 50
    views = {"front34": (35, 7.5, 1.6), "rear34": (150, 7.5, 1.8), "side": (90, 8.5, 0.7), "front": (0, 8.0, 1.0),
             "rear": (180, 8.0, 1.2), "top": (60, 6.0, 6.5), "low": (25, 5.5, 0.5)}
    target = B(0, 0.5, 0.2)
    for name, (yaw, dist, h) in views.items():
        a = math.radians(yaw)
        p = B(math.sin(a) * dist, h, math.cos(a) * dist + 0.2)
        cam.location = p
        d = target - p
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)


def manifest(path, n=24):
    """The body's lines at n stations nose to tail (visual coordinates): the top centre, the belt
    (the side's top), the widest point's height, the sill (the side's foot) and the half width;
    the canopy's span (distances back from the nose)."""
    z0, z1 = STATIONS[0][0], STATIONS[-1][0]
    out = {"z": [], "top": [], "belt": [], "mid": [], "sill": [], "hw": []}
    for k in range(n):
        z = z0 + (z1 - z0) * (k + 0.5) / n
        p = station_at(z)
        out["z"].append(round(z, 4))
        out["top"].append(round(p[0][1], 4))
        out["belt"].append(round(p[6][1], 4))
        out["mid"].append(round((p[6][1] + p[7][1]) * 0.5, 4))
        out["sill"].append(round(p[7][1], 4))
        out["hw"].append(round(p[6][0], 4))
    import json
    with open(path, "w") as f:
        json.dump({"id": "hyper", "z_nose": z0, "z_tail": z1, "cabin": [round(z0 - 0.97, 3), round(z0 + 0.36, 3)],
                   "anchors": out}, f, indent=1)
    print("HYPERCAR manifest", path)


if opt("manifest") and not opt("out"):
    manifest(opt("manifest"))
    raise SystemExit(0)
ob = build()
if opt("manifest"):
    manifest(opt("manifest"))
out = opt("out")
if out:
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    import roadcar
    import tuning_kit
    roadcar.export_objects([ob, SPOILER], out)
    print("HYPERCAR wrote", out)
    # the tuning kit fitted to the body without its wing: the hood is the nose's centre between
    # the fender pods, from behind its tip to short of the windscreen's foot
    geo = tuning_kit.Geo(ob, STATIONS[0][0], STATIONS[-1][0], 2.25, 1.05, lambda z: station_at(z)[1][0] * 0.85)
    kit = tuning_kit.kit(geo)
    roadcar.export_objects(kit, out.replace(".glb", "_kit.glb"))
    print("HYPERCAR kit", {o.name: len(o.data.polygons) for o in kit})
    # the manifest (the body's lines) with the underglow's tubes, lights and light on the road
    import json
    man_path = out.replace(".glb", ".json")
    manifest(man_path)
    with open(man_path) as f:
        man = json.load(f)
    man["underglow"] = tuning_kit.underglow(geo, [FRONT, REAR], [0.364, 0.364], [0.172, 0.18], out.replace(".glb", ""))
    with open(man_path, "w") as f:
        json.dump(man, f, indent=1)
    print("HYPERCAR underglow", man_path)
if opt("blend"):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(opt("blend")))
if opt("shots"):
    shots(opt("shots"))
