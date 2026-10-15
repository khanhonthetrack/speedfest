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
var finish_gate: Area3D
var boost_pads: Array[Area3D] = []


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
	t.kill_y = float(t.layout.get("kill_y", min_y - 12.0))
	t._build_geometry()
	if with_scenery:
		var env := SceneryKit.build_environment(t.theme)
		if env != null:
			t.add_child(env)
		var props := SceneryKit.build_props(t.theme, t.path, hash(t.track_id))
		if props != null:
			t.add_child(props)
	return t


func _build_geometry() -> void:
	TrackBuilder.build_road(self, data, layout)
	TrackBuilder.build_supports(self, data, layout)
	match String(layout.get("ground", "none")):
		"city", "arena":
			TrackBuilder.build_flat_ground(self, data, layout)
		"terrain":
			TrackBuilder.build_terrain(self, data, layout)
	TrackBuilder.build_corner_signs(self, data, layout)
	_build_gates()
	_build_boost_pads()


# ---------------------------------------------------------------- gates

func _build_gates() -> void:
	var gate_root := Node3D.new()
	gate_root.name = "Gates"
	add_child(gate_root)
	for i in checkpoint_count:
		var area := _make_gate(gate_root, checkpoint_distances[i], "cp")
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


func _make_gate(parent: Node3D, d: float, kind: String, with_area := true) -> Area3D:
	var f := path.sample_transform(d)
	var hw := path.width_at(d) * 0.5
	var root := Node3D.new()
	root.transform = f
	parent.add_child(root)
	# arch visual
	var frame := TrackBuilder.Acc.new()
	var neon := TrackBuilder.Acc.new()
	var banner := TrackBuilder.Acc.new()
	var px := hw + TrackBuilder.WALL_GAP + 1.5
	var top := 7.6
	var pw := 1.5
	var bh := 2.2
	for sx in [-1.0, 1.0]:
		frame.box(Transform3D(Basis.IDENTITY, Vector3(sx * px, top * 0.5 - 0.6, 0)), Vector3(pw, top + 1.2, pw))
		# neon on the inner face and on the front/back edges of each pillar
		neon.box(Transform3D(Basis.IDENTITY, Vector3(sx * (px - pw * 0.5 - 0.02), top * 0.5 - 0.4, 0)), Vector3(0.06, top + 0.2, 0.35))
		for sz in [-1.0, 1.0]:
			neon.box(Transform3D(Basis.IDENTITY, Vector3(sx * (px - pw * 0.5 + 0.08), top * 0.5 - 0.4, sz * (pw * 0.5 + 0.02))), Vector3(0.14, top + 0.2, 0.06))
	frame.box(Transform3D(Basis.IDENTITY, Vector3(0, top + bh * 0.5 - 0.2, 0)), Vector3(px * 2.0 + pw, bh, pw))
	neon.box(Transform3D(Basis.IDENTITY, Vector3(0, top - 0.24, 0)), Vector3(px * 2.0 - pw, 0.06, 0.6))
	for sz in [-1.0, 1.0]:
		neon.box(Transform3D(Basis.IDENTITY, Vector3(0, top + bh - 0.32, sz * (pw * 0.5 + 0.02))), Vector3(px * 2.0 + pw - 0.2, 0.12, 0.06))
		neon.box(Transform3D(Basis.IDENTITY, Vector3(0, top - 0.08, sz * (pw * 0.5 + 0.02))), Vector3(px * 2.0 + pw - 0.2, 0.12, 0.06))
	if kind != "cp":
		banner.box(Transform3D(Basis.IDENTITY, Vector3(0, top + bh * 0.5 - 0.2, 0)), Vector3(px * 2.0 - pw - 0.4, bh - 0.6, pw + 0.06), 1.0)
	var mesh := ArrayMesh.new()
	frame.commit(mesh, TrackBuilder.material("metal_dark"))
	var neon_key := "neon_cyan" if kind == "cp" else "neon_magenta"
	if theme == "coast":
		neon_key = "neon_orange" if kind == "cp" else "neon_magenta"
	neon.commit(mesh, TrackBuilder.material(neon_key))
	if not banner.is_empty():
		banner.commit(mesh, TrackBuilder.shader_material("res://shaders/track_neon.gdshader", {
			"color": Color(1, 1, 1), "energy": 1.4, "checker": 1.0, "checker_scale": Vector2(1.0, 0.65)}))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Arch"
	root.add_child(mi)
	if kind != "cp":
		var lbl := Label3D.new()
		lbl.text = "FINISH" if (kind == "finish" and not is_circuit) else ("START" if kind == "start" else "START  ·  FINISH")
		lbl.font_size = 96
		lbl.pixel_size = 0.016
		lbl.outline_size = 18
		lbl.modulate = Color(1, 1, 1)
		lbl.outline_modulate = Color(0.05, 0.0, 0.1)
		lbl.position = Vector3(0, top + bh * 0.5 - 0.2, pw * 0.5 + 0.08)
		root.add_child(lbl)
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
	for b in data["boosts"]:
		var d0: float = b["d"]
		var len: float = b["len"]
		var mid := path.sample_transform(d0 + len * 0.5)
		var pw := minf(path.width_at(d0) - 4.0, 9.0)
		var acc := TrackBuilder.Acc.new()
		var ds := TrackBuilder.ring_ds(d0, d0 + len, 1.0)
		var frames: Array[Transform3D] = []
		var prof: Array = []
		for dd in ds:
			var f := path.sample_transform(dd)
			frames.append(Transform3D(f.basis, f.origin + f.basis.y * 0.03))
			prof.append(PackedVector2Array([Vector2(-pw * 0.5, 0), Vector2(pw * 0.5, 0)]))
		var dsl := PackedFloat32Array()
		for dd in ds:
			dsl.append(dd - d0)
		TrackBuilder.loft(acc, frames, dsl, prof)
		var mesh := ArrayMesh.new()
		acc.commit(mesh, mat)
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
		area.transform = mid
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
