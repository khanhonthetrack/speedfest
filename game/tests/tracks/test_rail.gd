extends Node3D
## Rail Rush (track "rails"): the start-ledge jump -> rail grind -> landing -> finish sequence works
## with the real car physics, and the grind is required.
##  - layout: one rail, no road under it, finish platform well off the take-off line
##  - real runs (AutoDriver, all cars, uncapped and at capped approach speeds, plus keyboard
##    emulation): the car leaves the ledge, the rail captures it, it grinds the whole rail, hops
##    off, lands on the platform and finishes, with 0 respawns
##  - control: with the rail's capture switched off the car falls (it can't reach the finish by
##    jumping alone)
## Run: tools/run_scene.sh res://tests/tracks/test_rail.tscn --headless

const KeyEmu := preload("res://tests/physics/key_emulator.gd")
const MAX_TICKS := 60 * 20

## [car, launch km/h (0 = full run from the start; else placed 30 m before the ledge at that speed
##  and held there by the bot), keyboard, rail enabled]
var scenarios: Array = [
	["kaze", 0.0, false, true], ["brute", 0.0, false, true], ["veloce", 0.0, false, true],
	["kaze", 0.0, true, true], ["veloce", 0.0, true, true],
	["kaze", 90.0, false, true], ["brute", 130.0, false, true], ["veloce", 250.0, false, true],
	["kaze", 0.0, false, false], ["veloce", 0.0, false, false], ["brute", 130.0, false, false],
]
## Slowest launch the rail is checked at; below this the hop off the rail end falls short.
const MIN_LAUNCH_KMH := 90.0   # (documentation: the kaze_at90 scenario)
var track: Track
var rail: TrackRail
var car: Car
var ai: AutoDriver
var sc := -1
var tick := 0
var start_tick := 0
var grind_t0 := -1
var grind_t1 := -1
var grind_kmh := 0.0
var finished := false
var fell := false
var ledge_kmh := 0.0


func _ready() -> void:
	track = Track.build("rails")
	add_child(track)
	_check_layout()
	if track.rails.is_empty():
		TestHooks.finish()
		return
	rail = track.rails[0]
	rail.grind_started.connect(func(c: Node) -> void:
		if c == car:
			grind_t0 = tick
			grind_kmh = car.get_speed_kmh())
	rail.grind_ended.connect(func(c: Node) -> void:
		if c == car:
			grind_t1 = tick)
	track.finish_reached.connect(func(b: Node) -> void:
		if b == car and not finished and tick > start_tick:
			finished = true)
	_next()


func _check_layout() -> void:
	var data := track.data
	var rails: Array = data.get("rails", [])
	TestHooks.check(rails.size() == 1 and track.rails.size() == 1, "rail_one_rail", str(rails))
	if rails.is_empty():
		return
	var r0: float = rails[0]["from"]
	var r1: float = rails[0]["to"]
	TestHooks.check(r1 - r0 > 60.0 and r1 - r0 < 140.0, "rail_length", "%.0f m" % (r1 - r0))
	TestHooks.check(TrackBuilder.in_ranges((r0 + r1) * 0.5, data["gaps"]), "rail_no_deck", "")
	TestHooks.check(track.finish_distance > r1 + 8.0, "rail_finish_after_rail", "%.0f vs %.0f" % [track.finish_distance, r1])
	# the ledge: last deck point before the rail
	var ledge_d := r0
	for g in data["gaps"]:
		if float(g[1]) >= r0 and float(g[0]) <= r0:
			ledge_d = float(g[0])
	var lf := track.path.sample_transform(ledge_d)
	var fwd := -lf.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var ff := track.path.sample_transform(track.finish_distance)
	var off := ff.origin - lf.origin
	var lateral := absf(off.dot(fwd.cross(Vector3.UP)))
	var half := track.path.width_at(track.finish_distance) * 0.5
	# a straight flight off the ledge misses the finish platform by a wide margin
	TestHooks.check(lateral - half > 8.0, "rail_required_offline", "finish %.1f m off the take-off line (platform half width %.1f)" % [lateral, half])
	TestHooks.check(ff.origin.y < lf.origin.y, "rail_finish_below_ledge", "%.1f vs %.1f" % [ff.origin.y, lf.origin.y])


