class_name TmStadiumBuild
extends RefCounted
## The Stadium around a 32 x 32 map, rebuilt from our own measurements of TMNF's surround
## (Zone/Square32.Solid.Gbx, read locally with tools/research/tmnf/visual_mesh.py and cut with
## vsection.py; nothing of it is shipped). Coordinates: TMNF axes centred on the field (x right,
## y up from the field's grass, z forward), metres; build() places it on the map. The surround is
## symmetric in x and z, so each table holds one quarter:
## - on each long side (z) a lens-shaped grandstand: a 20 m wall at the field, a ledge, a seating
##   rake up to a 46 m deck (rows of seats, tm_surface pattern 7), the same facing out on the far
##   side, a ribbon of LED boards along the inner face; over its inner half a roof band (a thin
##   visor at the field, a thick main part falling to the masts) arched along x and dipping past
##   the stand's tips; masts on the midline with cables;
## - on each short side (x) a terrace (a 21 m wall, a ledge, a raised block with the big screen),
##   six flagpoles a quarter and a floodlight tower at each end;
## - the field-level apron between the field and the buildings, the ground falling outside to the
##   outer level (-19.5 m) and the edge, 100 m below the field.
## Sections: vsection.py --deg -90 at x = 100 (long side), --deg 0 at z = 100 (short side); plan
## lines: --y 10; the roof: cuts every 100 m in x.

const FIELD_Y := 9.0                ## the field's grass in the map (TmMapBuilder.GROUND_Y)
const CENTRE := Vector3(512.0, FIELD_Y, 512.0)   ## the field's centre in a 32 x 32 map (TMNF)

## Long side (z < 0 shown): the inner wall's line at 10 m, from x = 0 to the stand's tip (x, z).
const LENS_INNER := [Vector2(0.0, -523.0), Vector2(44.7, -524.7), Vector2(86.8, -527.8),
	Vector2(128.7, -532.2), Vector2(170.4, -538.0), Vector2(211.9, -545.2), Vector2(253.0, -553.6),
	Vector2(293.8, -563.4), Vector2(334.1, -574.5), Vector2(374.0, -586.9), Vector2(413.4, -600.6),
	Vector2(452.1, -615.6), Vector2(490.2, -631.7), Vector2(527.7, -649.1), Vector2(564.5, -667.7),
	Vector2(600.5, -686.8), Vector2(644.1, -711.5)]
const LENS_MID_Z := -746.1          ## the grandstand's midline (it is symmetric about it)
## Its section from the wall inwards: [d (m into the stand), y, material of the segment to the next].
## The last point runs on to the midline; the outer half mirrors it (its foot on the outer ground).
const LENS_SECTION := [[0.0, -24.0, "facade"], [0.0, 20.1, "concrete"], [2.8, 21.1, "concrete"],
	[11.1, 21.1, "concrete"], [23.0, 27.6, "stands"], [57.6, 45.9, "concrete"], [1e4, 45.9, "concrete"],
	[1e4, -24.0, "concrete"]]
## The LED boards: d, bottom, top, half length in x. Measured as one face from 25.1 m to the rake's
## top (46.1), it hid the whole seating rake from the field: we keep a ribbon two ads high (8 m,
## its bottom on the ramp, its rows on the ads' 4 m grid: 32-40 m above the map's base) and the
## seats show above it.
const LED := [14.0, 23.0, 31.0, 593.0]
const LED_BOARD := 44.0             ## the LED ribbon's boards, at least this long (m)
const FIN := [[66.0, 45.9], [87.3, 60.8]]  ## the glass screen behind the rake's top (d, y)

## The roof band (z from -528.8 at the field to -785.0), every 100 m in x: [x, top and underside at
## z = -626.1, top and underside at the back edge]; the visor in front rises to the field edge.
const ROOF_Z := [-528.8, -577.3, -626.1, -785.0]
const ROOF := [[0.0, 120.5, 112.1, 87.4, 85.9], [100.0, 118.2, 109.5, 85.4, 83.8],
	[200.0, 113.3, 104.5, 80.2, 78.7], [300.0, 105.2, 96.6, 73.4, 71.8], [400.0, 94.8, 86.4, 64.1, 62.6],
	[500.0, 82.2, 74.4, 53.4, 51.8], [600.0, 69.8, 61.8, 43.5, 42.0], [700.0, 57.9, 49.6, 34.1, 32.5],
	[725.0, 54.9, 46.6, 31.7, 30.1]]
