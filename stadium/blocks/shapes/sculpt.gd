extends RefCounted
## Stadium "Sculpt" blocks: the hand-sculpted landmarks (the A/B/C sculptures, the bridges and
## arch rings). Our own geometry from measured numbers (TMNF block-local metres: x right, y up,
## z forward; see TmGeo).
##
## Sculpted parts are lofts: blocks/data/sculpt_lofts.json holds, per shape, tubes of horizontal
## rings (every 2 m up the piece, each resampled to a fixed number of points; written by
## tools/research/tmnf/loft_sections.py from the measured mesh) that end in an apex or a flat top.
## A tube is built ring to ring, closed underneath; the rest of a piece (curbs, decks) is ordinary
## swept geometry.

const S_METAL := 4
const S_ROAD := 16
const PATH := "res://blocks/data/sculpt_lofts.json"

## Sculpt/A, B, C stand on the same plinth: a low double curb along x (x0..x1) round each groove
## at z A_CURB_Z, rubber pads at the curbs' ends; the curb's section (z offset from the groove's
## middle, y), measured. The lofts: tools/research/tmnf/sculpt_lofts.sh.
const A_CURB_X := [4.47, 27.52]
const A_CURB_Z := [8.472, 23.472]
## As TMNF's, the curbs are its border atlas (key, rows from the segment's start to its end).
const A_CURB := [[-1.729, 1.0, "border_black", Vector2(287.0, 221.2)], [-1.604, 1.5, "border_black", Vector2(221.2, 214.6)],
	[-1.554, 1.55, "border_ribs", Vector2(150.4, 181.2)], [-0.813, 1.55, "border_ribs", Vector2(181.2, 192.2)],
	[-0.763, 1.5, "border_ribs", Vector2(192.2, 214.8)], [-0.763, 1.05, "border_ribs", Vector2(159.3, 192.3)],
	[0.763, 1.05, "border_ribs", Vector2(214.8, 192.2)], [0.763, 1.5, "border_ribs", Vector2(192.2, 181.2)],
	[0.813, 1.55, "border_ribs", Vector2(181.2, 150.4)], [1.554, 1.55, "border_black", Vector2(214.6, 221.2)],
	[1.604, 1.5, "border_black", Vector2(221.2, 287.0)], [1.729, 1.0, "", Vector2(-1, -1)]]

const SMOOTH_DEG := 30.0      ## faces turning less than this from their neighbours shade smooth

static var _lofts: Dictionary = {}


static func lofts() -> Dictionary:
	if _lofts.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_lofts = (parsed as Dictionary).get("shapes", {})
	return _lofts


## Mirrored pieces: the same lofts with x mirrored (across the block's middle, x -> 32 - x, unless
## MIRROR_X names another plane), measured.
const MIRRORED := {"Sculpt/Bridge/BridgeSuspendSlope2Mirror": "Sculpt/Bridge/BridgeSuspendSlope2",
	"Sculpt/Bridge/BridgeSuspendSlopeEndMirror": "Sculpt/Bridge/BridgeSuspendSlopeEnd",
	"Sculpt/Bridge/BridgeSlopeStartAirMirror": "Sculpt/Bridge/BridgeSlopeStartAir",
	"Sculpt/Bridge/BridgeSlopeEndAirMirror": "Sculpt/Bridge/BridgeSlopeEndAir",
	"Sculpt/Bridge/BridgeSlopeStartGroundMirror": "Sculpt/Bridge/BridgeSlopeStartGround",
	"Sculpt/Bridge/BridgePillarAirMirror": "Sculpt/Bridge/BridgePillarAir",
	"Sculpt/Bridge/BridgePillarGroundMirror": "Sculpt/Bridge/BridgePillarGround",
	"Sculpt/ArchRing/StartGroundMirror": "Sculpt/ArchRing/StartGround",
	"Sculpt/ArchRing/EndGroundMirror": "Sculpt/ArchRing/EndGround"}
## The plane the x-mirror reflects across, if not the block's middle (x = 16): measured.
const MIRROR_X := {"Sculpt/ArchRing/StartGroundMirror": 64.0, "Sculpt/ArchRing/EndGroundMirror": 64.0}
## A piece's extra parts in the lofts (key suffix -> visual material).
const PARTS := {"#struts": "structure", "#rail": "metal"}
## Lofted pieces that are not white sculpture (shape -> visual material).
const MATERIAL := {"Other/Airship": "airship"}


