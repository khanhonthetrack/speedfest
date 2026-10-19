class_name TrackBuilder
extends RefCounted
## Turns a TrackDefs entry into a drivable, neon-lit stretch of city: the road surface and its
## collision, curbs, lit edge strips, barriers with LED rails, light gantries, turbo pads, the
## start gantry and the checkpoint gates.
##
## Road UVs follow shaders/road.gdshader: UV.x = metres from the left edge, UV.y = metres along the
## track, UV2.x = half width, UV2.y = curb amount (0..1) or >= 2 inside a tunnel.
##
## Everything the race logic needs is returned in `info`:
##   path          the TrackPath (distance -> road frame)
##   checkpoints   [distance along the path], in order, the start line last
##   start         Transform3D of the grid slot
##   length        metres per lap

const STEP := 2.5                 ## road sample spacing (m)
const WALL_H := 1.25
const CURB_W := 1.4
const SURFACE_ASPHALT := 16
const SURFACE_TURBO := 26         ## TmTuning.Surface.TURBO2 (the red pad)

var path: TrackPath
var def: Dictionary
var root: Node3D
var info: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _neon_mat: ShaderMaterial
var _road_mat: ShaderMaterial
var _wall_mat: StandardMaterial3D
var _metal_mat: StandardMaterial3D
var _boost_mat: ShaderMaterial


## Build the track `id`. Returns a Node3D to add to the scene; `info` is filled in.
func build(id: String, rng_seed: int = 12345) -> Node3D:
	def = TrackDefs.get_def(id)
	path = TrackDefs.build_path(id)
	_rng.seed = rng_seed
	root = Node3D.new()
	root.name = "Track"
	_materials()
	_road()
	_barriers()
	_tunnels()
	_arches()
	_pads()
	_start_gantry()
	var cps: Array = []
	for i in def.get("checkpoints", []):
		cps.append(path.point_offset(int(i)))
	cps.sort()
	cps.append(path.length)        # the start/finish line closes the lap
	info = {
		"path": path,
		"checkpoints": cps,
		"start": _start_transform(),
		"length": path.length,
		"laps": TrackDefs.laps_of(id),
		"name": TrackDefs.name_of(id),
	}
	root.set_meta("info", info)
	return root


