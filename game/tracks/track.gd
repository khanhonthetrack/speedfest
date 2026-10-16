class_name Track
extends Node3D
## A built, drivable track: road + collision, barriers, stunt pieces, checkpoint gates,
## boost pads, ground/terrain, environment and scenery. API fixed by docs/ARCHITECTURE.md "Track".
## Build with Track.build(track_id). Layouts live in res://tracks/defs/<id>.gd.

signal checkpoint_reached(car: Node, index: int)
signal finish_reached(car: Node)

## Circuits: the car starts this far *past* the start/finish line (so it doesn't touch the
## finish trigger at spawn). Point-to-point: this far *behind* the (trigger-less) start gate.
const START_BACKOFF := 6.0
const SPAWN_HEIGHT := 0.6       # car origin above the road surface
const GATE_TRIGGER_H := 40.0    # checkpoint/finish trigger height

var track_id: String = "arena"
var path: TrackPath
var checkpoint_count: int = 0
var kill_y: float = -50.0

## Extra (non-contract) data.
var checkpoint_distances: Array[float] = []
var start_distance: float = 0.0
var finish_distance: float = 0.0
var is_circuit: bool = true
var layout: Dictionary = {}
var data: Dictionary = {}
var theme: String = "arena"
var gates: Array[Area3D] = []          # checkpoint gates in order
var rails: Array[TrackRail] = []       # grind rails (layout "rail": true segments)
var finish_gate: Area3D
var boost_pads: Array[Area3D] = []
## Weather (see res://weather/weather.gd): grip map with the stage's puddles, current mode.
var surface: TrackSurface = TrackSurface.new()
var weather: String = "dry"
var _puddle_root: Node3D
var _puddle_meshes: Array[MeshInstance3D] = []
var _puddle_mat: ShaderMaterial


static func load_layout(p_track_id: String) -> Dictionary:
	var script_path := "res://tracks/defs/%s.gd" % p_track_id
	if not ResourceLoader.exists(script_path):
		script_path = "res://tracks/defs/arena.gd"
	var def: Object = load(script_path).new()
	return def.call("layout")


## Builds only the path and gameplay data (no meshes): fast, for tests and tools.
static func build_data(p_track_id: String) -> Dictionary:
	return TrackBuilder.build_layout(load_layout(p_track_id))


static func build(p_track_id: String, with_scenery := true) -> Track:
	var t := Track.new()
	t.track_id = p_track_id if p_track_id in TrackDefs.IDS else "arena"
	t.name = "Track_" + t.track_id
	t.theme = TrackDefs.theme(t.track_id)
	t.layout = load_layout(t.track_id)
	t.data = TrackBuilder.build_layout(t.layout)
	t.path = t.data["path"]
	t.is_circuit = t.data["circuit"]
	for d in t.data["checkpoints"]:
		t.checkpoint_distances.append(float(d))
	t.checkpoint_count = t.checkpoint_distances.size()
	t.start_distance = t.data["start_d"]
	t.finish_distance = t.data["finish_d"]
	var min_y := 1e9
	var d := 0.0
	while d <= t.path.length:
		min_y = minf(min_y, t.path.sample_position(d).y)
		d += 5.0
	t.kill_y = float(t.layout.get("kill_y", min_y - float(t.layout.get("kill_below", 12.0))))
	t._build_kill_profile()
	t._build_geometry()
	if with_scenery:
		var env := SceneryKit.build_environment(t.theme)
		if env != null:
			t.add_child(env)
		var props := SceneryKit.build_props(t.theme, t.path, hash(t.track_id))
		if props != null:
			t.add_child(props)
		if t.layout.get("ground", "") == "terrain" and not _has_sea(env) and not _has_sea(props):
			t.add_child(TrackBuilder.build_fallback_sea(t.path))
	return t


## True when the scenery provides its own sea (any node whose name contains "sea").
static func _has_sea(n: Node) -> bool:
	if n == null:
		return false
	if String(n.name).to_lower().contains("sea"):
		return true
	for c in n.get_children():
		if _has_sea(c):
			return true
	return false


