class_name SceneryCoastKit
extends RefCounted
## "coast" theme props: dusk clifftop coast road. Terrain that hugs the road with cliffs down to
## the sea on one side and hills on the other (a bay opens under bridges), an animated sea,
## palms, rocks and sea stacks, reflector posts, warm street lamps, a lighthouse with a rotating
## beam, distant town lights, islands and mountain silhouettes, and a rock hill over tunnels.
## The sea is on the left of the direction of travel unless the path carries
## `path.set_meta("sea_side", 1.0)` (right).

const SEA_LEVEL := 0.0

var field: SceneryField
var root: Node3D
var rng := RandomNumberGenerator.new()
var terrain: SceneryTerrain
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var sea_side: float = -1.0
var seaward := Vector3.LEFT
var bay := PackedFloat32Array()     # per field sample: 1 on/near bridges
var batches := SceneryBatches.new(300.0)
var footprints: Array = []
var stats := {}


func build(p_field: SceneryField, rng_seed: int) -> Node3D:
	field = p_field
	rng.seed = rng_seed
	root = Node3D.new()
	root.name = "CoastProps"
	noise.seed = rng_seed
	noise.frequency = 0.004
	noise.fractal_octaves = 4
	noise2.seed = rng_seed + 11
	noise2.frequency = 0.02
	if field.path.has_meta("sea_side"):
		sea_side = signf(float(field.path.get_meta("sea_side")))
	var acc := Vector3.ZERO
	for i in field.count:
		acc += field.rgt[i] * sea_side
	acc.y = 0.0
	seaward = acc.normalized() if acc.length() > 0.01 else Vector3.LEFT
	_bay_weights()
	batches.register("neon", SceneryMat.neon(3.0), 900.0, false)
	batches.register("rock", SceneryMat.shader_mat("terrain", {"mode": 2, "sea_level": SEA_LEVEL}), 0.0, true)
	batches.register("metal", SceneryMat.vcolor(0.6, 0.3), 600.0, true)
	batches.register("far", SceneryMat.vcolor(0.95, 0.0), 0.0, false)
	_terrain()
	_sea()
	_tunnel_hills()
	_palms()
	_rocks()
	_posts_and_lamps()
	_lighthouse()
	_town()
	_far_silhouettes()
	batches.build(root)
	stats["duplicates"] = 0
	root.set_meta("footprints", footprints)
	root.set_meta("stats", stats)
	return root


func _bay_weights() -> void:
	bay.resize(field.count)
	bay.fill(0.0)
	var reach := 25   # samples (4 m each) of fade around a bridge
	for i in field.count:
		if field.has_zone(i, "bridge"):
			for k in range(maxi(i - reach, 0), mini(i + reach + 1, field.count)):
				var w := 1.0 - float(absi(k - i)) / reach
				bay[k] = maxf(bay[k], w * w * (3.0 - 2.0 * w))


func _far_height(x: float, z: float, side: float, road_y: float, ed: float, i: int) -> float:
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var n2 := noise2.get_noise_2d(x, z)
	var h: float
	var b := bay[i] if i >= 0 else 0.0
	if side == sea_side:
		var drop := smoothstep(0.0, 70.0 + n * 40.0, ed)
		h = lerpf(road_y - 1.5, SEA_LEVEL - 10.0 - n * 8.0, drop) + n2 * 3.0 * (1.0 - drop)
		# rocky points that stick out into the sea
		if n > 0.68:
			h = maxf(h, SEA_LEVEL + (n - 0.68) * 90.0 * (1.0 - smoothstep(120.0, 260.0, ed)))
	else:
		var rise := smoothstep(0.0, 320.0, ed)
		h = road_y + 1.0 + rise * (35.0 + n * 85.0) + n2 * 4.0 * smoothstep(0.0, 40.0, ed)
		h = lerpf(h, SEA_LEVEL - 9.0, b * (1.0 - smoothstep(60.0, 240.0, ed)))
	if terrain != null:
		# fade to sea at the edge of the terrain grid (islands-like border)
		var bx := minf(x - terrain.origin.x, terrain.origin.x + (terrain.nx - 1) * terrain.cell - x)
		var bz := minf(z - terrain.origin.y, terrain.origin.y + (terrain.nz - 1) * terrain.cell - z)
		var edge_k := smoothstep(0.0, 260.0, minf(bx, bz))
		h = lerpf(SEA_LEVEL - 25.0, h, edge_k)
	return h


