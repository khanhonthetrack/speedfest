class_name Race
extends Node3D
## One session on a track: the night city, the circuit, the player's car, the chase camera, the
## timing and the HUD.
##
## Progress is geometric, not physical: the car's position is projected onto the TrackPath every
## frame (through the CityField index), which gives the distance along the lap. A checkpoint counts
## when that distance passes it going forward, and a lap when every checkpoint has been passed and
## the car crosses the line. Respawning puts the car back on the road at the last checkpoint.
##
## Test args: --track=downtown|harbour --car=<id> --laps=N --nocity=1 --autodrive=1

signal checkpoint_passed(index: int, time_ms: int)
signal lap_done(lap: int, time_ms: int, best: bool)
signal race_done(total_ms: int)

const RESPAWN_HOLD_MS := 450

var track_id := "downtown"
var car: TmCar
var rig: CarRig
var cam: TmCamera
var hud: Node

var path: TrackPath
var field: SceneryField
var info: Dictionary = {}
var city: Node3D

# --- timing ---
var started := false
var finished := false
var start_ms := 0
var lap := 1
var laps := 3
var lap_start_ms := 0
var best_lap_ms := 0
var last_lap_ms := 0
var next_cp := 0
var cp_times: Array[int] = []
var countdown_ms := 3200

var bot: AutoDriver           ## set when --autodrive is on: the bot drives instead of the player

var _progress := 0.0          ## distance along the lap of the car's projection on the path
var _lap_distance := 0.0      ## metres covered this lap (unwrapped; negative when going backwards)
var _respawn_d := 0.0
var _off_road_ms := 0


func _ready() -> void:
	track_id = String(TestHooks.arg("track", Game.track))
	if not TrackDefs.has(track_id):
		track_id = "downtown"
	laps = int(TestHooks.arg("laps", TrackDefs.laps_of(track_id)))
	_build_world()
	_build_car()
	_build_camera()
	countdown_ms = 0 if TestHooks.is_testing() and not TestHooks.has_arg("countdown") else 3200
	lap_start_ms = Time.get_ticks_msec()
	start_ms = lap_start_ms


func _build_world() -> void:
	var builder := TrackBuilder.new()
	var track := builder.build(track_id)
	add_child(track)
	path = builder.path
	info = builder.info
	laps = mini(laps, 99)
	field = SceneryField.new(path, 4.0)
	# the night city all around the circuit
	if not bool(TestHooks.arg("nocity", false)):
		var t0 := Time.get_ticks_msec()
		city = CityKit.new().build(field, hash(track_id))
		add_child(city)
		print("CITY built in %d ms: %s" % [Time.get_ticks_msec() - t0, city.get_meta("stats", {})])
	add_child(CityEnv.create())


func _build_car() -> void:
	var id := String(TestHooks.arg("car", Garage.selected))
	if not CarDefs.has(id):
		id = "kaze"
	car = TmCar.new()
	car.name = "Car"
	add_child(car)
	car.configure(id, Garage.setup_of(id))
	rig = CarRig.new(car)
	car.add_child(rig)
	var input := TmCarInput.new()
	input.car = car
	add_child(input)
	car.controls_enabled = false
	_place_at(0.0)
	if bool(TestHooks.arg("autodrive", false)):
		input.queue_free()
		bot = AutoDriver.new()
		bot.car = car
		bot.path = path
		car.add_child(bot)
		bot.reset_to(2.0)
		bot.stuck.connect(func() -> void:
			respawn()
			bot.reset_to(_respawn_d))


func _build_camera() -> void:
	cam = TmCamera.new()
	cam.target = car
	add_child(cam)
	cam.current = true
	cam.snap()


## Put the car on the road at distance `d`, at rest, facing the direction of travel.
func _place_at(d: float, keep_speed: float = 0.0) -> void:
	var t := path.sample_transform(fposmod(d, path.length))
	# the car's frame is +X left, +Z forward; the path frame is +X right, -Z forward
	var xf := Transform3D(Basis(-t.basis.x, t.basis.y, -t.basis.z), t.origin + t.basis.y * 0.02)
	car.place(xf)
	car.lin_vel = xf.basis.z * keep_speed
	car.boost_meter = maxf(car.boost_meter, 0.35)
	_progress = fposmod(d, path.length)
	_lap_distance = 0.0
	if cam:
		cam.snap()


