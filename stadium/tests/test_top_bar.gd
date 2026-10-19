extends Node
## TMNF's top bar (TmTopBar): in a race it is hidden until the mouse reaches the top edge, stays while
## the mouse is on it and goes a moment after the mouse leaves; its wedges set the sound and music
## volumes, the speaker mutes, the window button toggles fullscreen, the display button opens its
## panel (races) or the options page (menus, where the bar stays up with your nickname). Settings go
## to a test file.


func _ready() -> void:
	TestHooks.args["settings"] = "user://test_settings.cfg"
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["menu_dry"] = "true"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	await _popup()
	await _controls()
	await _in_scenes()
	TestHooks.finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _popup() -> void:
	var bar := TmTopBar.new()
	add_child(bar)
	await _frames(3)
	TestHooks.check(not bar.shown(), "bar_hidden_at_first")
	bar.mouse_override = Vector2(800, 3)          # the mouse at the top edge
	await _frames(15)
	TestHooks.check(bar.shown() and bar._bar.offset_top > -1.0, "bar_comes_down_at_the_top", "%.1f" % bar._bar.offset_top)
	bar.mouse_override = Vector2(1400, 20)        # on the bar: it stays
	await _frames(90)
	TestHooks.check(bar.shown(), "bar_stays_under_the_mouse")
	bar.mouse_override = Vector2(800, 500)        # away: it goes after a moment
	await _frames(30)
	TestHooks.check(bar.shown(), "bar_waits_before_going")
	await _frames(60)
	TestHooks.check(not bar.shown(), "bar_goes_when_the_mouse_leaves")
	bar.queue_free()
	await _frames(1)


func _controls() -> void:
	var bar := TmTopBar.new()
	bar.popup = false
	add_child(bar)
	await _frames(2)
	TestHooks.check(bar.shown(), "bar_up_without_popup")
	bar._sound.set_value(0.4)
	bar._music.set_value(0.3)
	TestHooks.check(is_equal_approx(float(TmUi.setting("sound_volume")), 0.4) and is_equal_approx(float(TmUi.setting("music_volume")), 0.3)
		and absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.4)) < 0.05, "bar_volumes",
		"%s %s %.2f dB" % [TmUi.setting("sound_volume"), TmUi.setting("music_volume"), AudioServer.get_bus_volume_db(0)])
	bar._sound_icon.pressed.emit()
	await _frames(1)
	TestHooks.check(not bool(TmUi.setting("sound")) and bar._sound_icon.off and AudioServer.is_bus_mute(0), "bar_speaker_mutes")
	bar._sound_icon.pressed.emit()
	var full := bool(TmUi.setting("fullscreen"))
	bar._window_icon.pressed.emit()
	TestHooks.check(bool(TmUi.setting("fullscreen")) != full, "bar_window_toggles_fullscreen")
	bar._window_icon.pressed.emit()
	var display: Button = null
	for g in bar.find_children("*", "Button", true, false):
		if g is TmTopBar.Glyph and (g as TmTopBar.Glyph).kind == "display":
			display = g
	display.pressed.emit()
	TestHooks.check(bar._panel.visible, "bar_display_panel")
	TmUi.set_setting("sound_volume", 1.0)
	TmUi.set_setting("music_volume", 0.7)
	bar.queue_free()
	await _frames(1)


## In the menus the bar stays up with your nickname, its display button opens the options; a race
## has it hidden until the mouse goes up.
func _in_scenes() -> void:
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _frames(2)
	var mb: TmTopBar = menu._bar
	TestHooks.check(mb != null and mb.shown() and not mb.popup and mb._nick != null, "menu_bar_up")
	mb.display_pressed.emit()
	await _frames(1)
	TestHooks.check(menu.page == "options", "menu_bar_display_opens_options", menu.page)
	menu.queue_free()
	await _frames(2)
	TestHooks.args["track"] = "A01"
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var rb: TmTopBar = scene.top_bar
	TestHooks.check(rb != null and rb.popup and not rb.shown(), "race_bar_hidden")
	rb.mouse_override = Vector2(800, 2)
	await _frames(15)
	TestHooks.check(rb.shown(), "race_bar_comes_down")
	scene.queue_free()
	await _frames(2)
