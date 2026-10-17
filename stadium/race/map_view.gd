extends Node3D
## Loads a .Challenge.Gbx and shows it built from the recreated blocks (placeholders where a
## shape isn't recreated yet). Prints build stats and the missing shapes.
## Run: stadium/tools/run.sh res://race/map_view.tscn -- --map=/path/X.Challenge.Gbx [--shot=/abs.png]
##      or --tmnf=/path/to/TMNF --track=A01 (official campaign from the player's install)
## --car=ours|ref|both puts cars on the start (ref: TMNF's own car from --ref=<dir>, local research
## files, TmRefVisuals; both: ours on the left, the original on the right); --view=car[:yaw[:dist]]
## looks at them (yaw in degrees around the car, 0 = from the front-left, dist in m); --car_ahead=M
## moves them M metres down the road from the start.

var builder: TmMapBuilder


func _ready() -> void:
	var ch := TmStage.load_from_args()
	if not ch.ok():
		push_error("map_view: %s" % ch.error)
		TestHooks.finish()
		return
	builder = TmMapBuilder.build(ch)
	add_child(builder.root)
	print("MAP %s: %s" % [ch.name, builder.stats])
	var miss := builder.missing.keys()
	miss.sort_custom(func(a, b): return builder.missing[a] > builder.missing[b])
	print("MISSING (shape: count): ", ", ".join(miss.slice(0, 40).map(func(k): return "%s:%d" % [k, builder.missing[k]])))
	TmStage.add_environment(self, builder)
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
	var side := s.basis.x
	if which in ["ours", "both"]:
		var ours := TmCarVisual.new()
		ours.paint_colour = TmUi.car_colour()
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
	cam.far = 4000.0
	add_child(cam)
	var view := String(TestHooks.arg("view", "overview"))
	if view.begins_with("at:"):
		# at:x,y,z,tx,ty,tz  (Godot world)
		var v := view.substr(3).split(",")
		cam.position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		cam.look_at(Vector3(float(v[3]), float(v[4]), float(v[5])))
	elif view.begins_with("near:"):
		# near:<block id>[:index[:zoom]]: a 3/4 view of that block (zoom 2: twice as close)
		var parts := view.split(":")
		var want := parts[1]
		var idx := int(parts[2]) if parts.size() > 2 else 0
		var zoom := float(parts[3]) if parts.size() > 3 else 1.0
		for n in builder.root.get_node("Blocks").get_children():
			if String(n.get_meta("block", "")) == want:
				if idx > 0:
					idx -= 1
					continue
				var c: Vector3 = (n as Node3D).global_position + Vector3(-16, 10, 16)
				cam.position = c + Vector3(45, 40, -45) / zoom
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
	elif view == "start" and builder.has_start:
		var s := builder.start
		cam.global_transform = Transform3D(s.basis, s.origin - s.basis.z * 14.0 + Vector3.UP * 5.0)
		cam.look_at(s.origin + s.basis.z * 20.0 + Vector3.UP * 1.0)
	else:
		cam.position = Vector3(-512, 700, 512 + 620)
		cam.look_at(Vector3(-512, 0, 512))
	cam.current = true
