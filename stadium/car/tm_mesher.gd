class_name TmMesher
extends RefCounted
## Builds smooth meshes from point grids, for our own models (the car): lofts through rings,
## surfaces of revolution, extrusions, fans. Triangles are grouped by material key into one
## ArrayMesh (a surface per key). Normals: smooth over a grid (area-weighted face normals),
## flat on fans and extrusion caps. Godot's front faces wind clockwise seen from the front; every
## triangle is wound to match its outward normal, so callers only say where "out" is.

class Part:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()

	func tri(a: int, b: int, c: int, out: Vector3) -> void:
		if (v[b] - v[a]).cross(v[c] - v[a]).dot(out) > 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

var parts := {}                    ## material key -> Part
var offset := Vector3.ZERO         ## added to every point (e.g. -VIS: model space -> node space)


func part(key: String) -> Part:
	if not parts.has(key):
		parts[key] = Part.new()
	return parts[key]


## A grid of rows (PackedVector3Array each, the same size): faces between neighbouring rows and
## columns (columns wrap when closed). `out` gives a point's outward direction for one sample
## face (Callable(face centre, row, column) -> Vector3); the grid's winding follows from it.
func grid(key: String, rows: Array, closed: bool, out: Callable) -> void:
	var p := part(key)
	var nr := rows.size()
	var nc := (rows[0] as PackedVector3Array).size()
	var base := p.v.size()
	for r in nr:
		for c in nc:
			p.v.append((rows[r] as PackedVector3Array)[c] + offset)
			p.n.append(Vector3.ZERO)
	var cmax := nc if closed else nc - 1
	var sign := 0.0
	var faces := []
	for r in nr - 1:
		for c in cmax:
			var c1 := (c + 1) % nc
			var a := base + r * nc + c
			var b := base + r * nc + c1
			var d := base + (r + 1) * nc + c
			var e := base + (r + 1) * nc + c1
			var fn := (p.v[d] - p.v[b]).cross(p.v[e] - p.v[a])
			faces.append([a, b, d, e, fn])
			if sign == 0.0 and fn.length_squared() > 1e-12:
				var centre := (p.v[a] + p.v[b] + p.v[d] + p.v[e]) * 0.25 - offset
				sign = 1.0 if fn.dot(out.call(centre, r, c)) >= 0.0 else -1.0
	if sign == 0.0:
		sign = 1.0
	for f: Array in faces:
		var fn: Vector3 = f[4] * sign
		for k in 4:
			var i: int = f[k]
			p.n[i] += fn
		if fn.length_squared() <= 1e-14:
			continue
		p.tri(f[0], f[1], f[3], fn)
		p.tri(f[0], f[3], f[2], fn)


## Closes a ring with a flat fan around `centre`; `out` is the cap's outward direction.
func fan(key: String, ring: PackedVector3Array, centre: Vector3, out: Vector3) -> void:
	var p := part(key)
	var nrm := out.normalized()
	var c := p.v.size()
	p.v.append(centre + offset)
	p.n.append(nrm)
	for q in ring:
		p.v.append(q + offset)
		p.n.append(nrm)
	for i in ring.size():
		p.tri(c, c + 1 + i, c + 1 + (i + 1) % ring.size(), nrm)


