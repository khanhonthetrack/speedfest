extends Node3D
## Rail Rush (track "rails"): the start-ledge jump -> rail grind -> landing -> finish sequence works
## with the real car physics, and the grind is required.
##  - layout: one rail, no road under it, finish platform well off the take-off line
##  - real runs (AutoDriver, all cars, uncapped and at capped approach speeds, plus keyboard
##    emulation): the car leaves the ledge, the rail captures it, it grinds the whole rail, hops
##    off, lands on the platform and finishes, with 0 respawns
##  - control: with the rail's capture switched off the car falls (it can't reach the finish by
##    jumping alone)
##  - not magnetic (owner, session 7): a car beside the rail or still rising over it is not caught;
##    a car landing on it slightly off-center is caught without a teleport
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
	await _magnet_checks()
	_next()


## Drop a free car (no inputs) near the rail and watch whether the rail takes it.
## lat: m beside the rail line, h: m above ride height, vy: vertical m/s. Returns
## [caught (bool), largest position jump beyond the car's own motion in one step (m)].
func _probe(lat: float, h: float, vy: float, frames: int) -> Array:
	var s := rail.length * 0.35
	var t := rail.tangent_at(s)
	var right := t.cross(Vector3.UP).normalized()
	var pos := rail.point_at(s) + Vector3.UP * (TrackRail.RIDE_H + h) + right * lat
	var c := Car.create(CarDefs.default_config("kaze"))
	add_child(c)
	c.frozen_controls = true
	c.teleport(Transform3D(Basis.looking_at(t, Vector3.UP), pos), t * 30.0 + Vector3.UP * vy)
	# the teleport velocity applies on the next physics step: keep the rail blind until it has
	rail.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	rail.set_physics_process(true)
	var caught := false
	var jump := 0.0
	var prev := c.global_position
	var prev_v := c.linear_velocity
	for i in frames:
		await get_tree().physics_frame
		var now := c.global_position
		if TestHooks.has_arg("probe_debug"):
			print("PROBE lat=%.1f i=%d vy=%.2f h=%.2f grinding=%s" % [lat, i, c.linear_velocity.y, now.y - rail.point_at(rail.nearest(now).x).y - TrackRail.RIDE_H, rail.is_grinding(c)])
		if rail.is_grinding(c):
			if not caught:
				jump = maxf(jump, (now - (prev + prev_v / 60.0)).length())
			caught = true
		prev = now
		prev_v = c.linear_velocity
	rail.release(c)
	c.queue_free()
	await get_tree().physics_frame
	return [caught, jump]


func _magnet_checks() -> void:
	rail.set_physics_process(true)
	var beside: Array = await _probe(1.0, 0.0, -0.5, 25)
	TestHooks.check(not bool(beside[0]), "rail_not_magnetic_beside", "a car 1 m beside the rail was caught")
	var rising: Array = await _probe(0.0, -0.25, 3.5, 2)   # rising through ride height (the old capture took cars rising at up to 2.5 m/s)
	TestHooks.check(not bool(rising[0]), "rail_not_magnetic_rising", "a car still going up over the rail was caught")
	var landing: Array = await _probe(0.3, 0.2, -2.0, 25)
	TestHooks.check(bool(landing[0]), "rail_catches_a_landing", "a car landing 0.3 m off-center was not caught")
	TestHooks.check(float(landing[1]) < 0.15, "rail_no_snap", "%.2f m jump at the catch" % float(landing[1]))
	print("RAIL probes: beside caught=%s rising caught=%s landing caught=%s jump=%.3f m" % [beside[0], rising[0], landing[0], landing[1]])


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
