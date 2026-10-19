extends Node3D
## Screenshot helper: a stage under a given weather, camera behind puddle N at driver height.
## tools/run_scene.sh res://tests/weather/weather_view.tscn -- --track=downtown --weather=rain --puddle=0 --frames=40 --shot=/abs/x.png
var track: Track


func _ready() -> void:
	var id := String(TestHooks.arg("track", "downtown"))
	var mode := String(TestHooks.arg("weather", "rain"))
	track = Track.build(id)
	add_child(track)
	track.apply_weather(mode)
	var pds: Array = track.data["puddles"]
	var i := clampi(int(TestHooks.arg("puddle", 0)), 0, maxi(pds.size() - 1, 0))
	var d: float = pds[i]["d"] - float(TestHooks.arg("back", 18.0)) if not pds.is_empty() else 50.0
	var f := track.path.sample_transform(d)
	var cam := Camera3D.new()
	cam.fov = 70
	add_child(cam)
	var look := track.path.sample_transform(d + 22.0)
	cam.global_position = f.origin + f.basis.y * float(TestHooks.arg("height", 2.2)) + f.basis.x * float(TestHooks.arg("side", 0.0))
	cam.look_at(look.origin + look.basis.x * (float(pds[i]["x"]) if not pds.is_empty() else 0.0) * 0.5, f.basis.y)
	cam.current = true
	var fx := WeatherFX.create(track, mode, cam)
	add_child(fx)
	print("VIEW track=%s weather=%s puddle=%d active=%d" % [id, mode, i, track.surface.active_count()])