func _terrain() -> void:
	terrain = SceneryTerrain.new(field)
	terrain.cell = 14.0 if Settings.quality >= 2 else (18.0 if Settings.quality == 1 else 24.0)
	terrain.margin = 650.0
	terrain.base = SEA_LEVEL - 10.0
	terrain.flat_margin = 5.0
	terrain.blend = 12.0
	terrain.shoulder_drop = 0.35
	terrain.hole_below = -1e6
	terrain.chunk_cells = 24
	terrain.far_fn = _far_height
	terrain.follow_fn = func(i: int) -> float: return 1.0 - bay[i] if field.has_zone(i, "bridge") else 1.0
	terrain.compute()
	terrain.build_meshes(root, SceneryMat.shader_mat("terrain", {"mode": 2, "sea_level": SEA_LEVEL}), "Terrain")


func _sea() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(16000, 16000)
	sea.mesh = pm
	sea.position = Vector3(field.center().x, SEA_LEVEL, field.center().z)
	sea.material_override = SceneryMat.shader_mat("sea")
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)


## Rock hill over each tunnel zone: an outer hill surface, an inner arch lining and portal faces.
func _tunnel_hills() -> void:
	var made := 0
	for z in field.path.zones:
		if String(z.get("kind", "")) != "tunnel":
			continue
		var d0 := maxf(float(z["from"]) - 6.0, 0.0)
		var d1 := minf(float(z["to"]) + 6.0, field.path.length)
		var frames: Array = []
		var d := d0
		while d <= d1:
			var t := field.path.sample_transform(d)
			var yb := SceneryField.yaw_basis(-t.basis.z)
			frames.append(Transform3D(yb, t.origin))
			d += 4.0
		if frames.size() < 2:
			continue
		var hw := field.path.width_at((d0 + d1) * 0.5) * 0.5 + 2.5
		var n := 14
		var inner := PackedVector2Array()
		var outer := PackedVector2Array()
		for k in n + 1:
			var a := PI * float(k) / n          # 0 = right .. PI = left
			inner.append(Vector2(cos(a) * hw, -0.6 + sin(a) * 9.5))
			var wob := noise2.get_noise_1d(float(k) * 13.0 + made * 7.0) * 4.0
			outer.append(Vector2(cos(a) * (hw + 30.0 + wob), -4.0 + sin(a) * (24.0 + wob)))
		var m := batches.at("rock", (frames[frames.size() / 2] as Transform3D).origin)
		# outer surface: profile right->left over the top = faces outward
		m.add_loft(outer, frames, Color.WHITE, Vector2(200.0, 0.0))
		# inner lining: left->right so faces point into the tunnel
		var inner_rev := inner.duplicate()
		inner_rev.reverse()
		m.add_loft(inner_rev, frames, Color.WHITE, Vector2(200.0, 0.0))
		# portal faces at both ends
		for end in [0, frames.size() - 1]:
			var f: Transform3D = frames[end]
			for k in n:
				var a0 := f * Vector3(inner[k].x, inner[k].y, 0)
				var a1 := f * Vector3(inner[k + 1].x, inner[k + 1].y, 0)
				var b0 := f * Vector3(outer[k].x, outer[k].y, 0)
				var b1 := f * Vector3(outer[k + 1].x, outer[k + 1].y, 0)
				if end == 0:
					m.add_quad(a0, b0, b1, a1, Color.WHITE, Vector2(200.0, 0.0))
				else:
					m.add_quad(a1, b1, b0, a0, Color.WHITE, Vector2(200.0, 0.0))
		made += 1
	stats["tunnel_hills"] = made


