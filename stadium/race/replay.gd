class_name TmReplayView
extends Node3D
## Watching a replay (TMNF's replay viewer): the track built as for a race, the run played back on
## a puppet car (a TmCar that doesn't simulate: its state is set from the replay every tick, so the
## chase camera, the engine sound and the HUD's clock, speed and checkpoint times work as in a
## race), the countdown before it, and cameras: CHASE, CLOSE, COCKPIT, TRACKSIDE (TV spots beside
## the run, every ~120 m), FREE (fly).
## Keys: Space play/pause, Left/Right 5 s back/on, Up/Down speed (x1/8 .. x4), C or 1-5 camera,
## Home from the start, H hide the controls, Esc back.
## Args: --replay=<path> (else the newest kept); --back=menu|race (Esc: the menu's replays page, or
## a race on the replay's track); --replay_at=<ms> (start there, paused: screenshots), --cam=<name>.

const PREROLL_MS := 1500           ## the countdown before the run
const TAIL_MS := 2500              ## after the finish
const SPEEDS := [0.125, 0.25, 0.5, 1.0, 2.0, 4.0]
const CAMS := ["CHASE", "CLOSE", "COCKPIT", "TRACKSIDE", "FREE"]

var replay: TmReplay
var challenge: TmChallenge
var builder: TmMapBuilder
var car: TmCar
var race: TmRace                   ## the HUD's clock and checkpoints, driven by the replay
var hud: TmRaceHud
var audio: TmCarAudio
var t_ms := -float(PREROLL_MS)     ## replay time (race clock; negative: the countdown)
var playing := true
var speed_index := 3
var cam_index := 0
var best := {}
var error := ""

var _chase: TmCamera
var _close: TmCamera
var _cockpit: Camera3D
var _tv: Camera3D
var _free: Camera3D
var _spots: Array[Vector3] = []
var _spot := -1
var _last_index := -1
var _splits_shown := 0
var _finish_shown := false
var _bar: Control
var _play_btn: Button
var _speed_l: Label
var _cam_l: Label
var _time_l: Label
var _slider: HSlider
var _sliding := false
var _free_look := Vector2.ZERO


func _ready() -> void:
	TmUi.apply()
	var path := String(TestHooks.arg("replay", ""))
	if path.is_empty():
		var all := TmReplay.list()
		if not all.is_empty():
			path = String(all[0]["path"])
	replay = TmReplay.load_file(path) if not path.is_empty() else null
	if replay == null or replay.count() == 0:
		_fail("No replay to watch" + (" (%s)" % path if not path.is_empty() else ""))
		return
	TestHooks.args.erase("map")
	TestHooks.args.erase("track")
	if not replay.map.is_empty():
		TestHooks.args["map"] = replay.map
	else:
		TestHooks.args["track"] = replay.track
	challenge = TmStage.load_from_args()
	if not challenge.ok():
		_fail(challenge.error)
		return
	builder = TmMapBuilder.build(challenge)
	add_child(builder.root)
	TmStage.add_environment(self, builder)
	Music.play_list("race")
	car = TmCar.new()
	add_child(car)
	car.set_physics_process(false)   # a puppet: never simulated (after add_child, which turns it on)
	var look := TmCarVisual.new()
	look.paint_colour = replay.colour
	car.add_child(look)
	var cps := 0
	for wp: Dictionary in builder.waypoints:
		if int(wp["kind"]) == TmBlockCatalogue.Waypoint.CHECKPOINT:
			cps += 1
	_spots = spots(replay)
	race = TmRace.new(cps, challenge.nb_laps if challenge.lap_race else 1)
	best = TmRecords.best(challenge)
	hud = TmRaceHud.new()
	hud.race = race
	hud.car = car
	hud.challenge = challenge
	hud.best = best
	add_child(hud)
	audio = TmCarAudio.new()
	audio.car = car
	add_child(audio)
	_cameras()
	_controls()
	t_ms = float(TestHooks.arg("replay_at", -PREROLL_MS))
	if TestHooks.has_arg("replay_at"):
		playing = false
	var cam_arg := String(TestHooks.arg("cam", "")).to_upper()
	set_camera(maxi(0, CAMS.find(cam_arg)) if not cam_arg.is_empty() else 0)
	_apply(true)
	if not replay.uid.is_empty() and replay.uid != challenge.uid:
		_note("This track has changed since the replay was recorded")