const MASTS := [0.0, 430.0, 876.0]  ## x on the midline (and mirrored); 270 m tall
const MAST_TOP := 270.0

## Short side (x > 0 shown): the inner wall's line at 10 m from z = 0 to the terrace's end (x, z).
const TERRACE_INNER := [Vector2(776.6, 0.0), Vector2(775.1, -35.8), Vector2(771.4, -71.8),
	Vector2(764.7, -113.5), Vector2(761.9, -135.2), Vector2(751.9, -174.4), Vector2(739.7, -213.3),
	Vector2(724.4, -253.5), Vector2(707.0, -294.1), Vector2(687.8, -361.3), Vector2(668.0, -391.8),
	Vector2(642.5, -426.4)]
## Its section from the wall outwards [d, y, material of the segment to the next] (closed).
const TERRACE_SECTION := [[0.0, -15.0, "facade"], [0.0, 20.9, "concrete"], [3.0, 21.7, "concrete"],
	[46.5, 21.7, "concrete"], [46.5, 34.3, "concrete"], [90.3, 34.3, "stands"], [127.8, 24.3, "concrete"],
	[139.9, 20.9, "concrete"], [169.5, 20.9, "concrete"], [172.5, 19.8, "concrete"], [172.5, -15.0, "concrete"]]
const SCREEN := [822.0, 79.0, 47.0, 128.4]   ## the big screen: x, half width in z, bottom, top
const FLAGPOLES := [Vector2(771.0, -110.0), Vector2(773.0, -144.0), Vector2(763.0, -180.0),
	Vector2(751.0, -217.0), Vector2(738.0, -249.0), Vector2(723.0, -282.0)]
const FLAGPOLE_FOOT := 21.7
const FLAGPOLE_TOP := 229.0
const TOWER := Vector2(652.0, -449.0)   ## the floodlight tower's shaft; its lamp head 209-277 m
const TOWER_HEAD := Vector3(632.0, 243.0, -445.0)

const OUTER_Y := -19.5              ## the outer ground's level
const EDGE := Vector2(1728.0, 1248.0)   ## the surround's half extents (x, z)
const BOTTOM := -100.0              ## the edge's foot and the plain beyond


## The whole Stadium as one node, placed on a 32 x 32 map.
static func build() -> Node3D:
	var geo := TmGeo.new()
	_flag_nodes.clear()
	for sz: float in [-1.0, 1.0]:
		_grandstand(geo, sz)
		_roof(geo, sz)
		_masts(geo, sz)
	for sx: float in [-1.0, 1.0]:
		_terrace(geo, sx)
		for sz: float in [-1.0, 1.0]:
			_flags(geo, sx, sz)
			_tower(geo, sx, sz)
		_screen(geo, sx)
	_ground(geo)
	var root := geo.build()
	root.name = "Stadium"
	for f in _flag_nodes:
		root.add_child(f)
	_flag_nodes.clear()
	root.position = TmGeo.g(CENTRE)
	for c in root.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	return root


## A quad whose front faces `out`.
static func _quad(geo: TmGeo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: String, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) >= 0.0:
		geo.quad(a, b, c, d, mat, TmGeo.NO_COLLISION)
	else:
		geo.quad(a, d, c, b, mat, TmGeo.NO_COLLISION)


## A polyline's unit normals in the x-z plane, on the side of `towards` (a point).
static func _normals(path: Array, towards: Vector2) -> Array:
	var out := []
	for i in path.size():
		var t: Vector2 = (path[mini(i + 1, path.size() - 1)] as Vector2) - (path[maxi(i - 1, 0)] as Vector2)
		var n := Vector2(-t.y, t.x).normalized()
		if n.dot(towards - (path[i] as Vector2)) < 0.0:
			n = -n
		out.append(n)
	return out