func _ground_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


func _palms() -> void:
	var mat := SceneryMat.vcolor(0.85, 0.0, true)
	var variants: Array = []
	for v in 3:
		variants.append(SceneryInstances.new(SceneryProps.palm(v), mat, 300.0))
	var made := 0
	# along the land side of the road
	var d := rng.randf_range(0.0, 20.0)
	while d < field.path.length:
		var dm := d
		d += rng.randf_range(14.0, 34.0)
		if field.zone_near(dm, ["tunnel", "bridge", "no_props"], 20.0):
			continue
		var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
		var yb := SceneryField.yaw_basis(field.fwd[i])
		var side := -sea_side if rng.randf() < 0.8 else sea_side
		var lat := field.half[i] + rng.randf_range(4.5, 16.0 if side != sea_side else 7.0)
		var p := field.pos[i] + yb.x * side * lat
		if field.query(p, 30.0) < 3.0:
			continue
		p.y = _ground_at(p.x, p.z)
		if p.y < SEA_LEVEL + 1.0:
			continue
		var s := rng.randf_range(0.85, 1.25)
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(Vector3(s, s, s))
		(variants[rng.randi_range(0, 2)] as SceneryInstances).add(Transform3D(b, p - Vector3(0, 0.3, 0)))
		footprints.append([p, 0.5, "palm", 0.4, 0.4, Basis.IDENTITY])
		made += 1
	# groves on low ground near the shore
	var tries := 0
	while tries < 900:
		tries += 1
		var x := rng.randf_range(terrain.origin.x + 200.0, terrain.origin.x + (terrain.nx - 1) * terrain.cell - 200.0)
		var z := rng.randf_range(terrain.origin.y + 200.0, terrain.origin.y + (terrain.nz - 1) * terrain.cell - 200.0)
		var h := _ground_at(x, z)
		if h < SEA_LEVEL + 1.2 or h > SEA_LEVEL + 9.0:
			continue
		var p := Vector3(x, h, z)
		if field.query(p, 30.0) < 6.0:
			continue
		for k in rng.randi_range(2, 5):
			var q := p + Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9))
			q.y = _ground_at(q.x, q.z)
			if q.y < SEA_LEVEL + 0.8 or field.query(q, 20.0) < 4.0:
				continue
			var s2 := rng.randf_range(0.8, 1.3)
			(variants[rng.randi_range(0, 2)] as SceneryInstances).add(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(Vector3(s2, s2, s2)), q - Vector3(0, 0.3, 0)))
			footprints.append([q, 0.5, "palm", 0.4, 0.4, Basis.IDENTITY])
			made += 1
	for v in 3:
		(variants[v] as SceneryInstances).build(root, "Palms%d" % v, 650.0, true)
	stats["palms"] = made