func handles(shape: String) -> bool:
	return lofts().has(shape) or MIRRORED.has(shape)


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	var src: String = MIRRORED.get(shape, shape)
	# mirrored pieces: x -> msum - x
	var msum := 2.0 * float(MIRROR_X.get(shape, 16.0)) if MIRRORED.has(shape) else 0.0
	if src == "Other/Airship":
		_airship(geo)
	else:
		for tube: Dictionary in lofts()[src]:
			_tube(geo, tube, String(MATERIAL.get(src, "sculpt")), S_METAL, msum)
	for part: String in PARTS:
		for tube: Dictionary in lofts().get(src + part, []):
			_tube(geo, tube, PARTS[part], S_METAL, msum)
	match shape:
		"Sculpt/A/Ground", "Sculpt/B/Ground", "Sculpt/C/Ground":
			# the three sculptures share their plinth (measured: the same pads and curbs; the pads
			# light as TMNF's, its border atlas' panel)
			for tube: Dictionary in lofts().get("Sculpt/A/Ground#pads", []):
				_tube(geo, tube, "plinth_pad", 9)
			for zc: float in A_CURB_Z:
				var sec := A_CURB.map(func(q: Array) -> Array:
					if String(q[2]).is_empty():
						return [Vector2(zc + float(q[0]), float(q[1])), "", TmGeo.NO_COLLISION]
					return [Vector2(zc + float(q[0]), float(q[1])), q[2], S_ROAD, q[3]])
				geo.wall_sweep(sec, [Vector3(A_CURB_X[0], 0, 0), Vector3(A_CURB_X[1], 0, 0)], [Vector3(0, 0, 1), Vector3(0, 0, 1)],
					true, "structure", S_METAL)
	return geo.build()


## The airship (TMNF's layout, our livery: texgen/stadium.py airship_skin): the envelope lofted
## (AIRSHIP_PARTS: the lofts' index; UV-mapped, u along it from the nose, v round it from the top,
## ring point i of n; its tail rounded by one more ring, AIRSHIP_TIP), the rest ours from TMNF's measured outlines (its lofts lost them):
## - the tail's fins (AIRSHIP_FINS: [outline, plane, thickness, key]; the top and bottom ones
##   (z, y) at x = 16.04, the side ones (z, x) at y = 37, mirrored; one entry per colour), TMNF's
##   colours (red; the bottom fin white, yellow along its leading edge and its foot);
## - the gondola's hull (AIRSHIP_HULL: its half section at full width, from the top centre down;
##   scaled per AIRSHIP_STATIONS: z, half width, bottom y), three windows along its front
##   (AIRSHIP_WINDOWS: their segment of the section, their z spans), a red stripe high along it
##   (AIRSHIP_STRIPE: its segment, z span), the dark frame up to the envelope
##   (AIRSHIP_FRAME: half width, y0, y1, the ridge's y, z extent);
## - the engine pods (AIRSHIP_PODS: centre (x, y), radius, z extent; mirrored) with their fans
##   and stub wings to the hull (AIRSHIP_STUB: (x, y) at the hull and at the pod, half thickness,
##   z extent);
## - the keel girders fore and aft (AIRSHIP_KEELS: x0, x1, top and bottom lines (z, y)), the
##   mooring arms (AIRSHIP_ARM: outline (x, y), the z spans; mirrored) and their cables
##   (AIRSHIP_CABLES: x; down to the ground at the arms' middle), dark cut-out truss cards.
const AIRSHIP_PARTS := {"envelope": 0}
const AIRSHIP_C := 16.04
const AIRSHIP_AXIS_Y := 37.0
const AIRSHIP_TIP := Vector2(183.54, 0.66)
const AIRSHIP_FINS := [
	[[Vector2(145.04, 47.4), Vector2(153.48, 55.02), Vector2(165.32, 55.02), Vector2(163.58, 43.9), Vector2(151.1, 46.2)], "x", 0.8, "airship_fin"],
	[[Vector2(163.72, 44.6), Vector2(166.85, 44.1), Vector2(168.51, 54.88), Vector2(165.32, 55.02)], "x", 0.2, "airship_fin"],
	[[Vector2(144.89, 26.27), Vector2(151.44, 20.59), Vector2(157.0, 20.88), Vector2(157.0, 22.6), Vector2(152.3, 28.11),
		Vector2(151.1, 27.9)], "x", 0.8, "airship_yellow"],
	[[Vector2(157.0, 20.88), Vector2(165.0, 21.29), Vector2(164.66, 23.4), Vector2(157.0, 22.6)], "x", 0.8, "airship_yellow"],
	[[Vector2(152.3, 28.11), Vector2(157.0, 22.6), Vector2(164.66, 23.4), Vector2(163.58, 30.1)], "x", 0.8, "airship_white"],
	[[Vector2(163.72, 29.4), Vector2(164.58, 23.43), Vector2(167.74, 23.75), Vector2(166.85, 29.9)], "x", 0.2, "airship_white"],
	[[Vector2(164.58, 23.43), Vector2(164.89, 21.29), Vector2(168.0, 21.97), Vector2(167.74, 23.75)], "x", 0.2, "airship_yellow"],
	[[Vector2(143.2, 5.3), Vector2(153.4, 0.85), Vector2(165.14, 0.0), Vector2(163.58, 9.4)], "y", 0.8, "airship_fin"],
	[[Vector2(163.72, 8.7), Vector2(165.14, 0.0), Vector2(168.3, 0.14), Vector2(166.85, 9.2)], "y", 0.2, "airship_fin"],
]
const AIRSHIP_FIN_Y := 37.0
const AIRSHIP_HULL := [Vector2(0.0, 17.45), Vector2(4.81, 17.45), Vector2(4.744, 17.0), Vector2(4.67, 16.5),
	Vector2(4.49, 15.28), Vector2(4.28, 13.55),
	Vector2(4.05, 12.83), Vector2(3.63, 12.32), Vector2(3.31, 12.16), Vector2(2.94, 11.96), Vector2(0.0, 11.96)]
