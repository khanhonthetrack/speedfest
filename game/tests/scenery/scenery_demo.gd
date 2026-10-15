extends Node3D
## Scenery showcase: a sample TrackPath + simple road, the theme environment and props.
## Args: --theme=city|arena|coast  --cam=driver|chase|overview|high  --d=<m along path>
##       --lat=<m lateral>  --yaw=<deg>  --fly=<m/s> (camera drives along the path)  --stats_frame=N

var theme: String
var path: TrackPath
var cam: Camera3D
var props: Node3D
var cam_mode: String
var d: float
var fly: float
var stats_frame: int


func _ready() -> void:
	theme = String(TestHooks.arg("theme", "city"))
	cam_mode = String(TestHooks.arg("cam", "driver"))
	path = SceneryDemoPaths.for_theme(theme)
	d = float(TestHooks.arg("d", path.length * 0.08))
	fly = float(TestHooks.arg("fly", 0.0))
	stats_frame = int(TestHooks.arg("stats_frame", 30))
	add_child(SceneryKit.build_environment(theme))
	add_child(SceneryDemoPaths.road_node(path, theme))
	props = SceneryKit.build_props(theme, path, 1234)
	add_child(props)
	cam = Camera3D.new()
	cam.far = 4000.0
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	if SceneryKit.has_rain(theme) and cam_mode != "overview" and cam_mode != "high" and not TestHooks.has_arg("norain"):
		cam.add_child(SceneryKit.build_rain(theme))
	_place_camera()
	print("SCENERY_BUILD theme=%s build_ms=%d stats=%s" % [theme, props.get_meta("build_ms", -1), str(props.get_meta("stats", {}))])


func _place_camera() -> void:
	var lat := float(TestHooks.arg("lat", 0.0))
	var yaw := deg_to_rad(float(TestHooks.arg("yaw", 0.0)))
	var t := path.sample_transform(d)
	match cam_mode:
		"overview":
			var fld := SceneryField.new(path, 8.0)
			var c := fld.center()
			var ext := fld.extent().length()
			cam.global_position = c + Vector3(ext * 0.55, ext * 0.45, ext * 0.55)
			cam.look_at(c, Vector3.UP)
		"high":
			var up := Vector3.UP
			cam.global_position = t.origin + up * 60.0 - (-t.basis.z) * 80.0 + t.basis.x * lat
			cam.look_at(t.origin + (-t.basis.z) * 120.0, Vector3.UP)
		"chase":
			cam.global_position = t.origin + t.basis.y * 3.2 - (-t.basis.z) * 7.5 + t.basis.x * lat
			var target := t.origin + t.basis.y * 1.2 + (-t.basis.z) * 12.0
			cam.look_at(target, t.basis.y)
			cam.rotate(t.basis.y, yaw)
		_:
			cam.global_position = t.origin + t.basis.y * 1.3 + t.basis.x * lat
			cam.look_at(cam.global_position + (-t.basis.z) * 10.0 + t.basis.y * 0.3, t.basis.y)
			cam.rotate(t.basis.y.normalized(), yaw)


func _process(delta: float) -> void:
	if fly > 0.0:
		d = fposmod(d + fly * delta, path.length) if path.is_circuit else minf(d + fly * delta, path.length - 1.0)
		_place_camera()
	if TestHooks.frame == stats_frame:
		var lights := 0
		for n in find_children("*", "Light3D", true, false):
			if (n as Light3D).visible and not (n is DirectionalLight3D):
				lights += 1
		print("SCENERY_STATS theme=%s compat=%s quality=%d draw_calls=%d primitives=%d objects=%d nodes=%d lights=%d budget=%d fps=%.1f" % [
			theme, Settings.is_compat(), Settings.quality,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), lights, Settings.light_budget(),
			Performance.get_monitor(Performance.TIME_FPS)])
