extends Node
## GPU benchmark for a real GPU (M7 RTX tests). Runs the race for --track (solo, AutoDriver) in real
## time with V-Sync and the FPS cap off, and measures frame and GPU times over the same stretch of the
## run every time (from --warmup seconds after GO, for --seconds):
##   godot --path game res://tests/integration/gpu_bench.tscn -- --track=downtown --weather=rain
##       --quality=2 [--window=2] [--aa=FSR2] [--seconds=20] [--warmup=3] [--bench_shot=/abs/x.png]
##       [--out=/abs/x.json]
## --window: 0 window (size from --resolution), 1 borderless, 2 exclusive fullscreen (default).
## On the RTX fork add --dlss=Quality|Balanced|Performance|DLAA [--dlss_model=Fast|Sharp|Sharpest]
## and/or --rtx (path tracing).
## Prints one "BENCH ..." line (fps, frame ms, 1% low, GPU/CPU ms, render size) and quits.
## Not --shot/--frames: those make Settings treat the run as automated and keep a small window.

const RUNNING := 2                       # race.gd State.RUNNING

var _race: Node
var _seconds := 20.0
var _warmup := 3.0
var _go_us := -1
var _start_us := -1
var _last_us := -1
var _frame_ms: PackedFloat32Array = []
var _gpu_ms: PackedFloat32Array = []
var _cpu_ms: PackedFloat32Array = []
var _pso_start := 0
var _draw_calls := 0
var _kmh_max := 0.0
var _ready_us := 0
var _done := false


func _ready() -> void:
	_seconds = float(TestHooks.arg("seconds", 20.0))
	_warmup = float(TestHooks.arg("warmup", 3.0))
	Game.mode = "solo"
	Game.track_id = String(TestHooks.arg("track", "downtown"))
	if TestHooks.has_arg("car"):
		Profile.set_selected_car(String(TestHooks.arg("car", "kaze")))
	TestHooks.args["autodrive"] = "true"           # race.gd reads it in _ready
	Settings.vsync_mode = DisplayServer.VSYNC_DISABLED
	Settings.fps_cap = 0
	Settings.window_mode = clampi(int(TestHooks.arg("window", 2)), 0, Settings.WINDOW_NAMES.size() - 1)
	Settings.render_scale = clampf(float(TestHooks.arg("render_scale", 1.0)), 0.5, 1.0)
	Settings.show_fps = TestHooks.arg("show_fps", false)
	Settings.apply()
	_ready_us = Time.get_ticks_usec()
	_race = (load(Game.SCENE_RACE) as PackedScene).instantiate()
	add_child(_race)


func _process(_delta: float) -> void:
	if _done:
		return
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)   # the HUD turns it off with show_fps off
	var now := Time.get_ticks_usec()
	if _go_us < 0:
		if int(_race.get("state")) == RUNNING:
			_go_us = now
		elif now - _ready_us > 90_000_000:
			print("BENCH_FAIL the race did not start within 90 s")
			_finish()
		return
	var car: Node = _race.get("car")
	if car != null and car.has_method("get_speed_kmh"):
		_kmh_max = maxf(_kmh_max, float(car.call("get_speed_kmh")))
	if _start_us < 0:
		if now - _go_us >= int(_warmup * 1e6):
			_start_us = now
			_last_us = now
			_pso_start = _pso_count()
		return
	_frame_ms.append((now - _last_us) / 1000.0)
	_last_us = now
	_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
	_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
	if _draw_calls == 0 and now - _start_us >= int(_seconds * 0.5e6):
		_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if now - _start_us >= int(_seconds * 1e6):
		_report(now)


func _report(now: int) -> void:
	_done = true
	var vp := get_viewport()
	var size := get_window().size          # canvas_items stretch: 3D draws at the window size, not 1280x720
	var s3d := float(vp.get("scaling_3d_scale"))
	var elapsed_s := (now - _start_us) / 1e6
	var r := {
		"track": Game.track_id,
		"weather": String(TestHooks.arg("weather", "")),
		"quality": Settings.quality,
		"aa": Settings.AA_NAMES[Settings.effective_aa()],
		"dlss": (Settings.DLSS_NAMES[Settings.dlss_mode] + "/" + Settings.dlss_preset()) if Settings.dlss_active() else "off",
		"pt": Settings.path_tracing_active(),
		"res": "%dx%d" % [size.x, size.y],
		"render": "%dx%d" % [roundi(size.x * s3d), roundi(size.y * s3d)],
		"window": Settings.WINDOW_NAMES[Settings.window_mode],
		"frames": _frame_ms.size(),
		"fps": _frame_ms.size() / elapsed_s,
		"ms": _mean(_frame_ms),
		"p99_ms": _percentile(_frame_ms, 0.99),
		"max_ms": _percentile(_frame_ms, 1.0),
		"gpu_ms": _mean(_gpu_ms),
		"gpu_p95": _percentile(_gpu_ms, 0.95),
		"cpu_ms": _mean(_cpu_ms),
		"draw_calls": _draw_calls,
		"compiles": _pso_count() - _pso_start,
		"kmh_max": _kmh_max,
		"gpu": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"engine": Engine.get_version_info()["string"],
		"rtx_status": Settings.rtx_status(),
	}
	print("BENCH track=%s weather=%s quality=%d aa=%s dlss=%s pt=%s res=%s render=%s fps=%.1f ms=%.2f p99_ms=%.2f max_ms=%.1f gpu_ms=%.2f gpu_p95=%.2f cpu_ms=%.2f draw_calls=%d compiles=%d kmh_max=%.0f" % [
		r.track, r.weather, r.quality, r.aa, r.dlss, str(r.pt), r.res, r.render, r.fps, r.ms, r.p99_ms,
		r.max_ms, r.gpu_ms, r.gpu_p95, r.cpu_ms, r.draw_calls, r.compiles, r.kmh_max])
	print("BENCH_ENV gpu=%s driver=%s engine=%s rtx=%s" % [r.gpu, r.driver, r.engine, r.rtx_status])
	if TestHooks.has_arg("out"):
		var f := FileAccess.open(String(TestHooks.arg("out", "")), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(r, "\t"))
	if TestHooks.has_arg("bench_shot"):
		TestHooks.save_screenshot(String(TestHooks.arg("bench_shot", "")))
	_finish()


func _finish() -> void:
	_done = true
	TestHooks.finish()


static func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


static func _percentile(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(ceili(p * b.size()) - 1, 0, b.size() - 1)]


static func _pso_count() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
