class_name SceneryField
extends RefCounted
## Fast spatial queries against a TrackPath for prop placement: the path is sampled every few
## meters and bucketed in a 2D (XZ) grid. `query(p)` finds the nearest centerline segment in XZ
## and fills the q_* fields (no allocation). XZ clearance is stricter than
## TrackPath.edge_clearance (which ignores height), so props never stand under or over the road
## unless a kit places them there on purpose.

var path: TrackPath
var step: float = 4.0
var count: int = 0
var pos := PackedVector3Array()
var rgt := PackedVector3Array()
var fwd := PackedVector3Array()
var nrm := PackedVector3Array()
var half := PackedFloat32Array()      # half road width
var low := PackedFloat32Array()       # lowest road-edge height (banking)
var dist := PackedFloat32Array()      # distance along the path
var zone_bits := PackedInt32Array()   # bit per zone kind (see ZONE_BITS)
var bmin := Vector2(1e9, 1e9)
var bmax := Vector2(-1e9, -1e9)
var ymin: float = 1e9
var ymax: float = -1e9
var max_half: float = 7.0

const ZONE_BITS := {"loop": 1, "jump": 2, "tunnel": 4, "bridge": 8, "boost": 16, "no_props": 32}

var _cell: float = 24.0
var _grid: Dictionary = {}

# results of the last query()
var q_index: int = -1
var q_dist: float = 1e9        # XZ distance to the centerline
var q_clear: float = 1e9       # XZ distance beyond the road edge
var q_lat: float = 0.0         # signed lateral offset (+ = right of travel)
var q_y: float = 0.0           # road height at the nearest point
var q_d: float = 0.0           # distance along the path at the nearest point


func _init(p_path: TrackPath, p_step := 4.0) -> void:
	path = p_path
	step = p_step
	count = maxi(2, int(ceil(path.length / step)) + 1)
	var real_step := path.length / float(count - 1)
	for i in count:
		var d := minf(i * real_step, path.length)
		var t := path.sample_transform(d)
		var w := path.width_at(d) * 0.5
		pos.append(t.origin)
		rgt.append(t.basis.x)
		fwd.append(-t.basis.z)
		nrm.append(t.basis.y)
		half.append(w)
		max_half = maxf(max_half, w)
		low.append(minf((t.origin + t.basis.x * w).y, (t.origin - t.basis.x * w).y))
		dist.append(d)
		var bits := 0
		for z in path.zones:
			if d >= float(z.get("from", 0.0)) and d <= float(z.get("to", 0.0)):
				bits |= int(ZONE_BITS.get(String(z.get("kind", "")), 0))
		zone_bits.append(bits)
		bmin = Vector2(minf(bmin.x, t.origin.x), minf(bmin.y, t.origin.z))
		bmax = Vector2(maxf(bmax.x, t.origin.x), maxf(bmax.y, t.origin.z))
		ymin = minf(ymin, t.origin.y)
		ymax = maxf(ymax, t.origin.y)
		var key := _key(t.origin.x, t.origin.z)
		if not _grid.has(key):
			_grid[key] = PackedInt32Array()
		var arr: PackedInt32Array = _grid[key]
		arr.append(i)
		_grid[key] = arr


func _key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / _cell), floori(z / _cell))


func center() -> Vector3:
	return Vector3((bmin.x + bmax.x) * 0.5, 0.0, (bmin.y + bmax.y) * 0.5)


func extent() -> Vector2:
	return bmax - bmin


## Nearest centerline point in XZ within `radius` (beyond that: q_clear = radius, q_index = -1).
## Returns q_clear.
func query(p: Vector3, radius := 60.0) -> float:
	q_index = -1
	q_dist = radius + max_half
	q_clear = radius
	var r := int(ceil((radius + max_half) / _cell))
	var k := _key(p.x, p.z)
	var best := q_dist * q_dist
	var bi := -1
	var bt := 0.0
	for gx in range(k.x - r, k.x + r + 1):
		for gz in range(k.y - r, k.y + r + 1):
			var key := Vector2i(gx, gz)
			if not _grid.has(key):
				continue
			for i in (_grid[key] as PackedInt32Array):
				# segment i -> i+1 (and i-1 -> i through the neighbour's own bucket)
				var j := mini(i + 1, count - 1)
				var a := pos[i]
				var b := pos[j]
				var ab := Vector2(b.x - a.x, b.z - a.z)
				var ap := Vector2(p.x - a.x, p.z - a.z)
				var l2 := ab.length_squared()
				var t := 0.0 if l2 < 1e-6 else clampf(ap.dot(ab) / l2, 0.0, 1.0)
				var dd := (ap - ab * t).length_squared()
				if dd < best:
					best = dd
					bi = i
					bt = t
	if bi < 0:
		return q_clear
	var j2 := mini(bi + 1, count - 1)
	q_index = bi if bt < 0.5 else j2
	q_dist = sqrt(best)
	var h := lerpf(half[bi], half[j2], bt)
	q_clear = q_dist - h
	var c := pos[bi].lerp(pos[j2], bt)
	q_y = c.y
	q_d = lerpf(dist[bi], dist[j2], bt)
	var r3 := rgt[bi]
	q_lat = (p.x - c.x) * r3.x + (p.z - c.z) * r3.z
	return q_clear


## Minimum XZ clearance of a rotated rectangle footprint (center, yaw basis, half extents),
## checked at the corners, edge midpoints and center.
func rect_clearance(center_p: Vector3, xdir: Vector3, zdir: Vector3, hx: float, hz: float, radius := 60.0) -> float:
	var m := 1e9
	for sx: float in [-1.0, 0.0, 1.0]:
		for sz: float in [-1.0, 0.0, 1.0]:
			m = minf(m, query(center_p + xdir * (hx * sx) + zdir * (hz * sz), radius))
	return m


func has_zone(i: int, kind: String) -> bool:
	if i < 0 or i >= count:
		return false
	return (zone_bits[i] & int(ZONE_BITS.get(kind, 0))) != 0


## True if any zone in `kinds` covers path distance range [d - margin, d + margin].
func zone_near(d: float, kinds: Array, margin := 0.0) -> bool:
	for z in path.zones:
		if kinds.has(String(z.get("kind", ""))):
			var a := float(z.get("from", 0.0)) - margin
			var b := float(z.get("to", 0.0)) + margin
			if d >= a and d <= b:
				return true
			if path.is_circuit:
				if d + path.length >= a and d + path.length <= b:
					return true
				if d - path.length >= a and d - path.length <= b:
					return true
	return false


## Frame at sample i (origin on road, basis.x right, basis.y up, -z forward).
func frame(i: int) -> Transform3D:
	return Transform3D(Basis(rgt[i], nrm[i], -fwd[i]), pos[i])


## Yaw-only basis for a direction (props stay upright).
static func yaw_basis(forward: Vector3) -> Basis:
	var f := Vector3(forward.x, 0.0, forward.z)
	if f.length_squared() < 1e-6:
		f = Vector3.FORWARD
	f = f.normalized()
	var r := f.cross(Vector3.UP).normalized()
	return Basis(r, Vector3.UP, -f)


## Percentile of road heights (used as the "ground" level of flat themes).
func height_percentile(pct: float) -> float:
	var ys: Array = []
	for p in pos:
		ys.append(p.y)
	ys.sort()
	return ys[clampi(int(pct * (ys.size() - 1)), 0, ys.size() - 1)]