func _build_geometry() -> void:
	TrackBuilder.build_road(self, data, layout)
	TrackBuilder.build_supports(self, data, layout)
	TrackBuildings.build(self, data, layout)
	_build_rails()
	match String(layout.get("ground", "none")):
		"city", "arena":
			TrackBuilder.build_flat_ground(self, data, layout)
		"terrain":
			TrackBuilder.build_terrain(self, data, layout)
	TrackBuilder.build_corner_signs(self, data, layout)
	TrackBuilder.build_jump_dressing(self, data, layout)
	TrackBuilder.build_loop_gantries(self, data, layout)
	_build_gates()
	_build_boost_pads()
	_build_effect_pads()
	_build_puddles()
	_build_ground_patches()
	apply_weather("dry")


func _build_rails() -> void:
	for r in data.get("rails", []):
		var rail := TrackRail.new()
		rail.setup(path, float(r["from"]), float(r["to"]))
		add_child(rail)
		rails.append(rail)


# ---------------------------------------------------------------- gates

func _build_gates() -> void:
	var gate_root := Node3D.new()
	gate_root.name = "Gates"
	add_child(gate_root)
	for i in checkpoint_count:
		var area := _make_gate(gate_root, checkpoint_distances[i], "cp", true, i)
		area.name = "Checkpoint%d" % i
		area.body_entered.connect(_on_checkpoint_body.bind(i))
		gates.append(area)
	if is_circuit:
		finish_gate = _make_gate(gate_root, finish_distance, "finish")
	else:
		_make_gate(gate_root, start_distance, "start", false)
		finish_gate = _make_gate(gate_root, finish_distance, "finish")
	finish_gate.name = "Finish"
	finish_gate.body_entered.connect(_on_finish_body)
	_build_line(gate_root, start_distance)
	if not is_circuit:
		_build_line(gate_root, finish_distance)


