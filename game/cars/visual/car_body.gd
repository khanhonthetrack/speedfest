class_name CarBody
extends RefCounted
## Lofts the main body shell and the greenhouse (cabin) of a car from its CarShape.
## Output goes into a MeshKit in GROUND space (y = 0 is the road); CarVisual offsets the mesh.
##
## Material keys written: "paint" (vertex color R = 1 on the hood panel, for carbon),
## "glass" (side/rear), "glass_front" (windshield), "trim" (black plastic / underbody / cabin, vertex
## colored).

const SIDE_PTS := 9
const DECK_PTS := 8
const GH_SIDE := 6
const GH_ROOF := 6

const COL_PAINT := Color(0, 0, 0, 1)
const COL_HOOD := Color(1, 0, 0, 1)
const COL_UNDER := Color(0.025, 0.025, 0.028, 1)
const COL_BLACK := Color(0.035, 0.035, 0.04, 1)
const COL_SEAL := Color(0.02, 0.02, 0.022, 1)
const COL_CABIN := Color(0.018, 0.018, 0.02, 1)
const COL_INTERIOR := Color(0.045, 0.045, 0.05, 1)   # dash top, tub floor and door cards


## Station t values along the body (denser at the ends and around the wheel arches).
static func stations(s: CarShape) -> Array[float]:
	var ts: Array[float] = []
	var n := 64
	for k in n + 1:
		var u := float(k) / float(n)
		ts.append(u - 0.55 * sin(TAU * u) / TAU)
	var ra := s.arch_radius()
	for at in s.axle_t:
		var zw := s.z_of(at)
		for side in [-1.0, 1.0]:
			ts.append(s.t_of(zw + side * (ra + 0.002)))
			ts.append(s.t_of(zw + side * (ra - 0.002)))
		for k in range(1, 16):
			var a := PI * float(k) / 16.0
			ts.append(s.t_of(zw + ra * cos(a)))
	for key in ["cowl", "ws_top", "roof_end", "back_end"]:
		ts.append(float(s.gh[key]))
	# crisp cabin tub ends (dash face, rear bulkhead)
	var cab := s.cabin()
	for key in ["t_dash", "t_back"]:
		for d in [-1.0, 1.0]:
			ts.append(float(cab[key]) + d * float(cab["et"]))
	ts.append(float(s.style_k["hood_from"]))
	ts.append(float(s.style_k["hood_to"]))
	ts.sort()
	var out: Array[float] = []
	for t in ts:
		if t < 0.0 or t > 1.0:
			continue
		if out.is_empty() or (t - out[out.size() - 1]) * s.length > 0.0025:
			out.append(t)
	return out


## Half cross-section at t (x >= 0), from the bottom centerline around to the top centerline.
static func section(s: CarShape, t: float) -> PackedVector3Array:
	var z := s.z_of(t)
	var yb := s.bot(t)
	var ay := s.arch_y(t)
	var ya := yb
	var wl := s.side_x(yb, t)
	var xf := wl - 0.04
	if ay > 0.0:
		ya = minf(ay, s.belt(t) - 0.12)
		var g := s.g
		var x_in: float = g["track_front"] * 0.5 - g["wheel_width"] * 0.5 - 0.05
		xf = minf(xf, x_in)
	var pts := PackedVector3Array()
	pts.append(Vector3(0, yb, z))
	pts.append(Vector3(xf, yb, z))
	pts.append(Vector3(xf, ya, z))
	pts.append(Vector3(s.side_x(ya, t) - 0.012, ya, z))
	var r: float = s.style_k["shoulder_r"]
	var yt := s.belt(t) - r
	for k in SIDE_PTS:
		var f := float(k) / float(SIDE_PTS - 1)
		# bias samples toward the bottom (the rocker rounding) and the top
		var ff := f - 0.08 * sin(TAU * f)
		var y := lerpf(ya + 0.012, yt, ff)
		pts.append(Vector3(s.side_x(y, t), y, z))
	var xs := s.side_x(yt, t)
	var cx := xs - r
	for a in [0.3, 0.62, 1.0]:
		var ang: float = a * PI * 0.5
		pts.append(Vector3(cx + r * cos(ang), yt + r * sin(ang), z))
	# deck: two samples right at the cabin tub wall (fixed fractions of the deck half-width, so
	# every station has the same columns), then the usual samples in to the centerline
	var cab := s.cabin()
	var fw: float = cab["fw"]
	var fe: float = cab["fe"]
	var us: Array[float] = [fw + fe, fw - fe]
	for k in range(1, DECK_PTS + 1):
		us.append((fw - fe) * (1.0 - float(k) / float(DECK_PTS)))
	for u in us:
		var x := cx * u
		pts.append(Vector3(x, s.shell_deck_y(x, u, t), z))
	for k in pts.size():
		var q := pts[k]
		pts[k] = Vector3(q.x, q.y, q.z + s.end_bulge(q.x, q.y, t))
	return pts


