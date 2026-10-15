extends Node3D
## Side-view frames of a car taking a real track jump (for judging how jumps look).
## tools/run_scene.sh res://tests/physics/jump_view.tscn -- --track=arena --jump=0 --car=brute --frames=260 --shots=...

var track: Track
var car: Car


func _ready() -> void:
	var id := String(TestHooks.arg("track", "arena"))
	track = Track.build(id, true)
	add_child(track)
	var jumps: Array = track.data["jumps"]
	var j: Dictionary = jumps[clampi(int(TestHooks.arg("jump", 0)), 0, jumps.size() - 1)]
	car = Car.create(CarDefs.default_config(String(TestHooks.arg("car", "brute"))))
	add_child(car)
	for ch in car.get_children():
		if ch is CarInput:
			ch.queue_free()
	var ai := AutoDriver.new()
	ai.path = track.path
	car.add_child(ai)
	var d0: float = float(j["from"]) - float(TestHooks.arg("lead", 120.0))
	var f := track.path.sample_transform(d0)
	car.teleport(Transform3D(f.basis, f.origin + f.basis.y * 0.6), -f.basis.z * float(TestHooks.arg("kmh", 190.0)) / 3.6)
	if ai.has_method("reset_tracking"):
		ai.call("reset_tracking")
	var mid := track.path.sample_transform((float(j["lip"]) + float(j["land"])) * 0.5)
	var cam := Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.global_position = mid.origin + mid.basis.x * float(TestHooks.arg("side", 38.0)) + Vector3.UP * 4.0
	cam.look_at(mid.origin + Vector3.UP * 3.0, Vector3.UP)
	cam.current = true
	print("JUMP lip=%.0f land=%.0f gap=%.0f v_min=%.0f km/h" % [j["lip"], j["land"], j["gap"], float(j["v_min"]) * 3.6])


func _physics_process(_d: float) -> void:
	var fr := Engine.get_physics_frames()
	if car and (fr % 6 == 0 or (TestHooks.has_arg("trace_from") and fr >= int(TestHooks.arg("trace_from", 0)) and fr <= int(TestHooks.arg("trace_to", 0)))):
		var up := car.global_transform.basis.y
		var pitch := rad_to_deg(asin(clampf(-car.global_transform.basis.z.y, -1, 1)))
		var wc := 0
		for i in 4:
			if car.get_wheel_contact(i):
				wc += 1
		var d := track.path.closest_distance(car.global_position)
		var lat := track.path.lateral_offset(car.global_position)
		var q := PhysicsRayQueryParameters3D.create(car.global_position + Vector3.UP * 5.0, car.global_position + Vector3.DOWN * 30.0, 1, [car.get_rid()])
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		var ground_y: float = (h["position"] as Vector3).y if not h.is_empty() else -999.0
		var road_y := track.path.sample_position(d).y
		var names := []
		for b in car.get_colliding_bodies():
			names.append(String(b.name))
		print("T f=%d y=%.2f vy=%.1f pitch=%.1f v=%.0f wheels=%d contacts=%d d=%.1f lat=%.1f ground_y=%.2f path_y=%.2f bodies=%s" % [fr, car.global_position.y, car.linear_velocity.y, pitch, car.linear_velocity.length() * 3.6, wc, car.get_contact_count(), d, lat, ground_y, road_y, names])