func _fail(text: String) -> void:
	error = text
	push_error("replay: %s" % text)
	if TestHooks.is_testing():
		return
	_note(text + "   (Esc: back)")


func _note(text: String) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 6
	add_child(cl)
	var l := TmUi.label(text, 26, TmUi.TEXT, TmUi.BOLD)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 110)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cl.add_child(l)


## The trackside (TV) spots for a run: every SPOT_STEP metres along it, beside the line (sides
## alternating), up, a little ahead, so the car comes towards the camera and passes it.
const SPOT_STEP := 120.0


static func spots(r: TmReplay) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var run := SPOT_STEP * 0.5
	var prev := Vector3.INF
	for i in r.count():
		var st := r.state(i * TmReplay.INTERVAL_MS)
		var xf: Transform3D = st["xform"]
		if prev != Vector3.INF:
			run += xf.origin.distance_to(prev)
		prev = xf.origin
		if run < SPOT_STEP:
			continue
		run = 0.0
		var b := xf.basis.orthonormalized()
		var fwd := Vector3(b.z.x, 0.0, b.z.z).normalized()
		if fwd.length() < 0.5:
			continue
		var right := fwd.cross(Vector3.UP)
		var side := 1.0 if out.size() % 2 == 0 else -1.0
		out.append(xf.origin + right * 13.0 * side + fwd * 30.0 + Vector3.UP * 5.0)
	return out


func _cameras() -> void:
	_chase = TmCamera.new()
	_chase.target = car
	add_child(_chase)
	_close = TmCamera.new()
	_close.target = car
	_close.distance = 4.0
	_close.height = 1.15
	_close.look_height = 0.7
	_close.base_fov = 78.0
	_close.fast_fov = 90.0
	add_child(_close)
	_cockpit = Camera3D.new()
	_cockpit.near = 0.05
	_cockpit.fov = 80.0
	# at the driver's eyes (the helmet's centre, car coordinates), looking along the car (+Z)
	_cockpit.transform = Transform3D(Basis(Vector3.UP, PI), TmCarVisual.HELMET - TmCarVisual.VIS + Vector3(0.0, 0.06, 0.08))
	car.add_child(_cockpit)
	_tv = Camera3D.new()
	_tv.far = 4000.0
	_tv.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_tv)
	_free = Camera3D.new()
	_free.far = 4000.0
	_free.fov = 70.0
	_free.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_free)


func set_camera(i: int) -> void:
	var prev := get_viewport().get_camera_3d()
	cam_index = posmod(i, CAMS.size())
	var cam: Camera3D = [_chase, _close, _cockpit, _tv, _free][cam_index]
	if cam == _free and prev:
		_free.global_transform = prev.global_transform
		_free_look = Vector2(prev.global_rotation.y, prev.global_rotation.x)
	if cam == _tv:
		_spot = -1
	cam.current = true
	if cam is TmCamera:
		(cam as TmCamera).snap()
	if _cam_l:
		_cam_l.text = CAMS[cam_index]