## A closed section [d, y, mat] swept along a path (x-z points) with normals m (d runs along m);
## dmax[i] clips d at each point. Faces point out of the section's polygon; caps close the ends.
static func _sweep(geo: TmGeo, path: Array, m: Array, section: Array, dmax: Array) -> void:
	var n := section.size()
	var rings := []
	for i in path.size():
		var p: Vector2 = path[i]
		var mi: Vector2 = m[i]
		var ring := []
		for s: Array in section:
			var d := minf(float(s[0]), float(dmax[i]))
			ring.append(Vector3(p.x + mi.x * d, float(s[1]), p.y + mi.y * d))
		rings.append(ring)
	# outward normal of an edge (dd, dy) in the (d, y) plane: (dy, -dd) on a counter-clockwise loop
	var area := 0.0
	for k in n:
		var a: Array = section[k]
		var b: Array = section[(k + 1) % n]
		area += minf(float(a[0]), 500.0) * float(b[1]) - minf(float(b[0]), 500.0) * float(a[1])
	var flip := 1.0 if area > 0.0 else -1.0
	for i in path.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var mi: Vector2 = m[i]
		for k in n:
			var k1 := (k + 1) % n
			var e: Vector3 = (r0[k1] as Vector3) - (r0[k] as Vector3)
			var ed := e.x * mi.x + e.z * mi.y
			var out := Vector3(mi.x, 0.0, mi.y) * (e.y * flip) + Vector3.UP * (-ed * flip)
			_quad(geo, r0[k], r1[k], r1[k1], r0[k1], String(section[k][2]), out)
	for end: int in [0, path.size() - 1]:
		var ring: Array = rings[end]
		var poly := PackedVector2Array()
		var mi: Vector2 = m[end]
		for k in n:
			var q: Vector3 = ring[k]
			poly.append(Vector2((q.x - ring[0].x) * mi.x + (q.z - ring[0].z) * mi.y, q.y))
		var idx := Geometry2D.triangulate_polygon(poly)
		var j := mini(end + 1, path.size() - 1) if end == 0 else end - 1
		var along := Vector3((path[end] as Vector2).x - (path[j] as Vector2).x, 0.0, (path[end] as Vector2).y - (path[j] as Vector2).y)
		for t in range(0, idx.size(), 3):
			var a: Vector3 = ring[idx[t]]
			var b: Vector3 = ring[idx[t + 1]]
			var c: Vector3 = ring[idx[t + 2]]
			if (b - a).cross(c - a).dot(along) < 0.0:
				geo.tri(a, c, b, "concrete", TmGeo.NO_COLLISION)
			else:
				geo.tri(a, b, c, "concrete", TmGeo.NO_COLLISION)


## The long side's inner wall line across the whole stand (x from tip to tip), z mirrored by sz.
static func _lens_path(sz: float) -> Array:
	var path := []
	for i in range(LENS_INNER.size() - 1, 0, -1):
		path.append(Vector2(-(LENS_INNER[i] as Vector2).x, -sz * (LENS_INNER[i] as Vector2).y))
	for p: Vector2 in LENS_INNER:
		path.append(Vector2(p.x, -sz * p.y))
	return path


static func _grandstand(geo: TmGeo, sz: float) -> void:
	var mid := -sz * LENS_MID_Z
	for half: int in [0, 1]:   # the inner half, then the outer one (the inner line mirrored)
		var path := _lens_path(sz)
		if half == 1:
			path = path.map(func(p: Vector2) -> Vector2: return Vector2(p.x, 2.0 * mid - p.y))
		var m := _normals(path, Vector2(0.0, mid))
		var dmax := []
		for i in path.size():
			dmax.append(absf((mid - (path[i] as Vector2).y) / (m[i] as Vector2).y))
		_sweep(geo, path, m, LENS_SECTION, dmax)
		# the glass screen behind the rake's top, and (inner half) the LED boards
		var led := []
		for i in path.size() - 1:
			var p0: Vector2 = path[i]
			var p1: Vector2 = path[i + 1]
			var m0: Vector2 = m[i]
			var m1: Vector2 = m[i + 1]
			if minf(float(dmax[i]), float(dmax[i + 1])) > float(FIN[1][0]):
				var a := Vector3(p0.x + m0.x * FIN[0][0], FIN[0][1], p0.y + m0.y * FIN[0][0])
				var b := Vector3(p1.x + m1.x * FIN[0][0], FIN[0][1], p1.y + m1.y * FIN[0][0])
				var c := Vector3(p1.x + m1.x * FIN[1][0], FIN[1][1], p1.y + m1.y * FIN[1][0])
				var d := Vector3(p0.x + m0.x * FIN[1][0], FIN[1][1], p0.y + m0.y * FIN[1][0])
				_quad(geo, a, b, c, d, "glass", Vector3(-m0.x, 1.0, -m0.y))
			if half == 0 and absf(p0.x) < LED[3] and absf(p1.x) < LED[3]:
				var e := Vector3(p0.x + m0.x * LED[0], LED[1], p0.y + m0.y * LED[0])
				var f := Vector3(p1.x + m1.x * LED[0], LED[1], p1.y + m1.y * LED[0])
				led.append([e, f, Vector3(-m0.x, 0.0, -m0.y)])
				_quad(geo, e, f, f + Vector3(0, LED[2] - LED[1], 0), e + Vector3(0, LED[2] - LED[1], 0), "structure", Vector3(m0.x, 0.0, m0.y))
		_led_boards(geo, led)


