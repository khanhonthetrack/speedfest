class_name PhysicsTestGround
extends RefCounted
## Builds test geometry for the physics tests without depending on the tracks module:
## road strips from a TrackPath (trimesh collision, layer 1), flat pads, walls, and sample paths.


static func _road_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## A road strip along `path` (both sides collide). Optional side walls of height `wall_h`.
static func road_from_path(path: TrackPath, wall_h: float = 0.0, step: float = 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var faces := PackedVector3Array()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var n := int(ceil(path.length / step))
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_lt := Vector3.ZERO
	var prev_rt := Vector3.ZERO
	for i in n + 1:
		var d := minf(i * step, path.length)
		if path.is_circuit and i == n:
			d = 0.0
		var t := path.sample_transform(d)
		var hw := path.width_at(d) * 0.5
		var l := t.origin - t.basis.x * hw
		var r := t.origin + t.basis.x * hw
		var lt := l + t.basis.y * wall_h
		var rt := r + t.basis.y * wall_h
		if i > 0:
			var c := Color(0.22, 0.22, 0.25) if (i / 10) % 2 == 0 else Color(0.32, 0.30, 0.34)
			_quad(faces, verts, cols, prev_l, l, r, prev_r, c)
			if wall_h > 0.0:
				var wc := Color(0.9, 0.2, 0.6)
				_quad(faces, verts, cols, prev_l, prev_lt, lt, l, wc)
				_quad(faces, verts, cols, prev_r, r, rt, prev_rt, wc)
		prev_l = l
		prev_r = r
		prev_lt = lt
		prev_rt = rt
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _road_material()
	body.add_child(mi)
	return body


static func _quad(faces: PackedVector3Array, verts: PackedVector3Array, cols: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for p in [a, b, c, a, c, d]:
		faces.append(p)
		verts.append(p)
		cols.append(col)


## Flat box ground: top surface at y = top_y, centered at `center` (x, z).
static func flat_pad(size_x: float, size_z: float, center: Vector3 = Vector3.ZERO, top_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size_x, 2.0, size_z)
	cs.shape = box
	body.add_child(cs)
	body.position = Vector3(center.x, top_y - 1.0, center.z)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.26)
	mat.uv1_triplanar = true
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	return body


## A wall (box) from a to b on the ground, height h, thickness 1.
static func wall(a: Vector3, b: Vector3, h: float = 2.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, h, a.distance_to(b))
	cs.shape = box
	body.add_child(cs)
	var mid := (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
	body.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), mid)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.6)
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	return body


# --- sample paths -----------------------------------------------------------------------------

## Straight -> vertical loop of radius r (with a lateral shift) -> straight. Starts at `origin`, heading -Z.
static func loop_path(r: float = 18.0, lead: float = 220.0, tail: float = 150.0, width: float = 12.0, origin: Vector3 = Vector3.ZERO) -> TrackPath:
	var c := Curve3D.new()
	c.bake_interval = 0.5
	var shift := width + 2.0
	c.add_point(origin + Vector3(0, 0, 0))
	c.add_point(origin + Vector3(0, 0, -lead * 0.5))
	var n := 32
	for i in n + 1:
		var a := TAU * i / n
		# ease the lateral shift so the loop's ends stay straight
		var f := (1.0 - cos(PI * float(i) / n)) * 0.5
		c.add_point(origin + Vector3(shift * f, r - r * cos(a), -lead - r * sin(a)))
	c.add_point(origin + Vector3(shift, 0, -lead - tail * 0.5))
	c.add_point(origin + Vector3(shift, 0, -lead - tail))
	_smooth(c)
	var p := TrackPath.new(c, false, width)
	var loop_from := p.closest_distance(origin + Vector3(0, 0, -lead)) - 5.0
	p.zones = [{"from": loop_from, "to": loop_from + TAU * r + 15.0, "kind": "loop"}]
	return p


## Straight -> ramp (angle_deg, ramp_len) -> gap -> landing down-ramp -> straight.
static func jump_ramp(angle_deg: float = 12.0, ramp_len: float = 22.0, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	var a := deg_to_rad(angle_deg)
	var h := sin(a) * ramp_len
	var ramp := _slab(Vector3(14, 0.5, ramp_len), -a, origin + Vector3(0, h * 0.5 - 0.25 * cos(a), -ramp_len * 0.5 * cos(a)))
	root.add_child(ramp)
	return root


static func _slab(size: Vector3, pitch: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.transform = Transform3D(Basis(Vector3.RIGHT, pitch), pos)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.6, 0.9)
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	return body


## A closed test circuit: straights, a hairpin, sweepers, a banked turn and some elevation.
static func circuit_path(width: float = 14.0) -> TrackPath:
	var c := Curve3D.new()
	c.bake_interval = 0.5
	var pts := [
		Vector3(0, 0, 0), Vector3(0, 0, -150), Vector3(0, 2, -300), Vector3(40, 6, -400),
		Vector3(140, 8, -430), Vector3(230, 6, -380), Vector3(260, 3, -290), Vector3(230, 0, -220),
		Vector3(180, 0, -200), Vector3(150, 0, -150), Vector3(180, 0, -90), Vector3(250, 0, -60),
		Vector3(280, 0, 20), Vector3(240, 0, 100), Vector3(130, 0, 130), Vector3(40, 0, 100),
	]
	for p in pts:
		c.add_point(p)
	c.add_point(pts[0])
	c.set_point_tilt(4, 0.12)
	c.set_point_tilt(5, 0.15)
	_smooth(c, 0.35)
	return TrackPath.new(c, true, width)


## Catmull-Rom style handles so the curve is smooth through its points.
static func _smooth(c: Curve3D, k: float = 0.3) -> void:
	var n := c.point_count
	for i in n:
		var prev := c.get_point_position(maxi(i - 1, 0))
		var next := c.get_point_position(mini(i + 1, n - 1))
		if i == 0 or i == n - 1:
			var closed := c.get_point_position(0).distance_to(c.get_point_position(n - 1)) < 0.01
			if closed:
				prev = c.get_point_position(n - 2)
				next = c.get_point_position(1)
		var tan := (next - prev) * k * 0.5
		c.set_point_in(i, -tan)
		c.set_point_out(i, tan)