## The controls along the bottom (TMNF's replay bar): play/pause, speed, the time line, the camera.
func _controls() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	_bar = PanelContainer.new()
	_bar.theme = TmUi.theme()
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -560
	_bar.offset_right = 560
	_bar.offset_top = -262
	_bar.offset_bottom = -150
	cl.add_child(_bar)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	_bar.add_child(lines)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	lines.add_child(row)
	_play_btn = TmUi.button("PAUSE", toggle_play, 130)
	_play_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_play_btn)
	var slower := TmUi.button("-", func() -> void: set_speed(speed_index - 1), 54)
	slower.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(slower)
	_speed_l = TmUi.label("x1", 24, TmUi.ACCENT, TmUi.HEAD)
	_speed_l.custom_minimum_size.x = 76
	_speed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_speed_l)
	var faster := TmUi.button("+", func() -> void: set_speed(speed_index + 1), 54)
	faster.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(faster)
	_slider = HSlider.new()
	_slider.min_value = -PREROLL_MS
	_slider.max_value = replay.length_ms() + TAIL_MS
	_slider.step = 10
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.custom_minimum_size.y = 40
	_slider.drag_started.connect(func() -> void: _sliding = true)
	_slider.drag_ended.connect(func(_c: bool) -> void:
		_sliding = false
		seek(_slider.value))
	row.add_child(_slider)
	_time_l = TmUi.label("", 22, TmUi.TEXT, TmUi.HEAD)
	_time_l.custom_minimum_size.x = 250
	_time_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_time_l)
	_cam_l = TmUi.label(CAMS[cam_index], 20, TmUi.ACCENT, TmUi.HEAD, 2)
	var cam_btn := TmUi.button("CAMERA", func() -> void: set_camera(cam_index + 1), 150)
	cam_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(cam_btn)
	# who and what, at the top right; the keys under the controls
	var who := VBoxContainer.new()
	who.anchor_left = 1.0
	who.anchor_right = 1.0
	who.offset_left = -700
	who.offset_right = -40
	who.offset_top = 76
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.theme = TmUi.theme()
	cl.add_child(who)
	var tag := TmUi.label("REPLAY", 22, TmUi.ACCENT, TmUi.HEAD, 3)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_END
	who.add_child(tag)
	var nick := TmUi.nick_label(replay.player, 30)
	nick.size_flags_horizontal = Control.SIZE_SHRINK_END
	who.add_child(nick)
	var what := TmUi.label("%s   %s" % [replay.track_name, TmRace.time_text(replay.finish_ms)], 22, TmUi.DIM, TmUi.BOLD, 1)
	what.size_flags_horizontal = Control.SIZE_SHRINK_END
	who.add_child(what)
	_cam_l.size_flags_horizontal = Control.SIZE_SHRINK_END
	who.add_child(_cam_l)
	var keys := TmUi.label("SPACE  PLAY / PAUSE      LEFT / RIGHT  5 S      UP / DOWN  SPEED      C / 1-5  CAMERA      H  HIDE      ESC  BACK",
		15, TmUi.DIM, TmUi.BOLD, 2)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(keys)


func toggle_play() -> void:
	if not playing and t_ms >= replay.length_ms() + TAIL_MS - 10:
		seek(-PREROLL_MS)
	playing = not playing
	_play_btn.text = "PAUSE" if playing else "PLAY"


func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	var s: float = SPEEDS[speed_index]
	_speed_l.text = "x%s" % (str(int(s)) if s >= 1.0 else "1/%d" % roundi(1.0 / s))


## Jumps to a time (ms): the car there, the HUD's checkpoints as they stood then.
func seek(to_ms: float) -> void:
	t_ms = clampf(to_ms, -PREROLL_MS, replay.length_ms() + TAIL_MS)
	hud.reset()
	_apply(true)


func _physics_process(_delta: float) -> void:
	if replay == null or car == null:
		return
	if playing:
		t_ms += TmRace.TICK_MS * float(SPEEDS[speed_index])
		if t_ms >= replay.length_ms() + TAIL_MS:
			t_ms = replay.length_ms() + TAIL_MS
			playing = false
			_play_btn.text = "PLAY"
	_apply(false)


## The puppet, the clock and the HUD at t_ms. jump: a seek (no events, no blending from before).
func _apply(jump: bool) -> void:
	var st := replay.state(t_ms)
	var xf: Transform3D = st["xform"]
	var m := car.model
	car.transform = xf
	car.body.xform = xf
	car.body.lin_vel = st["vel"]
	car.body.gas = float(st["gas"]) if t_ms >= 0.0 else 0.0
	car.body.brake = float(st["brake"])
	m.steer = float(st["steer"])
	m.susp_len = st["susp"]
	car.body.wheel_contact = st["contact"]
	m.grounded = st["grounded"]
	m.any_sliding = st["sliding"]
	car.body.now_ms = int(t_ms)
	var index := int(st["index"])
	if jump:
		car.reset_physics_interpolation()
		m.turbo_until_ms = -1
	elif index > _last_index and t_ms >= 0.0:
		for i in range(_last_index + 1, index + 1):
			var fl := replay.flags_at(i)
			if fl & TmReplay.F_WALL:
				car.wheel_hit_wall.emit()
			if fl & TmReplay.F_TURBO:
				m.turbo_until_ms = int(t_ms) + 1000
			if fl & TmReplay.F_CUT:
				car.reset_physics_interpolation()
				_chase.snap()
				_close.snap()
	if jump:
		_chase.snap()
		_close.snap()
	_last_index = index
	_clock(jump)
	if not _sliding and _slider:
		_slider.set_value_no_signal(t_ms)
	if _time_l:
		_time_l.text = "%s / %s" % [TmRace.time_text(maxi(0, int(t_ms))), TmRace.time_text(replay.length_ms())]