## The LED ribbon along a stand (its segments [bottom start, bottom end, facing]) as boards of about
## LED_BOARD metres, each showing the ad centred (TmGeo.SCREENS).
static func _led_boards(geo: TmGeo, segs: Array) -> void:
	var h: float = LED[2] - LED[1]
	var up := Vector3(0, h, 0)
	var k := 0
	var board := 0
	while k < segs.size():
		var k1 := k
		var w := 0.0
		while k1 < segs.size() and (w < LED_BOARD or segs.size() - k1 < 2):
			w += ((segs[k1][1] as Vector3) - (segs[k1][0] as Vector3)).length()
			k1 += 1
		var along := 0.0
		for j in range(k, k1):
			var e: Vector3 = segs[j][0]
			var f: Vector3 = segs[j][1]
			var a0 := along
			along += (f - e).length()
			var ue := [TmGeo.screen_uv(a0, w, h, h, board), TmGeo.screen_uv(a0, w, 0.0, h, board)]
			var uf := [TmGeo.screen_uv(along, w, h, h, board), TmGeo.screen_uv(along, w, 0.0, h, board)]
			if (f - e).cross(f + up - e).dot(segs[j][2]) >= 0.0:
				geo.quad_uv(e, f, f + up, e + up, "led", TmGeo.NO_COLLISION, ue[0], uf[0], uf[1], ue[1])
			else:
				geo.quad_uv(f, e, e + up, f + up, "led", TmGeo.NO_COLLISION, uf[0], ue[0], ue[1], uf[1])
		k = k1
		board += 1


## The roof's section at x: [z, y] around the band (top from the field edge back, underside back).
static func _roof_section(x: float) -> Array:
	var ax := absf(x)
	var k := 0
	while k < ROOF.size() - 2 and ax > float(ROOF[k + 1][0]):
		k += 1
	var r0: Array = ROOF[k]
	var r1: Array = ROOF[k + 1]
	var t := clampf((ax - float(r0[0])) / (float(r1[0]) - float(r0[0])), 0.0, 1.0)
	var v := []
	for j in range(1, 5):
		v.append(lerpf(float(r0[j]), float(r1[j]), t))
	var visor := float(v[0]) + 12.3 - 0.0056 * ax
	var crease := float(v[0]) + 5.8 - 0.0016 * ax
	return [Vector2(ROOF_Z[0], visor), Vector2(ROOF_Z[1], crease), Vector2(ROOF_Z[2], v[0]),
		Vector2(ROOF_Z[3], v[2]), Vector2(ROOF_Z[3], v[3]), Vector2(ROOF_Z[2], v[1]),
		Vector2(ROOF_Z[1], crease - 0.6), Vector2(ROOF_Z[0], visor - 0.6)]