const AIRSHIP_HULL_BOTTOM := 11.96
const AIRSHIP_STATIONS := [Vector3(57.41, 0.35, 16.1), Vector3(58.6, 1.9, 13.4), Vector3(60.1, 3.14, 12.09),
	Vector3(62.6, 4.12, 11.96), Vector3(65.1, 4.65, 11.96), Vector3(67.6, 4.81, 11.96), Vector3(68.9, 4.81, 11.96),
	Vector3(71.0, 4.81, 11.96), Vector3(72.4, 4.81, 11.96), Vector3(74.4, 4.81, 11.96), Vector3(80.1, 4.81, 11.96),
	Vector3(81.33, 4.79, 11.96), Vector3(82.6, 4.76, 11.96), Vector3(85.1, 4.61, 11.96), Vector3(87.6, 4.43, 11.96), Vector3(90.1, 4.27, 11.96),
	Vector3(92.6, 4.08, 11.96), Vector3(95.1, 2.37, 12.7), Vector3(96.67, 0.35, 16.1)]
const AIRSHIP_WINDOWS := [4, [Vector2(57.72, 67.6), Vector2(68.9, 72.4), Vector2(74.4, 81.33)]]
const AIRSHIP_STRIPE := [2, Vector2(71.0, 92.6)]
const AIRSHIP_FRAME := [4.4, 17.45, 20.76, 22.28, 63.66, 95.92]
const AIRSHIP_PODS := [Vector2(7.445, 13.085), 2.565, 87.89, 91.78]
const AIRSHIP_STUB := [Vector2(19.7, 13.87), Vector2(22.6, 13.47), 0.33, 88.9, 90.9]
const AIRSHIP_KEELS := [
	[14.04, 18.04, [Vector2(49.07, 21.07), Vector2(63.7, 21.09)],
		[Vector2(49.07, 21.05), Vector2(49.11, 20.58), Vector2(49.52, 19.92), Vector2(50.14, 19.53), Vector2(52.56, 19.27), Vector2(63.7, 18.26)]],
	[14.18, 17.91, [Vector2(95.88, 22.2), Vector2(105.51, 22.35), Vector2(122.4, 22.66), Vector2(125.32, 22.68)],
		[Vector2(95.88, 17.65), Vector2(105.56, 18.76), Vector2(122.27, 21.12), Vector2(124.38, 21.35), Vector2(124.92, 21.69),
		Vector2(125.32, 22.68)]],
]
const AIRSHIP_ARM := [[Vector2(11.67, 17.99), Vector2(6.36, 17.88), Vector2(3.96, 18.21), Vector2(4.29, 19.2),
	Vector2(4.74, 19.54), Vector2(6.48, 19.77), Vector2(11.67, 20.69)], [Vector2(67.6, 69.34), Vector2(90.6, 92.34)]]
const AIRSHIP_CABLES := [4.18, 4.76]


