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


## One lofted tube: its rings joined ring to ring (horizontal rings up y, or rings across z for
## "axis": "z"); the start closed flat underneath (y) or drawn in to its base point (z); the end
## drawn up to its apex or closed flat at top_y. Faces are turned outward afterwards (by majority,
## the rings' winding is not relied on); msum > 0 mirrors: x -> msum - x.
func _tube(geo: TmGeo, tube: Dictionary, mat: String, surface: int, msum := 0.0) -> void:
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
			if votes >= 0:
				geo.tri(q[0], q[1], q[2], mat, surface, na, nb, nc)
				geo.tri(q[0], q[2], q[3], mat, surface, na, nc, nd)
			else:
				geo.tri(q[3], q[2], q[1], mat, surface, nd, nc, nb)
				geo.tri(q[3], q[1], q[0], mat, surface, nd, nb, na)
	var first: Array = rings[0]
	var last: Array = rings[rings.size() - 1]
	if along_z:
		_fan(geo, first, mx.call(_vec(tube.get("base", []), _mean(first))), mat, surface)
	else:
		geo.flat_polygon(_plan(first), float((first[0] as Vector3).y), mat, surface, true)
	if tube.has("apex"):
		_fan(geo, last, mx.call(_vec(tube["apex"], _mean(last))), mat, surface)
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
func _fan(geo: TmGeo, ring: Array, tip: Vector3, mat: String, surface: int) -> void:
	var c := _mean(ring)
	for i in ring.size():
		var p: Vector3 = ring[i]
		var q: Vector3 = ring[(i + 1) % ring.size()]
		var nrm := (q - p).cross(tip - p)
		if nrm.dot((p + q + tip) / 3.0 - c) >= 0.0:
			geo.tri(p, q, tip, mat, surface)
		else:
			geo.tri(p, tip, q, mat, surface)


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