## A surface of revolution about the x axis through `profile` ([x, radius] points, Vector2), from
## angle a0 to a1 (radians, 0 = +y, towards +z), `seg` steps; `side` 1: the outside is to the left
## of the profile's travel in the (x, r) plane (rotated +90 deg), -1 the other way. Full turns
## close; partial ones get flat end caps when `caps`. `at` moves it (the wheel centre).
func revolve(key: String, profile: Array, seg: int, side := 1.0, a0 := 0.0, a1 := TAU,
		at := Vector3.ZERO, caps := false) -> void:
	var full := absf(a1 - a0 - TAU) < 1e-6
	var steps := seg if full else seg + 1
	var rows := []
	for k in profile.size():
		var q: Vector2 = profile[k]
		var ring := PackedVector3Array()
		for s in steps:
			var a := lerpf(a0, a1, float(s) / seg)
			ring.append(at + Vector3(q.x, cos(a) * q.y, sin(a) * q.y))
		rows.append(ring)
	var hint := func(centre: Vector3, r: int, _c: int) -> Vector3:
		var q0: Vector2 = profile[r]
		var q1: Vector2 = profile[r + 1]
		var d := q1 - q0
		var n2 := Vector2(-d.y, d.x) * side
		var rad := Vector3(0.0, centre.y - at.y, centre.z - at.z).normalized()
		return Vector3(n2.x, 0.0, 0.0) + rad * n2.y
	grid(key, rows, full, hint)
	if not full and caps:
		for end in [0, 1]:
			var a := a0 if end == 0 else a1
			var ring := PackedVector3Array()
			var c := Vector3.ZERO
			for q: Vector2 in profile:
				var pt := at + Vector3(q.x, cos(a) * q.y, sin(a) * q.y)
				ring.append(pt)
				c += pt
			c /= profile.size()
			var tangent := Vector3(0.0, -sin(a), cos(a))
			fan(key, ring, c, tangent * (1.0 if end == 1 else -1.0))


## Rings swept through `rows` that are convex sections around their own centre: the outside is
## away from each ring's centre. Caps (fans) at the first and last ring when asked.
func loft(key: String, rows: Array, closed := true, cap0 := false, cap1 := false, cap_key := "") -> void:
	var centres := []
	for ring: PackedVector3Array in rows:
		var c := Vector3.ZERO
		for q in ring:
			c += q
		centres.append(c / ring.size())
	grid(key, rows, closed, func(centre: Vector3, r: int, _c: int) -> Vector3:
		return centre - (centres[r] as Vector3))
	var ck := key if cap_key.is_empty() else cap_key
	if cap0:
		fan(ck, rows[0], centres[0], (centres[0] as Vector3) - (centres[1] as Vector3))
	if cap1:
		var last := rows.size() - 1
		fan(ck, rows[last], centres[last], (centres[last] as Vector3) - (centres[last - 1] as Vector3))


## A flat-sided prism: polygon `poly` (Vector2 in the plane across `axis`: for "x" (z, y), "y"
## (x, z), "z" (x, y)) from a0 to a1 along the axis, sides flat-shaded, both ends capped.
func extrude(key: String, poly, axis: String, a0: float, a1: float) -> void:
	var mk := func(q: Vector2, a: float) -> Vector3:
		match axis:
			"x": return Vector3(a, q.y, q.x)
			"y": return Vector3(q.x, a, q.y)
		return Vector3(q.x, q.y, a)
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	var c0 := Vector3.ZERO
	for q: Vector2 in poly:
		r0.append(mk.call(q, a0))
		r1.append(mk.call(q, a1))
		c0 += mk.call(q, a0)
	c0 /= poly.size()
	var ax: Vector3 = mk.call(Vector2.ZERO, 1.0) - mk.call(Vector2.ZERO, 0.0)
	var p := part(key)
	for i in poly.size():
		var j: int = (i + 1) % poly.size()
		var face := [r0[i], r0[j], r1[j], r1[i]]
		var mid: Vector3 = (r0[i] + r0[j]) * 0.5
		var out: Vector3 = mid - c0
		out -= ax * out.dot(ax)
		var fn := ((face[1] as Vector3) - (face[0] as Vector3)).cross(ax)
		if fn.dot(out) < 0.0:
			fn = -fn
		fn = fn.normalized()
		var b := p.v.size()
		for q: Vector3 in face:
			p.v.append(q + offset)
			p.n.append(fn)
		p.tri(b, b + 1, b + 2, fn)
		p.tri(b, b + 2, b + 3, fn)
	fan(key, r0, c0, -ax * signf(a1 - a0))
	fan(key, r1, c0 + ax * (a1 - a0), ax * signf(a1 - a0))


## A copy of every part with x negated (the other side of the car).
func add_mirror_x(from: TmMesher) -> void:
	for key: String in from.parts:
		var src: Part = from.parts[key]
		var p := part(key)
		var base := p.v.size()
		for i in src.v.size():
			var q := src.v[i]
			p.v.append(Vector3(-q.x, q.y, q.z))
			var m := src.n[i]
			p.n.append(Vector3(-m.x, m.y, m.z))
		for t in range(0, src.idx.size(), 3):
			p.idx.append_array([base + src.idx[t], base + src.idx[t + 2], base + src.idx[t + 1]])


