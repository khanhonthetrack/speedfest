extends Node
## Integration perf probe: loads the real race scene for --track=<id> (solo, --autodrive)
## and prints render stats at a few frames, so web (--compat) budgets can be checked:
##   tools/run_scene.sh res://tests/integration/perf_probe.tscn --compat -- --track=coast --frames=700
## Prints "PERF frame=N draw_calls=.. primitives=.. objects=.. lights=.. fps=..".

var _race: Node


func _ready() -> void:
	Game.mode = "solo"
	Game.track_id = String(TestHooks.arg("track", "arena"))
	Settings.quality = int(TestHooks.arg("quality", Settings.quality))
	if TestHooks.has_arg("car"):
		Profile.set_selected_car(String(TestHooks.arg("car", "kaze")))
	_race = (load(Game.SCENE_RACE) as PackedScene).instantiate()
	add_child(_race)


func _process(_delta: float) -> void:
	var f: int = TestHooks.frame
	if f in [120, 300, 450, 600, 690]:
		var lights := 0
		for n in get_tree().root.find_children("*", "Light3D", true, false):
			if (n as Light3D).visible:
				lights += 1
		print("PERF frame=%d track=%s quality=%d compat=%s draw_calls=%d primitives=%d objects=%d lights=%d fps=%.1f mem_mb=%.0f" % [
			f, Game.track_id, Settings.quality, str(Settings.is_compat()),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			lights, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