## Materials for the shaders that live under res://shaders/track_*.gdshader.
static func _track_shader_mat(shader_name: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/%s.gdshader" % shader_name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _materials() -> void:
	_road_mat = ShaderMaterial.new()
	_road_mat.shader = load("res://shaders/road.gdshader")
	_road_mat.set_shader_parameter("asphalt_color", Color(0.055, 0.057, 0.065))
	_road_mat.set_shader_parameter("edge_color", Color(0.86, 0.88, 0.92))
	_road_mat.set_shader_parameter("edge_emission", 0.45)
	_road_mat.set_shader_parameter("curb_a", Color(0.95, 0.10, 0.25))
	_road_mat.set_shader_parameter("curb_b", Color(0.92, 0.94, 1.0))
	_road_mat.set_shader_parameter("center_mode", 1)
	_road_mat.set_shader_parameter("lane_count", 3)
	_road_mat.set_shader_parameter("wetness", 0.85)
	_road_mat.set_shader_parameter("water_gloss", 1.0 if Settings.quality >= 1 else 0.3)
	_road_mat.set_shader_parameter("paint_glow", 0.22)
	_road_mat.set_shader_parameter("tunnel_light", Color(1.0, 0.55, 0.22))
	_road_mat.set_shader_parameter("tunnel_fake", 0.35)
	_neon_mat = SceneryMat.neon(5.0)
	_boost_mat = _track_shader_mat("track_boost", {"color_a": Color(1.0, 0.45, 0.05),
		"color_b": Color(1.0, 0.1, 0.6), "speed": 11.0})
	_wall_mat = SceneryMat.vcolor(0.55, 0.25)
	_metal_mat = SceneryMat.plain(Color(0.085, 0.09, 0.105), 0.45, 0.7)


# --- the road ------------------------------------------------------------------------------------

func _road() -> void:
	var n := maxi(8, int(ceil(path.length / STEP)))
	var step := path.length / float(n)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var col := PackedColorArray()
	var prev := path.sample_transform(0.0)
	var prev_w := path.width_at(0.0) * 0.5
	var prev_curb := _curb_at(0.0)
	var prev_tun := path.in_zone(0.0, "tunnel")
	for i in range(1, n + 1):
		var d := minf(i * step, path.length)
		var cur := path.sample_transform(d)
		var w := path.width_at(d) * 0.5
		var curb := _curb_at(d)
		var tun := path.in_zone(d, "tunnel")
		var a := prev.origin + prev.basis.x * prev_w
		var b := prev.origin - prev.basis.x * prev_w
		var c := cur.origin - cur.basis.x * w
		var e := cur.origin + cur.basis.x * w
		var d0 := (i - 1) * step
		# two triangles, winding so the road faces up
		for t in [[a, b, c], [a, c, e]]:
			for q: Vector3 in t:
				verts.append(q)
		for k in 6:
			col.append(Color.WHITE)
		norms.append(prev.basis.y); norms.append(prev.basis.y); norms.append(cur.basis.y)
		norms.append(prev.basis.y); norms.append(cur.basis.y); norms.append(cur.basis.y)
		# UV.x = metres from the LEFT edge (the road's +x is right, so the left edge is -x)
		uvs.append(Vector2(prev_w * 2.0, d0)); uvs.append(Vector2(0.0, d0)); uvs.append(Vector2(0.0, d))
		uvs.append(Vector2(prev_w * 2.0, d0)); uvs.append(Vector2(0.0, d)); uvs.append(Vector2(w * 2.0, d))
		var p2 := Vector2(prev_w, prev_curb + (2.0 if prev_tun else 0.0))
		var c2 := Vector2(w, curb + (2.0 if tun else 0.0))
		uv2s.append(p2); uv2s.append(p2); uv2s.append(c2)
		uv2s.append(p2); uv2s.append(c2); uv2s.append(c2)
		prev = cur
		prev_w = w
		prev_curb = curb
		prev_tun = tun
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _road_mat)
	var body := StaticBody3D.new()
	body.name = "Road"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(verts)
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "RoadMesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	body.set_meta("surface", SURFACE_ASPHALT)
	root.add_child(body)
	_road_underside(n, step)


## The road is a deck on the flyover: close it from below so it is not see-through.
func _road_underside(n: int, step: float) -> void:
	var kit := MeshKit.new()
	kit.color = Color(0.045, 0.046, 0.055)
	var any := false
	for i in n:
		var d0 := i * step
		var d1 := minf((i + 1) * step, path.length)
		if path.sample_position(d0).y < 1.0 and path.sample_position(d1).y < 1.0:
			continue
		any = true
		var t0 := path.sample_transform(d0)
		var t1 := path.sample_transform(d1)
		var w0 := path.width_at(d0) * 0.5
		var w1 := path.width_at(d1) * 0.5
		var drop := Vector3(0, -0.85, 0)
		var a0 := t0.origin + t0.basis.x * w0
		var b0 := t0.origin - t0.basis.x * w0
		var a1 := t1.origin + t1.basis.x * w1
		var b1 := t1.origin - t1.basis.x * w1
		kit.flat_quad("u", a0 + drop, b0 + drop, b1 + drop, a1 + drop, Vector3.DOWN)
		kit.flat_quad("u", a0, a1, a1 + drop, a0 + drop, t0.basis.x)
		kit.flat_quad("u", b0, b0 + drop, b1 + drop, b1, -t0.basis.x)
		# a pier every ~30 m
		if i % int(maxf(1.0, 30.0 / step)) == 0 and t0.origin.y > 2.0:
			var h := t0.origin.y
			kit.box("u", t0.origin + Vector3(0, -h * 0.5 - 0.8, 0), Vector3(2.4, h, 2.4))
	if not any:
		return
	var mi := MeshInstance3D.new()
	mi.name = "RoadDeck"
	mi.mesh = kit.commit({"u": SceneryMat.vcolor(0.7, 0.2)})
	root.add_child(mi)