static func _roof(geo: TmGeo, sz: float) -> void:
	var xs := []
	var x_end := float(ROOF[ROOF.size() - 1][0])
	var steps := 58
	for i in steps + 1:
		xs.append(lerpf(-x_end, x_end, float(i) / steps))
	# the section loop's orientation in the (z, y) plane: outward of an edge (dz, dy) is (dy, -dz)
	# on a counter-clockwise loop
	var s0 := _roof_section(0.0).map(func(q: Vector2) -> Vector2: return Vector2(-sz * q.x, q.y))
	var area := 0.0
	for k in s0.size():
		var a: Vector2 = s0[k]
		var b: Vector2 = s0[(k + 1) % s0.size()]
		area += a.x * b.y - b.x * a.y
	var flip := 1.0 if area > 0.0 else -1.0
	var prev := []
	for i in xs.size():
		var x: float = xs[i]
		var sec := _roof_section(x).map(func(q: Vector2) -> Vector3: return Vector3(x, q.y, -sz * q.x))
		if not prev.is_empty():
			var n := sec.size()
			for k in n:
				var k1 := (k + 1) % n
				var e: Vector3 = (sec[k1] as Vector3) - (sec[k] as Vector3)
				var mat := "roof_under" if k >= 4 and k <= 6 else "roof"   # the underside: louvres
				_quad(geo, prev[k], sec[k], sec[k1], prev[k1], mat, Vector3(0.0, -e.z, e.y) * flip)
		prev = sec
	# the tube along the visor's front edge and the beams under the roof every 45 m
	for i in xs.size() - 1:
		var a: Vector2 = _roof_section(xs[i])[0]
		var b: Vector2 = _roof_section(xs[i + 1])[0]
		geo.pipe(Vector3(xs[i], a.y - 0.8, -sz * a.x), Vector3(xs[i + 1], b.y - 0.8, -sz * b.x), 2.2, 8, "mast", TmGeo.NO_COLLISION)
	# lamp strips under the visor's front and along the main roof's front edge (measured glows)
	for i in xs.size() - 1:
		if absf(xs[i]) > 640.0:
			continue
		for row: int in [7, 5]:
			var a: Vector2 = _roof_section(xs[i])[row]
			var b: Vector2 = _roof_section(xs[i + 1])[row]
			var za := -sz * (a.x + (3.0 if row == 7 else -1.5))
			var zb := -sz * (b.x + (3.0 if row == 7 else -1.5))
			var p0 := Vector3(xs[i] + 1.0, a.y - 0.4, za)
			var p1 := Vector3(xs[i + 1] - 1.0, b.y - 0.4, zb)
			_quad(geo, p0 - Vector3(0, 0, 0.6), p1 - Vector3(0, 0, 0.6), p1 + Vector3(0, 0, 0.6), p0 + Vector3(0, 0, 0.6), "lamp", Vector3.DOWN)
	var bx := -floorf(x_end / 45.0) * 45.0
	while bx <= x_end:
		var sec := _roof_section(bx)
		var under := [sec[7], sec[6], sec[5], sec[4]]
		for k in 3:
			var p: Vector2 = under[k]
			var q: Vector2 = under[k + 1]
			geo.pipe(Vector3(bx, p.y - 1.5, -sz * p.x), Vector3(bx, q.y - 1.5, -sz * q.x), 1.3, 4, "structure", TmGeo.NO_COLLISION, PI / 4.0)
		bx += 45.0
	for x: float in [-x_end, x_end]:
		var sec := _roof_section(x).map(func(q: Vector2) -> Vector3: return Vector3(x, q.y, -sz * q.x))
		for k in range(1, sec.size() - 1):
			var a: Vector3 = sec[0]
			var b: Vector3 = sec[k]
			var c: Vector3 = sec[k + 1]
			if (b - a).cross(c - a).x * signf(x) < 0.0:
				geo.tri(a, c, b, "roof", TmGeo.NO_COLLISION)
			else:
				geo.tri(a, b, c, "roof", TmGeo.NO_COLLISION)


static func _masts(geo: TmGeo, sz: float) -> void:
	var mid := -sz * LENS_MID_Z
	var x_end := float(ROOF[ROOF.size() - 1][0])
	for mx0: float in MASTS:
		for s: float in ([1.0] if mx0 == 0.0 else [-1.0, 1.0]):
			var mx := mx0 * s
			geo.pipe(Vector3(mx, OUTER_Y, mid), Vector3(mx, 180.0, mid), 4.0, 12, "mast", TmGeo.NO_COLLISION)
			geo.pipe(Vector3(mx, 180.0, mid), Vector3(mx, MAST_TOP, mid), 2.6, 12, "mast", TmGeo.NO_COLLISION)
			var top := Vector3(mx, MAST_TOP - 6.0, mid)
			for dx: float in [-45.0, 45.0]:
				var tx := clampf(mx + dx, -x_end, x_end)
				var vis: Vector2 = _roof_section(tx)[0]
				geo.pipe(top, Vector3(tx, vis.y - 0.3, -sz * vis.x), 0.35, 4, "cable", TmGeo.NO_COLLISION)
				geo.pipe(top, Vector3(mx + dx * 0.7, OUTER_Y, mid - sz * 255.0), 0.35, 4, "cable", TmGeo.NO_COLLISION)


## The short side's inner wall line across the whole terrace (z from +end to -end), x mirrored by sx.
static func _terrace_path(sx: float) -> Array:
	var path := []
	for i in range(TERRACE_INNER.size() - 1, 0, -1):
		var p: Vector2 = TERRACE_INNER[i]
		path.append(Vector2(sx * p.x, -p.y))
	for p: Vector2 in TERRACE_INNER:
		path.append(Vector2(sx * p.x, p.y))
	return path


static func _terrace(geo: TmGeo, sx: float) -> void:
	var path := _terrace_path(sx)
	var m := _normals(path, Vector2(sx * 5000.0, 0.0))
	var dmax := []
	for i in path.size():
		dmax.append(1e4)
	_sweep(geo, path, m, TERRACE_SECTION, dmax)