## Everything as one ArrayMesh, a surface per material key (sorted); keys() lists them in order.
func build() -> ArrayMesh:
	var am := ArrayMesh.new()
	for key in keys():
		var p: Part = parts[key]
		if p.idx.is_empty():
			continue
		var nn := PackedVector3Array()
		nn.resize(p.n.size())
		for i in p.n.size():
			var m := p.n[i]
			nn[i] = m.normalized() if m.length_squared() > 1e-20 else Vector3.UP
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p.v
		arrays[Mesh.ARRAY_NORMAL] = nn
		arrays[Mesh.ARRAY_INDEX] = p.idx
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_name(am.get_surface_count() - 1, key)
	return am


func keys() -> Array:
	var k := parts.keys().filter(func(x: String) -> bool: return not (parts[x] as Part).idx.is_empty())
	k.sort()
	return k


## A rounded polygon: the corners of `poly` (Vector2) filleted with radii `radii` (one per corner,
## clamped to half the shorter edge), `arc` points per corner and `mid` extra points along each
## edge: the same point count for the same corner count, whatever the radii (for lofts).
static func rounded(poly: Array, radii: Array, arc: int, mid: int, closed := true) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	var corners := []           # per corner: [start tangent point, arc points..., end tangent point]
	for i in n:
		var p: Vector2 = poly[i]
		if not closed and (i == 0 or i == n - 1):
			var one := []
			for k in arc:
				one.append(p)
			corners.append(one)
			continue
		var a: Vector2 = poly[(i - 1 + n) % n]
		var c: Vector2 = poly[(i + 1) % n]
		var u := a - p
		var w := c - p
		var lu := u.length()
		var lw := w.length()
		var pts := []
		if lu < 1e-6 or lw < 1e-6:
			for k in arc:
				pts.append(p)
			corners.append(pts)
			continue
		u /= lu
		w /= lw
		var th := acos(clampf(u.dot(w), -1.0, 1.0))
		var r := float(radii[i])
		if th > PI - 1e-3 or r <= 1e-6:
			for k in arc:
				pts.append(p)
			corners.append(pts)
			continue
		var t := r / tan(th * 0.5)
		var tmax := minf(lu, lw) * 0.5
		if t > tmax:
			t = tmax
			r = t * tan(th * 0.5)
		var t1 := p + u * t
		var t2 := p + w * t
		var centre := p + (u + w).normalized() * (r / sin(th * 0.5))
		var s0 := (t1 - centre).angle()
		var s1 := (t2 - centre).angle()
		var ds := wrapf(s1 - s0, -PI, PI)
		for k in arc:
			var f := float(k) / (arc - 1)
			pts.append(centre + Vector2.from_angle(s0 + ds * f) * r)
		corners.append(pts)
	for i in n:
		var pts: Array = corners[i]
		for q: Vector2 in pts:
			out.append(q)
		if not closed and i == n - 1:
			break
		var nxt: Array = corners[(i + 1) % n]
		var e0: Vector2 = pts[pts.size() - 1]
		var e1: Vector2 = nxt[0]
		for k in mid:
			out.append(e0.lerp(e1, float(k + 1) / (mid + 1)))
	return out


## Catmull-Rom through rows of numbers (stations), `per` samples per span; the last row as is.
static func resample(stations: Array, per: int) -> Array:
	var out := []
	var n := stations.size()
	var w := (stations[0] as Array).size()
	for i in n - 1:
		var p0: Array = stations[maxi(i - 1, 0)]
		var p1: Array = stations[i]
		var p2: Array = stations[i + 1]
		var p3: Array = stations[mini(i + 2, n - 1)]
		for s in per:
			var t := float(s) / per
			var row := []
			for k in w:
				var a := float(p0[k])
				var b := float(p1[k])
				var c := float(p2[k])
				var d := float(p3[k])
				row.append(0.5 * (2.0 * b + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t
					+ (3.0 * b - a - 3.0 * c + d) * t * t * t))
			out.append(row)
	out.append((stations[n - 1] as Array).duplicate())
	return out