## How much curb to paint at this distance (from the local curvature).
func _curb_at(d: float) -> float:
	var a := path.sample_position(fposmod(d - 12.0, path.length))
	var b := path.sample_position(d)
	var c := path.sample_position(fposmod(d + 12.0, path.length))
	var v1 := (b - a)
	var v2 := (c - b)
	v1.y = 0.0
	v2.y = 0.0
	if v1.length() < 0.01 or v2.length() < 0.01:
		return 0.0
	var ang := absf(v1.normalized().angle_to(v2.normalized()))
	return clampf((ang - 0.03) * 7.0, 0.0, 1.0)


# --- barriers ------------------------------------------------------------------------------------

func _barriers() -> void:
	var kit := MeshKit.new()
	var neon := MeshKit.new()
	var n := maxi(8, int(ceil(path.length / STEP)))
	var step := path.length / float(n)
	var colours := CityKit.NEON
	for side: float in [-1.0, 1.0]:
		var hue := 0
		for i in n:
			var d0 := i * step
			var d1 := minf((i + 1) * step, path.length)
			var t0 := path.sample_transform(d0)
			var t1 := path.sample_transform(d1)
			var w0 := path.width_at(d0) * 0.5 + 0.12
			var w1 := path.width_at(d1) * 0.5 + 0.12
			var p0 := t0.origin + t0.basis.x * w0 * side
			var p1 := t1.origin + t1.basis.x * w1 * side
			var up0 := t0.basis.y * WALL_H
			var up1 := t1.basis.y * WALL_H
			var inward := -t0.basis.x * side
			kit.color = Color(0.085, 0.09, 0.11)
			kit.flat_quad("w", p0, p1, p1 + up1, p0 + up0, inward)
			kit.color = Color(0.05, 0.05, 0.06)
			kit.flat_quad("w", p0 - inward * 0.22, p0 - inward * 0.22 + up0,
				p1 - inward * 0.22 + up1, p1 - inward * 0.22, -inward)
			kit.color = Color(0.11, 0.115, 0.13)
			kit.flat_quad("w", p0 + up0, p1 + up1, p1 + up1 - inward * 0.22, p0 + up0 - inward * 0.22, Vector3.UP)
			# LED rail along the top, colour changing every ~40 m, chasing toward the next corner
			if i % 2 == 0:
				var col: Color = colours[(hue / 16) % colours.size()]
				hue += 1
				var ph := fmod(d0 / 40.0, 1.0)
				neon.color = col
				var mid := (p0 + p1) * 0.5 + (up0 + up1) * 0.5 - inward * 0.11
				_neon_bar(neon, mid + Vector3(0, 0.06, 0), p1 - p0, inward, 0.09, Vector2(4.0, ph))
	var mi := MeshInstance3D.new()
	mi.name = "Barriers"
	mi.mesh = kit.commit({"w": _wall_mat})
	root.add_child(mi)
	var nmi := MeshInstance3D.new()
	nmi.name = "BarrierLEDs"
	nmi.mesh = neon.commit({"n": _neon_mat})
	nmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(nmi)
	_barrier_collision(n, step)


## A thin glowing bar along `fwd`, `thick` wide, facing `face`. uv2 = (animation mode, phase).
func _neon_bar(kit: MeshKit, centre: Vector3, fwd: Vector3, face: Vector3, thick: float, anim: Vector2) -> void:
	var f := fwd * 0.5
	var up := face.cross(fwd).normalized() * thick * 0.5
	var o := face.normalized() * 0.02
	var a := centre - f - up + o
	var b := centre + f - up + o
	var c := centre + f + up + o
	var d := centre - f + up + o
	_quad_uv2(kit, "n", a, b, c, d, face, anim)


