extends Node3D
## Loads a .Challenge.Gbx and shows it built from the recreated blocks (placeholders where a
## shape isn't recreated yet). Prints build stats and the missing shapes.
## Run: stadium/tools/run.sh res://race/map_view.tscn -- --map=/path/X.Challenge.Gbx [--shot=/abs.png]
##      or --tmnf=/path/to/TMNF --track=A01 (official campaign from the player's install)
## --car=ours|ref|both puts cars on the start (ref: TMNF's own car from --ref=<dir>, local research
## files, TmRefVisuals; both: ours on the left, the original on the right); --view=car[:yaw[:dist]]
## looks at them (yaw in degrees around the car, 0 = from the front-left, dist in m); --car_ahead=M
## moves them M metres down the road from the start. --view=path:<frac>[:back[:up]]: our tracks:
## a driver's view at that fraction (0-1) of the bot's line, back metres behind it, up above it
## (--yaw=deg turns it left, negative right; --pitch=deg tilts it up; --fov= its field of view, default 70).

var builder: TmMapBuilder
var _path: Array = []


func _ready() -> void:
	var ch := TmStage.load_from_args()
	if not ch.ok():
		push_error("map_view: %s" % ch.error)
		TestHooks.finish()
		return
	TmMaterials.use_mod(TmCommunity.my_mod())
	builder = TmMapBuilder.build(ch)
	_path = ch.path
	add_child(builder.root)
	print("MAP %s: %s" % [ch.name, builder.stats])
	var miss := builder.missing.keys()
	miss.sort_custom(func(a, b): return builder.missing[a] > builder.missing[b])
	print("MISSING (shape: count): ", ", ".join(miss.slice(0, 40).map(func(k): return "%s:%d" % [k, builder.missing[k]])))
	TmStage.add_environment(self, builder)
	await get_tree().physics_frame   # the blocks' collision is in the physics space (cars on the road)
	_cars()
	_camera()


var _car_at := Transform3D()        ## where the cars stand (the start, at the visual's ground)