## Checkpoint / start / finish gate (Trackmania-style, owner feedback session 4: gates must look
## and feel solid, not like a see-through neon outline). Light painted-metal pillars on concrete
## footings with collision, a crossbar carrying a backlit sign ("CHECKPOINT 2/4", "FINISH"),
## colored light strips, and on Forward+ (quality >= 2) a light that washes the road under it.
## The crossbar only gets collision away from jumps, so no flight path can clip it.
func _make_gate(parent: Node3D, d: float, kind: String, with_area := true, cp_index := -1) -> Area3D:
	var f := path.sample_transform(d)
	var hw := path.width_at(d) * 0.5
	var root := Node3D.new()
	root.transform = f
	parent.add_child(root)
	var accent := _gate_accent(kind)
	var px := hw + TrackBuilder.WALL_GAP + 1.5     # pillar centre
	var pw := 1.6                                  # pillar width
	var top := 7.6                                 # crossbar underside
	var bh := 2.6                                  # crossbar height
	var bd := 1.3                                  # crossbar depth
	var body := TrackBuilder.Acc.new()
	var foot := TrackBuilder.Acc.new()
	var strip := TrackBuilder.Acc.new()
	var sign := TrackBuilder.Acc.new()
	var pillar_h := top + bh + 1.0
	for sx in [-1.0, 1.0]:
		body.box(Transform3D(Basis.IDENTITY, Vector3(sx * px, pillar_h * 0.5 - 1.0, 0)), Vector3(pw, pillar_h, pw))
		foot.box(Transform3D(Basis.IDENTITY, Vector3(sx * px, -0.2, 0)), Vector3(pw + 0.8, 1.6, pw + 0.8))
		# light strips: full height on the road-facing side, plus the front and back faces
		strip.box(Transform3D(Basis.IDENTITY, Vector3(sx * (px - pw * 0.5 - 0.03), top * 0.5 + 0.3, 0)), Vector3(0.06, top - 0.6, 0.5))
		for sz in [-1.0, 1.0]:
			strip.box(Transform3D(Basis.IDENTITY, Vector3(sx * px, top * 0.5 + 0.3, sz * (pw * 0.5 + 0.03))), Vector3(0.42, top - 0.6, 0.06))
	var span := px * 2.0 + pw
	body.box(Transform3D(Basis.IDENTITY, Vector3(0, top + bh * 0.5, 0)), Vector3(span, bh, bd))
	for sz in [-1.0, 1.0]:
		# backlit sign panel on both faces, framed by light strips top and bottom
		sign.box(Transform3D(Basis.IDENTITY, Vector3(0, top + bh * 0.5, sz * (bd * 0.5 + 0.02))), Vector3(span - pw * 2.0 - 0.3, bh - 0.55, 0.04))
		strip.box(Transform3D(Basis.IDENTITY, Vector3(0, top + 0.12, sz * (bd * 0.5 + 0.03))), Vector3(span - 0.2, 0.12, 0.06))
		strip.box(Transform3D(Basis.IDENTITY, Vector3(0, top + bh - 0.12, sz * (bd * 0.5 + 0.03))), Vector3(span - 0.2, 0.12, 0.06))
	strip.box(Transform3D(Basis.IDENTITY, Vector3(0, top - 0.03, 0)), Vector3(span - pw * 2.0, 0.06, bd - 0.3))
	var mesh := ArrayMesh.new()
	body.commit(mesh, _gate_body_material(accent))
	foot.commit(mesh, TrackBuilder.material("concrete"))
	strip.commit(mesh, TrackBuilder.material(_gate_neon_key(kind)))
	sign.commit(mesh, _gate_sign_material(accent, kind))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Arch"
	root.add_child(mi)
	var lbl := Label3D.new()
	match kind:
		"cp":
			lbl.text = "CHECKPOINT  %d/%d" % [cp_index + 1, checkpoint_count] if cp_index >= 0 else "CHECKPOINT"
		"start":
			lbl.text = "START"
		_:
			lbl.text = "FINISH" if not is_circuit else "START  ·  FINISH"
	var f_heavy: Variant = load("res://assets/fonts/orbitron-latin-900-normal.woff2")
	if f_heavy is Font:
		lbl.font = f_heavy
	lbl.font_size = 96
	lbl.pixel_size = 0.0115 if kind == "cp" else 0.016
	lbl.outline_size = 14
	lbl.modulate = Color(1, 1, 1)
	lbl.outline_modulate = Color(accent.darkened(0.55), 1.0)
	lbl.shaded = false
	lbl.double_sided = false
	lbl.position = Vector3(0, top + bh * 0.5, bd * 0.5 + 0.07)
	root.add_child(lbl)
	# solid: cars hit the pillars and footings (and the crossbar, away from jumps)
	var sb := StaticBody3D.new()
	sb.name = "GateBody"
	sb.collision_layer = TrackBuilder.LAYER_WORLD
	sb.collision_mask = 0
	for sx in [-1.0, 1.0]:
		_gate_box(sb, Vector3(sx * px, pillar_h * 0.5 - 1.0, 0), Vector3(pw, pillar_h, pw))
		_gate_box(sb, Vector3(sx * px, -0.2, 0), Vector3(pw + 0.8, 1.6, pw + 0.8))
	if not _near_jump(d):
		_gate_box(sb, Vector3(0, top + bh * 0.5, 0), Vector3(span, bh, bd))
	root.add_child(sb)
	if not Settings.is_compat() and Settings.quality >= 2:
		var light := OmniLight3D.new()
		light.name = "GateLight"
		light.light_color = accent.lerp(Color.WHITE, 0.35)
		light.light_energy = 2.2
		light.omni_range = 16.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.position = Vector3(0, top - 1.2, 0)
		root.add_child(light)
	if not with_area:
		return null
	var area := Area3D.new()
	area.collision_layer = TrackBuilder.LAYER_TRIGGER
	area.collision_mask = TrackBuilder.MASK_CAR
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Tall trigger: cars flying over the arch after a jump still count.
	box.size = Vector3(hw * 2.0 + 2.0 * (TrackBuilder.WALL_GAP + 0.7), GATE_TRIGGER_H, 4.0)
	cs.shape = box
	cs.position = Vector3(0, GATE_TRIGGER_H * 0.5 - 1.0, 0)
	area.add_child(cs)
	root.add_child(area)
	area.set_meta("distance", d)
	return area


func _gate_box(sb: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	sb.add_child(cs)


## True when a jump or gap is within 60 m before (or 10 m after) distance d: cars may be airborne.
func _near_jump(d: float) -> bool:
	for g in data.get("gaps", []):
		if d >= float(g[0]) - 10.0 and d <= float(g[1]) + 60.0:
			return true
	for z in path.zones:
		if String(z.get("kind", "")) in ["jump", "loop"] and d >= float(z["from"]) - 10.0 and d <= float(z["to"]) + 60.0:
			return true
	return false


func _gate_accent(kind: String) -> Color:
	if kind != "cp":
		return Color(1.0, 0.17, 0.84)                    # magenta start/finish
	return Color(1.0, 0.55, 0.1) if theme == "coast" else Color(0.0, 0.9, 1.0)


func _gate_neon_key(kind: String) -> String:
	if kind != "cp":
		return "neon_magenta"
	return "neon_orange" if theme == "coast" else "neon_cyan"


static var _gate_mats: Dictionary = {}


## Light painted metal with a faint self-glow so the gate reads as a solid object at night.
func _gate_body_material(accent: Color) -> Material:
	var key := "body_%s_%s" % [accent.to_html(), Settings.is_compat()]
	if not _gate_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.86, 0.87, 0.9)
		m.metallic = 0.35
		m.roughness = 0.4
		m.emission_enabled = true
		m.emission = Color(0.85, 0.88, 0.95).lerp(accent, 0.15)
		m.emission_energy_multiplier = 0.18 if Settings.is_compat() else 0.1
		_gate_mats[key] = m
	return _gate_mats[key]


