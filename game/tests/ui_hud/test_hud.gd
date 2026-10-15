extends Node
## Headless logic test for the HUD, pause menu and results:
## API coverage, formatting, leaderboard compaction, minimap fit, no per-tick allocations
## (node/object counts stay flat), and the per-tick setter cost.

var hud: Node
var pause_menu: Node
var results: Node


func _ready() -> void:
	hud = load("res://ui/hud.tscn").instantiate()
	add_child(hud)
	pause_menu = load("res://ui/pause_menu.tscn").instantiate()
	add_child(pause_menu)
	results = load("res://ui/results.tscn").instantiate()
	add_child(results)
	await get_tree().process_frame
	_test_formatting()
	_test_api()
	_test_leaderboard()
	_test_minimap()
	await _test_per_tick_cost()
	await _test_pause()
	_test_results()
	TestHooks.finish()


func _test_formatting() -> void:
	var codes := PackedInt32Array()
	var ok := true
	for ms in [0, 1, 999, 1000, 59999, 60000, 62345, 599999, 600000, 3599999]:
		HudText.time_codes(ms, codes)
		var s := ""
		for c in codes:
			s += String.chr(c)
		if s != UITheme.format_time(ms):
			ok = false
			print("mismatch %d: %s vs %s" % [ms, s, UITheme.format_time(ms)])
	HudText.time_codes(-1, codes)
	var dash := ""
	for c in codes:
		dash += String.chr(c)
	TestHooks.check(ok and dash == "--:--.---", "time_codes_match_format_time", dash)
	HudText.clock_codes(272001, codes)
	var clk := ""
	for c in codes:
		clk += String.chr(c)
	TestHooks.check(clk == "4:33", "clock_codes_round_up", clk)
	HudText.int_codes(0, codes)
	var z := String.chr(codes[0])
	HudText.int_codes(305, codes)
	TestHooks.check(z == "0" and codes.size() == 3 and codes[0] == 51 and codes[2] == 53, "int_codes")


func _test_api() -> void:
	# Every contract method must exist and accept edge values without errors.
	hud.set_speed(-20.0)
	hud.set_speed(9999.0)
	hud.set_rpm(-1.0, -1)
	hud.set_rpm(2.0, 7)
	hud.set_nitro(-1.0, false)
	hud.set_nitro(5.0, true)
	hud.set_run_time(-1)
	hud.set_run_time(5999999)
	hud.set_best(-1)
	hud.set_best(61234)
	hud.set_checkpoints(0, 0)
	hud.set_checkpoints(3, 12)
	hud.show_split(12345, -100, true)
	hud.show_split(12345, 100, true)
	hud.show_split(12345, 0, false)
	hud.show_finish(60000, true, -500, true)
	hud.show_finish(60000, false, 0, false)
	for n in [3, 2, 1, 0, -1]:
		hud.show_countdown(n)
	hud.show_message("Hello", 0.5)
	hud.show_message("")
	hud.set_round_time_left(-1)
	hud.set_round_time_left(0)
	hud.set_round_time_left(300000)
	hud.set_leaderboard([], 1)
	hud.set_minimap(PackedVector2Array())
	hud.set_minimap_cars(Vector2.ZERO, [])
	hud.set_minimap_cars(Vector2(1, 2), [Vector2(3, 4), {"pos": Vector2(5, 6)}, {"pos": Vector2(1, 1), "color": Color.RED}, 42])
	hud.clear_banners()
	var tacho: HudTachometer = hud._tacho
	TestHooks.check(tacho.rpm == 1.0 and tacho.nitro == 1.0 and tacho.gear == 7, "setters_clamp", "%s %s %s" % [tacho.rpm, tacho.nitro, tacho.gear])
	Settings.units_mph = true
	hud.set_speed(100.0)
	TestHooks.check(tacho._speed_shown == 62 and tacho.mph, "mph_conversion", str(tacho._speed_shown))
	Settings.units_mph = false
	hud.set_speed(100.0)
	TestHooks.check(tacho._speed_shown == 100, "kmh_display", str(tacho._speed_shown))
	# Split label follows set_checkpoints in either call order.
	hud.set_checkpoints(1, 5)
	hud.show_split(1000, -5, true)
	hud.set_checkpoints(2, 5)
	TestHooks.check(hud._split._cp_text == "CP 2", "split_label_after", hud._split._cp_text)
	hud.set_checkpoints(3, 5)
	hud.show_split(2000, 5, true)
	TestHooks.check(hud._split._cp_text == "CP 3", "split_label_before", hud._split._cp_text)
	TestHooks.ok("api_complete")


