class_name StoryCabinKit
## The car's interior parts for the cutscenes' cabins (StoryCabin), built in code: rounded, pillowed
## boxes in leather, alcantara, satin plastic, soft-touch, carpet and aluminium with a fine grain in
## their normals (object-space triplanar, so it doesn't slide as the car drives). The seats as a
## sports car's (a pleated centre between bolsters, a shell behind, an integrated headrest), the dash
## sculpted (a soft top to the windscreen, a face, the driver's binnacle, a centre stack, vents), door
## cards (a panel, a belt cap the window drops into, an armrest, a lever), sun visors, a mirror's
## housing and stem. Everything shared is made once (materials, meshes by size); a shot's cabin only
## makes nodes.

static var _mats := {}
static var _meshes := {}


## A box with rounded edges (radius r) whose top, bottom, front and back faces bulge out by `pillow`
## at their middle (a cushion, a padded panel): `seg` quads across each face, more of them in the
## rounded bands. UVs in metres on each face's plane.
static func rbox(size: Vector3, r: float, pillow := 0.0, seg := 6) -> ArrayMesh:
	var key := "%s|%.4f|%.4f|%d" % [size, r, pillow, seg]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.95)
	var inner := h - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# each face: its normal axis and the two axes across it
	var faces := [[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var ha := absf(h.dot(a))
		var hb := absf(h.dot(b))
		var hn := absf(h.dot(n))
		var pts := []
		var ca := _coords(ha, r, seg)
		var cb := _coords(hb, r, seg)
		var bulge := pillow if absf(n.x) < 0.5 else 0.0          # (the sides don't bulge)
		for j in cb.size():
			var row := []
			for i in ca.size():
				var p: Vector3 = n * hn + a * float(ca[i]) + b * float(cb[j])
				var q := p.clamp(-inner, inner)
				var d := p - q
				var nn := d.normalized() if d.length() > 1e-6 else n
				var pos := q + nn * r
				var u := float(ca[i]) / ha
				var v := float(cb[j]) / hb
				pos += n * bulge * (1.0 - u * u) * (1.0 - v * v)
				row.append([pos, nn, Vector2(float(ca[i]), float(cb[j]))])
			pts.append(row)
		for j in cb.size() - 1:
			for i in ca.size() - 1:
				var c00: Array = pts[j][i]
				var c10: Array = pts[j][i + 1]
				var c01: Array = pts[j + 1][i]
				var c11: Array = pts[j + 1][i + 1]
				for c: Array in [c00, c11, c10, c00, c01, c11]:      # clockwise seen from outside
					st.set_normal(c[1])
					st.set_uv(c[2])
					st.add_vertex(c[0])
	st.generate_tangents()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Coordinates across a face from -half to half: the rounded bands (r wide at each end) sampled in
## 4 steps each, the flat middle in `seg`.
static func _coords(half: float, r: float, seg: int) -> Array:
	var out := []
	var flat := half - r
	for k in 4:
		out.append(-half + r * (1.0 - cos(PI * 0.5 * k / 4.0)))
	for k in seg + 1:
		out.append(-flat + 2.0 * flat * k / float(seg))
	for k in range(3, -1, -1):
		out.append(half - r * (1.0 - cos(PI * 0.5 * k / 4.0)))
	return out


## The kit's materials by name: "leather", "alcantara", "satin", "soft", "piano", "alu", "carpet",
## "headliner", "rubber", "housing".
static func mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	match name:
		"leather":
			m.albedo_color = Color(0.040, 0.038, 0.037)
			m.roughness = 0.62
			m.metallic_specular = 0.3
			_grain(m, "cellular", 0.09, 6.0, 0.5, 66.0)
		"alcantara":
			m.albedo_color = Color(0.055, 0.053, 0.052)
			m.roughness = 0.95
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.5
			_grain(m, "value", 0.5, 2.0, 0.35, 50.0)
		"satin":
			m.albedo_color = Color(0.045, 0.045, 0.048)
			m.roughness = 0.62
			_grain(m, "simplex", 0.35, 3.0, 0.3, 100.0)
		"soft":
			m.albedo_color = Color(0.035, 0.035, 0.037)
			m.roughness = 0.75
			_grain(m, "simplex", 0.35, 3.0, 0.25, 70.0)
		"piano":
			m.albedo_color = Color(0.012, 0.012, 0.013)
			m.roughness = 0.07
			m.clearcoat_enabled = true
		"alu":                                     # dark brushed metal: bright aluminium glinted like a lamp
			m.albedo_color = Color(0.26, 0.26, 0.28)
			m.metallic = 1.0
			m.roughness = 0.5
		"carpet":
			m.albedo_color = Color(0.028, 0.028, 0.03)
			m.roughness = 1.0
			_grain(m, "simplex", 0.25, 8.0, 0.8, 20.0)
		"headliner":                               # a sports car's black alcantara (the lining's dark too)
			m.albedo_color = Color(0.032, 0.031, 0.030)
			m.roughness = 0.95
			m.rim_enabled = true
			m.rim = 0.3
			_grain(m, "value", 0.5, 2.0, 0.35, 33.0)
		"rubber":
			m.albedo_color = Color(0.02, 0.02, 0.02)
			m.roughness = 0.45
		"housing":                                 # a mirror's back: near-black, matt, a faint edge sheen
			m.albedo_color = Color(0.014, 0.014, 0.015)
			m.roughness = 0.55
			m.metallic_specular = 0.35
	_mats[name] = m
	return m


## A fine grain in a material's normals: seamless noise made now (not on a thread, so the first
## frame is the same every time), turned into a normal map; `tiles` repeats a metre.
static func _grain(m: StandardMaterial3D, kind: String, freq: float, bump: float, strength: float, tiles: float) -> void:
	var n := FastNoiseLite.new()
	n.seed = 47
	n.frequency = freq
	match kind:
		"cellular":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
		"value":
			n.noise_type = FastNoiseLite.TYPE_VALUE
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
		_:
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
	var img := n.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(bump)
	img.generate_mipmaps()
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(img)
	m.normal_scale = strength
	m.uv1_scale = Vector3.ONE * tiles


## A part: an rbox of material `kind` under `parent` at `at`, turned by `rot` (degrees: x pitch, y
## yaw, z roll).
static func part(parent: Node3D, size: Vector3, r: float, kind: String, at: Vector3, rot := Vector3.ZERO, pillow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = rbox(size, r, pillow)
	mi.material_override = mat(kind)
	mi.position = at
	mi.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	parent.add_child(mi)
	return mi


## A front sports seat, its root at the cushion's middle (the cushion's top 6 cm over it, where the
## sitter rests): a pleated alcantara centre between leather bolsters, a back raked 12 degrees with its
## own bolsters and an integrated headrest, a satin shell behind, the base on two rails.
static func seat(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Seat"
	root.position = at
	root.set_meta("cushion", Vector3(0.5, 0.12, 0.48))        # the cushion's size, its top 6 cm over the root
	parent.add_child(root)
	part(root, Vector3(0.30, 0.10, 0.46), 0.03, "alcantara", Vector3(0.0, 0.01, 0.0), Vector3.ZERO, 0.012)
	for s: float in [-1.0, 1.0]:
		part(root, Vector3(0.10, 0.14, 0.48), 0.045, "leather", Vector3(0.215 * s, 0.03, 0.0), Vector3(0, 0, -10.0 * s))
		part(root, Vector3(0.11, 0.48, 0.17), 0.05, "leather", Vector3(0.20 * s, 0.27, -0.27), Vector3(-12.0, -12.0 * s, 0))
		part(root, Vector3(0.02, 0.03, 0.45), 0.008, "alu", Vector3(0.18 * s, -0.10, 0.0))
	part(root, Vector3(0.30, 0.60, 0.09), 0.04, "alcantara", Vector3(0.0, 0.32, -0.285), Vector3(-12.0, 0, 0), 0.015)
	part(root, Vector3(0.26, 0.20, 0.10), 0.05, "leather", Vector3(0.0, 0.74, -0.40), Vector3(-12.0, 0, 0))
	part(root, Vector3(0.50, 0.80, 0.05), 0.025, "satin", Vector3(0.0, 0.40, -0.37), Vector3(-12.0, 0, 0))
	for s: float in [-1.0, 1.0]:                   # the harness slots in the headrest's foot
		part(root, Vector3(0.055, 0.018, 0.012), 0.005, "piano", Vector3(0.07 * s, 0.62, -0.333), Vector3(-12.0, 0, 0))
	return root


## The rear bench, its root at the middle cushion: three places (the passenger sits at x 0), backs
## raked 18 degrees, two outer headrests on chrome posts.
static func bench(parent: Node3D, at: Vector3, width: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bench"
	root.position = at
	parent.add_child(root)
	var w := minf(0.40, (width - 0.06) / 3.0)
	root.set_meta("cushion", Vector3(w * 3.12, 0.12, 0.44))
	for i in [-1, 0, 1]:
		part(root, Vector3(w, 0.10, 0.44), 0.035, "leather", Vector3(w * 1.04 * i, 0.01, 0.0), Vector3.ZERO, 0.015)
		part(root, Vector3(w, 0.50, 0.09), 0.04, "leather", Vector3(w * 1.04 * i, 0.30, -0.28), Vector3(-18.0, 0, 0), 0.015)
	for s: float in [-1.0, 1.0]:
		part(root, Vector3(0.22, 0.14, 0.08), 0.04, "leather", Vector3(w * 1.04 * s, 0.70, -0.40), Vector3(-18.0, 0, 0))
		for k: float in [-1.0, 1.0]:
			part(root, Vector3(0.012, 0.10, 0.012), 0.005, "rubber", Vector3(w * 1.04 * s + 0.06 * k, 0.60, -0.37), Vector3(-18.0, 0, 0))
	return root


## The dash, sculpted from parts: a soft top running up to the windscreen's foot (its top at y0: the
## cameras over it), narrower than the cabin so its ends stay inside the side glass, a satin face
## the full width under the belt with a knee recess, the driver's binnacle and its cluster glowing
## under it, a centre stack (its face leaning back to the driver's eyes: StoryCabin sets the satnav in
## it, under the top, so cameras over the dash see past it), two outer vents, a glovebox line. `hw` its half width, `z0` its face,
## `belt` the window line (the face stays under it).
static func dash(parent: Node3D, hw: float, z0: float, driver_x: float, y0: float, belt: float) -> void:
	part(parent, Vector3((hw - 0.08) * 2.0, 0.20, 0.50), 0.06, "soft", Vector3(0.0, y0 - 0.10, z0 + 0.25), Vector3.ZERO, 0.01)
	var face_top := minf(y0 - 0.17, belt - 0.04)
	part(parent, Vector3(hw * 2.0, face_top - (y0 - 0.43), 0.10), 0.03, "satin", Vector3(0.0, (face_top + y0 - 0.43) * 0.5, z0 + 0.06), Vector3(20.0, 0, 0))
	part(parent, Vector3(0.34, 0.07, 0.16), 0.03, "soft", Vector3(driver_x, y0 + 0.03, z0 + 0.03))
	var c := MeshInstance3D.new()                  # the cluster under the binnacle's hood, facing the driver
	c.name = "Cluster"
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.105)
	c.mesh = q
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_texture = cluster_texture()
	cm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	c.material_override = cm
	c.position = Vector3(driver_x, y0 - 0.035, z0 + 0.0)
	c.rotation = Vector3(deg_to_rad(-12.0), PI, 0.0)          # a quad faces +z: turned to the seat, leaning back
	parent.add_child(c)
	part(parent, Vector3(0.30, 0.12, 0.02), 0.01, "piano", Vector3(driver_x, y0 - 0.035, z0 + 0.012), Vector3(12.0, 0, 0))
	var stack := part(parent, Vector3(0.26, 0.26, 0.06), 0.02, "piano", Vector3(0.0, y0 - 0.175, z0 - 0.02), Vector3(15.0, 0, 0))
	stack.name = "Stack"
	for s: float in [-1.0, 1.0]:
		part(parent, Vector3(0.11, 0.055, 0.02), 0.012, "alu", Vector3(s * (hw - 0.16), y0 - 0.075, z0 - 0.005))
		part(parent, Vector3(0.095, 0.042, 0.022), 0.01, "piano", Vector3(s * (hw - 0.16), y0 - 0.075, z0 - 0.008))
	part(parent, Vector3(0.36, 0.14, 0.02), 0.015, "satin", Vector3(-driver_x, face_top - 0.10, z0 + 0.0), Vector3(20.0, 0, 0))


## The cluster's face: two dials (a rev counter, a speedometer) in a dim cyan, their needles at rest,
## the red line; made once.
static var _cluster: ImageTexture
static func cluster_texture() -> ImageTexture:
	if _cluster != null:
		return _cluster
	var w := 320
	var h := 120
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.004, 0.005, 0.007))
	var dim := Color(0.10, 0.36, 0.52)
	var red := Color(0.75, 0.08, 0.05)
	for dial: int in 2:
		var cx := 80.0 + 160.0 * dial
		var cy := 62.0
		for y in h:
			for x in range(int(cx) - 60, int(cx) + 60):
				var d := Vector2(x - cx, y - cy)
				var r := d.length()
				var a := fposmod(atan2(d.x, -d.y) + PI, TAU)          # 0 at the bottom, clockwise
				if r > 48.0 and r < 50.0 and a > 0.7 and a < TAU - 0.7:
					img.set_pixel(x, y, red if dial == 0 and a > TAU - 1.6 else dim)
				var tick := fposmod((a - 0.7) / ((TAU - 1.4) / 10.0), 1.0)
				if r > 40.0 and r < 47.0 and a > 0.65 and a < TAU - 0.65 and (tick < 0.04 or tick > 0.96):
					img.set_pixel(x, y, red if dial == 0 and a > TAU - 1.6 else dim * 1.4)
				# the needle at rest, pointing down-left
				var nd := Vector2(-sin(0.75), cos(0.75))
				var along := d.dot(nd)
				if along > -6.0 and along < 42.0 and absf(d.cross(nd)) < 1.3:
					img.set_pixel(x, y, Color(0.85, 0.18, 0.08))
				if r < 4.0:
					img.set_pixel(x, y, Color(0.05, 0.05, 0.06))
	img.generate_mipmaps()
	_cluster = ImageTexture.create_from_image(img)
	return _cluster


## A door's card on side s (+1 the driver's), from zb (the B-pillar) to zf (a rear quarter's: no lever): a satin panel, a
## soft belt cap with a felt strip where the glass drops (its top at `belt`), an alcantara insert, a
## leather armrest, a dark satin lever in a piano-black recess.
static func door(parent: Node3D, s: float, x: float, zb: float, zf: float, belt: float, lever := true) -> void:
	var len := zf - zb
	var mid := (zb + zf) * 0.5
	part(parent, Vector3(0.03, 0.54, len), 0.012, "satin", Vector3(s * x, belt - 0.30, mid))
	part(parent, Vector3(0.07, 0.022, len), 0.01, "soft", Vector3(s * (x - 0.02), belt - 0.011, mid))
	part(parent, Vector3(0.008, 0.008, len - 0.04), 0.003, "rubber", Vector3(s * (x + 0.012), belt + 0.001, mid))
	part(parent, Vector3(0.012, 0.12, len * 0.7), 0.005, "alcantara", Vector3(s * (x - 0.018), belt - 0.09, mid - len * 0.05))
	part(parent, Vector3(0.085, 0.05, 0.40), 0.02, "leather", Vector3(s * (x - 0.045), belt - 0.36, mid - 0.04))
	if lever:
		part(parent, Vector3(0.012, 0.03, 0.12), 0.006, "piano", Vector3(s * (x - 0.018), belt - 0.21, zf - 0.30))
		part(parent, Vector3(0.012, 0.018, 0.10), 0.006, "satin", Vector3(s * (x - 0.024), belt - 0.21, zf - 0.30))   # (brushed, it glared white under a bright sky)


## A sun visor on side s under the roof at `top` (the headlining's height there), its front at z.
static func visor(parent: Node3D, s: float, top: float, z: float) -> void:
	part(parent, Vector3(0.36, 0.022, 0.16), 0.01, "soft", Vector3(s * 0.36, top - 0.034, z - 0.08), Vector3(-6.0, 0, 0))
	part(parent, Vector3(0.012, 0.01, 0.03), 0.004, "satin", Vector3(s * 0.17, top - 0.03, z - 0.01))