static func _screen(geo: TmGeo, sx: float) -> void:
	var x: float = sx * SCREEN[0]
	var w: float = SCREEN[1]
	var lo: float = SCREEN[2]
	var hi: float = SCREEN[3]
	_box(geo, Vector3(x + sx * 2.0, (lo + hi) * 0.5, 0.0), Vector3(2.0, (hi - lo) * 0.5 + 1.5, w + 1.5), "structure")
	var f := x - sx * 0.05   # the picture, just in front of the box's face
	geo.screen_rect(Vector3(f, lo, -w), Vector3(f, lo, w), Vector3(f, hi, w), Vector3(f, hi, -w), "screen_on",
		TmGeo.NO_COLLISION, 0 if sx > 0.0 else 1, Vector3(-sx, 0.0, 0.0))
	for z: float in [-w * 0.6, w * 0.6]:
		geo.pipe(Vector3(x + sx * 2.0, 34.3, z), Vector3(x + sx * 2.0, SCREEN[2], z), 1.5, 8, "structure", TmGeo.NO_COLLISION)


## A box with half extents h along x, y, z around c.
static func _box(geo: TmGeo, c: Vector3, h: Vector3, mat: String) -> void:
	_oriented_box(geo, c, Vector3(h.x, 0, 0), Vector3(0, h.y, 0), Vector3(0, 0, h.z), mat, mat)


## A box from its centre and three half-axis vectors; `front_mat` on the face along -az.
static func _oriented_box(geo: TmGeo, c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, mat: String, front_mat: String) -> void:
	for f in [[ax, ay, az], [-ax, ay, az], [ay, az, ax], [-ay, az, ax], [az, ax, ay], [-az, ax, ay]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + n
		var key := front_mat if n.is_equal_approx(-az) else mat
		_quad(geo, o - u - v, o + u - v, o + u + v, o - u + v, key, n)


static func _tower(geo: TmGeo, sx: float, sz: float) -> void:
	var base := Vector3(sx * TOWER.x, OUTER_Y + 4.0, sz * absf(TOWER.y))
	geo.pipe(base, Vector3(base.x, 230.0, base.z), 3.5, 10, "mast", TmGeo.NO_COLLISION)
	var hc := Vector3(sx * TOWER_HEAD.x, TOWER_HEAD.y, sz * absf(TOWER_HEAD.z))
	var to_field := Vector3(-hc.x, 25.0 - hc.y, -hc.z).normalized()   # the head looks at the field
	var right := Vector3.UP.cross(to_field).normalized()
	var up := to_field.cross(right).normalized()
	_oriented_box(geo, hc, right * 24.0, up * 30.0, -to_field * 2.5, "structure", "lamp")
	geo.pipe(Vector3(base.x, 228.0, base.z), hc - to_field * 2.0, 1.2, 6, "mast", TmGeo.NO_COLLISION)


## The flags' atlas (stadium/tools/texgen/flags.py: FLAGS, 8 x 3 cells of 384 x 256 px with a 6 px
## gutter) and which flag flies where: Poland on the pole nearest the field's middle in each
## corner, twenty other countries on the rest.
const FLAG_ATLAS := ["poland", "germany", "france", "italy", "united_kingdom", "usa", "japan", "sweden",
	"finland", "norway", "denmark", "netherlands", "belgium", "austria", "czechia", "ukraine",
	"hungary", "spain", "ireland", "switzerland", "greece", "estonia", "lithuania", "latvia"]
const FLAG_CELL := Vector2(384.0, 256.0)
const FLAG_PAD := 6.0
const FLAG_SIZE := Vector2(26.0, 17.0)    ## flown from 4 m under the pole's top

static var _flag_nodes: Array[Node3D] = []
static var _flag_mat: ShaderMaterial


## Six flagpoles a quarter, each flying a country's flag (its own mesh, waving: env/tm_flag.gdshader).
static func _flags(geo: TmGeo, sx: float, sz: float) -> void:
	var quarter := (1 if sx > 0 else 0) + (2 if sz > 0 else 0)
	for i in FLAGPOLES.size():
		var p: Vector2 = FLAGPOLES[i]
		var foot := Vector3(sx * p.x, FLAGPOLE_FOOT, -sz * p.y)
		var top := Vector3(foot.x, FLAGPOLE_TOP, foot.z)
		geo.pipe(foot, top, 1.0, 6, "mast", TmGeo.NO_COLLISION)
		var out := Vector3(foot.x, 0.0, foot.z).normalized()
		var centre := top + Vector3(0.0, -4.0 - FLAG_SIZE.y * 0.5, 0.0) + out * FLAG_SIZE.x * 0.5
		var flag := 0 if i == 0 else 1 + (quarter * (FLAGPOLES.size() - 1) + i - 1) % (FLAG_ATLAS.size() - 1)
		_flag_nodes.append(_flag(TmGeo.g(centre), TmGeo.g(out), flag, float(quarter * 7 + i) * 1.7))


## One flag: a 26 x 17 m plane centred at `at` (Godot), its length along `along` from the pole.
static func _flag(at: Vector3, along: Vector3, index: int, wave_phase: float) -> MeshInstance3D:
	if _flag_mat == null:
		_flag_mat = ShaderMaterial.new()
		_flag_mat.shader = preload("res://env/tm_flag.gdshader")
		_flag_mat.set_shader_parameter("atlas", TmMaterials._tex("flags", "albedo"))
		_flag_mat.set_shader_parameter("length_m", FLAG_SIZE.x)
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = FLAG_SIZE
	pm.subdivide_width = 24
	pm.subdivide_depth = 12
	var mi := MeshInstance3D.new()
	mi.name = "Flag_" + String(FLAG_ATLAS[index])
	mi.mesh = pm
	mi.material_override = _flag_mat
	var x := along.normalized()
	mi.transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), at)
	var atlas := Vector2(8.0 * (FLAG_CELL.x + 2.0 * FLAG_PAD), 3.0 * (FLAG_CELL.y + 2.0 * FLAG_PAD))
	var cell := Vector2(index % 8, index / 8) * (FLAG_CELL + Vector2.ONE * 2.0 * FLAG_PAD) + Vector2.ONE * (FLAG_PAD + 0.5)
	mi.set_instance_shader_parameter(&"cell", Vector4(cell.x / atlas.x, cell.y / atlas.y,
		(FLAG_CELL.x - 1.0) / atlas.x, (FLAG_CELL.y - 1.0) / atlas.y))
	mi.set_instance_shader_parameter(&"phase", wave_phase)
	return mi


