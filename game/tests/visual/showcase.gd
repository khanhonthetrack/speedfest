extends Node3D
## Car showcase: reflective dark floor, studio/night lighting, one or all cars.
## Args: --car=kaze|brute|veloce|all  --angle=front|rear|side|three_quarter|top|low  --style=default|alt|max
##       --spin=1 (turntable)  --nitro=1  --brake=1  --ghost=0.5  --lights=1 (real headlights)

var cars: Array[CarVisual] = []
var cam: Camera3D


func _ready() -> void:
	var car_arg := String(TestHooks.arg("car", "all"))
	var angle := String(TestHooks.arg("angle", "three_quarter"))
	var style_arg := String(TestHooks.arg("style", "default"))
	_build_world()
	var ids: Array = CarDefs.IDS if car_arg == "all" else [car_arg]
	var spacing := 3.2
	for i in ids.size():
		var id: String = ids[i]
		var cv := CarVisual.new()
		add_child(cv)
		cv.build(id, style_for(id, style_arg))
		var x := (float(i) - float(ids.size() - 1) * 0.5) * spacing
		cv.position = Vector3(x, float(CarDefs.geometry(id)["wheel_radius"]), 0)
		var steer := float(TestHooks.arg("steer", 0.0))
		cv.set_wheel_state(steer, [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0])
		cv.set_lights(TestHooks.arg("brake", false), TestHooks.arg("reverse", false))
		cv.set_nitro(TestHooks.arg("nitro", false))
		if TestHooks.has_arg("ghost"):
			cv.set_ghost(float(TestHooks.arg("ghost", 1.0)))
		if TestHooks.arg("lights", false):
			cv.set_headlights_real(true)
		cars.append(cv)
		print("CAR %s tris=%d" % [id, cv.get_triangle_count()])
	_place_camera(angle, ids.size())


static func style_for(id: String, which: String) -> Dictionary:
	var s := CarDefs.default_style(id)
	if which == "alt":
		var alt := {
			"kaze": {"paint": "#f4f4f4", "finish": "pearl", "accent": "#e0102a", "livery": "side_stripe", "hood": 2, "hood_carbon": false,
				"front": 2, "rear": 2, "skirts": 2, "spoiler": 4, "rims": 4, "rim_color": "#202020", "underglow": "#ff2bd6", "tint": 0.85},
			"brute": {"paint": "#1257ff", "finish": "metallic", "accent": "#f0f0f0", "livery": "two_tone", "hood": 3, "front": 2, "rear": 2,
				"skirts": 1, "spoiler": 3, "rims": 0, "rim_color": "#c8c8c8", "underglow": "#00e5ff", "underglow_mode": "static"},
			"veloce": {"paint": "#ffd400", "finish": "gloss", "accent": "#111111", "livery": "racing_stripes", "hood": 1, "hood_carbon": true,
				"front": 1, "rear": 1, "skirts": 1, "spoiler": 3, "rims": 1, "rim_color": "#b0b0b0", "underglow": "#ff6a00", "underglow_mode": "static"},
		}
		s.merge(alt[id], true)
	elif which == "max":
		s.merge({"hood": 3, "hood_carbon": true, "front": 2, "rear": 2, "skirts": 2, "spoiler": 4, "rims": 3,
			"livery": "checker", "finish": "chrome", "underglow_mode": "rainbow", "ride_height": -1.0}, true)
	elif which.begins_with("parts"):
		# parts:<hood>,<front>,<rear>,<skirts>,<spoiler>,<rims>
		var v := which.substr(6).split(",")
		var keys := ["hood", "front", "rear", "skirts", "spoiler", "rims"]
		for k in mini(v.size(), keys.size()):
			s[keys[k]] = int(v[k])
	elif which.begins_with("livery:"):
		s["livery"] = which.substr(7)
	elif which.begins_with("finish:"):
		s["finish"] = which.substr(7)
	return s


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.05, 0.07, 0.16)
	psm.sky_horizon_color = Color(0.55, 0.42, 0.65)
	psm.ground_bottom_color = Color(0.02, 0.02, 0.03)
	psm.ground_horizon_color = Color(0.25, 0.15, 0.3)
	psm.sky_energy_multiplier = 1.6
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssr_enabled = true
	env.ssao_enabled = true
	Settings.tune_environment(env)
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.95, 0.9)
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 30, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.6, 0.9)
	rim.light_specular = 0.0
	add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.8
	fill.light_color = Color(0.5, 0.6, 1.0)
	fill.light_specular = 0.2
	add_child(fill)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.03, 0.03, 0.035)
	fm.metallic = 0.0
	fm.roughness = 0.4
	floor.material_override = fm
	add_child(floor)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)


func _place_camera(angle: String, n: int) -> void:
	var dist := 7.0 if n == 1 else 11.5
	var dir := Vector3(-1.0, 0.35, -1.15)
	match angle:
		"front":
			dir = Vector3(0, 0.3, -1)
		"rear":
			dir = Vector3(0, 0.3, 1)
		"side":
			dir = Vector3(-1, 0.18, 0)
		"rear_quarter":
			dir = Vector3(-1.0, 0.4, 1.1)
		"top":
			dir = Vector3(0.01, 1, 0.01)
		"low":
			dir = Vector3(-1.0, 0.08, -0.8)
		"chase":
			dir = Vector3(0.0, 0.32, 1.0)
			dist = 6.5 if n == 1 else 9.0
		"close":
			dir = Vector3(-1.0, 0.9, -0.6)
			dist = 4.5
		"wheel":
			dir = Vector3(-1.0, 0.05, -0.25)
			dist = 2.6
	var target := Vector3(0, 0.55, 0)
	if angle == "wheel" and n == 1:
		target = Vector3(-0.7, 0.33, -1.2)
	cam.position = target + dir.normalized() * dist
	cam.look_at(target)


func _process(delta: float) -> void:
	if TestHooks.arg("spin", false):
		for c in cars:
			c.rotate_y(delta * 0.6)
