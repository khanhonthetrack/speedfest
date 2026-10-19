extends Node3D
## Look-dev flight over a circuit: builds the track and the city, then parks the camera somewhere
## along the lap. Args: --track=downtown|harbour --at=0..1 (fraction of the lap) --back=m
## --height=m --top=1 (overhead) --nocity=1 --fov=deg

var path: TrackPath


func _ready() -> void:
	var id := String(TestHooks.arg("track", "downtown"))
	var builder := TrackBuilder.new()
	add_child(builder.build(id))
	path = builder.path
	var field := SceneryField.new(path, 4.0)
	if not bool(TestHooks.arg("nocity", false)):
		var t0 := Time.get_ticks_msec()
		add_child(CityKit.new().build(field, hash(id)))
		print("CITY %d ms %s" % [Time.get_ticks_msec() - t0, get_child(get_child_count() - 1).get_meta("stats", {})])
	add_child(CityEnv.create())
	print("TRACK %s length=%.0f m checkpoints=%s" % [id, path.length, str(builder.info["checkpoints"])])
	var cam := Camera3D.new()
	cam.fov = float(TestHooks.arg("fov", 62.0))
	cam.far = 6000.0
	add_child(cam)
	cam.current = true
	if bool(TestHooks.arg("top", false)):
		var c := field.center()
		var span := maxf(field.extent().x, field.extent().y)
		cam.position = c + Vector3(0, span * 1.05, span * 0.01)
		cam.look_at(c, Vector3.FORWARD)
		return
	var d := path.length * clampf(float(TestHooks.arg("at", 0.0)), 0.0, 1.0)
	var t := path.sample_transform(d)
	var back := float(TestHooks.arg("back", 22.0))
	var height := float(TestHooks.arg("height", 6.0))
	cam.position = t.origin + t.basis.z * back + Vector3(0, height, 0)
	cam.look_at(path.sample_transform(fposmod(d + 60.0, path.length)).origin + Vector3(0, 1.5, 0), Vector3.UP)