func _quad_uv2(kit: MeshKit, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		outward: Vector3, anim: Vector2) -> void:
	var before: int = (kit.surfaces.get(key, {}) as Dictionary).get("v", PackedVector3Array()).size()
	kit.flat_quad(key, a, b, c, d, outward)
	var s: Dictionary = kit.surfaces[key]
	var uv: PackedVector2Array = s["uv"]
	var added: int = (s["v"] as PackedVector3Array).size() - before
	# MeshKit writes UV per vertex; the neon shader reads the animation out of UV2, which it
	# shares with UV here (one quad = one animation), so stamp it on every new vertex.
	for i in range(uv.size() - added, uv.size()):
		uv[i] = anim
	s["uv"] = uv


## Invisible walls that match the barriers (the car's chassis bounces off them).
func _barrier_collision(n: int, step: float) -> void:
	var faces := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		for i in n:
			var d0 := i * step
			var d1 := minf((i + 1) * step, path.length)
			var t0 := path.sample_transform(d0)
			var t1 := path.sample_transform(d1)
			var w0 := path.width_at(d0) * 0.5 + 0.12
			var w1 := path.width_at(d1) * 0.5 + 0.12
			var p0 := t0.origin + t0.basis.x * w0 * side
			var p1 := t1.origin + t1.basis.x * w1 * side
			var u0 := p0 + t0.basis.y * WALL_H
			var u1 := p1 + t1.basis.y * WALL_H
			if side > 0.0:
				faces.append(p0); faces.append(p1); faces.append(u1)
				faces.append(p0); faces.append(u1); faces.append(u0)
			else:
				faces.append(p0); faces.append(u1); faces.append(p1)
				faces.append(p0); faces.append(u0); faces.append(u1)
	var body := StaticBody3D.new()
	body.name = "BarrierCollision"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	body.set_meta("surface", SURFACE_ASPHALT)
	root.add_child(body)