func _airship(geo: TmGeo) -> void:
	var tubes: Array = lofts()["Other/Airship"]
	var env: Dictionary = tubes[AIRSHIP_PARTS["envelope"]]
	var rings: Array = env["rings"]
	var z0 := float(rings[0][0])
	var z1 := float(rings[rings.size() - 1][0])
	var n := (rings[0][1] as Array).size() / 2
	# the tail rounded as TMNF's: one more ring before the apex (AIRSHIP_TIP: z, scale about the axis)
	var last: Array = rings[rings.size() - 1][1]
	var tip := []
	for i in range(0, last.size(), 2):
		tip.append(AIRSHIP_C + (float(last[i]) - AIRSHIP_C) * AIRSHIP_TIP.y)
		tip.append(AIRSHIP_AXIS_Y + (float(last[i + 1]) - AIRSHIP_AXIS_Y) * AIRSHIP_TIP.y)
	env = env.duplicate(true)
	(env["rings"] as Array).append([AIRSHIP_TIP.x, tip])
	rings = env["rings"]
	var uv := func(k: int, i: int) -> Vector2:
		return Vector2(minf((float(rings[k][0]) - z0) / (z1 - z0), 1.0), float(i) / n)
	_tube(geo, env, "airship", S_METAL, 0.0, uv)
	var nz := TmGeo.NO_COLLISION
	for f: Array in AIRSHIP_FINS:
		var poly: Array = f[0]
		var t: float = f[2] * 0.5
		if String(f[1]) == "x":
			_slab(geo, poly.map(func(q: Vector2) -> Vector3: return Vector3(AIRSHIP_C - t, q.y, q.x)),
				poly.map(func(q: Vector2) -> Vector3: return Vector3(AIRSHIP_C + t, q.y, q.x)), String(f[3]), S_METAL)
		else:
			for mirror in [false, true]:
				var mx := func(x: float) -> float: return 2.0 * AIRSHIP_C - x if mirror else x
				_slab(geo, poly.map(func(q: Vector2) -> Vector3: return Vector3(mx.call(q.y), AIRSHIP_FIN_Y - t, q.x)),
					poly.map(func(q: Vector2) -> Vector3: return Vector3(mx.call(q.y), AIRSHIP_FIN_Y + t, q.x)), String(f[3]), S_METAL)
	_gondola(geo)
	# the engine pods: a duct (white outside, dark inside), a hub, the fan; a stub wing to the hull
	var pc: Vector2 = AIRSHIP_PODS[0]
	var r: float = AIRSHIP_PODS[1]
	var pz0: float = AIRSHIP_PODS[2]
	var pz1: float = AIRSHIP_PODS[3]
	for mirror in [false, true]:
		var c := Vector2(2.0 * AIRSHIP_C - pc.x if mirror else pc.x, pc.y)
		geo.revolve_z([[pz0, r - 0.45, "stands_dark", S_METAL], [pz1, r - 0.45, "airship_white", S_METAL],
			[pz1, r, "airship_white", S_METAL], [pz0 + 0.4, r, "airship_white", S_METAL], [pz0, r - 0.2, "airship_white", S_METAL]],
			c, 0.0, 360.0, 20, false)
		geo.pipe(Vector3(c.x, c.y, pz0 - 0.25), Vector3(c.x, c.y, pz1 - 0.1), 0.52, 10, "airship_white", nz)
		geo.fan(Vector3(c.x, c.y, (pz0 + pz1) * 0.5), 0.5, r - 0.48, 0.28, "stands_dark", 5)
		var st: Array = AIRSHIP_STUB
		var a: Vector2 = st[0]
		var b: Vector2 = st[1]
		var mx2 := func(q: Vector2) -> Vector2: return Vector2(2.0 * AIRSHIP_C - q.x, q.y) if not mirror else q
		var h: float = st[2]
		var aa: Vector2 = mx2.call(a)
		var bb: Vector2 = mx2.call(b)
		_slab(geo, [Vector3(aa.x, aa.y - h, st[3]), Vector3(bb.x, bb.y - h, st[3]), Vector3(bb.x, bb.y + h, st[3]), Vector3(aa.x, aa.y + h, st[3])],
			[Vector3(aa.x, aa.y - h, st[4]), Vector3(bb.x, bb.y - h, st[4]), Vector3(bb.x, bb.y + h, st[4]), Vector3(aa.x, aa.y + h, st[4])],
			"airship_white", nz)
	# the keels (dark truss cards: both sides and the bottom)
	for k: Array in AIRSHIP_KEELS:
		var top: Array = k[2]
		var bot: Array = k[3]
		for x: float in [k[0], k[1]]:
			_lattice_side(geo, x, top, bot)
		for i in bot.size() - 1:
			var p: Vector2 = bot[i]
			var q: Vector2 = bot[i + 1]
			var du := p.distance_to(q) / 8.0
			geo.quad_uv(Vector3(k[0], p.y, p.x), Vector3(k[1], p.y, p.x), Vector3(k[1], q.y, q.x), Vector3(k[0], q.y, q.x), "girder_dark",
				nz, Vector2(0, 0), Vector2(0, 1), Vector2(du, 1), Vector2(du, 0))
	# the mooring arms (cards on both faces and round the edge) and their cables
	var arm: Array = AIRSHIP_ARM[0]
	for mirror in [false, true]:
		var pts: Array = arm.map(func(q: Vector2) -> Vector2: return Vector2(2.0 * AIRSHIP_C - q.x, q.y) if mirror else q)
		for span: Vector2 in AIRSHIP_ARM[1]:
			for z: float in [span.x, span.y]:
				_card_fan(geo, pts.map(func(q: Vector2) -> Vector3: return Vector3(q.x, q.y, z)), 2.8)
			for i in pts.size() - 1:
				var p: Vector2 = pts[i]
				var q: Vector2 = pts[i + 1]
				var du := p.distance_to(q) / 8.0
				geo.quad_uv(Vector3(p.x, p.y, span.x), Vector3(q.x, q.y, span.x), Vector3(q.x, q.y, span.y), Vector3(p.x, p.y, span.y),
					"girder_dark", nz, Vector2(0, 0), Vector2(du, 0), Vector2(du, 1), Vector2(0, 1))
			for x: float in AIRSHIP_CABLES:
				var cx := 2.0 * AIRSHIP_C - x if mirror else x
				var cz := (span.x + span.y) * 0.5
				geo.pipe(Vector3(cx, 0.2, cz), Vector3(cx, 18.3, cz), 0.04, 4, "stands_dark", nz)