## The bowl's edge: the buildings' inner walls joined across the corners (x, z loop: the z < 0
## stand left to right, the x > 0 terrace, the z > 0 stand right to left, the x < 0 terrace).
static func _bowl() -> PackedVector2Array:
	var parts := [_lens_path(-1.0), _terrace_path(1.0), _lens_path(1.0), _terrace_path(-1.0)]
	(parts[1] as Array).reverse()
	(parts[2] as Array).reverse()
	var loop := PackedVector2Array()
	for part: Array in parts:
		for p: Vector2 in part:
			loop.append(p)
	return loop


## The ground: our coarse grid measured from TMNF's surround (blocks/data/stadium_ground.json, one
## quarter mirrored: heights on 16 m cell corners, a class per cell: forecourt, road, grass,
## parking); where it has none (under the buildings) the apron at the field's level inside the
## bowl, falling outside it; then the edge and the plain far below (the map covers the field).
const GROUND_CLASSES := {"p": "parvis", "r": "road_dark", "g": "grass", "k": "parking"}

static var _ground_data := {}


static func _ground_grid() -> Dictionary:
	if _ground_data.is_empty():
		_ground_data = JSON.parse_string(FileAccess.get_file_as_string("res://blocks/data/stadium_ground.json"))
	return _ground_data