static func build_shell(s: CarShape, kit: MeshKit) -> void:
	var ts := stations(s)
	var rows: Array = []
	for t in ts:
		rows.append(section(s, t))
	var nc: int = rows[0].size()
	var deck_start := 4 + SIDE_PTS + 3 - 1
	var hood_from: float = s.style_k["hood_from"]
	var hood_to: float = s.style_k["hood_to"]
	# the deck under the glass is cabin interior (dash top, tub, parcel shelf), not body paint
	var c0: float = s.gh["cowl"]
	var c3: float = s.gh["back_end"]
	var inside := func(j: int, c: Vector3) -> bool:
		if j < deck_start:
			return false
		var tt := s.t_of(c.z)
		return tt > c0 + 0.002 and tt < c3 - 0.002 and absf(c.x) < s.gh_base_w(tt) - 0.004
	var mat_fn := func(i: int, j: int, c: Vector3) -> String:
		if j < 3:
			return "trim"
		if s.style_k["intake"] and s.in_intake(c.y, s.t_of(c.z)):
			return "trim"
		if inside.call(j, c):
			return "trim"
		return "paint"
	var color_fn := func(i: int, j: int, c: Vector3) -> Color:
		if j < 3:
			return COL_UNDER
		if s.style_k["intake"] and s.in_intake(c.y, s.t_of(c.z)):
			return COL_BLACK
		if inside.call(j, c):
			return COL_INTERIOR
		var t := s.t_of(c.z)
		if j >= deck_start and t > hood_from and t < hood_to:
			return COL_HOOD
		return COL_PAINT
	kit.mirror_x = true
	kit.grid("paint", rows, 1.0, [1, 2, 3], [], mat_fn, color_fn)
	# end caps (front fascia and tail panel): rings from the outline to the center, on the bulged surface
	for e in [0, rows.size() - 1]:
		var row: PackedVector3Array = rows[e]
		var t_end: float = ts[e]
		var cy := 0.0
		for pnt in row:
			cy += pnt.y
		cy /= float(row.size())
		var z0 := s.z_of(t_end)
		var rings: Array = []
		for k in 5:
			var f := float(k) / 4.0
			var ring := PackedVector3Array()
			for pnt in row:
				var x := pnt.x * (1.0 - f)
				var y := lerpf(pnt.y, cy, f)
				ring.append(Vector3(x, y, z0 + s.end_bulge(x, y, t_end)))
			rings.append(ring)
		kit.color = COL_PAINT
		kit.grid("paint", rings, -1.0 if e == 0 else 1.0, [1, 2, 3])
	kit.color = Color(1, 1, 1, 1)
	kit.mirror_x = false


