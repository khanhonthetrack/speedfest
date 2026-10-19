extends Node3D
## HUD demo: feeds fake race data to the real HUD over a simple night-street backdrop.
## Args: --show=hud|pause|results  --online=1 (round clock + leaderboard)  --expand=1 (hold Tab)
## Timeline (frames @60): countdown 3/2/1/GO at 10/70/130/190, split blue @330, split red @520,
## nitro 560-700, finish (PB) @760. Speed sweeps 0 -> ~340 km/h.

var hud: Node
var pause_menu: Node
var results: Node
var frame: int = 0
var run_ms: int = -1
var show := "hud"
var online := true
var oval := PackedVector2Array()
var others: Array = []
var _gear: int = 1
var _rpm: float = 0.0


func _ready() -> void:
	show = String(TestHooks.arg("show", "hud"))
	online = TestHooks.arg("online", true)
	_build_backdrop()
	hud = load("res://ui/hud.tscn").instantiate()
	add_child(hud)
	pause_menu = load("res://ui/pause_menu.tscn").instantiate()
	add_child(pause_menu)
	results = load("res://ui/results.tscn").instantiate()
	add_child(results)
	pause_menu.quit_requested.connect(func() -> void: print("demo: quit_requested"))
	for i in 97:
		var a := TAU * i / 96.0
		oval.append(Vector2(cos(a) * 220.0 + sin(a * 2.0) * 30.0, sin(a) * 110.0))
	hud.set_best(62345)
	hud.set_checkpoints(0, 5)
	hud.set_run_time(-1)
	if online:
		hud.set_leaderboard(_fake_board(), 4)
	hud.set_round_time_left(-1)
	if TestHooks.arg("expand", false):
		Input.action_press("leaderboard")
	if show == "pause":
		hud.set_speed(184.0)
		hud.set_rpm(0.62, 4)
		hud.set_run_time(31457)
		pause_menu.open()
		if TestHooks.arg("settings", false):
			pause_menu._toggle_settings()
	elif show == "results":
		hud.set_speed(0.0)
		results.show_results(_fake_board(), 4)


func _fake_board() -> Array:
	return [
		{"id": 2, "name": "NightRider", "car": "veloce", "best_ms": 58712, "runs": 7},
		{"id": 4, "name": "Khanh", "car": "kaze", "best_ms": 59034, "runs": 9},
		{"id": 7, "name": "drift_queen", "car": "brute", "best_ms": 60411, "runs": 5},
		{"id": 1, "name": "Turbo Tom", "car": "kaze", "best_ms": 61988, "runs": 4},
		{"id": 9, "name": "Zed", "car": "brute", "best_ms": -1, "runs": 2},
		{"id": 5, "name": "LongNameMcGeeTheThird", "car": "veloce", "best_ms": 64200, "runs": 3},
	]


func _physics_process(_delta: float) -> void:
	frame += 1
	if show != "hud":
		return
	match frame:
		10: hud.show_countdown(3)
		70: hud.show_countdown(2)
		130: hud.show_countdown(1)
		190:
			hud.show_countdown(0)
			run_ms = 0
		330:
			hud.set_checkpoints(1, 5)
			hud.show_split(run_ms, -234, true)
		400: hud.show_message("Respawned at checkpoint 1", 1.5)
		520:
			hud.set_checkpoints(2, 5)
			hud.show_split(run_ms, 512, true)
		760:
			hud.set_checkpoints(5, 5)
			hud.show_finish(run_ms, true, -1311, true)
			hud.set_best(run_ms)
			if online:
				var b := _fake_board()
				b[1]["best_ms"] = run_ms
				hud.set_leaderboard(b, 4)
	if run_ms >= 0 and frame < 760:
		run_ms += 17
	hud.set_run_time(run_ms if frame < 760 or run_ms < 0 else run_ms)
	# Speed sweep with a fake gearbox.
	var t := clampf((frame - 190) / 560.0, 0.0, 1.0)
	var kmh := 345.0 * (1.0 - pow(1.0 - t, 1.6)) if frame >= 190 else 0.0
	var top := [0.0, 70.0, 120.0, 170.0, 225.0, 285.0, 400.0]
	_gear = 1
	while _gear < 6 and kmh > top[_gear]:
		_gear += 1
	var lo: float = top[_gear - 1] * 0.7
	_rpm = clampf((kmh - lo) / (top[_gear] - lo), 0.12, 0.97) if frame >= 190 else 0.14 + 0.05 * sin(frame * 0.3)
	hud.set_speed(kmh)
	hud.set_rpm(_rpm, _gear if frame >= 190 else 0)
	var nitro_on := frame >= 560 and frame < 700
	var amount := 1.0 - clampf((frame - 560) / 200.0, 0.0, 0.7) if frame >= 560 else 1.0
	hud.set_nitro(amount, nitro_on)
	if online:
		hud.set_round_time_left(maxi(0, 34000 - frame * 1000 / 60))
	# Cars around the oval.
	var u := fmod(frame / 900.0, 1.0)
	var idx := int(u * 96.0)
	others.clear()
	for k in 3:
		others.append({"pos": oval[(idx + 10 + k * 23) % 96], "color": [UITheme.MAGENTA, UITheme.AMBER, UITheme.CYAN][k]})


func _build_backdrop() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.02, 0.03, 0.09)
	mat.sky_horizon_color = Color(0.35, 0.12, 0.4)
	mat.ground_horizon_color = Color(0.2, 0.08, 0.25)
	mat.ground_bottom_color = Color(0.02, 0.02, 0.04)
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.glow_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Settings.tune_environment(e)
	env.environment = e
	add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.2, 6)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 70
	add_child(cam)
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 400)
	road.mesh = pm
	road.position = Vector3(0, 0, -190)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.06, 0.06, 0.08)
	rm.roughness = 0.35
	road.material_override = rm
	add_child(road)
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(400, 400)
	ground.mesh = gm
	ground.position = Vector3(0, -0.02, -190)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.02, 0.02, 0.035)
	ground.material_override = gmat
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var side := -1.0 if i % 2 == 0 else 1.0
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var h := rng.randf_range(8.0, 40.0)
		bm.size = Vector3(rng.randf_range(6, 12), h, rng.randf_range(6, 14))
		b.mesh = bm
		b.position = Vector3(side * rng.randf_range(14, 24), h * 0.5, -10.0 - i * 9.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.06, 0.1)
		m.emission_enabled = true
		m.emission = [UITheme.CYAN, UITheme.MAGENTA, UITheme.AMBER][i % 3] * 0.25
		b.material_override = m
		add_child(b)
	for i in 30:
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.2, 0.02, 3.0)
		line.mesh = lm
		line.position = Vector3(0, 0.01, -i * 8.0)
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(1, 1, 1)
		m2.emission_enabled = true
		m2.emission = Color(0.8, 0.8, 0.7)
		line.material_override = m2
		add_child(line)
	# A stand-in car shape.
	var car := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.9, 0.9, 4.2)
	car.mesh = cm
	car.position = Vector3(0, 0.6, 0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.7, 0.05, 0.4)
	cmat.metallic = 0.6
	cmat.roughness = 0.3
	car.material_override = cmat
	add_child(car)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 0.5
	add_child(light)