## Where the path runs through a "tunnel" zone, build the thing it runs through: a concrete tube
## over the road with a lit ceiling, sodium strips along the walls and a portal at each end.
func _tunnels() -> void:
	for z: Dictionary in path.zones:
		if String(z.get("kind", "")) != "tunnel":
			continue
		var d0 := float(z["from"])
		var d1 := float(z["to"])
		if d1 <= d0:
			continue
		var kit := MeshKit.new()
		var neon := MeshKit.new()
		var h := 7.2
		var n := maxi(4, int((d1 - d0) / 6.0))
		var step := (d1 - d0) / float(n)
		for i in range(n + 1):
			var d := d0 + float(i) * step
			var t := path.sample_transform(d)
			var w := path.width_at(d) * 0.5 + 2.6
			if i < n:
				var t2 := path.sample_transform(d + step)
				var w2 := path.width_at(d + step) * 0.5 + 2.6
				# ceiling
				kit.color = Color(0.105, 0.10, 0.105)
				kit.flat_quad("t", t.origin + t.basis.x * w + Vector3(0, h, 0),
					t.origin - t.basis.x * w + Vector3(0, h, 0),
					t2.origin - t2.basis.x * w2 + Vector3(0, h, 0),
					t2.origin + t2.basis.x * w2 + Vector3(0, h, 0), Vector3.DOWN)
				# walls
				kit.color = Color(0.135, 0.13, 0.125)
				for side: float in [-1.0, 1.0]:
					var a := t.origin + t.basis.x * w * side
					var b := t2.origin + t2.basis.x * w2 * side
					kit.flat_quad("t", a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0),
						-t.basis.x * side)
				# sodium strip along both walls and a run of ceiling lights
				if i % 2 == 0:
					neon.color = Color(1.0, 0.62, 0.22)
					for side2: float in [-1.0, 1.0]:
						var mid := (t.origin + t2.origin) * 0.5 + t.basis.x * ((w + w2) * 0.5 - 0.12) * side2
						_neon_bar(neon, mid + Vector3(0, 3.4, 0), t2.origin - t.origin,
							-t.basis.x * side2, 0.22, Vector2(0.0, 0.0))
				if i % 3 == 0:
					neon.color = Color(1.0, 0.75, 0.42)
					_neon_bar(neon, t.origin + Vector3(0, h - 0.12, 0), t.basis.x * 3.2, Vector3.DOWN,
						0.55, Vector2(0.0, 0.0))
					if Settings.quality >= 1:
						var ol := OmniLight3D.new()
						ol.position = t.origin + Vector3(0, h - 0.6, 0)
						ol.light_color = Color(1.0, 0.68, 0.30)
						ol.light_energy = 4.0
						ol.omni_range = 18.0
						ol.light_volumetric_fog_energy = 2.5
						Settings.tune_point_light(ol)
						root.add_child(ol)
		# portals
		kit.color = Color(0.09, 0.09, 0.095)
		for d: float in [d0, d1]:
			var t3 := path.sample_transform(d)
			var w3 := path.width_at(d) * 0.5 + 3.2
			kit.box("t", t3.origin + Vector3(0, h * 0.5 + 0.6, 0),
				Vector3(w3 * 2.0 + 1.6, h + 1.6, 1.2), Basis(t3.basis))
		var mi := MeshInstance3D.new()
		mi.name = "Tunnel"
		mi.mesh = kit.commit({"t": SceneryMat.vcolor(0.85, 0.05)})
		root.add_child(mi)
		var nmi := MeshInstance3D.new()
		nmi.name = "TunnelLights"
		nmi.mesh = neon.commit({"n": _neon_mat})
		nmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(nmi)
		# the walls stop the car like the barriers do
		var body := StaticBody3D.new()
		body.name = "TunnelCollision"
		var cs := CollisionShape3D.new()
		var faces := PackedVector3Array()
		for i2 in n:
			var da := d0 + float(i2) * step
			var db := da + step
			var ta := path.sample_transform(da)
			var tb := path.sample_transform(db)
			var wa := path.width_at(da) * 0.5 + 2.6
			var wb := path.width_at(db) * 0.5 + 2.6
			for side3: float in [-1.0, 1.0]:
				var p0 := ta.origin + ta.basis.x * wa * side3
				var p1 := tb.origin + tb.basis.x * wb * side3
				var u0 := p0 + Vector3(0, h, 0)
				var u1 := p1 + Vector3(0, h, 0)
				if side3 > 0.0:
					faces.append(p0); faces.append(p1); faces.append(u1)
					faces.append(p0); faces.append(u1); faces.append(u0)
				else:
					faces.append(p0); faces.append(u1); faces.append(p1)
					faces.append(p0); faces.append(u0); faces.append(u1)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		cs.shape = shape
		body.add_child(cs)
		body.set_meta("surface", SURFACE_ASPHALT)
		root.add_child(body)


# --- gantries, pads, start -------------------------------------------------------------------

