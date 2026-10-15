class_name MeshKit
extends RefCounted
## Procedural geometry accumulator. Collects triangles per material key, then commits them into one
## ArrayMesh with one surface per key (so a whole car body is a handful of draw calls).
##
## Winding is fixed automatically: every triangle is oriented so its front face points along the
## normals supplied with it. Godot treats clockwise triangles as front-facing.

## key -> {"v": PackedVector3Array, "n": PackedVector3Array, "c": PackedColorArray, "uv": PackedVector2Array}
var surfaces: Dictionary = {}
## When true every triangle is also emitted mirrored across x = 0 (build half a car, get a whole one).
var mirror_x := false
## Current vertex color written with each vertex (shaders use it as a per-vertex tag).
var color := Color(1, 1, 1, 1)


func _surf(key: String) -> Dictionary:
	if not surfaces.has(key):
		surfaces[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array()}
	return surfaces[key]


func tri_count() -> int:
	var n := 0
	for k in surfaces:
		n += surfaces[k]["v"].size() / 3
	return n


## Adds one triangle with per-vertex normals. Orientation follows the normals.
func tri(key: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO) -> void:
	_tri_one(key, a, b, c, na, nb, nc, uva, uvb, uvc)
	if mirror_x:
		var m := Vector3(-1, 1, 1)
		_tri_one(key, a * m, b * m, c * m, na * m, nb * m, nc * m, uva, uvb, uvc)