func _next() -> void:
	if car != null:
		car.queue_free()
		car = null
	sc += 1
	if sc >= scenarios.size():
		TestHooks.finish()
		return
	var s: Array = scenarios[sc]
	car = Car.create(CarDefs.default_config(String(s[0])))
	car.surface = track.surface
	add_child(car)
	ai = AutoDriver.new()
	ai.path = track.path
	ai.reset_callable = func() -> void: fell = true
	var launch := float(s[1])
	if launch > 0.0:
		ai.target_speed_kmh = launch
	car.add_child(ai)
	if bool(s[2]):
		ai.emulate_player = true
		var emu := Node.new()
		emu.set_script(KeyEmu)
		emu.set("car", car)
		car.add_child(emu)
		var inp := CarInput.new()
		car.add_child(inp)
		emu.set("inp", inp)
	rail.set_physics_process(bool(s[3]))
	if launch > 0.0:
		var xf := track.path.sample_transform(_ledge_d() - 30.0)
		xf.origin += xf.basis.y * Track.SPAWN_HEIGHT
		car.teleport(xf, -xf.basis.z * launch / 3.6)
		start_tick = tick
		car.frozen_controls = false
	else:
		car.teleport(track.get_start_transform())
		start_tick = tick + 30
		car.frozen_controls = true
	ai.reset_tracking()
	grind_t0 = -1
	grind_t1 = -1
	grind_kmh = 0.0
	finished = false
	fell = false
	ledge_kmh = 0.0


func _ledge_d() -> float:
	var r0: float = track.data["rails"][0]["from"]
	for g in track.data["gaps"]:
		if float(g[1]) >= r0 and float(g[0]) <= r0:
			return float(g[0])
	return r0


func _tag() -> String:
	var s: Array = scenarios[sc]
	return "%s%s%s%s" % [s[0], "_at%d" % int(s[1]) if float(s[1]) > 0.0 else "", "_kb" if bool(s[2]) else "", "" if bool(s[3]) else "_norail"]


func _physics_process(_dt: float) -> void:
	tick += 1
	if car == null or sc >= scenarios.size():
		return
	if tick == start_tick:
		car.frozen_controls = false
	if car.frozen_controls:
		return
	var s: Array = scenarios[sc]
	var d := ai.get_distance()
	if ledge_kmh == 0.0 and d > float(track.data["rails"][0]["from"]) - 8.0:
		ledge_kmh = car.get_speed_kmh()
	if car.global_position.y < track.kill_y_at(car.global_position):
		fell = true
	var t := tick - start_tick
	var done := finished or fell or t > MAX_TICKS
	if not done:
		return
	var tag := _tag()
	var secs := t / 60.0
	if bool(s[3]):
		var grind_s := (grind_t1 - grind_t0) / 60.0 if grind_t0 >= 0 and grind_t1 >= 0 else 0.0
		print("RAIL %s: finished=%s fell=%s time=%.2fs ledge=%.0f km/h grind=%.2fs at %.0f km/h" % [tag, finished, fell, secs, ledge_kmh, grind_s, grind_kmh])
		TestHooks.check(grind_t0 >= 0, "rail_%s_captured" % tag, "")
		TestHooks.check(grind_t1 > grind_t0 and grind_s > 0.8, "rail_%s_grinds_whole_rail" % tag, "%.2fs" % grind_s)
		TestHooks.check(finished and not fell, "rail_%s_lands_and_finishes" % tag, "finished=%s fell=%s %.1fs" % [finished, fell, secs])
	else:
		print("RAIL %s (control, no rail): finished=%s fell=%s time=%.2fs ledge=%.0f km/h" % [tag, finished, fell, secs, ledge_kmh])
		TestHooks.check(fell and not finished, "rail_%s_jump_alone_fails" % tag, "finished=%s fell=%s" % [finished, fell])
	_next()
