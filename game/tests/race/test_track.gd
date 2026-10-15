extends Track
## Tiny test track for the race module (doesn't depend on the tracks module): a flat 600 m
## straight (point-to-point), 3 checkpoint gates and a finish gate, all real Area3Ds.
## Build with `load("res://tests/race/test_track.gd").create()`.

const GATE_DISTANCES: Array[float] = [120.0, 240.0, 360.0]
const FINISH_DISTANCE := 480.0
const LENGTH := 600.0
const WIDTH := 16.0

var gates: Array[Area3D] = []
var finish_gate: Area3D


static func create() -> Track:
	var t: Track = load("res://tests/race/test_track.gd").new()
	t.call("_build")
	return t


func _build() -> void:
	name = "TestTrack"
	track_id = "race_test"
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 20))
	c.add_point(Vector3(0, 0, -LENGTH + 20))
	path = TrackPath.new(c, false, WIDTH)
	checkpoint_count = GATE_DISTANCES.size()
	kill_y = -20.0
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH * 4.0, 1.0, LENGTH + 100.0)
	cs.shape = box
	cs.position = Vector3(0, -0.5, -LENGTH * 0.5 + 20.0)
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(WIDTH, LENGTH + 100.0)
	mi.mesh = pm
	mi.position = Vector3(0, 0.01, -LENGTH * 0.5 + 20.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.17)
	mat.roughness = 0.6
	pm.material = mat
	ground.add_child(mi)
	add_child(ground)
	for i in GATE_DISTANCES.size():
		var g := _make_gate(GATE_DISTANCES[i], Color(0.0, 0.9, 1.0))
		g.body_entered.connect(func(body: Node3D) -> void:
			if body is Car:
				checkpoint_reached.emit(body, i))
		gates.append(g)
	finish_gate = _make_gate(FINISH_DISTANCE, Color(1.0, 0.17, 0.84))
	finish_gate.body_entered.connect(func(body: Node3D) -> void:
		if body is Car:
			finish_reached.emit(body))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.55)
	we.environment = env
	add_child(we)


func _make_gate(d: float, color: Color) -> Area3D:
	var xf := path.sample_transform(d)
	var a := Area3D.new()
	a.collision_layer = 4
	a.collision_mask = 2 | 1
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, 6.0, 2.0)
	cs.shape = box
	cs.position = Vector3(0, 3.0, 0)
	a.add_child(cs)
	a.transform = xf
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 6.0, 0.5)
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		bm.material = m
		post.mesh = bm
		post.position = Vector3(side * WIDTH * 0.5, 3.0, 0)
		a.add_child(post)
	add_child(a)
	return a


func _ready() -> void:
	pass


func get_start_transform() -> Transform3D:
	var xf := path.sample_transform(10.0)
	xf.origin += xf.basis.y * 0.6
	return xf


func get_checkpoint_transform(index: int) -> Transform3D:
	if index < 0:
		return get_start_transform()
	var xf := path.sample_transform(GATE_DISTANCES[clampi(index, 0, GATE_DISTANCES.size() - 1)])
	xf.origin += xf.basis.y * 0.6
	return xf


## Transform inside gate i (finish = -2), for tests that teleport through gates.
func gate_transform(index: int) -> Transform3D:
	var d := FINISH_DISTANCE if index == -2 else GATE_DISTANCES[index]
	var xf := path.sample_transform(d)
	xf.origin += xf.basis.y * 0.6
	return xf


func get_minimap_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		var p := path.sample_position(path.length * i / 32.0)
		pts.append(Vector2(p.x, p.z))
	return pts
