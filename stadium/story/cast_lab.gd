extends Node3D
## Looks at the modelled cast (StoryCast, PLAN M20-9) in a studio: --who=kit,dee,mannequin
## --mode=lineup|face|full --clip=Idle (or Stand, Stand_B, Stand_Talk: each one's own take) --t=1.0 --shapes=eyeBlinkLeft:1,jawOpen:0.6 (face shapes)
## --turn=180 (their backs) --play (the clip plays on from --t: for tools/clip.sh) --frames=30 --shot=/abs.png. "face" frames the first one's head (a 250-px head at 1600x900,
## the size a cutscene's close-up gives it); "lineup" stands everyone in a row on their own feet
## (StoryCast.ground), the Mannequin for scale. Prints each one's height and feet.

const GAP := 0.85


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.045, 0.047, 0.058)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.33, 0.38)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ssao_enabled = true
	e.ssil_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.3
	env.environment = e
	add_child(env)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.16, 0.18)
	fm.roughness = 0.55
	floor.material_override = fm
	add_child(floor)
	var mode := String(TestHooks.arg("mode", "lineup"))
	var clip := String(TestHooks.arg("clip", "Idle"))
	var t := float(TestHooks.arg("t", 1.0))
	var who := String(TestHooks.arg("who", ",".join(StoryCast.ids()) + ",mannequin")).split(",", false)
	var people: Array[Node3D] = []
	var x := 0.0
	for w in who:
		var p := _person(w, clip, t)
		if p == null:
			continue
		p.position.x += x
		p.rotation_degrees.y = float(TestHooks.arg("turn", 0.0))
		x += GAP
		people.append(p)
	if people.is_empty():
		push_error("cast_lab: nobody to look at (%s)" % [who])
		TestHooks.finish()
		return
	_lights()
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var mid := (x - GAP) * 0.5
	match mode:
		"face":
			var head := _head(people[0])
			cam.fov = 20
			cam.position = head + Vector3(0.12, 0.02, 0.95)
			cam.look_at(head + Vector3(0, 0.0, 0))
		"full":
			cam.fov = 28
			cam.position = Vector3(0.2, 1.0, 3.9)
			cam.look_at(Vector3(0.0, 0.88, 0))
		_:
			cam.fov = 32
			cam.position = Vector3(mid, 1.05, 2.4 + x * 0.95)
			cam.look_at(Vector3(mid, 0.92, 0))


## A key from the front left, warm; a fill from the right, cool; a violet rim behind (the game's
## night colours).
func _lights() -> void:
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.93, 0.85)
	key.light_energy = 8.0
	key.spot_range = 14.0
	key.spot_angle = 40.0
	key.shadow_enabled = true
	add_child(key)
	key.position = Vector3(-2.2, 3.0, 3.6)
	key.look_at(Vector3(1.2, 1.0, 0))
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 1.6
	fill.omni_range = 9.0
	fill.position = Vector3(4.5, 1.6, 3.0)
	add_child(fill)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.62, 0.42, 1.0)
	rim.light_energy = 4.0
	rim.omni_range = 7.0
	rim.position = Vector3(1.5, 2.4, -1.8)
	add_child(rim)


func _person(w: String, clip: String, t: float) -> Node3D:
	var root: Node3D
	var ap: AnimationPlayer
	var id := w
	StoryCast.library()                 # the standing takes too
	clip = StoryCast.take("" if w == "mannequin" else w, clip)   # "Stand": hers or his
	if w == "mannequin":
		root = (load(StoryPerson.GLB) as PackedScene).instantiate()
		add_child(root)
		ap = root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	else:
		root = StoryCast.instance(w)
		if root == null:
			push_warning("cast_lab: no cast member %s" % w)
			return null
		add_child(root)
		ap = StoryCast.player(root)
		root.position.y = StoryCast.ground(id, root, clip)
		for kv in String(TestHooks.arg("shapes", "")).split(",", false):
			StoryCast.set_shape(root, kv.get_slice(":", 0), float(kv.get_slice(":", 1)))
	ap.play(clip)
	ap.seek(t, true)
	if not TestHooks.has_arg("play"):
		ap.pause()                      # held at --t: the still, the printout and the camera agree
	var sk := StoryCast.skeleton(root)
	print("CAST_LAB %s %s t=%.2f lift=%.3f head=%.3f m %d bones" % [w, clip, t, root.position.y,
		_head(root).y, sk.get_bone_count()])
	return root


func _head(p: Node3D) -> Vector3:
	var sk := StoryCast.skeleton(p)
	var i := sk.find_bone("Head")
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin + Vector3(0, 0.08, 0.03)
