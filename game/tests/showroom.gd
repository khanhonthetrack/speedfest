extends Node3D
## Car look-dev: one car or the whole lineup on a dark reflective floor under neon rim lights.
## Args: --car=f4|kaze|vector|polonez|ridge|all  --angle=front|rear|side|three_quarter|low|top
##       --spin=1 (turntable)  --nitro=1  --brake=1  --lights=1  --setup=stock|max
## Screenshots: --frames=N --shot=/abs/path.png

var cars: Array[CarVisual] = []
var cam: Camera3D
var _spin := false


func _ready() -> void:
	var car_arg := String(TestHooks.arg("car", "all"))
	var angle := String(TestHooks.arg("angle", "three_quarter"))
	_spin = bool(TestHooks.arg("spin", false))
	_world()
	var ids: Array = CarDefs.IDS if car_arg == "all" else [car_arg]
	var spacing := 3.4
	for i in ids.size():
		var id: String = ids[i]
		if not CarDefs.has(id):
			continue
		var setup := _setup_for(id)
		var holder := Node3D.new()
		add_child(holder)
		holder.position = Vector3((float(i) - float(ids.size() - 1) * 0.5) * spacing, 0, 0)
		var cv := CarVisual.new()
		holder.add_child(cv)
		cv.build(id, CarDefs.style_from_setup(id, setup))
		cv.position = Vector3(0, float(CarDefs.geometry(id)["wheel_radius"]), 0)
		cv.set_wheel_state(deg_to_rad(float(TestHooks.arg("steer", 0.0))), [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0])
		cv.set_lights(bool(TestHooks.arg("brake", false)), false)
		cv.set_nitro(bool(TestHooks.arg("nitro", false)))
		if bool(TestHooks.arg("lights", false)):
			cv.set_headlights_real(true)
		cars.append(cv)
		print("CAR %s tris=%d" % [id, cv.get_triangle_count()])
	_camera(angle, ids.size(), spacing)


func _setup_for(id: String) -> Dictionary:
	var setup := Tuning.default_setup(id)
	if String(TestHooks.arg("setup", "stock")) == "max":
		for slot in Tuning.SLOTS:
			if slot in ["paint", "vinyl", "neon", "headlights", "tint", "rims"]:
				continue
			setup[slot] = Tuning.level_count(slot) - 1
	return setup


func _world() -> void:
	var we := WorldEnvironment.new()
	var env := Settings.night_environment()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.30, 0.45)
	env.ambient_light_energy = 0.35
	env.volumetric_fog_density = 0.010
	Settings.tune_environment(env)
	we.environment = env
	add_child(we)
	# dark wet floor
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.020, 0.021, 0.026)
	fm.roughness = 0.12
	fm.metallic = 0.65
	floor_mi.material_override = fm
	add_child(floor_mi)
	# key, fill and two neon rim lights
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 150, 0)
	key.light_energy = 0.55
	key.light_color = Color(0.72, 0.80, 1.0)
	Settings.tune_sun(key)
	add_child(key)
	for spec in [[Vector3(-6, 2.4, -4), Color(0.1, 0.85, 1.0), 26.0], [Vector3(7, 2.0, 5), Color(1.0, 0.15, 0.75), 22.0],
			[Vector3(0, 5.0, -9), Color(0.6, 0.65, 1.0), 14.0]]:
		var o := OmniLight3D.new()
		o.position = spec[0]
		o.light_color = spec[1]
		o.light_energy = spec[2]
		o.omni_range = 28.0
		o.omni_attenuation = 1.4
		add_child(o)


func _camera(angle: String, n: int, spacing: float) -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true
	var span := maxf(float(n - 1) * spacing + 5.0, 6.0)
	var d := span * 0.95
	var p := Vector3(d * 0.75, 1.5, -d * 0.85)
	var look := Vector3(0, 0.55, 0)
	match angle:
		"front":
			p = Vector3(0, 1.1, -d)
		"rear":
			p = Vector3(0, 1.2, d)
		"side":
			p = Vector3(d, 0.95, 0)
		"low":
			p = Vector3(d * 0.6, 0.42, -d * 0.7)
			look = Vector3(0, 0.5, 0)
		"top":
			p = Vector3(0.01, d * 0.9, -0.01)
		_:
			p = Vector3(d * 0.72, 1.45, -d * 0.82)
	cam.position = p
	cam.look_at(look, Vector3.UP)


func _process(delta: float) -> void:
	if _spin:
		for c in cars:
			var h := c.get_parent() as Node3D
			if h:
				h.rotate_y(delta * 0.5)
