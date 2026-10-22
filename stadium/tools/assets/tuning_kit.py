"""The tuning kit (PLAN M17): spoilers and hood add-ons fitted to one car's body, for
tools/assets/roadcar.py (the road cars) and tools/assets/hypercar.py (the hypercar). Blender,
imported by those scripts; everything in the car's visual frame (x to its left, y up, z forward,
the ground at y 0), placed by ray casts against the car's own body (without its stock spoiler).

Spoilers (TmRoadCars.SPOILERS; 0 is the car's own, 1 none): 2 lip, 3 ducktail, 4 low wing,
5 street wing on stanchions, 6 GT wing, 7 swan neck, 8 twin plane, 9 drift wing. Each is one
object "Spoiler<k>".
Hoods (TmRoadCars.HOODS: shapes; the finishes are the paint shader's): vents, scoop, bulge,
louvres, cowl. Each is one object "Hood<Shape>".
Materials by name: paint (the livery shader paints it like the body), carbon, inlet (dark).
Underglow (TmRoadCars.GLOWS): underglow() fits neon tubes under the car (under its sills between the
wheels, across behind its bumpers) and bakes the light they throw on the road into two pictures.
"""
import struct
import zlib
import math

import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import roadcar as rc

B = rc.B


class Geo:
    """What the kit needs of a car: its body to cast against, where its nose and tail are (z), its
    hood's span (z0 at the front, z1 by the windscreen) and a function of z for the hood's usable
    half width."""

    def __init__(self, body_ob, z_nose, z_tail, hood_z0, hood_z1, hood_hw):
        bm = bmesh.new()
        bm.from_mesh(body_ob.data)
        bm.transform(body_ob.matrix_world)
        self.bvh = BVHTree.FromBMesh(bm)
        bm.free()
        self.z_nose, self.z_tail = z_nose, z_tail
        self.hood_z0, self.hood_z1 = hood_z0, hood_z1
        self.hood_hw = hood_hw

    def top(self, x, z, default=None):
        """The body's top (y) at (x, z), from above."""
        hit = self.bvh.ray_cast(B(x, 4.0, z), Vector((0.0, 0.0, -1.0)))
        return hit[0].z if hit[0] is not None else default

    def side(self, y, z, default=None):
        """The body's side (x > 0) at height y, z, from the left."""
        hit = self.bvh.ray_cast(B(4.0, y, z), Vector((-1.0, 0.0, 0.0)))
        return hit[0].x if hit[0] is not None else default

    def below(self, x, z, default=None):
        """The body's underside (y) at (x, z), from the road."""
        hit = self.bvh.ray_cast(B(x, -1.0, z), Vector((0.0, 0.0, 1.0)))
        return hit[0].z if hit[0] is not None else default


# --- building blocks -------------------------------------------------------------------------------

def prism_zy(name, outline, x0, x1, mats, radii=None):
    """An outline in (z, y) extruded across x from x0 to x1."""
    return rc.prism(name, outline, x0, x1, "x", mats, radii=radii)


def foil_zy(chord, thick, camber, z_le, y_le, pitch):
    """An airfoil section in (z, y): leading edge at (z_le, y_le), the trailing edge behind it
    (towards -z); camber < 0 and pitch < 0 for downforce (the trailing edge up)."""
    return [(-d, y) for d, y in rc.airfoil(chord, thick, camber, (-z_le, y_le), pitch)]


def loft(name, rings, mats, cap0=True, cap1=True):
    """Rings of visual points (same counts) lofted; caps as fans (material mats[1])."""
    return rc.loft_rings(name, [[B(*p) for p in ring] for ring in rings], mats, cap0, cap1)