func _rocks() -> void:
	var mat := SceneryMat.vcolor(0.9)
	var variants: Array = []
	for v in 3:
		variants.append(SceneryInstances.new(SceneryProps.rock(v), mat, 400.0))
	var made := 0
	var tries := 0
	while tries < 2500 and made < 700:
		tries += 1
		var x := rng.randf_range(terrain.origin.x + 100.0, terrain.origin.x + (terrain.nx - 1) * terrain.cell - 100.0)
		var z := rng.randf_range(terrain.origin.y + 100.0, terrain.origin.y + (terrain.nz - 1) * terrain.cell - 100.0)
		var p := Vector3(x, 0, z)
		var clear := field.query(p, 120.0)
		if clear < 8.0 or clear >= 120.0:
			continue
		var h := _ground_at(x, z)
		var s := rng.randf_range(1.5, 6.0)
		if h < SEA_LEVEL - 6.0:
			continue
		if h < SEA_LEVEL + 2.0:
			s = rng.randf_range(2.5, 7.0)   # boulders at the waterline
		p.y = h - s * 0.25
		if clear < s * 1.2 + 4.0:
			continue
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(Vector3(s, s * rng.randf_range(0.7, 1.6), s))
		(variants[rng.randi_range(0, 2)] as SceneryInstances).add(Transform3D(b, p))
		footprints.append([p + Vector3(0, s * 0.3, 0), s, "rock", s * 1.1, s * 1.1, Basis.IDENTITY])
		made += 1
	# a few tall sea stacks offshore
	for k in 10:
		var i := rng.randi_range(0, field.count - 1)
		var p := field.pos[i] + seaward * rng.randf_range(140.0, 420.0) + Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		var h := _ground_at(p.x, p.z) if terrain.inside(p.x, p.z) else SEA_LEVEL - 20.0
		if h > SEA_LEVEL - 1.0 or field.query(p, 60.0) < 40.0:
			continue
		var s := rng.randf_range(8.0, 16.0)
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(Vector3(s, s * rng.randf_range(2.0, 3.5), s))
		(variants[rng.randi_range(0, 2)] as SceneryInstances).add(Transform3D(b, Vector3(p.x, SEA_LEVEL - 4.0, p.z)))
		made += 1
	for v in 3:
		(variants[v] as SceneryInstances).build(root, "Rocks%d" % v, 900.0, true)
	stats["rocks"] = made


func _posts_and_lamps() -> void:
	var posts := SceneryInstances.new(SceneryProps.delineator(), SceneryMat.vcolor(0.6), 250.0)
	var refl := SceneryInstances.new(SceneryProps.delineator_reflector(), SceneryMat.neon(1.6), 250.0, true)
	var poles := SceneryInstances.new(SceneryProps.street_lamp_pole(), SceneryMat.plain(Color(0.3, 0.3, 0.32), 0.5, 0.5), 300.0)
	var heads := SceneryInstances.new(SceneryProps.street_lamp_head(), SceneryMat.neon(4.0), 300.0, true)
	var pools := SceneryInstances.new(SceneryProps.ground_quad(), SceneryMat.glow(0, 1.0, 1.6, 350.0), 300.0, true)
	for side: float in [-1.0, 1.0]:
		var d := 0.0 if side > 0 else 16.0
		while d < field.path.length:
			var dm := d
			d += 32.0
			if field.zone_near(dm, ["tunnel", "bridge", "no_props"], 4.0):
				continue
			var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
			var fr := field.frame(i)
			var yb := SceneryField.yaw_basis(field.fwd[i])
			var p := fr.origin + yb.x * side * (field.half[i] + 2.4)
			if field.query(p, 10.0) < 2.2:
				continue
			p.y = fr.origin.y - 0.1
			var b := Basis(yb.x, Vector3.UP, yb.z) if side > 0 else Basis(-yb.x, Vector3.UP, -yb.z)
			posts.add(Transform3D(yb, p))
			refl.add(Transform3D(yb, p), Color(1.0, 0.55, 0.1) if side == sea_side else Color(0.9, 0.9, 1.0))
			footprints.append([p, 0.2, "post", 0.1, 0.1, Basis.IDENTITY])
	# warm lamps on the land side every ~70 m
	var dl := 20.0
	while dl < field.path.length:
		var dm := dl
		dl += 70.0
		if field.zone_near(dm, ["tunnel", "bridge", "no_props"], 8.0):
			continue
		var i := clampi(int(round(dm / field.path.length * (field.count - 1))), 0, field.count - 1)
		var fr := field.frame(i)
		var side := -sea_side
		var base := fr.origin + fr.basis.x * side * (field.half[i] + 3.2)
		base.y = fr.origin.y - 0.1
		if field.query(base, 20.0) < 2.5:
			continue
		var to_road := fr.origin - base
		to_road.y = 0.0
		to_road = to_road.normalized()
		var lb := Basis(-to_road, Vector3.UP, (-to_road).cross(Vector3.UP).normalized())
		var xf := Transform3D(lb, base)
		var col := Color(1.0, 0.62, 0.3)
		poles.add(xf)
		heads.add(xf, col)
		var head := xf * Vector3(-2.75, 8.6, 0)
		var pc := Vector3(head.x, fr.origin.y + 0.06, head.z)
		pools.add(Transform3D(Basis(fr.basis.x, fr.basis.y, fr.basis.z).scaled_local(Vector3(13, 1, 13)), pc), Color(col.r, col.g, col.b, 0.22))
		footprints.append([base, 0.4, "lamp", 0.3, 0.3, Basis.IDENTITY])
	posts.build(root, "Posts", 300.0, false)
	refl.build(root, "Reflectors", 300.0, false)
	poles.build(root, "LampPoles", 450.0, true)
	heads.build(root, "LampHeads", 900.0, false)
	pools.build(root, "LightPools", 350.0, false)
	stats["posts"] = posts.count
	stats["lamps"] = poles.count


