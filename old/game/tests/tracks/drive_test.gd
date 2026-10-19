extends Node3D
## Drives the real Car with the AutoDriver around a track and reports whether it reaches every
## checkpoint in order and the finish. Respawns at the last checkpoint below kill_y or when the
## bot reports being stuck. Needs the physics module's Car/AutoDriver (stubs can't drive).
## Args: --track=<id> --car=kaze|brute|veloce --max_s=150 [--shots=...] (camera follows the car)

var track: Track
var car: Car
var bot: Node
var cam: Camera3D
var next_cp := 0
var last_cp := -1
var frames := 0
var respawns := 0
var finished := false
var max_kmh := 0.0
var max_s := 150.0
var loop_top_hits := 0
var log_events: Array = []


func _ready() -> void:
	var id: String = TestHooks.arg("track", "arena")
	max_s = TestHooks.arg("max_s", 150.0)
	track = Track.build(id, TestHooks.arg("scenery", false))
	add_child(track)
	var cfg := CarDefs.default_config(TestHooks.arg("car", "kaze"))
	car = Car.create(cfg)
	add_child(car)
	car.contact_monitor = true
	car.max_contacts_reported = 4
	car.teleport(track.get_start_transform())
	bot = load("res://cars/auto_driver.gd").new()
	bot.set("path", track.path)
	if "reset_callable" in bot:
		bot.set("reset_callable", _respawn.bind("stuck"))
	car.add_child(bot)
	if TestHooks.arg("keyboard", false):
		# physics module's keyboard-player emulation: bot wishes -> digital keys -> CarInput
		var emu := Node.new()
		emu.set_script(load("res://tests/physics/key_emulator.gd"))
		emu.set("car", car)
		car.add_child(emu)
		var inp := CarInput.new()
		car.add_child(inp)
		emu.set("inp", inp)
	track.checkpoint_reached.connect(_on_cp)
	track.finish_reached.connect(_on_finish)
	cam = Camera3D.new()
	cam.far = 3000.0
	add_child(cam)
	cam.current = true


func _physics_process(_dt: float) -> void:
	frames += 1
	max_kmh = maxf(max_kmh, absf(car.get_speed_kmh()))
	if TestHooks.arg("trace", false) and frames % 30 == 0:
		var dd := track.path.closest_distance(car.global_position)
		print("  t=%.1f d=%.0f y=%.1f v=%.0f lat=%.1f gr=%s up=%.2f" % [frames / 60.0, dd, car.global_position.y, car.get_speed_kmh(), track.path.lateral_offset(car.global_position), car.is_grounded(), car.global_transform.basis.y.dot(track.path.sample_transform(dd).basis.y)])
	if TestHooks.arg("trace", false) and car.get_contact_count() > 0 and absf(car.get_speed_kmh()) > 60.0 and frames % 3 == 0:
		var space := get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 2.6
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, car.global_position)
		q.collision_mask = 1
		var names := []
		for r in space.intersect_shape(q, 8):
			names.append(str(r["collider"].name))
		print("    contact t=%.2f pos=%s %s" % [frames / 60.0, str(car.global_position.snapped(Vector3.ONE * 0.1)), str(names)])
	if car.global_position.y < track.kill_y:
		log_events.append("fell at %s d=%.0f" % [str(car.global_position.snapped(Vector3.ONE)), track.path.closest_distance(car.global_position)])
		_respawn("fell")
	for l in track.data["loops"]:
		var d := track.path.closest_distance(car.global_position)
		if d > l["from"] and d < l["to"] and car.global_position.y > float(l["radius"]) * 1.7:
			loop_top_hits += 1
	if finished or frames > int(max_s * 60.0):
		_report()


func _process(_dt: float) -> void:
	var xf := car.global_transform
	var target := xf.origin - xf.basis.z * 6.0 + xf.basis.y * 1.0
	var want := xf.origin + xf.basis.z * 9.0 + xf.basis.y * 3.5
	cam.global_position = cam.global_position.lerp(want, 0.2) if frames > 2 else want
	cam.look_at(target, xf.basis.y)


func _respawn(why: String) -> void:
	respawns += 1
	log_events.append("respawn(%s)@%.1fs cp%d" % [why, frames / 60.0, last_cp])
	var xf := track.get_checkpoint_transform(last_cp)
	car.teleport(xf, -xf.basis.z * 25.0)
	if bot.has_method("reset_tracking"):
		bot.call("reset_tracking")


func _on_cp(body: Node, index: int) -> void:
	if body != car:
		return
	if index == next_cp:
		log_events.append("cp%d@%.2fs %.0fkm/h" % [index, frames / 60.0, car.get_speed_kmh()])
		last_cp = index
		next_cp += 1


func _on_finish(body: Node) -> void:
	if body != car or next_cp < track.checkpoint_count or finished:
		return
	finished = true
	log_events.append("finish@%.2fs" % (frames / 60.0))


var _reported := false


func _report() -> void:
	if _reported:
		return
	_reported = true
	print("DRIVE %s time=%.2fs respawns=%d max=%.0fkm/h loop_top_frames=%d" % [track.track_id, frames / 60.0, respawns, max_kmh, loop_top_hits])
	print("  ", " | ".join(PackedStringArray(log_events.map(func(e): return str(e)))))
	TestHooks.check(finished, track.track_id + "_autodriver_finishes", "cps %d/%d" % [next_cp, track.checkpoint_count])
	TestHooks.check(respawns <= 1, track.track_id + "_autodriver_few_respawns", str(respawns))
	TestHooks.finish()