## The gondola: the hull lofted through AIRSHIP_STATIONS (white, its windows dark, its stripe
## red), its ends closed, and the dark frame on it up to the envelope (AIRSHIP_FRAME).
func _gondola(geo: TmGeo) -> void:
	var rings := []
	for st: Vector3 in AIRSHIP_STATIONS:
		var k := (AIRSHIP_HULL[0].y - st.z) / (AIRSHIP_HULL[0].y - AIRSHIP_HULL_BOTTOM)
		var half := AIRSHIP_HULL.map(func(q: Vector2) -> Vector2: return Vector2(q.x * st.y / 4.81, AIRSHIP_HULL[0].y - (AIRSHIP_HULL[0].y - q.y) * k))
		var ring := []
		for i in half.size():
			ring.append(Vector3(AIRSHIP_C + (half[i] as Vector2).x, (half[i] as Vector2).y, st.x))
		for i in range(half.size() - 2, 0, -1):
			ring.append(Vector3(AIRSHIP_C - (half[i] as Vector2).x, (half[i] as Vector2).y, st.x))
		rings.append(ring)
	var m := AIRSHIP_HULL.size()
	var win_seg: int = AIRSHIP_WINDOWS[0]
	var stripe: Vector2 = AIRSHIP_STRIPE[1]
	for j in rings.size() - 1:
		var ra: Array = rings[j]
		var rb: Array = rings[j + 1]
		var zm := (float((ra[0] as Vector3).z) + float((rb[0] as Vector3).z)) * 0.5
		var cen := Vector3(AIRSHIP_C, 14.7, zm)
		for i in ra.size():
			var i1 := (i + 1) % ra.size()
			# the segment's index in the half section (mirrored on the second half)
			var seg := i if i < m - 1 else ra.size() - i - 1
			var key := "airship_white"
			if seg == win_seg:
				for span: Vector2 in AIRSHIP_WINDOWS[1]:
					if zm > span.x and zm < span.y:
						key = "airship_window"
			elif seg == int(AIRSHIP_STRIPE[0]) and zm > stripe.x and zm < stripe.y:
				key = "airship_fin"
			var f := [ra[i], ra[i1], rb[i1], rb[i]]
			var mid: Vector3 = (f[0] + f[1] + f[2] + f[3]) * 0.25
			if ((f[1] - f[0]) as Vector3).cross(f[2] - f[0]).dot(mid - cen) < 0.0:
				geo.quad(f[0], f[3], f[2], f[1], key, S_METAL)
			else:
				geo.quad(f[0], f[1], f[2], f[3], key, S_METAL)
	for end in [0, rings.size() - 1]:
		var ring: Array = rings[end]
		var c := Vector3.ZERO
		for p: Vector3 in ring:
			c += p / ring.size()
		var out := -1.0 if end == 0 else 1.0
		for i in ring.size():
			var a: Vector3 = ring[i]
			var b: Vector3 = ring[(i + 1) % ring.size()]
			if (a - c).cross(b - c).z * out < 0.0:
				geo.tri(c, b, a, "airship_white", S_METAL)
			else:
				geo.tri(c, a, b, "airship_white", S_METAL)
	var fr: Array = AIRSHIP_FRAME
	var w: float = fr[0]
	geo.box(Vector3(AIRSHIP_C - w, fr[1], fr[4]), Vector3(AIRSHIP_C + w, fr[2], fr[5]), "stands_dark", S_METAL)
	_slab(geo, [Vector3(AIRSHIP_C - w + 0.04, fr[2], fr[4]), Vector3(AIRSHIP_C, fr[3], fr[4]), Vector3(AIRSHIP_C + w - 0.04, fr[2], fr[4])],
		[Vector3(AIRSHIP_C - w + 0.04, fr[2], fr[5]), Vector3(AIRSHIP_C, fr[3], fr[5]), Vector3(AIRSHIP_C + w - 0.04, fr[2], fr[5])],
		"stands_dark", S_METAL)


