extends Node3D
## Loads a .Challenge.Gbx and shows it built from the recreated blocks (placeholders where a
## shape isn't recreated yet). Prints build stats and the missing shapes.
## Run: stadium/tools/run.sh res://race/map_view.tscn -- --map=/path/X.Challenge.Gbx [--shot=/abs.png]
##      or --tmnf=/path/to/TMNF --track=A01 (official campaign from the player's install)

var builder: TmMapBuilder


func _ready() -> void:
	var path := String(TestHooks.arg("map", ""))
	if path.is_empty():
		path = _campaign_file(String(TestHooks.arg("tmnf", "")), String(TestHooks.arg("track", "A01")))
	var ch := TmChallenge.load_file(path)
	if not ch.ok():
		push_error("map_view: %s: %s" % [path, ch.error])
		TestHooks.finish()
		return
	builder = TmMapBuilder.build(ch)
	add_child(builder.root)
	print("MAP %s: %s" % [ch.name, builder.stats])
	var miss := builder.missing.keys()
	miss.sort_custom(func(a, b): return builder.missing[a] > builder.missing[b])
	print("MISSING (shape: count): ", ", ".join(miss.slice(0, 40).map(func(k): return "%s:%d" % [k, builder.missing[k]])))
	_environment()
	_camera()


func _campaign_file(root: String, track: String) -> String:
	var base := root.path_join("GameData/Tracks/Campaigns/Nations")
	for colour in ["White", "Green", "Blue", "Red", "Black"]:
		var d := DirAccess.open(base.path_join(colour))
		if d == null:
			continue
		for f in d.get_files():
			if f.begins_with(track) and f.to_lower().ends_with(".challenge.gbx"):
				return base.path_join(colour).path_join(f)
	return ""


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	we.environment = env
	add_child(we)
	# provisional Stadium ground: grass at 9 m over the 32 x 32 block map
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024, 1024)
	ground.mesh = pm
	ground.position = Vector3(-512, 9.0, 512)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.5, 0.22)
	ground.material_override = gm
	add_child(ground)


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
		# near:<block id>[:index]: a 3/4 view of that block
		var parts := view.split(":")
		var want := parts[1]
		var idx := int(parts[2]) if parts.size() > 2 else 0
		for n in builder.root.get_node("Blocks").get_children():
			if String(n.get_meta("block", "")) == want:
				if idx > 0:
					idx -= 1
					continue
				var c: Vector3 = (n as Node3D).global_position + Vector3(-16, 10, 16)
				cam.position = c + Vector3(45, 40, -45)
				cam.look_at(c)
				break
	elif view == "start" and builder.has_start:
		var s := builder.start
		cam.global_transform = Transform3D(s.basis, s.origin - s.basis.z * 14.0 + Vector3.UP * 5.0)
		cam.look_at(s.origin + s.basis.z * 20.0 + Vector3.UP * 1.0)
	else:
		cam.position = Vector3(-512, 700, 512 + 620)
		cam.look_at(Vector3(-512, 0, 512))
	cam.current = true