func _cars() -> void:
	var which := String(TestHooks.arg("car", ""))
	if which.is_empty() or not builder.has_start:
		return
	var s := builder.start
	# the start is on the road; TMNF's visual has its origin there, ours sits VIS above it (the
	# TmCar frame's origin is the centre of mass)
	_car_at = Transform3D(s.basis, s.origin + s.basis.z * float(TestHooks.arg("car_ahead", 0.0)))
	# the start transform is the spawn point, above the road: stand the cars on the road below it
	var q := PhysicsRayQueryParameters3D.create(_car_at.origin + s.basis.y * 1.5, _car_at.origin - s.basis.y * 2.5, TmCar.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_car_at.origin = hit["position"]
	var side := s.basis.x
	if which in ["ours", "both"]:
		var ours := TmCarVisual.new()
		ours.paint_colour = TmUi.car_colour()
		ours.model = String(TestHooks.arg("car_model", TmUi.car_model()))    # --car_model=hyper
		if TestHooks.has_arg("car_pack"):    # a community car pack (.zip) drawn instead of ours
			ours.pack = TmCarPack.load_zip(String(TestHooks.arg("car_pack", "")))
		add_child(ours)
		ours.global_transform = Transform3D(s.basis, _car_at * TmCarVisual.VIS + (side * 1.3 if which == "both" else Vector3.ZERO))
	if which in ["ref", "both"] and TmRefVisuals.active():
		var f := FileAccess.open(String(TestHooks.arg("ref", "")).path_join("vis/StadiumCar.json"), FileAccess.READ)
		if f != null:
			# the nearest of the solid's three levels of detail ("/#1/1/...")
			var meshes := ((JSON.parse_string(f.get_as_text()) as Dictionary)["meshes"] as Array).filter(
				func(m: Dictionary) -> bool: return String(m["name"]).begins_with("/#1/1/"))
			var ref := TmRefVisuals.mesh_from(meshes, false)
			add_child(ref)
			ref.global_transform = Transform3D(s.basis, _car_at.origin - (side * 1.3 if which == "both" else Vector3.ZERO))


func _camera() -> void:
	var cam := Camera3D.new()
	cam.far = TmSkyline.FAR
	add_child(cam)
	var view := String(TestHooks.arg("view", "overview"))
	if view.begins_with("at:"):
		# at:x,y,z,tx,ty,tz  (Godot world)
		var v := view.substr(3).split(",")
		cam.position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		cam.look_at(Vector3(float(v[3]), float(v[4]), float(v[5])))
	elif view.begins_with("near:"):
		# near:<block id>[:index[:zoom[:yaw[:height]]]]: a 3/4 view of that block (zoom 2: twice as
		# close; yaw turns the view about the block, degrees; height of the camera over the target, m)
		var parts := view.split(":")
		var want := parts[1]
		var idx := int(parts[2]) if parts.size() > 2 else 0
		var zoom := float(parts[3]) if parts.size() > 3 else 1.0
		var yaw := deg_to_rad(float(parts[4])) if parts.size() > 4 else 0.0
		var hgt := float(parts[5]) if parts.size() > 5 else 40.0
		for n in builder.root.get_node("Blocks").get_children():
			if String(n.get_meta("block", "")) == want:
				if idx > 0:
					idx -= 1
					continue
				var c: Vector3 = (n as Node3D).global_position + Vector3(-16, 10, 16)
				cam.position = c + (Vector3(45, 0, -45).rotated(Vector3.UP, yaw) + Vector3(0, hgt, 0)) / zoom
				cam.look_at(c)
				break
	elif view.begins_with("car"):
		# car[:yaw[:dist]]: around the cars on the start, at their height
		var parts := view.split(":")
		var yaw := deg_to_rad(float(parts[1]) if parts.size() > 1 else 35.0)
		var dist := float(parts[2]) if parts.size() > 2 else 6.5
		var b := _car_at.basis
		var c := _car_at.origin + b.y * 0.45
		if parts.size() > 3:      # car:yaw:dist:x,y,z looks at that point of the car (visual coords)
			var t := parts[3].split(",")
			c = _car_at * Vector3(float(t[0]), float(t[1]), float(t[2]))
		var dir := (b.z * cos(yaw) + b.x * sin(yaw)).normalized()
		cam.fov = 40.0
		cam.global_position = c + dir * dist + b.y * dist * 0.28
		cam.look_at(c, b.y)
	elif view.begins_with("gate:"):
		# gate:<block id>[:index[:dist[:height[:side[:look_y]]]]]: on the road in front of that block's
		# gate (block-local TMNF z 16, or `gz`), dist m before it, looking at it (at 4.5 m, or look_y)
		var parts := view.split(":")
		var want := parts[1]
		var idx := int(parts[2]) if parts.size() > 2 else 0
		var dist := float(parts[3]) if parts.size() > 3 else 18.0
		var hgt := float(parts[4]) if parts.size() > 4 else 2.5
		var side := float(parts[5]) if parts.size() > 5 else 0.0
		var look_y := float(parts[6]) if parts.size() > 6 else 4.5
		var gz := float(TestHooks.arg("gz", 16.0))
		for n in builder.root.get_node("Blocks").get_children():
			if String(n.get_meta("block", "")) == want:
				if idx > 0:
					idx -= 1
					continue
				var xf := (n as Node3D).global_transform
				cam.global_position = xf * Vector3(-16.0 - side, hgt, gz - dist)
				cam.look_at(xf * Vector3(-16.0, look_y, gz), xf.basis.y)
				break
	elif view.begins_with("rel:") and builder.has_start:
		# rel:x,y,z,tx,ty,tz: camera and target in the start's frame (x left, y up, z ahead, m)
		var v := view.substr(4).split(",")
		var s := builder.start
		cam.global_position = s * Vector3(float(v[0]), float(v[1]), float(v[2]))
		cam.look_at(s * Vector3(float(v[3]), float(v[4]), float(v[5])), s.basis.y)
		cam.fov = float(TestHooks.arg("fov", 60.0))
	elif view.begins_with("path:") and not _path.is_empty():
		var parts := view.split(":")
		var i := clampi(int(float(parts[1]) * (_path.size() - 1)), 0, _path.size() - 1)
		var back := float(parts[2]) if parts.size() > 2 else 9.0
		var up := float(parts[3]) if parts.size() > 3 else 3.5
		var p: Vector3 = _path[i]["p"]
		var d: Vector3 = _path[i]["dir"]
		var ahead: Vector3 = _path[mini(i + 6, _path.size() - 1)]["p"]
		# on the line itself, back metres before the point (slopes: the line's height there)
		var j := i
		while j > 0 and (_path[j]["p"] as Vector3).distance_to(p) < back:
			j -= 1
		var behind: Vector3 = _path[j]["p"] if j < i else p - d * back
		cam.global_position = behind + Vector3.UP * up
		cam.look_at(ahead + Vector3.UP * 1.0 if ahead.distance_to(p) > 1.0 else p + d * 40.0)
		# --yaw=deg turns the camera to the left (positive) or right from the line; --fov= narrows it
		cam.rotate_y(deg_to_rad(float(TestHooks.arg("yaw", 0.0))))
		cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(float(TestHooks.arg("pitch", 0.0))))
		cam.fov = float(TestHooks.arg("fov", 70.0))
	elif view == "start" and builder.has_start:
		var s := builder.start
		cam.global_transform = Transform3D(s.basis, s.origin - s.basis.z * 14.0 + Vector3.UP * 5.0)
		cam.look_at(s.origin + s.basis.z * 20.0 + Vector3.UP * 1.0)
	else:
		cam.position = Vector3(-512, 700, 512 + 620)
		cam.look_at(Vector3(-512, 0, 512))
	cam.current = true