## A solid between two matching convex rings (ring0[k] faces ring1[k]), faces outward, ends capped.
static func _slab(geo: TmGeo, ring0: Array, ring1: Array, key: String, surface: int) -> void:
	var c0 := Vector3.ZERO
	var c1 := Vector3.ZERO
	for k in ring0.size():
		c0 += ring0[k] / ring0.size()
		c1 += ring1[k] / ring1.size()
	var cc := (c0 + c1) * 0.5
	for k in ring0.size():
		var k1 := (k + 1) % ring0.size()
		var f := [ring0[k], ring0[k1], ring1[k1], ring1[k]]
		var mid: Vector3 = (f[0] + f[1] + f[2] + f[3]) * 0.25
		if ((f[1] - f[0]) as Vector3).cross(f[2] - f[0]).dot(mid - cc) < 0.0:
			geo.quad(f[0], f[3], f[2], f[1], key, surface)
		else:
			geo.quad(f[0], f[1], f[2], f[3], key, surface)
	for r in 2:
		var ring: Array = ring0 if r == 0 else ring1
		var c := c0 if r == 0 else c1
		var out := (c0 - c1) if r == 0 else (c1 - c0)
		for k in ring.size():
			var a: Vector3 = ring[k]
			var b: Vector3 = ring[(k + 1) % ring.size()]
			if (a - c).cross(b - c).dot(out) < 0.0:
				geo.tri(c, b, a, key, surface)
			else:
				geo.tri(c, a, b, key, surface)


## A girder's side as a dark truss card at x: between its top and bottom lines (z, y), fanned in
## strips along z (u along, v down from the top).
static func _lattice_side(geo: TmGeo, x: float, top: Array, bot: Array) -> void:
	var zs := []
	for q: Vector2 in top + bot:
		if not zs.has(q.x):
			zs.append(q.x)
	zs.sort()
	var at := func(line: Array, z: float) -> float:
		for i in line.size() - 1:
			var p: Vector2 = line[i]
			var q: Vector2 = line[i + 1]
			if z >= minf(p.x, q.x) - 1e-4 and z <= maxf(p.x, q.x) + 1e-4:
				return lerpf(p.y, q.y, 0.0 if absf(q.x - p.x) < 1e-6 else (z - p.x) / (q.x - p.x))
		return (line[0] as Vector2).y if z < (line[0] as Vector2).x else (line[line.size() - 1] as Vector2).y
	for i in zs.size() - 1:
		var za: float = zs[i]
		var zb: float = zs[i + 1]
		var ta: float = at.call(top, za)
		var tb: float = at.call(top, zb)
		var ba: float = minf(at.call(bot, za), ta)
		var bb: float = minf(at.call(bot, zb), tb)
		geo.quad_uv(Vector3(x, ba, za), Vector3(x, bb, zb), Vector3(x, tb, zb), Vector3(x, ta, za), "girder_dark", TmGeo.NO_COLLISION,
			Vector2(za / 8.0, 1), Vector2(zb / 8.0, 1), Vector2(zb / 8.0, 0), Vector2(za / 8.0, 0))


## A flat dark truss card over a convex outline (fanned from its centre): u along x, v down y per h.
static func _card_fan(geo: TmGeo, pts: Array, h: float) -> void:
	var c := Vector3.ZERO
	for p: Vector3 in pts:
		c += p / pts.size()
	var top := -INF
	for p: Vector3 in pts:
		top = maxf(top, p.y)
	var uv := func(p: Vector3) -> Vector2: return Vector2(p.x / 8.0, (top - p.y) / h)
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		geo.tri(c, a, b, "girder_dark", TmGeo.NO_COLLISION, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, uv.call(c), uv.call(a), uv.call(b))