def loft_edges(name, rings, edge_mats, cap_mat):
    """Rings of visual points (same counts, closed) lofted, each edge of the ring its own material
    (edge i: points i -> i + 1); capped."""
    mats = []
    for m in list(edge_mats) + [cap_mat]:
        if m not in mats:
            mats.append(m)
    bm = bmesh.new()
    vs = [[bm.verts.new(B(*p)) for p in ring] for ring in rings]
    n = len(vs[0])
    for a, b in zip(vs[:-1], vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = mats.index(edge_mats[i])
    for ring, flip in ((vs[0], True), (vs[-1], False)):
        f = bm.faces.new(ring[::-1] if flip else ring)
        f.material_index = mats.index(cap_mat)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return rc.new_object(name, bm, mats)


def fan(name, ring, mat):
    """A flat-ish face filling a ring of visual points (a fan from its centre)."""
    bm = bmesh.new()
    vs = [bm.verts.new(B(*p)) for p in ring]
    c = bm.verts.new(sum((v.co for v in vs), Vector()) / len(vs))
    for i in range(len(vs)):
        bm.faces.new((vs[i], vs[(i + 1) % len(vs)], c))
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return rc.new_object(name, bm, [mat])


def join(obs, name):
    obs = [o for o in obs if o is not None]
    return rc.join(obs, name) if obs else None


def path_band(path, half):
    """A band of half width `half` around a polyline in (z, y): its outline."""
    left, right = [], []
    for i, (z, y) in enumerate(path):
        z0, y0 = path[max(i - 1, 0)]
        z1, y1 = path[min(i + 1, len(path) - 1)]
        tz, ty = z1 - z0, y1 - y0
        ln = math.hypot(tz, ty) or 1.0
        nz, ny = -ty / ln, tz / ln
        left.append((z + nz * half, y + ny * half))
        right.append((z - nz * half, y - ny * half))
    return left + right[::-1]


# --- spoilers ----------------------------------------------------------------------------------------

def deck(geo):
    """Where a wing stands: the station 0.3 m inside the tail, the deck's height there (the highest
    of three points off the centre line, so a wing clears raised rear fenders; a fin or a badge on
    the centre line doesn't count), the body's half width just under it, and the tail's top at its
    edge."""
    zt = geo.z_tail
    zm = zt + 0.30
    ys = [geo.top(x, zm) for x in (0.32, 0.52, 0.70)]
    ym = max([y for y in ys if y is not None] or [0.9])
    hw = geo.side(ym - 0.05, zm, 0.8)
    ye = max([y for y in (geo.top(0.3, zt + 0.05), geo.top(0.5, zt + 0.05)) if y is not None] or [ym])
    return zm, ym, hw, ye


def deck_blade(geo, name, z0, z1, rise, span, mat, fall=6.0, n_x=24, n_z=8, thick=0.006, power=2.0):
    """A blade on the deck from z0 (front) to z1 (back), following the deck's surface across and
    along, its top rising to `rise` at the back (lip, ducktail), easing out at its ends."""
    rings = []
    for k in range(n_x + 1):
        x = -span + 2.0 * span * k / n_x
        e = max(0.0, 1.0 - abs(x / span) ** fall) ** 0.5
        bottom, top = [], []
        for i in range(n_z + 1):
            t = i / n_z
            z = z0 + (z1 - z0) * t
            # the lowest of three points 4 cm apart: a fin or a badge on the deck isn't its surface
            hs = [h for h in (geo.top(x + dx, z) for dx in (-0.04, 0.0, 0.04)) if h is not None]
            s = min(hs) if hs else geo.top(x * 0.9, z, 0.9)
            bottom.append((x, s - thick, z))
            top.append((x, s + thick * 0.5 + rise * e * t ** power, z))
        rings.append(bottom + top[::-1])
    return loft(name, rings, [mat, mat])


def endplates(z_front, z_back, y_low, y_high, x, mat, t=0.012, chamfer=0.04):
    o = prism_zy("EndPlate", [(z_front, y_low), (z_back, y_low), (z_back, y_high), (z_front - chamfer * 0.5, y_high),
                              (z_front, y_high - chamfer)], x, x + t, mat, radii=[0.01, 0.015, 0.02, 0.02, 0.015])
    return rc.both(o)


def upright(zs, ys, x, t, mat, radii=None):
    """A stanchion's outline (z, y) extruded at +-x."""
    o = prism_zy("Upright", list(zip(zs, ys)), x - t * 0.5, x + t * 0.5, mat, radii=radii)
    return rc.both(o)


def wing(geo, k):
    """Spoiler k (2-9)."""
    zm, ym, hw, ye = deck(geo)
    zt = geo.z_tail
    span = min(hw - 0.05, 0.82)
    obs = []
    if k == 2:                                    # a lip on the tail's edge
        return [deck_blade(geo, "Lip", zt + 0.17, zt + 0.035, 0.035, span - 0.03, "paint", fall=8.0)]
    if k == 3:                                    # a ducktail: the deck kicks up
        return [deck_blade(geo, "Ducktail", zt + 0.42, zt + 0.03, 0.085, span, "paint", fall=5.0, power=2.2, thick=0.008)]
    # wings: (chord, height over the deck, half span, wing material, upright x, upright material,
    # end plates (length, height) or None, gurney, elements)
    spec = {
        4: (0.22, 0.10, span - 0.06, "paint", 0.55, "paint", None, False, 1),
        5: (0.27, 0.20, span, "paint", 0.62, "paint", (0.20, 0.10), False, 1),
        6: (0.34, 0.30, min(span + 0.04, 0.86), "carbon", 0.40, "carbon", (0.42, 0.20), True, 1),
        7: (0.32, 0.27, min(span + 0.02, 0.84), "carbon", 0.36, "carbon", (0.36, 0.16), True, 1),
        8: (0.26, 0.21, span, "paint", 0.50, "carbon", (0.40, 0.22), False, 2),
        9: (0.38, 0.36, min(span + 0.05, 0.88), "paint", 0.46, "carbon", (0.52, 0.30), True, 1),
    }[k]
    chord, h, s, wmat, ux, umat, plates, gurney, elements = spec
    z_te = zt + 0.04                              # the trailing edge just inside the tail
    z_le = z_te + chord
    y_w = ym + h
    sec = foil_zy(chord, 0.11, -0.05, z_le, y_w, -0.14)
    obs.append(prism_zy("Wing", sec, -s, s, wmat))
    y_top = max(y for _, y in sec)
    if elements == 2:                             # a flap above and behind the main plane
        fc = chord * 0.55
        flap = foil_zy(fc, 0.10, -0.05, z_te + fc * 0.45, y_top + 0.03, -0.45)
        obs.append(prism_zy("Flap", flap, -s, s, "carbon"))
        y_top = max(y_top, max(y for _, y in flap))
    if gurney:
        te = min(sec, key=lambda p: p[0])
        obs.append(prism_zy("Gurney", [(te[0] + 0.006, te[1] - 0.004), (te[0] - 0.004, te[1] - 0.004),
                                       (te[0] - 0.004, te[1] + 0.022), (te[0] + 0.006, te[1] + 0.022)], -s, s, "carbon"))
    if plates:
        pl, ph = plates
        zf = z_le + (pl - chord) * 0.45
        obs += endplates(zf, zf - pl, y_w - ph * 0.55, y_top + ph * 0.35, s, "carbon" if k in (6, 7) else "paint")
    # the uprights: x as a fraction of the span (inside the deck's flat part)
    xu = min(s * ux, hw - 0.18)
    yd = geo.top(xu, z_le - chord * 0.5, ym)
    if k == 7:                                    # swan neck: from the deck up behind the wing, over it
        path = []
        z_base = z_le - chord * 0.35
        bump = chord * 0.6 + 0.06                 # how far behind the trailing edge the neck rises
        for i in range(13):
            t = i / 12.0
            z = z_base - bump * math.sin(math.pi * t) + (z_le - chord * 0.55 - z_base) * t ** 2
            y = yd - 0.01 + (y_top + 0.045 - yd) * math.sin(0.5 * math.pi * min(t * 1.25, 1.0))
            path.append((z, y))
        path.append((z_le - chord * 0.45, y_top - 0.01))
        obs += rc.both(prism_zy("Swan", path_band(path, 0.018), xu - 0.008, xu + 0.008, umat))
    else:
        f = z_le - chord * 0.18
        r = z_le - chord * (0.70 if k != 4 else 0.62)
        lean = 0.03 if k != 4 else 0.0
        obs += upright([f + 0.02, r + 0.04, r - lean, f - lean], [yd - 0.02, geo.top(xu, r + 0.04, yd) - 0.02, y_w - 0.005,
                       y_w - 0.005], xu, 0.02 if k != 4 else 0.016, umat, radii=[0.01, 0.01, 0.02, 0.02])
    return obs


def spoilers(geo):
    """{k: object} for spoilers 2-9."""
    out = {}
    for k in range(2, 10):
        out[k] = join(wing(geo, k), "Spoiler%d" % k)
    return out


# --- hoods ---------------------------------------------------------------------------------------------

def rect(xc, zc, hx, hz, r, n=48):
    return rc.closed_outline([(xc - hx, zc - hz), (xc + hx, zc - hz), (xc + hx, zc + hz), (xc - hx, zc + hz)],
                             [r] * 4, n=n)


def vent(geo, name, xc, zc, hx, hz, slats=5):
    """A raised vent on the hood: a frame (paint) round a dark floor, slats across it."""
    o = rect(xc, zc, hx, hz, min(hx, hz) * 0.35)
    rings = []
    for inset, lift in ((0.0, -0.004), (0.004, 0.016), (0.016, 0.016), (0.018, 0.003)):
        ring = []
        for x, z in o:
            xi = xc + (x - xc) * (hx - inset) / hx
            zi = zc + (z - zc) * (hz - inset) / hz
            ring.append((xi, geo.top(xi, zi, 0.8) + lift, zi))
        rings.append(ring)
    obs = [loft(name + "Frame", rings, ["paint", "paint"], cap0=False, cap1=False),
           fan(name + "Floor", rings[-1], "inlet")]
    for i in range(slats):
        z = zc + hz * 0.8 * (1.0 - 2.0 * (i + 0.5) / slats)
        y = geo.top(xc, z, 0.8)
        sec = [(z + 0.014, y + 0.004), (z - 0.004, y + 0.004), (z - 0.018, y + 0.015), (z + 0.0, y + 0.015)]
        obs.append(prism_zy(name + "Slat", sec, xc - hx + 0.018, xc + hx - 0.018, "paint"))
    return obs


def ridge(geo, name, zf, zb, w0, w1, h_front, h_back, open_back=False, open_front=False, n_z=14, n_x=16, power=1.0):
    """A raised shape on the hood from zf (front) to zb (back): its half width w0 -> w1 and its
    height h_front -> h_back (eased), rounded across; an end left open (dark) where asked."""
    rings = []
    for i in range(n_z + 1):
        t = i / n_z
        z = zf + (zb - zf) * t
        w = w0 + (w1 - w0) * t
        h = h_front + (h_back - h_front) * (t ** power if h_back > h_front else 1.0 - (1.0 - t) ** power)
        ring = []
        for j in range(n_x + 1):
            a = math.pi * j / n_x
            x = w * math.cos(a)
            prof = max(0.0, 1.0 - abs(x / w) ** 2.4) ** 0.6
            ring.append((x, geo.top(x, z, 0.8) + 0.002 + h * prof, z))
        ring.append((-w, geo.top(-w, z, 0.8) - 0.006, z))
        ring.append((w, geo.top(w, z, 0.8) - 0.006, z))
        rings.append(ring)
    edge = ["paint"] * (n_x + 3)
    cap_back = "inlet" if open_back else "paint"
    cap_front = "inlet" if open_front else "paint"
    ob = loft_edges(name, rings, edge, "paint")
    # the ends: re-colour the caps (the first ring's cap is the front)
    me = ob.data
    mats = [m.name.split(".")[0] for m in me.materials]
    for need in (cap_front, cap_back):
        if need not in mats:
            me.materials.append(rc.material(need))
            mats.append(need)
    front = Vector(B(0.0, 0.0, zf))
    back = Vector(B(0.0, 0.0, zb))
    for p in me.polygons:
        if len(p.vertices) > 4:
            c = p.center
            near_front = (c - front).y ** 2 < (c - back).y ** 2
            p.material_index = mats.index(cap_front if near_front else cap_back)
    return [ob]


def louvres(geo, name, xc, zc, n=7, pitch=0.05, hx=0.12):
    """Rows of louvres: small wedges rising towards the back, open (dark) behind."""
    obs = []
    for i in range(n):
        zf = zc + pitch * (n - 1) * 0.5 - pitch * i + 0.022
        zb = zf - 0.036
        rings = []
        for k in range(9):
            x = xc - hx + 2.0 * hx * k / 8
            e = min(1.0, (1.0 - abs((x - xc) / hx)) * 6.0)
            sf, sb = geo.top(x, zf, 0.8), geo.top(x, zb, 0.8)
            rings.append([(x, sf - 0.004, zf), (x, sb - 0.004, zb), (x, sb + 0.024 * e + 0.001, zb), (x, sf + 0.002, zf)])
        obs.append(loft_edges(name + "Louvre", rings, ["paint", "inlet", "paint", "paint"], "paint"))
    return obs


def hoods(geo):
    """{shape: object} for the hood shapes."""
    z0, z1 = geo.hood_z0, geo.hood_z1
    L = z0 - z1
    zc = z1 + L * 0.40
    hw = geo.hood_hw(zc)
    out = {}
    v = []
    for s in (1.0, -1.0):
        v += vent(geo, "Vent", s * hw * 0.48, zc, min(0.12, hw * 0.26), min(0.17, L * 0.18))
    out["vents"] = join(v, "HoodVents")
    out["scoop"] = join(ridge(geo, "Scoop", z1 + L * 0.62, z1 + L * 0.10, 0.20, 0.17, 0.075, 0.0, open_front=True, power=0.6),
                        "HoodScoop")
    out["bulge"] = join(ridge(geo, "Bulge", z0 - L * 0.05, z1 + 0.01, min(0.30, hw * 0.55), min(0.36, hw * 0.62), 0.0, 0.065,
                              power=1.4), "HoodBulge")
    lv = []
    for s in (1.0, -1.0):
        lv += louvres(geo, "Louvres", s * hw * 0.66, z1 + L * 0.45, hx=min(0.13, hw * 0.22))
    out["louvres"] = join(lv, "HoodLouvres")
    out["cowl"] = join(ridge(geo, "Cowl", z1 + L * 0.70, z1 + 0.015, 0.22, 0.27, 0.0, 0.085, open_back=True, power=1.3),
                       "HoodCowl")
    return out


HOOD_SHAPES = ["vents", "scoop", "bulge", "louvres", "cowl"]


def kit(geo):
    """Every kit part of one car: [object] named Spoiler2..9, HoodVents, HoodScoop, ..."""
    obs = list(spoilers(geo).values()) + list(hoods(geo).values())
    for o in obs:
        if o is not None:
            o.data.shade_smooth()
            o.data.set_sharp_from_angle(angle=math.radians(40.0))
    return [o for o in obs if o is not None]


# --- underglow -------------------------------------------------------------------------------------

TUBE_R = 0.011           # a neon tube's radius (22 mm tubes)
STEP = 0.08              # the tubes' points every 8 cm


def _tube_under(geo, x, z, floor):
    """A tube's height at (x, z): just under the body there (its floor if nothing is above)."""
    return max(geo.below(x, z, floor) - TUBE_R - 0.006, 0.035)


def underglow_tubes(geo, wheels, tyre_r, tyre_hw):
    """The tubes: [[(x, y, z)]] polylines under the car (visual coordinates). Two under the sills,
    from behind the front wheels to ahead of the rear ones, 7 cm in from the side at the sill; one
    across behind the front bumper (ahead of the front wheels) and one ahead of the rear bumper,
    6-15 cm in from the body's side there, each following the underside."""
    (xf, _, zf), (xr, _, zr) = wheels
    floor = geo.below(0.0, (zf + zr) * 0.5, 0.15)
    tubes = []
    # the sills
    z0, z1 = zr + tyre_r[1] + 0.10, zf - tyre_r[0] - 0.10
    n = max(2, int(round((z1 - z0) / STEP)))
    side = []
    for k in range(n + 1):
        z = z0 + (z1 - z0) * k / n
        y_low = geo.below(0.35, z, floor) + 0.05
        xs = geo.side(y_low, z, xf + tyre_hw[0])
        x = min(xs - 0.07, max(xf, xr) + 0.05)
        side.append((x, _tube_under(geo, x, z, floor), z))
    tubes.append(side)
    tubes.append([(-x, y, z) for x, y, z in side])
    # across: behind the front bumper, ahead of the rear one (inside the nose and tail)
    for zc, end in ((min(zf + tyre_r[0] + 0.14, geo.z_nose - 0.16), geo.z_nose), (max(zr - tyre_r[1] - 0.14, geo.z_tail + 0.16), geo.z_tail)):
        y_low = geo.below(0.0, zc, floor) + 0.05
        hw = geo.side(y_low, zc, 0.6) - 0.15
        hw = min(hw, max(xf, xr) + 0.05)
        m = max(2, int(round(2 * hw / STEP)))
        tubes.append([(-hw + 2 * hw * k / m, _tube_under(geo, -hw + 2 * hw * k / m, zc, floor), zc) for k in range(m + 1)])
    return tubes


def _png_gray(path, img):
    """An 8-bit greyscale PNG of img (rows top to bottom, values 0..1)."""
    h, w = img.shape
    raw = b"".join(b"\x00" + bytes((np.clip(row, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)) for row in img)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def underglow(geo, wheels, tyre_r, tyre_hw, out_prefix, ppm=40, margin=1.3):
    """The underglow's fitting for one car: its tubes (underglow_tubes) and the light they throw on
    the road, baked: each tube a line of small lamps (every 3 cm) lighting the road below
    (irradiance h / (d^2 + h^2)^1.5, d the distance along the road, h the tube's height), the tyres
    standing in the light's way (their shadows in the pool), the sum exposed like a camera sees
    neon ((1 - e^-kE)^2: saturated under the tubes, falling off softly to nothing a metre and a bit
    round the car) and faded out at the picture's border. Two pictures (sRGB greyscale): <out_prefix>_glow_f.png the front's share
    of the light, _glow_r.png the rear's (the side tubes' split along the car), so the game can
    colour the front and the rear apart (a two-tone glow, a rainbow flowing along the car).
    Returns the manifest's "underglow": {tubes, tube_t (each point's place along the car: 0 the
    nose, 1 the tail), rect [x0, z0, x1, z1] (the pictures' footprint; column 0 at x0, row 0 at z0, the
    rear: a Godot decal's texture laid flat, its top towards -z),
    lights [[x, y, z]] (where the game puts its lights)}."""
    tubes = underglow_tubes(geo, wheels, tyre_r, tyre_hw)
    L = geo.z_nose - geo.z_tail
    t_of = lambda z: (geo.z_nose - z) / L
    # the lamps along the tubes
    q = []
    for tube in tubes:
        for (xa, ya, za), (xb, yb, zb) in zip(tube[:-1], tube[1:]):
            seg = math.dist((xa, za), (xb, zb))
            n = max(1, int(math.ceil(seg / 0.03)))
            for k in range(n):
                u = (k + 0.5) / n
                x, y, z = xa + (xb - xa) * u, ya + (yb - ya) * u, za + (zb - za) * u
                q.append((x, max(y, 0.03), z, seg / n, t_of(z)))
    q = np.array(q)
    hw = max(abs(p[0]) for t in tubes for p in t)
    x0, x1 = -hw - margin, hw + margin
    z0, z1 = geo.z_tail - margin * 0.8, geo.z_nose + margin * 0.8
    w, h = int(round((x1 - x0) * ppm)), int(round((z1 - z0) * ppm))
    gx = x0 + (np.arange(w) + 0.5) / ppm
    gz = z0 + (np.arange(h) + 0.5) / ppm               # row 0 at the rear (a decal's top is its -z)
    GX, GZ = np.meshgrid(gx, gz)
    # the tyres: boxes in plan that the light can't cross (both sides)
    boxes = []
    for (wx, _, wz), r, thw in zip(wheels, tyre_r, tyre_hw):
        for sx in (1.0, -1.0):
            boxes.append((sx * wx - thw, sx * wx + thw, wz - r * 0.92, wz + r * 0.92))
    E = np.zeros((2, h, w))
    for x, y, z, dl, t in q:
        dx, dz = GX - x, GZ - z
        d2 = dx * dx + dz * dz
        e = dl * y / (d2 + y * y) ** 1.5
        for bx0, bx1, bz0, bz1 in boxes:
            # does the road point's line to the lamp cross this tyre? (slab test on the segment)
            with np.errstate(divide="ignore", invalid="ignore"):
                tx0, tx1 = (bx0 - x) / dx, (bx1 - x) / dx
                tz0, tz1 = (bz0 - z) / dz, (bz1 - z) / dz
            tmin = np.maximum(np.minimum(tx0, tx1), np.minimum(tz0, tz1))
            tmax = np.minimum(np.maximum(tx0, tx1), np.maximum(tz0, tz1))
            hit = (tmax >= np.maximum(tmin, 0.0)) & (tmin <= 1.0) & ~(np.isnan(tmin) | np.isnan(tmax))
            e = np.where(hit, e * 0.12, e)
        E[0] += e * (1.0 - t)
        E[1] += e * t
    tot = E[0] + E[1]
    # squared: a pool that holds its strength half a metre out and is all but gone (3%) by the
    # picture's border, so no edge of it shows
    img = (1.0 - np.exp(-1.15 * tot)) ** 2
    # faded out over the last 35 cm of the picture
    fx = np.clip(np.minimum(GX - x0, x1 - GX) / 0.35, 0.0, 1.0)
    fz = np.clip(np.minimum(GZ - z0, z1 - GZ) / 0.35, 0.0, 1.0)
    img *= (fx * fx * (3 - 2 * fx)) * (fz * fz * (3 - 2 * fz))
    share = np.where(tot > 0, E[0] / np.maximum(tot, 1e-9), 0.5)
    for part, frac in (("f", share), ("r", 1.0 - share)):
        _png_gray("%s_glow_%s.png" % (out_prefix, part), (img * frac) ** (1.0 / 2.2))
    lights = []
    for tube in tubes:
        mid = tube[len(tube) // 2]
        lights.append([round(mid[0], 3), round(max(mid[1] - 0.01, 0.05), 3), round(mid[2], 3)])
    r3 = lambda v: round(v, 4)
    return {"tubes": [[[r3(c) for c in p] for p in tube] for tube in tubes],
            "tube_t": [[r3(t_of(p[2])) for p in tube] for tube in tubes],
            "rect": [r3(x0), r3(z0), r3(x1), r3(z1)], "lights": lights}