func _board(n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append({"id": i + 1, "name": "P%d" % (i + 1), "car": "kaze", "best_ms": 60000 + i * 1000 if i != 2 else -1, "runs": i})
	a.shuffle()
	return a


func _test_leaderboard() -> void:
	var lb: HudLeaderboard = hud._board
	hud.set_leaderboard(_board(8), 2)
	TestHooks.check(lb.visible and lb._shown.size() == 5, "leaderboard_compact_5", str(lb._shown.size()))
	TestHooks.check(lb._rows[0]["name"] == "P1" and lb._rows[7]["dnf"] and lb._rows[7]["name"] == "P3", "leaderboard_sorted_dnf_last")
	hud.set_leaderboard(_board(8), 7)
	var last: Dictionary = lb._shown[4]
	TestHooks.check(last["me"] and last["rank"] == 6, "leaderboard_shows_my_row", str(last))
	lb.expanded = true
	TestHooks.check(lb._shown.size() == 8, "leaderboard_expanded_all")
	lb.expanded = false
	hud.set_leaderboard([], 7)
	TestHooks.check(not lb.visible, "leaderboard_hidden_when_empty")


func _test_minimap() -> void:
	var mm: HudMinimap = hud._minimap
	var pts := PackedVector2Array()
	for i in 65:
		var a := TAU * i / 64.0
		pts.append(Vector2(1000.0 + cos(a) * 400.0, -300.0 + sin(a) * 90.0))
	hud.set_minimap(pts)
	var ok := mm.visible
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in mm._line:
		mn = mn.min(p)
		mx = mx.max(p)
	ok = ok and mn.x >= HudMinimap.PAD - 0.5 and mn.y >= HudMinimap.PAD - 0.5
	ok = ok and mx.x <= HudMinimap.SIZE.x - HudMinimap.PAD + 0.5 and mx.y <= HudMinimap.SIZE.y - HudMinimap.PAD + 0.5
	# Fills the box along at least one axis.
	ok = ok and ((mx.x - mn.x) > HudMinimap.SIZE.x - HudMinimap.PAD * 2.0 - 2.0 or (mx.y - mn.y) > HudMinimap.SIZE.y - HudMinimap.PAD * 2.0 - 2.0)
	TestHooks.check(ok, "minimap_fits_box", "%s %s" % [mn, mx])


func _test_per_tick_cost() -> void:
	hud.set_leaderboard(_board(6), 2)
	hud.set_minimap(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50), Vector2(0, 0)]))
	var others: Array = [Vector2(10, 10), Vector2(20, 5)]
	await get_tree().process_frame
	await get_tree().process_frame
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objs0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var t0 := Time.get_ticks_usec()
	var iters := 3000
	for i in iters:
		_tick(i, others)
	var us := float(Time.get_ticks_usec() - t0) / iters
	print("HUD per-tick setters: %.1f us" % us)
	TestHooks.check(us < 150.0, "per_tick_cost_low", "%.1f us" % us)
	# Run some real frames so redraws happen too.
	for i in 30:
		_tick(i, others)
		await get_tree().process_frame
	var nodes1 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objs1 := Performance.get_monitor(Performance.OBJECT_COUNT)
	TestHooks.check(nodes1 == nodes0, "no_node_churn", "%d -> %d" % [nodes0, nodes1])
	TestHooks.check(objs1 - objs0 < 10, "no_object_churn", "%d -> %d" % [objs0, objs1])