func _lighthouse() -> void:
	# On a headland on the sea side, roughly two thirds along the road.
	var best := Vector3.ZERO
	var found := false
	for attempt in 40:
		var i := int(field.count * rng.randf_range(0.35, 0.85))
		var p := field.pos[i] + seaward * rng.randf_range(70.0, 160.0)
		var h := _ground_at(p.x, p.z)
		if h > SEA_LEVEL + 4.0 and field.query(p, 40.0) > 25.0:
			best = Vector3(p.x, h, p.z)
			found = true
			break
	if not found:
		var i2 := int(field.count * 0.6)
		best = field.pos[i2] + seaward * 220.0
		best.y = SEA_LEVEL
		# rocky base
		var rb := batches.at("rock", best)
		rb.add_arrays(SceneryProps.rock(1).surface_get_arrays(0), Transform3D(Basis.IDENTITY.scaled_local(Vector3(22, 14, 22)), best + Vector3(0, -2, 0)), Color.WHITE, Vector2(200, 0))
		best.y += 8.0
	var m := batches.at("metal", best)
	var segs := 6
	var h := 26.0
	for k in segs:
		var col := Color(0.92, 0.9, 0.86) if k % 2 == 0 else Color(0.75, 0.1, 0.08)
		var y0 := h * k / segs
		m.add_cylinder(Transform3D(Basis.IDENTITY, best + Vector3(0, y0, 0)), lerpf(3.4, 2.3, float(k) / segs), lerpf(3.4, 2.3, float(k + 1) / segs), h / segs, 14, col)
	m.add_cylinder(Transform3D(Basis.IDENTITY, best + Vector3(0, h, 0)), 3.2, 3.2, 0.5, 14, Color(0.15, 0.15, 0.15))
	m.add_cylinder(Transform3D(Basis.IDENTITY, best + Vector3(0, h + 4.0, 0)), 2.4, 0.3, 2.2, 14, Color(0.12, 0.12, 0.12))
	var neon := batches.at("neon", best)
	neon.add_cylinder(Transform3D(Basis.IDENTITY, best + Vector3(0, h + 0.5, 0)), 1.6, 1.6, 3.5, 12, Color(1.0, 0.9, 0.6))
	# rotating beam
	var rot := SceneryRotor.new()
	rot.name = "LighthouseBeam"
	rot.position = best + Vector3(0, h + 2.2, 0)
	rot.speed = 0.12
	var cone := SceneryProps.beam_cone()
	var bm := SceneryMesh.new()
	for sgn: float in [-1.0, 1.0]:
		var b := Basis(Vector3.FORWARD, PI * 0.5 * sgn).rotated(Vector3.UP, 0.0)
		bm.add_arrays(cone.surface_get_arrays(0), Transform3D(b.scaled_local(Vector3(10, 420, 10)), Vector3.ZERO), Color(1.0, 0.85, 0.6, 0.06))
	var mi := bm.to_instance(SceneryMat.glow(1, 1.0, 1.2, 3000.0), "Beam", false)
	rot.add_child(mi)
	root.add_child(rot)
	footprints.append([best, 3.5, "lighthouse", 3.4, 3.4, Basis.IDENTITY])
	stats["lighthouse"] = best


