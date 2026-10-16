class_name TmGeo
extends RefCounted
## Block geometry builder. Faces are authored in TMNF block-local coordinates (x right, y up, z
## forward, metres; the measured block data uses them), front side = (b - a) x (c - a); build()
## converts to Godot (x negated: the mirror and Godot's clockwise front faces cancel, so the vertex
## order is kept). Visual triangles are grouped per material key (TmMaterials); collision faces
## carry a TMNF surface id each (TmTuning.Surface), stored as the body's "surfaces" meta (per face).

const NO_COLLISION := -1

class Group:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()

var _vis := {}                      ## material key -> Group
var _col := PackedVector3Array()
var _surf := PackedInt32Array()


static func g(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, p.z)


func _group(mat: String) -> Group:
	if not _vis.has(mat):
		_vis[mat] = Group.new()
	return _vis[mat]


## One triangle (TMNF coords). mat "" = collision only; surface NO_COLLISION = visual only.
## Normals: flat unless given (smooth sweeps pass vertex normals).
func tri(a: Vector3, b: Vector3, c: Vector3, mat: String, surface: int, na := Vector3.ZERO,
		nb := Vector3.ZERO, nc := Vector3.ZERO, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if not mat.is_empty():
		var grp := _group(mat)
		var auto_uv := ua == Vector2.ZERO and ub == Vector2.ZERO and uc == Vector2.ZERO
		for k in 3:
			var p: Vector3 = [a, b, c][k]
			var vn: Vector3 = [na, nb, nc][k]
			grp.v.append(g(p))
			grp.n.append(g(n if vn == Vector3.ZERO else vn))
			grp.uv.append(_tri_uv(p, n) if auto_uv else [ua, ub, uc][k])
	if surface != NO_COLLISION:
		_col.append(g(a))
		_col.append(g(b))
		_col.append(g(c))
		_surf.append(surface)


## Quad a-b-c-d around its edge, front = (b - a) x (c - a).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: String, surface: int) -> void:
	tri(a, b, c, mat, surface)
	tri(a, c, d, mat, surface)


## World-aligned UVs in metres / 8 (texture tiles every 8 m), projected on the dominant axis.
static func _tri_uv(p: Vector3, n: Vector3) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) / 8.0
	if an.x >= an.z:
		return Vector2(p.z, p.y) / 8.0
	return Vector2(p.x, p.y) / 8.0


## Axis-aligned box [lo, hi] (TMNF coords), all six faces outward.
func box(lo: Vector3, hi: Vector3, mat: String, surface: int, top_mat := "", top_surface := -2) -> void:
	var tm := mat if top_mat.is_empty() else top_mat
	var ts := surface if top_surface == -2 else top_surface
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	quad(p[4], p[7], p[6], p[5], tm, ts)          # top (+y)
	quad(p[0], p[1], p[2], p[3], mat, surface)    # bottom (-y)
	quad(p[0], p[4], p[5], p[1], mat, surface)    # -z
	quad(p[2], p[6], p[7], p[3], mat, surface)    # +z
	quad(p[3], p[7], p[4], p[0], mat, surface)    # -x
	quad(p[1], p[5], p[6], p[2], mat, surface)    # +x


## Sweep a 2D profile along frames. profile: Array of [Vector2(lateral, up), mat, surface] points;
## segment k (point k -> k+1) uses point k's mat/surface. frames: Array[Transform3D] (TMNF coords:
## basis.x = lateral, basis.y = up, origin = profile origin). The front side is to the right of the
## profile's direction of travel when looking along +frame z... i.e. author profiles so that
## (p[k+1] - p[k]) turned by -90 deg (lateral, up) -> (up, -lateral) is the outward normal.
func sweep(profile: Array, frames: Array, smooth := false) -> void:
	for f in frames.size() - 1:
		var f0: Transform3D = frames[f]
		var f1: Transform3D = frames[f + 1]
		for k in profile.size() - 1:
			var p0: Vector2 = profile[k][0]
			var p1: Vector2 = profile[k + 1][0]
			var mat: String = profile[k][1]
			var surf: int = profile[k][2]
			var a := f0.origin + f0.basis.x * p0.x + f0.basis.y * p0.y
			var b := f0.origin + f0.basis.x * p1.x + f0.basis.y * p1.y
			var c := f1.origin + f1.basis.x * p1.x + f1.basis.y * p1.y
			var d := f1.origin + f1.basis.x * p0.x + f1.basis.y * p0.y
			quad(a, b, c, d, mat, surf)