static func _ground(geo: TmGeo) -> void:
	var data := _ground_grid()
	var cell := float(data["cell"])
	var nx := int(data["nx"])
	var nz := int(data["nz"])
	var heights: Array = data["heights_dm"]
	var classes: Array = data["classes"]
	var bowl := _bowl()
	var half := int(512.0 / cell)
	var hd := TmMaterials.hd()
	var cc := float(data["class_cell"])
	var cnx := int(data["cnx"])
	var cnz := int(data["cnz"])
	var per := int(cell / cc)
	var h := {}
	for i in range(-nx, nx + 1):
		for j in range(-nz, nz + 1):
			var v := int((heights[absi(j)] as Array)[absi(i)])
			var p := Vector2(i * cell, j * cell)
			var y := 0.0
			if Geometry2D.is_point_in_polygon(p, bowl):
				y = 0.0
			elif v != -9999:
				y = v * 0.1
			else:
				var dmin := 1e9
				for k in bowl.size():
					var q := Geometry2D.get_closest_point_to_segment(p, bowl[k], bowl[(k + 1) % bowl.size()])
					dmin = minf(dmin, p.distance_to(q))
				y = OUTER_Y * smoothstep(0.0, 250.0, dmin)
			h[Vector2i(i, j)] = y
	for i in range(-nx, nx):
		for j in range(-nz, nz):
			if i >= -half and i < half and j >= -half and j < half:
				continue   # the field: the map's own ground
			var ci := (i if i >= 0 else -i - 1) * per
			var cj := (j if j >= 0 else -j - 1) * per
			var cls := String(classes[cj]).substr(ci, 1)
			var y00: float = h[Vector2i(i, j)]
			var y10: float = h[Vector2i(i + 1, j)]
			var y11: float = h[Vector2i(i + 1, j + 1)]
			var y01: float = h[Vector2i(i, j + 1)]
			var low := minf(minf(y00, y10), minf(y11, y01)) <= -0.5
			if not GROUND_CLASSES.has(cls):
				cls = "p" if low else "g"
			var mat: String = "stadium_ground" if hd else GROUND_CLASSES[cls]
			var a := Vector3(i * cell, y00, j * cell)
			var b := Vector3((i + 1) * cell, y10, j * cell)
			var c := Vector3((i + 1) * cell, y11, (j + 1) * cell)
			var d := Vector3(i * cell, y01, (j + 1) * cell)
			_quad(geo, a, b, c, d, mat, Vector3.UP)
	if hd:
		# the class map: one texel per class cell, the quarter mirrored; none: grass in the bowl,
		# forecourt under the buildings
		var cmap := Image.create(cnx * 2, cnz * 2, false, Image.FORMAT_RGBA8)
		var weights := {"g": Color(1, 0, 0, 0), "r": Color(0, 1, 0, 0), "k": Color(0, 0, 1, 0), "p": Color(0, 0, 0, 1)}
		for cj in cnz:
			var row := String(classes[cj])
			for ci in cnx:
				var cls := row.substr(ci, 1)
				if not weights.has(cls):
					var centre := Vector2((ci + 0.5) * cc, -(cj + 0.5) * cc)
					cls = "g" if Geometry2D.is_point_in_polygon(centre, bowl) else "p"
				var col: Color = weights[cls]
				cmap.set_pixel(cnx + ci, cnz - 1 - cj, col)
				cmap.set_pixel(cnx - 1 - ci, cnz - 1 - cj, col)
				cmap.set_pixel(cnx + ci, cnz + cj, col)
				cmap.set_pixel(cnx - 1 - ci, cnz + cj, col)
		var gm := ShaderMaterial.new()
		gm.shader = preload("res://env/tm_ground.gdshader")
		gm.set_shader_parameter("class_map", ImageTexture.create_from_image(cmap))
		gm.set_shader_parameter("extent", Vector2(nx * cell, nz * cell))
		var noise := TmMaterials.noise_textures()
		gm.set_shader_parameter("noise_fine", noise[0])
		gm.set_shader_parameter("noise_coarse", noise[1])
		for key: String in ["grass", "road_dark", "parking", "parvis"]:
			var c: Color = TmMaterials.COLORS[key][0]
			gm.set_shader_parameter({"grass": "grass_col", "road_dark": "road_col", "parking": "parking_col", "parvis": "parvis_col"}[key], c)
		TmMaterials.register("stadium_ground", gm)
	# the edge: walls down to the bottom, and the plain beyond
	var ex := nx * cell
	var ez := nz * cell   # the measured grid's extent (EDGE)
	var corners := [Vector2(-ex, -ez), Vector2(ex, -ez), Vector2(ex, ez), Vector2(-ex, ez)]
	for k in 4:
		var p0: Vector2 = corners[k]
		var p1: Vector2 = corners[(k + 1) % 4]
		var out := Vector3(p0.x + p1.x, 0.0, p0.y + p1.y).normalized()
		_quad(geo, Vector3(p0.x, OUTER_Y, p0.y), Vector3(p1.x, OUTER_Y, p1.y), Vector3(p1.x, BOTTOM, p1.y), Vector3(p0.x, BOTTOM, p0.y), "concrete", out)
	var far := 12000.0
	geo.flat_polygon(PackedVector2Array([Vector2(-far, -far), Vector2(far, -far), Vector2(far, far), Vector2(-far, far)]), BOTTOM, "plain", TmGeo.NO_COLLISION)
