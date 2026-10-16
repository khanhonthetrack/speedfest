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
const A_CURB := [[-1.729, 1.0], [-1.604, 1.5], [-1.554, 1.55], [-0.813, 1.55], [-0.763, 1.5], [-0.763, 1.05],
	[0.763, 1.05], [0.763, 1.5], [0.813, 1.55], [1.554, 1.55], [1.604, 1.5], [1.729, 1.0]]

static var _lofts: Dictionary = {}


static func lofts() -> Dictionary:
	if _lofts.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_lofts = (parsed as Dictionary).get("shapes", {})
	return _lofts


## Mirrored pieces: the same lofts with x mirrored across the block (x -> 32 - x), measured.
const MIRRORED := {"Sculpt/Bridge/BridgeSuspendSlope2Mirror": "Sculpt/Bridge/BridgeSuspendSlope2"}


func handles(shape: String) -> bool:
	return lofts().has(shape) or MIRRORED.has(shape)


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	var src: String = MIRRORED.get(shape, shape)
	var mirror := MIRRORED.has(shape)
	for tube: Dictionary in lofts()[src]:
		_tube(geo, tube, "sculpt", S_METAL, mirror)
	for tube: Dictionary in lofts().get(src + "#struts", []):
		_tube(geo, tube, "structure", S_METAL, mirror)
	match shape:
		"Sculpt/A/Ground", "Sculpt/B/Ground", "Sculpt/C/Ground":
			# the three sculptures share their plinth (measured: the same pads and curbs)
			for tube: Dictionary in lofts().get("Sculpt/A/Ground#pads", []):
				_tube(geo, tube, "rubber", 9)
			for zc: float in A_CURB_Z:
				var sec := A_CURB.map(func(q: Array) -> Array: return [Vector2(zc + float(q[0]), float(q[1])), "rubber_white", S_ROAD])
				geo.wall_sweep(sec, [Vector3(A_CURB_X[0], 0, 0), Vector3(A_CURB_X[1], 0, 0)], [Vector3(0, 0, 1), Vector3(0, 0, 1)],
					true, "structure", S_METAL)
	return geo.build()


## One lofted tube: its rings joined ring to ring (horizontal rings up y, or rings across z for
## "axis": "z"); the start closed flat underneath (y) or drawn in to its base point (z); the end
## drawn up to its apex or closed flat at top_y. Faces are turned outward afterwards (by majority,
## the rings' winding is not relied on); mirror: x -> 32 - x.
func _tube(geo: TmGeo, tube: Dictionary, mat: String, surface: int, mirror := false) -> void:
	var along_z := String(tube.get("axis", "y")) == "z"
	var mx := func(p: Vector3) -> Vector3: return Vector3(32.0 - p.x, p.y, p.z) if mirror else p
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
			quads.append([lo[i], hi[i], hi[j], lo[j], c])
	# outward by majority: the face normal against the way out from the rings' centre
	var votes := 0
	for q: Array in quads:
		var nrm := ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[2] as Vector3) - (q[0] as Vector3))
		var mid := ((q[0] as Vector3) + (q[2] as Vector3)) * 0.5
		votes += 1 if nrm.dot(mid - (q[4] as Vector3)) >= 0.0 else -1
	for q: Array in quads:
		if votes >= 0:
			geo.quad(q[0], q[1], q[2], q[3], mat, surface)
		else:
			geo.quad(q[3], q[2], q[1], q[0], mat, surface)
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