## One lofted tube: its rings joined ring to ring (horizontal rings up y, or rings across z for
## "axis": "z"); the start closed flat underneath (y) or drawn in to its base point (z); the end
## drawn up to its apex or closed flat at top_y. Faces are turned outward afterwards (by majority,
## the rings' winding is not relied on); msum > 0 mirrors: x -> msum - x.
func _tube(geo: TmGeo, tube: Dictionary, mat: String, surface: int, msum := 0.0, uv_of := Callable()) -> void:
	var along_z := String(tube.get("axis", "y")) == "z"
	var mx := func(p: Vector3) -> Vector3: return Vector3(msum - p.x, p.y, p.z) if msum > 0.0 else p
	var rings := []
	for r: Array in tube["rings"]:
		var a := float(r[0])
		var pts: Array = r[1]
		var ring := []
		for i in range(0, pts.size(), 2):
			var u := float(pts[i])
			var w := float(pts[i + 1])
			ring.append(mx.call(Vector3(u, w, a) if along_z else Vector3(u, a, w)))
		rings.append(ring)
	var n: int = (rings[0] as Array).size()
	var quads := []
	for k in rings.size() - 1:
		var lo: Array = rings[k]
		var hi: Array = rings[k + 1]
		var c := (_mean(lo) + _mean(hi)) * 0.5
		for i in n:
			var j := (i + 1) % n
			quads.append([lo[i], hi[i], hi[j], lo[j], c, k, i])
	# outward by majority: the face normal against the way out from the rings' centre
	var votes := 0
	for q: Array in quads:
		var nrm := ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[2] as Vector3) - (q[0] as Vector3))
		var mid := ((q[0] as Vector3) + (q[2] as Vector3)) * 0.5
		votes += 1 if nrm.dot(mid - (q[4] as Vector3)) >= 0.0 else -1
	var uvs := _screen_uvs(tube, rings, mat) if mat in TmGeo.SCREENS else []
	# smooth shading across the faces of a surface (TMNF's are smooth), sharp at its edges: each
	# corner's normal the mean of the faces round it that turn less than SMOOTH_DEG from this one
	var sgn := 1.0 if votes >= 0 else -1.0
	var fn := []
	for q: Array in quads:
		fn.append((((q[1] as Vector3) - (q[0] as Vector3)).cross((q[2] as Vector3) - (q[0] as Vector3)) * sgn).normalized())
	var cos_lim := cos(deg_to_rad(SMOOTH_DEG))
	var corner := func(qi: int, k: int, i: int) -> Vector3:
		var own: Vector3 = fn[qi]
		var sum := Vector3.ZERO
		for dk in [-1, 0]:
			for di in [-1, 0]:
				var kk: int = k + dk
				if kk < 0 or kk > rings.size() - 2:
					continue
				var other: Vector3 = fn[kk * n + posmod(i + di, n)]
				if other.dot(own) > cos_lim:
					sum += other
		return sum.normalized() if sum.length_squared() > 1e-8 else own
	for qi in quads.size():
		var q: Array = quads[qi]
		if not uvs.is_empty():
			var k: int = q[5]
			var i: int = q[6]
			var u: Array = [uvs[k][i], uvs[k + 1][i], uvs[k + 1][n + i], uvs[k][n + i]]
			if votes >= 0:
				geo.quad_uv(q[0], q[1], q[2], q[3], mat, surface, u[0], u[1], u[2], u[3])
			else:
				geo.quad_uv(q[3], q[2], q[1], q[0], mat, surface, u[3], u[2], u[1], u[0])
		else:
			var k: int = q[5]
			var i: int = q[6]
			var j := (i + 1) % n
			var na: Vector3 = corner.call(qi, k, i)
			var nb: Vector3 = corner.call(qi, k + 1, i)
			var nc: Vector3 = corner.call(qi, k + 1, j)
			var nd: Vector3 = corner.call(qi, k, j)
			var ua := Vector2.ZERO
			var ub := Vector2.ZERO
			var uc := Vector2.ZERO
			var ud := Vector2.ZERO
			if uv_of.is_valid():
				ua = uv_of.call(k, i)
				ub = uv_of.call(k + 1, i)
				uc = uv_of.call(k + 1, i + 1)
				ud = uv_of.call(k, i + 1)
			if votes >= 0:
				geo.tri(q[0], q[1], q[2], mat, surface, na, nb, nc, ua, ub, uc)
				geo.tri(q[0], q[2], q[3], mat, surface, na, nc, nd, ua, uc, ud)
			else:
				geo.tri(q[3], q[2], q[1], mat, surface, nd, nc, nb, ud, uc, ub)
				geo.tri(q[3], q[1], q[0], mat, surface, nd, nb, na, ud, ub, ua)
	var first: Array = rings[0]
	var last: Array = rings[rings.size() - 1]
	if along_z:
		_fan(geo, first, mx.call(_vec(tube.get("base", []), _mean(first))), mat, surface, uv_of, 0)
	else:
		geo.flat_polygon(_plan(first), float((first[0] as Vector3).y), mat, surface, true)
	if tube.has("apex"):
		_fan(geo, last, mx.call(_vec(tube["apex"], _mean(last))), mat, surface, uv_of, rings.size() - 1)
	else:
		# a flat top: the last ring lifted to top_y
		var ty := float(tube.get("top_y", (last[0] as Vector3).y))
		for i in n:
			var p: Vector3 = last[i]
			var q: Vector3 = last[(i + 1) % n]
			var a := Vector3(p.x, ty, p.z)
			var b := Vector3(q.x, ty, q.z)
			if (a - p).cross(q - p).dot((p + q) * 0.5 - _mean(last)) >= 0.0:
				geo.quad(p, a, b, q, mat, surface)
			else:
				geo.quad(q, b, a, p, mat, surface)
		geo.flat_polygon(_plan(last), ty, mat, surface)