func _tick(i: int, others: Array) -> void:
	hud.set_speed(float(i % 340))
	hud.set_rpm(float(i % 100) / 100.0, 1 + (i / 100) % 6)
	hud.set_nitro(float(i % 50) / 50.0, i % 7 == 0)
	hud.set_run_time(i * 17)
	hud.set_round_time_left(300000 - i * 17)
	hud.set_checkpoints(i / 500, 6)
	hud.set_minimap_cars(Vector2(float(i % 100), 0.0), others)


func _test_pause() -> void:
	Game.mode = "solo"
	var got := {"resumed": 0, "restart": 0, "quit": 0}
	pause_menu.resumed.connect(func() -> void: got["resumed"] += 1)
	pause_menu.restart_requested.connect(func() -> void: got["restart"] += 1)
	pause_menu.quit_requested.connect(func() -> void: got["quit"] += 1)
	pause_menu.open()
	TestHooks.check(pause_menu.visible and get_tree().paused, "pause_solo_pauses_tree")
	TestHooks.check(pause_menu._btn_quit.text == "QUIT TO MENU", "pause_quit_label_solo")
	pause_menu._btn_resume.pressed.emit()
	TestHooks.check(not pause_menu.visible and not get_tree().paused and got["resumed"] == 1, "pause_resume")
	Game.mode = "online"
	pause_menu.open()
	TestHooks.check(pause_menu.visible and not get_tree().paused and pause_menu._hint.visible, "pause_online_no_tree_pause")
	TestHooks.check(pause_menu._btn_quit.text == "QUIT TO LOBBY", "pause_quit_label_online")
	pause_menu._btn_restart.pressed.emit()
	TestHooks.check(got["restart"] == 1 and not pause_menu.visible, "pause_restart_signal")
	pause_menu.open()
	pause_menu._btn_quit.pressed.emit()
	TestHooks.check(got["quit"] == 1 and not pause_menu.visible, "pause_quit_signal")
	# Esc while open resumes (but not on the same frame it opened).
	Game.mode = "solo"
	pause_menu.open()
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	pause_menu._unhandled_input(ev)
	TestHooks.check(pause_menu.visible, "pause_ignores_same_frame_toggle")
	await get_tree().process_frame
	pause_menu._unhandled_input(ev)
	TestHooks.check(not pause_menu.visible and not get_tree().paused, "pause_esc_resumes")
	# Settings sliders write to Settings.
	var before := Settings.music_volume
	pause_menu.open()
	pause_menu._toggle_settings()
	(pause_menu._sliders["music"] as HSlider).value = 25
	TestHooks.check(is_equal_approx(Settings.music_volume, 0.25), "pause_settings_slider", str(Settings.music_volume))
	Settings.music_volume = before
	pause_menu._settings_dirty = false
	pause_menu.close()
	Game.mode = "solo"


func _test_results() -> void:
	var rows := _board(6)
	rows.append({"id": 99, "name": "Ghost", "car": {"car": "brute"}, "best_ms": -1, "runs": 0})
	results.show_results(rows, 4)
	var box: VBoxContainer = results._rows_box
	TestHooks.check(results.visible and box.get_child_count() == 7, "results_rows", str(box.get_child_count()))
	TestHooks.check(results._car_name({"car": "brute"}) == CarDefs.display_name("brute").to_upper() and results._car_name("kaze") != "", "results_car_names")
	TestHooks.check(results._sub.text.contains("P3 OF 7"), "results_my_position", results._sub.text)
	TestHooks.check(not hud._root.visible, "results_hide_hud")
	var many: Array = []
	for i in 14:
		many.append({"id": i, "name": "N%d" % i, "car": "veloce", "best_ms": 50000 + i, "runs": 1})
	results.show_results(many, 13)
	TestHooks.check(results._footer.text.begins_with("RETURNING"), "results_footer")
	results.hide_results()
	TestHooks.check(not results.visible and hud._root.visible, "results_hide")