func _town() -> void:
	# A cluster of small houses with warm windows on low land away from the road.
	var bmat := SceneryMat.shader_mat("building", {"wetness": 0.0, "window_energy": 1.6, "daylight": 0.25,
		"wall_color": Color(0.55, 0.5, 0.45), "wall_color2": Color(0.7, 0.62, 0.55)})
	var houses := SceneryInstances.new(SceneryProps.unit_box(), bmat, 400.0, false, true)
	var dots := batches
	var made := 0
	var centres: Array = []
	for attempt in 300:
		if centres.size() >= 3:
			break
		var i := rng.randi_range(0, field.count - 1)
		var p := field.pos[i] - seaward * rng.randf_range(250.0, 650.0) + Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
		if not terrain.inside(p.x, p.z):
			continue
		var h := _ground_at(p.x, p.z)
		if h < SEA_LEVEL + 3.0 or field.query(p, 80.0) < 60.0:
			continue
		centres.append(Vector3(p.x, h, p.z))
	for c in centres:
		for k in 40:
			var q: Vector3 = c + Vector3(rng.randf_range(-90, 90), 0, rng.randf_range(-90, 90))
			if field.query(q, 40.0) < 20.0:
				continue
			q.y = _ground_at(q.x, q.z)
			if q.y < SEA_LEVEL + 1.5:
				continue
			var w := rng.randf_range(7.0, 12.0)
			var dd := rng.randf_range(7.0, 11.0)
			var hh := rng.randf_range(4.0, 9.0)
			var b := Basis(Vector3.UP, rng.randf_range(0, TAU))
			houses.add(Transform3D(b.scaled_local(Vector3(w, hh, dd)), q - Vector3(0, 0.5, 0)), Color.WHITE, Color(rng.randf(), 0.95, rng.randf_range(0.3, 0.7), 0.1))
			footprints.append([q, 6.0, "house", w * 0.5, dd * 0.5, b])
			made += 1
			if rng.randf() < 0.5:
				dots.at("neon", q).add_box(Transform3D(Basis.IDENTITY, q + Vector3(w * 0.6, 5.0, 0)), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.7, 0.35), Vector2(0, 0))
	houses.build(root, "Houses", 0.0, true)
	stats["houses"] = made


func _far_silhouettes() -> void:
	var far := batches
	var cen := field.center()
	var ext := field.extent().length() * 0.5
	# islands out at sea
	for k in 7:
		var ang := rng.randf_range(-0.9, 0.9)
		var dir := seaward.rotated(Vector3.UP, ang)
		var p := cen + dir * (ext + rng.randf_range(1400.0, 3200.0))
		var s := rng.randf_range(160.0, 420.0)
		var arr := SceneryProps.rock(k % 3).surface_get_arrays(0)
		far.at("far", p).add_arrays(arr, Transform3D(Basis(Vector3.UP, rng.randf()).scaled_local(Vector3(s, s * rng.randf_range(0.25, 0.5), s * rng.randf_range(0.6, 1.2))), Vector3(p.x, SEA_LEVEL - s * 0.08, p.z)), Color(0.22, 0.2, 0.25))
	# mountain range inland
	for k in 12:
		var ang2 := rng.randf_range(-1.3, 1.3)
		var dir2 := (-seaward).rotated(Vector3.UP, ang2)
		var p2 := cen + dir2 * (ext + rng.randf_range(1300.0, 2400.0))
		var s2 := rng.randf_range(300.0, 650.0)
		var arr2 := SceneryProps.rock((k + 1) % 3).surface_get_arrays(0)
		far.at("far", p2).add_arrays(arr2, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(s2, s2 * rng.randf_range(0.5, 0.9), s2)), Vector3(p2.x, SEA_LEVEL - 30.0, p2.z)), Color(0.2, 0.2, 0.26))
