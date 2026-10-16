extends Node3D
## Loads a .Challenge.Gbx and shows it built from the recreated blocks (placeholders where a
## shape isn't recreated yet). Prints build stats and the missing shapes.
## Run: stadium/tools/run.sh res://race/map_view.tscn -- --map=/path/X.Challenge.Gbx [--shot=/abs.png]
##      or --tmnf=/path/to/TMNF --track=A01 (official campaign from the player's install)

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
	_camera()


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