## Greenhouse cross-section at t: from the base (on the deck) up the side glass, around the roof
## edge, over the roof to the centerline.
static func gh_section(s: CarShape, t: float) -> PackedVector3Array:
	var z := s.z_of(t)
	var bw := s.gh_base_w(t)
	var by := s.gh_base_y(t)
	var h := s.gh_height(t)
	var rw := minf(s.gh_roof_w(t), bw)
	var crown: float = s.gh["roof_crown"]
	var r := 0.05
	var edge_y := maxf(h - crown - r, by)
	var pts := PackedVector3Array()
	for k in GH_SIDE:
		var f := float(k) / float(GH_SIDE - 1)
		var x := lerpf(bw, rw, f) + 0.025 * sin(PI * f) * clampf((edge_y - by) * 4.0, 0.0, 1.0)
		pts.append(Vector3(x, lerpf(by, edge_y, f), z))
	var rr := minf(r, maxf(h - crown - by, 0.0))
	for a in [0.5, 1.0]:
		var ang: float = a * PI * 0.5
		pts.append(Vector3(rw - r + r * cos(ang), edge_y + rr * sin(ang), z))
	for k in range(1, GH_ROOF + 1):
		var u := 1.0 - float(k) / float(GH_ROOF)
		var x := (rw - r) * u
		pts.append(Vector3(x, maxf(h - crown * u * u, by), z))
	return pts


static func build_greenhouse(s: CarShape, kit: MeshKit) -> void:
	var c0: float = s.gh["cowl"]
	var c1: float = s.gh["ws_top"]
	var c2: float = s.gh["roof_end"]
	var c3: float = s.gh["back_end"]
	var ts: Array[float] = []
	for k in 11:
		ts.append(lerpf(c0, c1, pow(float(k) / 10.0, 0.8)))
	for k in range(1, 7):
		ts.append(lerpf(c1, c2, float(k) / 6.0))
	for k in range(1, 15):
		ts.append(lerpf(c2, c3, float(k) / 14.0))
	var bp: float = s.gh["b_pillar"]
	if bp > 0.0:
		ts.append(bp - 0.012)
		ts.append(bp + 0.012)
		ts.sort()
	var rows: Array = []
	for t in ts:
		rows.append(gh_section(s, t))
	var side_end := GH_SIDE - 1   # columns [0, side_end) are side glass cells
	var notch: bool = s.gh["notch"]
	var mat_fn := func(i: int, j: int, c: Vector3) -> String:
		var t := s.t_of(c.z)
		var is_side := j < side_end
		var is_pillar := j >= side_end and j < side_end + 2
		if is_side and j == 0:
			return "trim"
		if t < c1:
			# windshield: its own, clearer glass (the tint is for side and rear windows)
			return "paint" if is_pillar else "glass_front"
		if t <= c2 + 0.004:
			if is_side:
				if bp > 0.0 and absf(t - bp) < 0.012:
					return "trim"
				return "glass"
			return "paint"
		# behind the roof
		if is_side:
			var q := (t - c2) / (c3 - c2)
			if notch:
				return "glass" if q < 0.35 and j < side_end - 1 else "paint"
			return "glass" if q < 0.3 and j < side_end - 1 else "paint"
		if is_pillar:
			return "paint"
		if notch:
			return "glass"
		# fastbacks: glass in the middle, painted buttresses on the sides
		return "glass" if j > side_end + 2 else "paint"
	var color_fn := func(i: int, j: int, c: Vector3) -> Color:
		if j == 0:
			return COL_SEAL
		var t := s.t_of(c.z)
		if bp > 0.0 and absf(t - bp) < 0.012 and j < side_end:
			return COL_BLACK
		return COL_PAINT
	kit.mirror_x = true
	kit.grid("paint", rows, 1.0, [], [], mat_fn, color_fn)
	# interior shell (dark headliner / cabin walls seen through the glass), facing inward
	var inner: Array = []
	for row in rows:
		var r2 := PackedVector3Array()
		for q in (row as PackedVector3Array):
			r2.append(Vector3(maxf(q.x - 0.03, 0.0), q.y - 0.025, q.z))
		inner.append(r2)
	kit.color = COL_CABIN
	kit.grid("trim", inner, -1.0)
	kit.color = Color(1, 1, 1, 1)
	kit.mirror_x = false