func _tri_one(key: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-14:
		return
	var s := _surf(key)
	var v: PackedVector3Array = s["v"]
	var n: PackedVector3Array = s["n"]
	var col: PackedColorArray = s["c"]
	var uv: PackedVector2Array = s["uv"]
	# Clockwise front faces: the geometric cross product must point away from the normal.
	if cr.dot(na + nb + nc) > 0.0:
		v.append(a); v.append(c); v.append(b)
		n.append(na); n.append(nc); n.append(nb)
		uv.append(uva); uv.append(uvc); uv.append(uvb)
	else:
		v.append(a); v.append(b); v.append(c)
		n.append(na); n.append(nb); n.append(nc)
		uv.append(uva); uv.append(uvb); uv.append(uvc)
	col.append(color); col.append(color); col.append(color)
	s["v"] = v
	s["n"] = n
	s["c"] = col
	s["uv"] = uv


## Flat-shaded triangle facing `outward` (any vector on the front side).
func flat_tri(key: String, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var nn := (b - a).cross(c - a).normalized()
	if nn.dot(outward) < 0.0:
		nn = -nn
	tri(key, a, b, c, nn, nn, nn)


## Flat quad a-b-c-d (in order around the edge) facing `outward`.
func flat_quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	flat_tri(key, a, b, c, outward)
	flat_tri(key, a, c, d, outward)


## Smooth quad with per-corner normals.
func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO, uvd := Vector2.ZERO) -> void:
	tri(key, a, b, c, na, nb, nc, uva, uvb, uvc)
	tri(key, a, c, d, na, nc, nd, uva, uvc, uvd)


## Box with flat faces. `basis` rotates (and may scale) the unit box around `center`.
func box(key: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY, skip_bottom := false) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		var p := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		corners.append(center + basis * p)
	# faces: indices into corners, outward direction in local space
	var faces := [
		[[1, 3, 7, 5], Vector3.RIGHT], [[0, 4, 6, 2], Vector3.LEFT],
		[[2, 6, 7, 3], Vector3.UP], [[0, 1, 5, 4], Vector3.DOWN],
		[[4, 5, 7, 6], Vector3.BACK], [[0, 2, 3, 1], Vector3.FORWARD],
	]
	for f in faces:
		if skip_bottom and f[1] == Vector3.DOWN:
			continue
		var idx: Array = f[0]
		var out: Vector3 = basis * f[1]
		flat_quad(key, corners[idx[0]], corners[idx[1]], corners[idx[2]], corners[idx[3]], out)


## Prism: a convex-or-not 2D polygon (in the plane spanned by `ax`, `ay`) extruded along `az` by
## `depth`, centered on `origin`. Side faces are flat; caps are fanned (polygon should be star-shaped
## around its centroid).
func prism(key: String, origin: Vector3, poly: PackedVector2Array, ax: Vector3, ay: Vector3, az: Vector3,
		depth: float, caps := true, smooth_sides := false) -> void:
	var n := poly.size()
	var hz := az * depth * 0.5
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= float(n)
	var c3 := origin + ax * cen.x + ay * cen.y
	for i in n:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		var a := origin + ax * p0.x + ay * p0.y
		var b := origin + ax * p1.x + ay * p1.y
		var out := ((a + b) * 0.5 - c3)
		if smooth_sides:
			var na := (a - c3).normalized()
			var nb := (b - c3).normalized()
			quad(key, a - hz, b - hz, b + hz, a + hz, na, nb, nb, na)
		else:
			flat_quad(key, a - hz, b - hz, b + hz, a + hz, out)
		if caps:
			flat_tri(key, c3 + hz, a + hz, b + hz, az)
			flat_tri(key, c3 - hz, a - hz, b - hz, -az)


## Cylinder (or cone/tube) along `axis` from `base`. r0 at base, r1 at the top.
func cylinder(key: String, base: Vector3, axis: Vector3, length: float, r0: float, r1: float, segs: int,
		cap_base := true, cap_top := true) -> void:
	var ax := axis.normalized()
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := ax.cross(u).normalized()
	var top := base + ax * length
	var slope := (r0 - r1) / maxf(length, 0.0001)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var d0 := u * cos(a0) + w * sin(a0)
		var d1 := u * cos(a1) + w * sin(a1)
		var n0 := (d0 + ax * slope).normalized()
		var n1 := (d1 + ax * slope).normalized()
		quad(key, base + d0 * r0, base + d1 * r0, top + d1 * r1, top + d0 * r1, n0, n1, n1, n0)
		if cap_base and r0 > 0.0:
			flat_tri(key, base, base + d0 * r0, base + d1 * r0, -ax)
		if cap_top and r1 > 0.0:
			flat_tri(key, top, top + d0 * r1, top + d1 * r1, ax)


## Surface of revolution around the X axis (wheels). `profile` = Array of Vector2(x, radius).
## Normals come from the profile (smooth around the axis). UV.x = angle 0..1, UV.y = profile index fraction.
## `crease` lists profile indices whose normals are not smoothed along the profile.
func revolve_x(key: String, profile: PackedVector2Array, segs: int, crease: Array = [], a_from := 0.0, a_to := TAU) -> void:
	var m := profile.size()
	# profile normals (2D, in (x, r) space), split at creases
	for j in m - 1:
		var p0 := profile[j]
		var p1 := profile[j + 1]
		var t := (p1 - p0)
		if t.length_squared() < 1e-12:
			continue
		var nseg := Vector2(-t.y, t.x).normalized()  # outward when the profile runs inner->outer
		var n0 := nseg
		var n1 := nseg
		if j > 0 and not (j in crease):
			var tp := profile[j] - profile[j - 1]
			if tp.length_squared() > 1e-12:
				n0 = (nseg + Vector2(-tp.y, tp.x).normalized()).normalized()
		if j + 2 < m and not ((j + 1) in crease):
			var tn := profile[j + 2] - profile[j + 1]
			if tn.length_squared() > 1e-12:
				n1 = (nseg + Vector2(-tn.y, tn.x).normalized()).normalized()
		for i in segs:
			var a0 := lerpf(a_from, a_to, float(i) / float(segs))
			var a1 := lerpf(a_from, a_to, float(i + 1) / float(segs))
			var r0 := Vector3(0, cos(a0), sin(a0))
			var r1 := Vector3(0, cos(a1), sin(a1))
			var v00 := Vector3(p0.x, 0, 0) + r0 * p0.y
			var v01 := Vector3(p0.x, 0, 0) + r1 * p0.y
			var v10 := Vector3(p1.x, 0, 0) + r0 * p1.y
			var v11 := Vector3(p1.x, 0, 0) + r1 * p1.y
			var nn00 := Vector3(n0.x, 0, 0) + r0 * n0.y
			var nn01 := Vector3(n0.x, 0, 0) + r1 * n0.y
			var nn10 := Vector3(n1.x, 0, 0) + r0 * n1.y
			var nn11 := Vector3(n1.x, 0, 0) + r1 * n1.y
			var fu0 := float(i) / float(segs)
			var fu1 := float(i + 1) / float(segs)
			var fv0 := float(j) / float(m - 1)
			var fv1 := float(j + 1) / float(m - 1)
			quad(key, v00, v01, v11, v10, nn00, nn01, nn11, nn10,
				Vector2(fu0, fv0), Vector2(fu1, fv0), Vector2(fu1, fv1), Vector2(fu0, fv1))


## Lofted grid. `rows[i]` is a PackedVector3Array of points (same count per row).
## Normals are computed from the grid as cross(d/du, d/dv) * `sign` (u = along a row, v = across rows),
## central differences inside, one-sided at the borders and at crease columns/rows.
## `mat_fn` (optional Callable(i, j, center: Vector3) -> String) chooses the material per cell; "" skips it.
func grid(key: String, rows: Array, sign := 1.0, crease_cols: Array = [], crease_rows: Array = [],
		mat_fn := Callable(), color_fn := Callable()) -> void:
	var nr := rows.size()
	if nr < 2:
		return
	var nc: int = rows[0].size()
	_centers.clear()
	if sign == 0.0:
		# auto orientation: normals point away from each row's centroid (closed convex-ish profiles)
		for row in rows:
			var c := Vector3.ZERO
			for q in (row as PackedVector3Array):
				c += q
			_centers.append(c / float((row as PackedVector3Array).size()))
	for i in nr - 1:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		for j in nc - 1:
			var a := r0[j]
			var b := r0[j + 1]
			var c := r1[j + 1]
			var d := r1[j]
			var k := key
			if mat_fn.is_valid():
				k = mat_fn.call(i, j, (a + b + c + d) * 0.25)
				if k == "":
					continue
			if color_fn.is_valid():
				color = color_fn.call(i, j, (a + b + c + d) * 0.25)
			var na := _grid_normal(rows, i, j, i, j, sign, crease_cols, crease_rows)
			var nb := _grid_normal(rows, i, j + 1, i, j, sign, crease_cols, crease_rows)
			var ncn := _grid_normal(rows, i + 1, j + 1, i, j, sign, crease_cols, crease_rows)
			var nd := _grid_normal(rows, i + 1, j, i, j, sign, crease_cols, crease_rows)
			quad(k, a, b, c, d, na, nb, ncn, nd)
	if color_fn.is_valid():
		color = Color(1, 1, 1, 1)


func _grid_normal(rows: Array, i: int, j: int, ci: int, cj: int, sign: float, crease_cols: Array, crease_rows: Array) -> Vector3:
	var nr := rows.size()
	var row: PackedVector3Array = rows[i]
	var nc := row.size()
	# derivative along u (within row)
	var j0 := j - 1
	var j1 := j + 1
	if j == 0 or (j in crease_cols and cj >= j):
		j0 = j
	if j == nc - 1 or (j in crease_cols and cj < j):
		j1 = j
	if j0 == j and j1 == j:
		j1 = mini(j + 1, nc - 1)
		j0 = maxi(j - 1, 0)
	var du := row[j1] - row[j0]
	# derivative along v (across rows)
	var i0 := i - 1
	var i1 := i + 1
	if i == 0 or (i in crease_rows and ci >= i):
		i0 = i
	if i == nr - 1 or (i in crease_rows and ci < i):
		i1 = i
	var dv: Vector3 = rows[i1][j] - rows[i0][j]
	# degenerate derivatives (collapsed rows/cols): fall back to neighbors
	if du.length_squared() < 1e-12:
		var jj := clampi(cj + 1, 0, nc - 1)
		du = row[jj] - row[cj]
		if du.length_squared() < 1e-12:
			for off in [1, 2, 3, -1, -2]:
				var ii := clampi(i + off, 0, nr - 1)
				var rr: PackedVector3Array = rows[ii]
				du = rr[mini(cj + 1, nc - 1)] - rr[cj]
				if du.length_squared() > 1e-12:
					break
	if dv.length_squared() < 1e-12:
		for off in [1, -1, 2, -2]:
			var jj := clampi(j + off, 0, nc - 1)
			dv = rows[mini(ci + 1, nr - 1)][jj] - rows[ci][jj]
			if dv.length_squared() > 1e-12:
				break
	var nrm := du.cross(dv) * (sign if sign != 0.0 else 1.0)
	if nrm.length_squared() < 1e-14:
		return Vector3.UP
	if sign == 0.0 and nrm.dot(rows[i][j] - _centers[i]) < 0.0:
		nrm = -nrm
	return nrm.normalized()


var _centers: Array[Vector3] = []


## Builds the ArrayMesh. `materials` maps key -> Material. Returns [mesh, keys_in_surface_order].
func commit(materials: Dictionary, into: ArrayMesh = null) -> ArrayMesh:
	var mesh := into if into else ArrayMesh.new()
	var keys := surfaces.keys()
	keys.sort()
	for k in keys:
		var s: Dictionary = surfaces[k]
		if (s["v"] as PackedVector3Array).is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s["v"]
		arr[Mesh.ARRAY_NORMAL] = s["n"]
		arr[Mesh.ARRAY_COLOR] = s["c"]
		arr[Mesh.ARRAY_TEX_UV] = s["uv"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_name(idx, k)
		if materials.has(k):
			mesh.surface_set_material(idx, materials[k])
	return mesh