## A lofted screen's UVs (TmGeo.SCREENS): its sides are the runs of the rings' edges
## that keep their direction (within 20 degrees: a video cube's faces, its chamfered corners on
## their own), each one screen as high as the loft.
static func _screen_uvs(tube: Dictionary, rings: Array, mat: String) -> Array:
	var along_z := String(tube.get("axis", "y")) == "z"
	var mid: Array = rings[rings.size() / 2]
	var n := mid.size()
	var flat := func(p: Vector3) -> Vector2: return Vector2(p.x, p.y) if along_z else Vector2(p.x, p.z)
	var dirs := []
	var lens := []
	for i in n:
		var d: Vector2 = flat.call(mid[(i + 1) % n]) - flat.call(mid[i])
		lens.append(d.length())
		dirs.append(d.normalized() if d.length() > 1e-6 else Vector2.RIGHT)
	# start at the sharpest corner, so no side is split where the ring starts
	var start := 0
	var worst := 2.0
	for i in n:
		var c := (dirs[i] as Vector2).dot(dirs[(i + n - 1) % n])
		if c < worst:
			worst = c
			start = i
	var sides := []                  # [first edge, edge count, length]
	var cos_lim := cos(deg_to_rad(20.0))
	for e in n:
		var i := (start + e) % n
		if sides.is_empty() or (dirs[i] as Vector2).dot(dirs[int(sides[-1][0])]) < cos_lim:
			sides.append([i, 0, 0.0])
		sides[-1][1] = int(sides[-1][1]) + 1
		sides[-1][2] = float(sides[-1][2]) + float(lens[i])
	var a0 := float((tube["rings"] as Array)[0][0])
	var a1 := float((tube["rings"] as Array)[-1][0])
	var h := absf(a1 - a0)
	# each edge's two ends on its side's screen (a point between two sides has a UV on each, so
	# [ring][point] holds the UV where edge `point` starts, [ring][point + n] where it ends)
	var out := []
	for k in rings.size():
		var down := maxf(a0, a1) - float((tube["rings"] as Array)[k][0])
		var row := []
		row.resize(2 * n)
		out.append(row)
		for si in sides.size():
			var sd: Array = sides[si]
			var run := 0.0
			for e in int(sd[1]):
				var i := (int(sd[0]) + e) % n
				row[i] = TmGeo.screen_uv(run, float(sd[2]), down, h, si)
				run += float(lens[i])
				row[n + i] = TmGeo.screen_uv(run, float(sd[2]), down, h, si)
	return out


## A ring drawn in to a point (a tube's tapering end), each triangle facing away from the ring.
## A ring drawn in to a tip; with uv_of (the tube's UVs, ring k), the tip takes the ring's u.
func _fan(geo: TmGeo, ring: Array, tip: Vector3, mat: String, surface: int, uv_of := Callable(), k := 0) -> void:
	var c := _mean(ring)
	for i in ring.size():
		var p: Vector3 = ring[i]
		var q: Vector3 = ring[(i + 1) % ring.size()]
		var nrm := (q - p).cross(tip - p)
		var up := Vector2.ZERO
		var uq := Vector2.ZERO
		var ut := Vector2.ZERO
		if uv_of.is_valid():
			up = uv_of.call(k, i)
			uq = uv_of.call(k, i + 1)
			ut = Vector2(up.x, (up.y + uq.y) * 0.5)
		if nrm.dot((p + q + tip) / 3.0 - c) >= 0.0:
			geo.tri(p, q, tip, mat, surface, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, up, uq, ut)
		else:
			geo.tri(p, tip, q, mat, surface, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, up, ut, uq)


static func _mean(ring: Array) -> Vector3:
	var s := Vector3.ZERO
	for p: Vector3 in ring:
		s += p
	return s / float(ring.size())


static func _vec(a: Array, fallback: Vector3) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() == 3 else fallback


static func _plan(ring: Array) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p: Vector3 in ring:
		poly.append(Vector2(p.x, p.z))
	return poly