## Sweeps a closed vertical section along a path. section: Array of [Vector2(d, y), mat, surface]
## where d is the offset along `outward` (horizontal unit vector per path point) and y the height
## above the path point. Any loop orientation and path direction: both are fixed so faces point
## out. caps: close both ends with the section polygon (cap_mat, cap_surface).
func wall_sweep(section: Array, path: Array, outward: Array, caps := true, cap_mat := "wall_dark", cap_surface := 4) -> void:
	var loop := section.duplicate()
	if TmGeo.loop_area(loop) < 0.0:
		loop = TmGeo.reversed_loop(loop)
	var pts := path.duplicate()
	var outs := outward.duplicate()
	# frames: lateral L = outward, up U, travel F = L x U; the path must run along F
	var f0 := (outs[0] as Vector3).cross(Vector3.UP)
	if f0.dot((pts[1] as Vector3) - (pts[0] as Vector3)) < 0.0:
		pts.reverse()
		outs.reverse()
	var frames := []
	for i in pts.size():
		var l: Vector3 = outs[i]
		frames.append(Transform3D(Basis(l, Vector3.UP, l.cross(Vector3.UP)), pts[i]))
	var closed := loop.duplicate()
	closed.append(loop[0])
	sweep(closed, frames)
	if caps:
		_section_cap(loop, frames[0], -1.0, cap_mat, cap_surface)
		_section_cap(loop, frames[frames.size() - 1], 1.0, cap_mat, cap_surface)


## Polygon cap of a section at a frame, facing along +frame z (side > 0) or -z.
func _section_cap(loop: Array, frame: Transform3D, side: float, mat: String, surface: int) -> void:
	var poly := PackedVector2Array()
	for p in loop:
		poly.append(p[0])
	var idx := Geometry2D.triangulate_polygon(poly)
	var fwd := frame.basis.z * side
	for k in range(0, idx.size(), 3):
		var pts := []
		for j in 3:
			var q: Vector2 = poly[idx[k + j]]
			pts.append(frame.origin + frame.basis.x * q.x + frame.basis.y * q.y)
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[1]
		var c: Vector3 = pts[2]
		if (b - a).cross(c - a).dot(fwd) < 0.0:
			tri(a, c, b, mat, surface)
		else:
			tri(a, b, c, mat, surface)


## Horizontal polygon (TMNF x, z points) at height y, facing up (or down if down).
func flat_polygon(poly: PackedVector2Array, y: float, mat: String, surface: int, down := false) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in range(0, idx.size(), 3):
		var a := Vector3(poly[idx[k]].x, y, poly[idx[k]].y)
		var b := Vector3(poly[idx[k + 1]].x, y, poly[idx[k + 1]].y)
		var c := Vector3(poly[idx[k + 2]].x, y, poly[idx[k + 2]].y)
		if ((b - a).cross(c - a).y < 0.0) != down:
			tri(a, c, b, mat, surface)
		else:
			tri(a, b, c, mat, surface)


static func loop_area(loop: Array) -> float:
	var a := 0.0
	for i in loop.size():
		var p: Vector2 = loop[i][0]
		var q: Vector2 = loop[(i + 1) % loop.size()][0]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Reverses a section loop; each segment keeps its material (moved to its new start point).
static func reversed_loop(loop: Array) -> Array:
	var n := loop.size()
	var out := []
	for i in n:
		var p: Array = loop[n - 1 - i]
		var seg: Array = loop[(n - 2 - i + n) % n]
		out.append([p[0], seg[1], seg[2]])
	return out


## Points of an arc in the TMNF x-z plane: centre c (x, z), radius r, angles a0 -> a1 (radians,
## measured from +x toward +z), at height y; and the radial unit vectors (outward from c).
static func arc(c: Vector2, r: float, a0: float, a1: float, y: float, steps: int) -> Array:
	var pts := []
	var rad := []
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		var d := Vector3(cos(a), 0.0, sin(a))
		pts.append(Vector3(c.x, y, c.y) + d * r)
		rad.append(d)
	return [pts, rad]


func is_empty() -> bool:
	return _vis.is_empty() and _col.is_empty()


## A Node3D: one MeshInstance3D (a surface per material) and a StaticBody3D (layer 1) whose
## "surfaces" meta holds the TMNF surface id of each collision face.
func build() -> Node3D:
	var root := Node3D.new()
	if not _vis.is_empty():
		var mesh := ArrayMesh.new()
		var keys := _vis.keys()
		keys.sort()
		for key in keys:
			var grp: Group = _vis[key]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = grp.v
			arrays[Mesh.ARRAY_NORMAL] = grp.n
			arrays[Mesh.ARRAY_TEX_UV] = grp.uv
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, TmMaterials.get_material(String(key)))
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		root.add_child(mi)
	if not _col.is_empty():
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(_col)
		cs.shape = shape
		body.add_child(cs)
		body.set_meta("surfaces", _surf)
		root.add_child(body)
	return root