## Backlit LED sign: deep accent colour, a checker band on start/finish.
func _gate_sign_material(accent: Color, kind: String) -> Material:
	var key := "sign_%s_%s" % [accent.to_html(), kind != "cp"]
	if not _gate_mats.has(key):
		if kind != "cp":
			_gate_mats[key] = TrackBuilder.shader_material("res://shaders/track_neon.gdshader", {
				"color": Color(1, 1, 1), "energy": 1.1, "checker": 1.0, "checker_scale": Vector2(1.0, 0.65)})
		else:
			var m := StandardMaterial3D.new()
			m.albedo_color = accent.darkened(0.8)
			m.emission_enabled = true
			m.emission = accent.darkened(0.5)
			m.emission_energy_multiplier = 0.55
			m.roughness = 0.6
			_gate_mats[key] = m
	return _gate_mats[key]


func _build_line(parent: Node3D, d: float) -> void:
	var acc := TrackBuilder.Acc.new()
	var ds := PackedFloat32Array([d - 1.2, d + 1.2])
	var frames: Array[Transform3D] = []
	var prof: Array = []
	for dd in ds:
		var f := path.sample_transform(dd)
		frames.append(Transform3D(f.basis, f.origin + f.basis.y * 0.025))
		var hw := path.width_at(dd) * 0.5
		prof.append(PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0)]))
	TrackBuilder.loft(acc, frames, ds, prof)
	var mesh := ArrayMesh.new()
	acc.commit(mesh, TrackBuilder.shader_material("res://shaders/track_neon.gdshader", {
		"color": Color(0.9, 0.9, 0.9), "energy": 0.25, "checker": 1.0, "checker_scale": Vector2(1.2, 0.83), "unlit_mix": 0.0}))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Line"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _on_checkpoint_body(body: Node3D, index: int) -> void:
	if body is Car:
		checkpoint_reached.emit(body, index)


func _on_finish_body(body: Node3D) -> void:
	if body is Car:
		finish_reached.emit(body)


# ---------------------------------------------------------------- boost pads