func respawn() -> void:
	_place_at(_respawn_d, 0.0)
	_off_road_ms = 0
	if bot:
		bot.reset_to(_respawn_d)


func restart() -> void:
	started = false
	finished = false
	lap = 1
	next_cp = 0
	cp_times.clear()
	best_lap_ms = 0
	last_lap_ms = 0
	_respawn_d = 0.0
	countdown_ms = 3200
	car.controls_enabled = false
	car.boost_meter = 1.0
	_place_at(0.0)
	lap_start_ms = Time.get_ticks_msec()
	start_ms = lap_start_ms


func elapsed_ms() -> int:
	if not started:
		return 0
	return Time.get_ticks_msec() - lap_start_ms


func total_ms() -> int:
	if not started:
		return 0
	return Time.get_ticks_msec() - start_ms


func _process(delta: float) -> void:
	_tick_countdown(delta)
	_track_progress(delta)
	if Input.is_action_just_pressed("respawn"):
		respawn()
	if Input.is_action_just_pressed("restart"):
		restart()


func _tick_countdown(delta: float) -> void:
	if started:
		return
	countdown_ms -= int(delta * 1000.0)
	if countdown_ms <= 0:
		started = true
		car.controls_enabled = true
		lap_start_ms = Time.get_ticks_msec()
		start_ms = lap_start_ms


func countdown_number() -> int:
	return clampi(int(ceil(countdown_ms / 1000.0)), 0, 3)


## Project the car onto the path and turn that into laps, checkpoints and a respawn point.
func _track_progress(delta: float) -> void:
	if car == null or path == null:
		return
	field.query(car.global_transform.origin, 400.0)
	if field.q_index < 0:
		return
	var prev := _progress
	_progress = field.q_d
	# the shortest signed step around the loop (the car moves a few metres per frame at most)
	var step := _progress - prev
	if step < -path.length * 0.5:
		step += path.length
	elif step > path.length * 0.5:
		step -= path.length
	_lap_distance += step
	# a safe place to come back to: on the road, upright, a little behind the car
	if field.q_clear < 4.0 and car.global_transform.basis.y.dot(Vector3.UP) > 0.5:
		_respawn_d = fposmod(_progress - 8.0, path.length)
		_off_road_ms = 0
	else:
		_off_road_ms += int(delta * 1000.0)
	# safety net: a car that ends up far below the road (through a gap, off a barrier) comes back
	if car.global_transform.origin.y < path.sample_position(_progress).y - 25.0:
		respawn()
		return
	if not started or finished or step <= 0.0:
		return
	var wrapped := _progress < prev
	var cps: Array = info.get("checkpoints", [])
	while next_cp < cps.size():
		var target := float(cps[next_cp])
		var crossed: bool
		if next_cp == cps.size() - 1:
			crossed = wrapped                       # the finish line is the wrap itself
		elif wrapped:
			crossed = prev < target or _progress >= target
		else:
			crossed = prev < target and _progress >= target
		if not crossed:
			break
		_pass_checkpoint()


func _pass_checkpoint() -> void:
	var cps: Array = info.get("checkpoints", [])
	var t := elapsed_ms()
	cp_times.append(t)
	checkpoint_passed.emit(next_cp, t)
	next_cp += 1
	if next_cp >= cps.size():
		_finish_lap(t)


func _finish_lap(t: int) -> void:
	next_cp = 0
	cp_times.clear()
	_lap_distance = 0.0
	last_lap_ms = t
	var improved := Game.submit_lap(track_id, car.car_id, t)
	if best_lap_ms == 0 or t < best_lap_ms:
		best_lap_ms = t
	lap_done.emit(lap, t, improved)
	if lap >= laps:
		finished = true
		car.controls_enabled = false
		race_done.emit(total_ms())
		return
	lap += 1
	lap_start_ms = Time.get_ticks_msec()


## 0..1 around the lap, for the HUD's mini map.
func progress_ratio() -> float:
	return clampf(_progress / maxf(path.length, 1.0), 0.0, 1.0)