func _arches() -> void:
	var kit := MeshKit.new()
	var neon := MeshKit.new()
	for entry: Dictionary in def.get("arches", []):
		var d := TrackDefs.feature_distance(path, entry)
		var t := path.sample_transform(d)
		var w := path.width_at(d) * 0.5 + 1.2
		var h := 7.0
		var col: Color = CityKit.NEON[_rng.randi_range(0, CityKit.NEON.size() - 1)]
		kit.color = Color(0.10, 0.105, 0.12)
		for side: float in [-1.0, 1.0]:
			var base := t.origin + t.basis.x * w * side
			kit.box("g", base + Vector3(0, h * 0.5, 0), Vector3(0.55, h, 0.7), Basis(t.basis))
			kit.box("g", base + Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 1.3), Basis(t.basis))
		var top := t.origin + Vector3(0, h, 0)
		kit.box("g", top, Vector3(w * 2.0, 0.85, 0.8), Basis(t.basis))
		# neon tubes under and along the beam
		neon.color = col
		_neon_bar(neon, top - Vector3(0, 0.5, 0), t.basis.x * (w * 2.0 - 0.6), Vector3.DOWN, 0.16, Vector2(4.0, 0.0))
		neon.color = col * 0.9
		_neon_bar(neon, top + Vector3(0, 0.5, 0), t.basis.x * (w * 2.0 - 0.6), Vector3.UP, 0.12, Vector2(3.0, 0.3))
		# a screen panel on the beam
		var board := MeshKit.new()
		board.color = Color(0.03, 0.03, 0.04)
		board.box("b", top + Vector3(0, 1.9, 0), Vector3(7.5, 2.6, 0.35), Basis(t.basis))
		var bmi := MeshInstance3D.new()
		bmi.mesh = board.commit({"b": SceneryMat.vcolor(0.5, 0.2)})
		root.add_child(bmi)
		var screen := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(7.1, 2.3)
		screen.mesh = qm
		screen.material_override = SceneryMat.shader_mat("screen", {"energy": 2.6})
		screen.transform = Transform3D(t.basis, top + Vector3(0, 1.9, 0) - t.basis.z * 0.2)
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(screen)
		# a real light so the arch throws colour on the road
		if Settings.quality >= 1:
			var ol := OmniLight3D.new()
			ol.position = top - Vector3(0, 1.2, 0)
			ol.light_color = col.lightened(0.2)
			ol.light_energy = 5.0
			ol.omni_range = 26.0
			ol.light_volumetric_fog_energy = 2.5
			Settings.tune_point_light(ol)
			root.add_child(ol)
	if kit.tri_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Arches"
	mi.mesh = kit.commit({"g": _metal_mat})
	root.add_child(mi)
	var nmi := MeshInstance3D.new()
	nmi.name = "ArchNeon"
	nmi.mesh = neon.commit({"n": _neon_mat})
	nmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(nmi)