## The race clock for the HUD: the countdown, the run, the checkpoints passed, the finish.
func _clock(jump: bool) -> void:
	var fin := replay.finish_ms
	if t_ms < 0.0:
		race.state = TmRace.State.COUNTDOWN
		race.countdown_ms = int(-t_ms)
		race.time_ms = 0
	elif fin >= 0 and t_ms >= fin:
		race.state = TmRace.State.FINISHED
		race.time_ms = fin
	else:
		race.state = TmRace.State.RACING
		race.time_ms = int(t_ms)
	# checkpoints: every split before the finish that the clock has passed
	var cps: Array = replay.splits.slice(0, maxi(0, replay.splits.size() - (1 if fin >= 0 else 0)))
	var passed := 0
	for s: Variant in cps:
		if t_ms >= float(s):
			passed += 1
	if jump or passed < _splits_shown:
		_splits_shown = passed
		_finish_shown = fin >= 0 and t_ms >= fin
	race.splits.clear()
	race.taken.clear()
	for k in passed:
		race.splits.append(int(cps[k]))
		race.taken[k] = true
	while _splits_shown < passed:
		_splits_shown += 1
		race.splits.resize(_splits_shown)
		race.checkpoint_taken.emit(_splits_shown, int(cps[_splits_shown - 1]))
	if fin >= 0 and t_ms >= fin and not _finish_shown:
		_finish_shown = true
		hud.show_finish(fin, best, false)


func _process(delta: float) -> void:
	if replay == null or car == null:
		return
	match cam_index:
		3:
			_trackside(delta)
		4:
			_fly(delta)


## TV: the spot nearest the car (changing only when another is clearly nearer), looking at it,
## zoomed so the car keeps its size.
func _trackside(_delta: float) -> void:
	var p := car.get_global_transform_interpolated().origin
	if _spots.is_empty():
		_spots.append(p + Vector3(12, 6, -12))
	var best_i := 0
	var best_d := INF
	for i in _spots.size():
		var d := _spots[i].distance_to(p)
		if d < best_d:
			best_d = d
			best_i = i
	if _spot < 0 or (best_i != _spot and best_d < _spots[_spot].distance_to(p) * 0.7):
		_spot = best_i
	var eye := _spots[_spot]
	var to := p + Vector3.UP * 0.6
	if eye.distance_to(to) > 0.5:
		_tv.global_transform = Transform3D(Basis(), eye).looking_at(to, Vector3.UP)
	_tv.fov = clampf(rad_to_deg(2.0 * atan(9.0 / maxf(eye.distance_to(to), 1.0))), 8.0, 75.0)


## Free camera: WASD / arrows move, Q / E down and up, Shift faster, the right mouse button looks.
func _fly(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		v.z += 1.0
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		v.y += 1.0
	var fast := 60.0 if Input.is_key_pressed(KEY_SHIFT) else 18.0
	_free.global_transform.basis = Basis.from_euler(Vector3(_free_look.y, _free_look.x, 0.0))
	_free.global_position += _free.global_transform.basis * v * fast * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and cam_index == 4 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mm := event as InputEventMouseMotion
		_free_look.x -= mm.relative.x * 0.004
		_free_look.y = clampf(_free_look.y - mm.relative.y * 0.004, -1.5, 1.5)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if replay == null or car == null:
		if key == KEY_ESCAPE:
			back()
		return
	match key:
		KEY_SPACE:
			toggle_play()
		KEY_LEFT:
			seek(t_ms - 5000.0)
		KEY_RIGHT:
			seek(t_ms + 5000.0)
		KEY_UP:
			set_speed(speed_index + 1)
		KEY_DOWN:
			set_speed(speed_index - 1)
		KEY_HOME:
			seek(-PREROLL_MS)
		KEY_C:
			set_camera(cam_index + 1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			set_camera(key - KEY_1)
		KEY_H:
			_bar.get_parent().visible = not _bar.get_parent().visible
		KEY_ESCAPE:
			back()
		_:
			return
	get_viewport().set_input_as_handled()


## Leaves: to the menu's replays page, or (--back=race) a race on the replay's track.
func back() -> void:
	if String(TestHooks.arg("back", "menu")) == "race" and replay != null:
		get_tree().change_scene_to_file("res://race/race.tscn")
		return
	TestHooks.args["page"] = "replays"
	get_tree().change_scene_to_file("res://ui/menu.tscn")
