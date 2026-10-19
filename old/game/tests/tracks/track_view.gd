extends Node3D
## Screenshot viewer for tracks.
## Args: --track=<id> --views="overview;drive:120;chase:300;orbit:870" --out=/abs/dir --tag=name
##   overview      high view of the whole layout
##   drive:D       driver-eye at distance D looking down the road
##   chase:D       chase camera 9 m behind and 4 m above D
##   side:D        side view of D (from the right, 40 m out)
##   orbit:D       elevated three-quarter view of D (good for stunts)
##   cp:N          chase view 22 m before checkpoint N (0-based; "cp:finish" for the finish gate)
## Each view is held for a few frames, then saved as <out>/<tag>_<i>.png.

var track: Track
var cam: Camera3D
var views: PackedStringArray
var out: String
var tag: String
var idx := 0
var timer := 0
const HOLD := 14


func _ready() -> void:
	var id: String = TestHooks.arg("track", "arena")
	out = TestHooks.arg("out", "/tmp")
	tag = TestHooks.arg("tag", id)
	views = String(TestHooks.arg("views", "overview;drive:60")).split(";")
	var t0 := Time.get_ticks_msec()
	track = Track.build(id)
	add_child(track)
	print("BUILD_MS %d" % (Time.get_ticks_msec() - t0))
	var car := Car.create(Profile.get_config())
	add_child(car)
	car.freeze = true
	car.global_transform = track.get_start_transform()
	cam = Camera3D.new()
	cam.far = 4000.0
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	_apply(views[0])


func _process(_dt: float) -> void:
	timer += 1
	if timer == HOLD:
		TestHooks.save_screenshot("%s/%s_%d.png" % [out, tag, idx])
		var info := "VIEW %d %s draw_calls=%d prims=%d objects=%d" % [idx, views[idx],
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)]
		print(info)
		idx += 1
		timer = 0
		if idx >= views.size():
			TestHooks.finish()
			return
		_apply(views[idx])


func _apply(v: String) -> void:
	var p := track.path
	if v == "overview":
		var r := TrackBuilder.path_bbox(p, 0.0)
		var c := Vector3(r.get_center().x, 0, r.get_center().y)
		var size := maxf(r.size.x, r.size.y)
		cam.global_position = c + Vector3(0, size * 0.75, size * 0.55)
		cam.look_at(c, Vector3.UP)
		return
	var parts := v.split(":")
	var d := float(parts[1]) if parts.size() > 1 else 0.0
	if parts[0] == "cp":
		var gd: float = track.finish_distance if parts[1] == "finish" else track.checkpoint_distances[int(parts[1])]
		var g := p.sample_transform(gd - 22.0)
		cam.global_position = g.origin + g.basis.y * 3.2 + g.basis.x * 2.5
		cam.look_at(p.sample_transform(gd).origin + p.sample_transform(gd).basis.y * 3.5, g.basis.y)
		return
	var f := p.sample_transform(d)
	match parts[0]:
		"drive":
			cam.global_position = f.origin + f.basis.y * 1.3 - f.basis.x * 1.5
			var ahead := p.sample_transform(d + 35.0)
			cam.look_at(ahead.origin + ahead.basis.y * 1.0, f.basis.y)
		"chase":
			cam.global_position = f.origin + f.basis.z * 9.0 + f.basis.y * 4.0
			cam.look_at(f.origin - f.basis.z * 12.0 + f.basis.y * 1.0, f.basis.y)
		"side":
			cam.global_position = f.origin + f.basis.x * 45.0 + Vector3.UP * 8.0
			cam.look_at(f.origin + Vector3.UP * 4.0, Vector3.UP)
		"orbit":
			cam.global_position = f.origin + f.basis.x * 40.0 + f.basis.z * 40.0 + Vector3.UP * 30.0
			cam.look_at(f.origin, Vector3.UP)