func _build_boost_pads() -> void:
	if data["boosts"].is_empty():
		return
	var root := Node3D.new()
	root.name = "BoostPads"
	add_child(root)
	var mat := TrackBuilder.shader_material("res://shaders/track_boost.gdshader")
	# red super boost: hotter colors and faster chevrons
	var mat_super := TrackBuilder.shader_material("res://shaders/track_boost.gdshader", {
		"color_a": Color(1.0, 0.08, 0.04), "color_b": Color(1.0, 0.35, 0.05), "speed": 16.0})
	var mat_boost := TrackBuilder.shader_material("res://shaders/track_boost.gdshader", {
		"color_a": Color(1.0, 0.85, 0.05), "color_b": Color(1.0, 0.55, 0.0)})
	for b in data["boosts"]:
		var d0: float = b["d"]
		var len: float = b["len"]
		var mid := path.sample_transform(d0 + len * 0.5)
		var pw := minf(path.width_at(d0) - 4.0, 9.0)
		if float(b.get("pw", 0.0)) > 0.0:
			pw = float(b["pw"])
		var px := float(b.get("x", 0.0))   # side pads: a line choice (session 6)
		var acc := TrackBuilder.Acc.new()
		var ds := TrackBuilder.ring_ds(d0, d0 + len, 1.0)
		var frames: Array[Transform3D] = []
		var prof: Array = []
		for dd in ds:
			var f := path.sample_transform(dd)
			frames.append(Transform3D(f.basis, f.origin + f.basis.y * 0.03 + f.basis.x * px))
			prof.append(PackedVector2Array([Vector2(-pw * 0.5, 0), Vector2(pw * 0.5, 0)]))
		var dsl := PackedFloat32Array()
		for dd in ds:
			dsl.append(dd - d0)
		TrackBuilder.loft(acc, frames, dsl, prof)
		var mesh := ArrayMesh.new()
		var pad_mat := mat
		if bool(b.get("super", false)):
			pad_mat = mat_super
		elif layout.get("platform", false):
			pad_mat = mat_boost
		acc.commit(mesh, pad_mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("pad_len", len)
		root.add_child(mi)
		var area := Area3D.new()
		area.name = "Boost"
		area.collision_layer = TrackBuilder.LAYER_TRIGGER
		area.collision_mask = TrackBuilder.MASK_CAR
		area.monitorable = false
		area.transform = Transform3D(mid.basis, mid.origin + mid.basis.x * px)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(pw, 3.0, len)
		cs.shape = box
		cs.position = Vector3(0, 1.0, 0)
		area.add_child(cs)
		root.add_child(area)
		var fwd := -mid.basis.z
		area.body_entered.connect(_on_boost_body.bind(fwd, float(b["accel"]), float(b["dur"])))
		boost_pads.append(area)


func _on_boost_body(body: Node3D, fwd: Vector3, accel: float, dur: float) -> void:
	if body is Car:
		(body as Car).apply_boost(fwd, accel, dur)


## Special pads (M7): the same chevron pad as a boost, colored per effect.
const EFFECT_COLORS := {
	"engine_off": [Color(0.9, 0.05, 0.05), Color(0.3, 0.0, 0.0)],
	"no_steer": [Color(0.75, 0.1, 1.0), Color(0.25, 0.0, 0.4)],
	"cruise": [Color(0.1, 1.0, 0.35), Color(0.0, 0.35, 0.1)],
	"reactor": [Color(0.85, 1.0, 0.05), Color(0.45, 0.6, 0.0)],
	"reset": [Color(0.95, 0.95, 1.0), Color(0.3, 0.3, 0.35)],
}


func _build_effect_pads() -> void:
	if data.get("effects", []).is_empty():
		return
	var root := Node3D.new()
	root.name = "EffectPads"
	add_child(root)
	for e in data["effects"]:
		var kind := String(e["kind"])
		var cols: Array = EFFECT_COLORS.get(kind, EFFECT_COLORS["reset"])
		var mat := TrackBuilder.shader_material("res://shaders/track_boost.gdshader", {
			"color_a": cols[0], "color_b": cols[1], "speed": 6.0})
		var d0: float = e["d"]
		var len: float = e["len"]
		var pw := float(e["pw"]) if float(e["pw"]) > 0.0 else path.width_at(d0) - 2.0
		var px := float(e["x"])
		var acc := TrackBuilder.Acc.new()
		var ds := TrackBuilder.ring_ds(d0, d0 + len, 1.0)
		var frames: Array[Transform3D] = []
		var prof: Array = []
		var dsl := PackedFloat32Array()
		for dd in ds:
			var f := path.sample_transform(dd)
			frames.append(Transform3D(f.basis, f.origin + f.basis.y * 0.035 + f.basis.x * px))
			prof.append(PackedVector2Array([Vector2(-pw * 0.5, 0), Vector2(pw * 0.5, 0)]))
			dsl.append(dd - d0)
		TrackBuilder.loft(acc, frames, dsl, prof)
		var mesh := ArrayMesh.new()
		acc.commit(mesh, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("pad_len", len)
		root.add_child(mi)
		var mid := path.sample_transform(d0 + len * 0.5)
		var area := Area3D.new()
		area.name = "Effect_" + kind
		area.collision_layer = TrackBuilder.LAYER_TRIGGER
		area.collision_mask = TrackBuilder.MASK_CAR
		area.monitorable = false
		area.transform = Transform3D(mid.basis, mid.origin + mid.basis.x * px)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(pw, 3.0, len)
		cs.shape = box
		cs.position = Vector3(0, 1.0, 0)
		area.add_child(cs)
		root.add_child(area)
		area.body_entered.connect(func(body: Node3D) -> void:
			if body is Car:
				(body as Car).apply_effect(kind, float(e["dur"])))


# ---------------------------------------------------------------- weather / puddles

## Fake puddle reflection per theme: [horizon glow, light streaks].
const PUDDLE_SHEEN := {
	"city": [Color(0.7, 0.3, 0.95), Color(0.15, 0.9, 1.0)],
	"arena": [Color(0.35, 0.55, 1.0), Color(0.95, 0.95, 1.0)],
	"coast": [Color(1.0, 0.55, 0.3), Color(1.0, 0.85, 0.55)],
}


func _build_puddles() -> void:
	var pds: Array = data.get("puddles", [])
	if pds.is_empty():
		return
	_puddle_root = Node3D.new()
	_puddle_root.name = "Puddles"
	add_child(_puddle_root)
	var sh: Array = PUDDLE_SHEEN.get(theme, PUDDLE_SHEEN["arena"])
	# where Forward+ SSR mirrors the real world, the fake reflection only fills in
	var ssr := not Settings.is_compat() and Settings.quality >= 2
	_puddle_mat = TrackBuilder.shader_material("res://shaders/track_puddle.gdshader", {
		"sheen_color": sh[0], "light_color": sh[1], "sheen": 0.45 if ssr else 1.0})
	var k := 0
	for pd in pds:
		var d0: float = pd["d"]
		var len: float = pd["len"]
		var w: float = pd["w"]
		var x: float = pd["x"]
		var mid := path.sample_transform(d0 + len * 0.5)
		surface.add_puddle(Transform3D(mid.basis, mid.origin + mid.basis.x * x), w * 0.5, len * 0.5, bool(pd["storm"]))
		var mi := MeshInstance3D.new()
		mi.name = "Puddle%d" % k
		mi.mesh = _puddle_mesh(d0, len, w, x)
		mi.material_override = _puddle_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("seed", float(k) * 0.37 + 0.11)
		mi.set_meta("storm_only", bool(pd["storm"]))
		_puddle_root.add_child(mi)
		_puddle_meshes.append(mi)
		k += 1


## A grid lying on the road from d0 to d0+len, `w` wide, centered `x` m right of the centerline.
## UV = [-1, 1]^2 over the puddle, UV2 = meters.
func _puddle_mesh(d0: float, len: float, w: float, x: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 6
	var nz := maxi(4, ceili(len / 1.5))
	for j in nz + 1:
		var fz := float(j) / nz
		var f := path.sample_transform(d0 + len * fz)
		for i in nx + 1:
			var fx := float(i) / nx
			var u := fx * 2.0 - 1.0
			st.set_uv(Vector2(u, fz * 2.0 - 1.0))
			st.set_uv2(Vector2(u * w * 0.5, fz * len))
			st.set_normal(f.basis.y)
			st.add_vertex(f.origin + f.basis.x * (x + u * w * 0.5) + f.basis.y * 0.035)
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			# road frame: +x right, -z forward; keep the faces pointing up (basis.y)
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_tangents()
	return st.commit()


# ---------------------------------------------------------------- ground patches (grass/gravel/sand)

const PATCH_BOX_LEN := 5.0


## Layout {"surface": ...} markers: a mesh lying on the road per patch (shaders/track_ground) and
## the matching boxes in `surface` (grip/drag per wheel, res://weather/track_surface.gd).
func _build_ground_patches() -> void:
	var pts: Array = data.get("patches", [])
	if pts.is_empty():
		return
	var root := Node3D.new()
	root.name = "GroundPatches"
	add_child(root)
	var k := 0
	for pt in pts:
		var kind := TrackSurface.kind_id(String(pt["kind"]))
		if kind == 0:
			continue
		var d0: float = pt["d"]
		var len: float = pt["len"]
		var hw := path.width_at(d0 + len * 0.5) * 0.5
		var x0 := clampf(float(pt["x0"]), -hw, hw)
		var x1 := clampf(float(pt["x1"]), -hw, hw)
		if x1 - x0 < 0.5:
			continue
		var boxes: Array = []
		var nb := maxi(1, ceili(len / PATCH_BOX_LEN))
		for b in nb:
			var dm := d0 + (b + 0.5) * len / nb
			var f := path.sample_transform(dm)
			boxes.append({"xf": Transform3D(f.basis, f.origin + f.basis.x * (x0 + x1) * 0.5),
				"hx": (x1 - x0) * 0.5, "hz": len / nb * 0.5 + 0.05})
		surface.add_patch(kind, d0, d0 + len, x0, x1, boxes)
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % [String(pt["kind"]).capitalize(), k]
		mi.mesh = _patch_mesh(d0, len, x0, x1)
		mi.material_override = _ground_material(kind)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		k += 1


static var _ground_mats: Dictionary = {}


func _ground_material(kind: int) -> Material:
	var key := "%d_%s_%s" % [kind, theme, Settings.is_compat()]
	if not _ground_mats.has(key):
		var night := theme != "coast"
		_ground_mats[key] = TrackBuilder.shader_material("res://shaders/track_ground.gdshader", {
			"kind": kind, "brightness": 1.5 if (night and Settings.is_compat()) else 1.0})
	return _ground_mats[key]


## A grid lying on the road from d0 to d0+len between lateral x0 and x1 (+ right), 2.5 cm up.
## UV = meters from the left edge / start, UV2 = meters to the right edge / end.
func _patch_mesh(d0: float, len: float, x0: float, x1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := x1 - x0
	var nx := maxi(2, ceili(w / 2.0))
	var nz := maxi(4, ceili(len / 1.5))
	for j in nz + 1:
		var fz := float(j) / nz
		var f := path.sample_transform(d0 + len * fz)
		for i in nx + 1:
			var fx := float(i) / nx
			st.set_uv(Vector2(fx * w, fz * len))
			st.set_uv2(Vector2((1.0 - fx) * w, (1.0 - fz) * len))
			st.set_normal(f.basis.y)
			st.add_vertex(f.origin + f.basis.x * (x0 + fx * w) + f.basis.y * 0.025)
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	return st.commit()


## Switch the track to a weather mode: puddles fill or dry up, the road gets wet or dry, and
## `surface` (shared with Car.surface) changes grip. Cheap, so it can be called any time.
func apply_weather(mode: String) -> void:
	weather = Weather.sanitize(mode)
	surface.set_mode(weather)
	if _puddle_mat != null:
		_puddle_mat.set_shader_parameter("extent", maxf(Weather.puddle_extent(weather), 0.01))
		_puddle_mat.set_shader_parameter("rain", Weather.rain_density(weather))
	for mi in _puddle_meshes:
		mi.visible = weather == "storm" or (weather == "rain" and not bool(mi.get_meta("storm_only", false)))
	var style: String = layout.get("wall_style", "concrete")
	var road_mat := TrackBuilder.road_material(String(layout.get("road_style", style)), layout.get("wet", false))
	road_mat.set_shader_parameter("wetness", Weather.road_wetness(weather))


# ---------------------------------------------------------------- API

func get_start_transform() -> Transform3D:
	return _pose_at(get_start_pose_distance())


## Distance along the path of the start pose.
func get_start_pose_distance() -> float:
	return start_distance + (START_BACKOFF if is_circuit else -START_BACKOFF)


func get_checkpoint_transform(index: int) -> Transform3D:
	if index < 0 or index >= checkpoint_count:
		return get_start_transform()
	return _pose_at(checkpoint_distances[index])


func _pose_at(d: float) -> Transform3D:
	var f := path.sample_transform(d)
	return Transform3D(f.basis.orthonormalized(), f.origin + f.basis.y * SPAWN_HEIGHT)


func get_minimap_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := clampi(int(path.length / 8.0), 64, 512)
	for i in n + 1:
		var p := path.sample_position(path.length * i / n)
		pts.append(Vector2(p.x, p.z))
	return pts



# ---------------------------------------------------------------- respawn height

## Lowest deck height in 20 m buckets along the path (for kill_y_at).
var _kill_profile := PackedFloat32Array()
const KILL_BUCKET := 20.0


func _build_kill_profile() -> void:
	var below: float = layout.get("kill_below", 12.0)
	var n := ceili(path.length / KILL_BUCKET) + 1
	_kill_profile.resize(n)
	for i in n:
		var lo := 1e9
		var d := (i - 1.5) * KILL_BUCKET
		while d <= (i + 1.5) * KILL_BUCKET:
			lo = minf(lo, path.sample_position(clampf(d, 0.0, path.length)).y)
			d += 4.0
		_kill_profile[i] = maxf(lo - below, kill_y)


## Height below which a car at `p` has fallen off the track (respawn). Follows the deck height
## locally, so a fall from a high platform respawns quickly; never lower than kill_y.
## (Extra API; race may use it instead of kill_y when present.)
func kill_y_at(p: Vector3) -> float:
	if _kill_profile.is_empty():
		return kill_y
	var i := clampi(int(round(path.closest_distance(p) / KILL_BUCKET)), 0, _kill_profile.size() - 1)
	return _kill_profile[i]