## Turbo strips: a glowing pad on the road that fires the car forward (TMNF's red pad).
func _pads() -> void:
	for entry: Dictionary in def.get("pads", []):
		var d := TrackDefs.feature_distance(path, entry)
		var t := path.sample_transform(d)
		var w := minf(path.width_at(d) * 0.5 - 1.0, 5.0)
		var len_m := 14.0
		var body := StaticBody3D.new()
		body.name = "BoostPad"
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w * 2.0, 0.22, len_m)
		cs.shape = box
		body.add_child(cs)
		body.transform = Transform3D(t.basis, t.origin + t.basis.y * 0.06)
		body.set_meta("surface", SURFACE_TURBO)
		body.set_meta("pad_dir", -t.basis.z)
		var mi := MeshInstance3D.new()
		mi.mesh = _pad_mesh(w * 2.0, len_m)
		mi.position = Vector3(0, 0.12, 0)
		mi.material_override = _boost_mat
		mi.set_instance_shader_parameter("pad_len", len_m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
		if Settings.quality >= 2:
			var ol := OmniLight3D.new()
			ol.light_color = Color(1.0, 0.45, 0.1)
			ol.light_energy = 4.0
			ol.omni_range = 16.0
			ol.position = Vector3(0, 1.2, 0)
			ol.light_volumetric_fog_energy = 2.0
			Settings.tune_point_light(ol)
			body.add_child(ol)
		root.add_child(body)


## A flat quad lying on the road with UVs in metres (what track_boost.gdshader expects).
static func _pad_mesh(w: float, l: float) -> ArrayMesh:
	var v := PackedVector3Array([Vector3(-w * 0.5, 0, -l * 0.5), Vector3(w * 0.5, 0, -l * 0.5),
		Vector3(w * 0.5, 0, l * 0.5), Vector3(-w * 0.5, 0, l * 0.5)])
	var verts := PackedVector3Array([v[0], v[2], v[1], v[0], v[3], v[2]])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(w, l), Vector2(w, 0),
		Vector2(0, 0), Vector2(0, l), Vector2(w, l)])
	var norms := PackedVector3Array()
	for i in 6:
		norms.append(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _start_transform() -> Transform3D:
	var t := path.sample_transform(2.0)
	# the car faces +Z in its own frame; the path frame's -Z is the direction of travel
	return Transform3D(Basis(-t.basis.x, t.basis.y, -t.basis.z), t.origin + t.basis.y * 0.05)


func _start_gantry() -> void:
	var t := path.sample_transform(0.0)
	var w := path.width_at(0.0) * 0.5 + 1.4
	var kit := MeshKit.new()
	var neon := MeshKit.new()
	kit.color = Color(0.09, 0.095, 0.11)
	var h := 8.0
	for side: float in [-1.0, 1.0]:
		var base := t.origin + t.basis.x * w * side
		kit.box("g", base + Vector3(0, h * 0.5, 0), Vector3(0.7, h, 0.9), Basis(t.basis))
		kit.box("g", base + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 1.6), Basis(t.basis))
	var top := t.origin + Vector3(0, h, 0)
	kit.box("g", top, Vector3(w * 2.0, 1.3, 1.0), Basis(t.basis))
	neon.color = Color(0.1, 1.0, 0.45)
	_neon_bar(neon, top - Vector3(0, 0.75, 0), t.basis.x * (w * 2.0 - 0.8), Vector3.DOWN, 0.22, Vector2(4.0, 0.0))
	# start lights: five red lamps across the beam
	for k in 5:
		neon.color = Color(1.0, 0.08, 0.05)
		var p := top + t.basis.x * lerpf(-w * 0.55, w * 0.55, float(k) / 4.0) + Vector3(0, 0.1, 0)
		_neon_bar(neon, p, t.basis.x * 0.55, -t.basis.z, 0.5, Vector2(0.0, 0.0))
	var mi := MeshInstance3D.new()
	mi.name = "StartGantry"
	mi.mesh = kit.commit({"g": _metal_mat})
	root.add_child(mi)
	var nmi := MeshInstance3D.new()
	nmi.name = "StartNeon"
	nmi.mesh = neon.commit({"n": _neon_mat})
	nmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(nmi)
	# the start/finish line painted on the road: a chequered band with a lit edge
	var road_w := path.width_at(0.0)
	var line_kit := MeshKit.new()
	var lt := path.sample_transform(0.0)
	var cells := maxi(8, int(road_w / 1.1))
	for k in cells:
		var u0 := lerpf(-road_w * 0.5, road_w * 0.5, float(k) / float(cells))
		var u1 := lerpf(-road_w * 0.5, road_w * 0.5, float(k + 1) / float(cells))
		for row in 2:
			var z0 := -0.8 + float(row) * 0.8
			var dark := (k + row) % 2 == 1
			line_kit.color = Color(0.045, 0.047, 0.055) if dark else Color(0.88, 0.90, 0.95)
			var a := lt.origin + lt.basis.x * u0 + lt.basis.z * z0 + lt.basis.y * 0.025
			var b := lt.origin + lt.basis.x * u1 + lt.basis.z * z0 + lt.basis.y * 0.025
			var c := b + lt.basis.z * 0.8
			var d2 := a + lt.basis.z * 0.8
			line_kit.flat_quad("l", a, b, c, d2, lt.basis.y)
	var line := MeshInstance3D.new()
	line.name = "StartLine"
	line.mesh = line_kit.commit({"l": SceneryMat.vcolor(0.35, 0.1)})
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(line)
