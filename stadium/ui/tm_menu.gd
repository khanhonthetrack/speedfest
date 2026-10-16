class_name TmMenu
extends Node3D
## The remake's menus (the project's main scene), laid out like TMNF's: the Stadium behind, our
## car on the field with the camera slowly circling it, and on top the pages: main (Play, open a
## track file, options, quit), the campaign (the five series as tabs, each track with your best
## time and medal, the selected track's details and Race), options, and what to do when TMNF
## isn't installed. Race starts race/race.tscn with the track in TestHooks' args.
## Args: --page=main|campaign|options|notmnf, --track=B05 (selected), --menu_dry (tests: Race
## only records the choice).

signal raced(track: String, map: String)

const CENTRE := Vector3(-512.0, 9.0, 512.0)   ## the field's centre (Godot)

var tmnf := ""
var tracks: Array[String] = []
var page := ""
var selected := ""
var series := 0
var _layer: CanvasLayer
var _cam: Camera3D
var _angle := 0.6
var _headers := {}
var _tiles := {}
var _detail: VBoxContainer
var _clear_armed := false


func _ready() -> void:
	TmUi.apply()
	_scene()
	_layer = CanvasLayer.new()
	add_child(_layer)
	tmnf = TmStage.find_tmnf()
	if not tmnf.is_empty():
		tracks = TmStage.campaign_tracks(tmnf)
	selected = String(TestHooks.arg("track", tracks[0] if not tracks.is_empty() else ""))
	for i in TmUi.SERIES.size():
		if selected.begins_with(String(TmUi.SERIES[i][0])):
			series = i
	show_page(String(TestHooks.arg("page", "main")))


## The 3D backdrop: sky, the Stadium, a grass field and our car.
func _scene() -> void:
	TmStadiumEnv.add(self)
	add_child(TmStadiumBuild.build())
	var field := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024, 1024)
	field.mesh = pm
	field.material_override = TmMaterials.get_material("grass")
	field.position = CENTRE
	add_child(field)
	var holder := Node3D.new()
	holder.position = CENTRE + Vector3(0.0, 0.441, 0.0)
	holder.rotation.y = 0.5
	add_child(holder)
	holder.add_child(TmCarVisual.new())
	_cam = Camera3D.new()
	_cam.fov = 50
	add_child(_cam)
	_cam.current = true
	_orbit(0.0)


func _orbit(delta: float) -> void:
	_angle += delta * 0.12
	var at := CENTRE + Vector3(0.0, 0.7, 0.0)
	_cam.position = at + Vector3(cos(_angle) * 7.5, 1.6, sin(_angle) * 7.5)
	_cam.look_at(at + Vector3(0.0, 0.0, 0.0))
	_cam.position -= _cam.basis.x * 2.4   # the car off-centre, right of the menu column


func _process(delta: float) -> void:
	_orbit(delta)


func _clear() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_tiles.clear()


## A full-screen page root with the title at the top left.
func _root(subtitle: String) -> Control:
	var root := Control.new()
	root.theme = TmUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)
	var title := VBoxContainer.new()
	title.position = Vector2(60, 40)
	root.add_child(title)
	title.add_child(TmUi.label("SPEEDFEST", 64, Color.WHITE))
	title.add_child(TmUi.label("STADIUM" + ("  ·  " + subtitle if not subtitle.is_empty() else ""), 28, TmUi.ACCENT))
	return root


func show_page(name: String) -> void:
	page = name
	_clear()
	match name:
		"campaign":
			_page_campaign() if not tracks.is_empty() else _page_notmnf()
		"options":
			_page_options()
		"notmnf":
			_page_notmnf()
		_:
			page = "main"
			_page_main()


func _column(root: Control, top := 200) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.position = Vector2(60, top)
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)
	return col


func _page_main() -> void:
	var root := _root("")
	var col := _column(root, 220)
	var play := TmUi.button("PLAY", func() -> void: show_page("campaign"))
	col.add_child(play)
	col.add_child(TmUi.button("OPEN A TRACK FILE", _open_file))
	col.add_child(TmUi.button("OPTIONS", func() -> void: show_page("options")))
	col.add_child(TmUi.button("QUIT", func() -> void: get_tree().quit()))
	var note := TmUi.label("TMNF found: %s" % tmnf if not tmnf.is_empty() else "TMNF not found: open a track file, or see Play", 18, TmUi.DIM)
	note.position = Vector2(60, 860)
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_top = -50
	root.add_child(note)
	play.grab_focus.call_deferred()


func _series_tracks(i: int) -> Array[String]:
	var letter := String(TmUi.SERIES[i][0])
	var out: Array[String] = []
	for t in tracks:
		if t.begins_with(letter):
			out.append(t)
	return out


func header(track: String) -> TmChallenge:
	if not _headers.has(track):
		_headers[track] = TmChallenge.load_file(TmStage.campaign_file(tmnf, track), true)
	return _headers[track]


func _page_campaign() -> void:
	var root := _root("CAMPAIGN")
	var box := HBoxContainer.new()
	box.position = Vector2(60, 170)
	box.add_theme_constant_override("separation", 24)
	root.add_child(box)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	box.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	left.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TmUi.SERIES.size():
		var s: Array = TmUi.SERIES[i]
		var b := Button.new()
		b.text = String(s[1]).to_upper()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == series
		b.custom_minimum_size = Vector2(140, 48)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(s[2], 0.9)
		st.set_corner_radius_all(6)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_color_override("font_pressed_color", Color.BLACK if i < 3 else Color.WHITE)
		b.pressed.connect(func() -> void:
			series = i
			var first := _series_tracks(i)
			if not first.is_empty() and not selected.begins_with(String(s[0])):
				selected = first[0]
			show_page("campaign"))
		tabs.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	left.add_child(grid)
	var focus: Button = null
	for t in _series_tracks(series):
		var ch := header(t)
		var best := TmRecords.best(ch)
		var ms := int(best.get("time_ms", -1))
		var m := TmRace.medal(ms, ch)
		var b := Button.new()
		b.text = "%s\n%s" % [t, TmRace.time_text(ms)]
		b.custom_minimum_size = Vector2(150, 92)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 22)
		if not m.is_empty():
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.06, 0.09, 0.16, 0.85)
			st.border_color = TmRaceHud.MEDAL_COLOURS[m]
			st.set_border_width_all(3)
			st.set_corner_radius_all(6)
			b.add_theme_stylebox_override("normal", st)
		b.pressed.connect(func() -> void: select(t))
		b.focus_entered.connect(func() -> void: select(t, false))
		grid.add_child(b)
		_tiles[t] = b
		if t == selected:
			focus = b
	var back := TmUi.button("BACK", func() -> void: show_page("main"), 200)
	left.add_child(back)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 560)
	box.add_child(panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	panel.add_child(_detail)
	select(selected if _tiles.has(selected) else _series_tracks(series)[0], false)
	if focus:
		focus.grab_focus.call_deferred()


## Shows a track's details (and races it on a second press of its tile).
func select(track: String, race_on_repeat := true) -> void:
	if race_on_repeat and track == selected and _detail and _detail.get_child_count() > 0:
		race(track)
		return
	selected = track
	if _detail == null:
		return
	for c in _detail.get_children():
		c.queue_free()
	var ch := header(track)
	var best := TmRecords.best(ch)
	var ms := int(best.get("time_ms", -1))
	var m := TmRace.medal(ms, ch)
	_detail.add_child(TmUi.label(track, 22, TmUi.ACCENT))
	_detail.add_child(TmUi.label(ch.name if ch.ok() else "(unreadable: %s)" % ch.error, 34, Color.WHITE))
	_detail.add_child(TmUi.label("by %s" % ch.author, 20, TmUi.DIM))
	_detail.add_child(HSeparator.new())
	for row: Array in [["Author", ch.author_ms, "author"], ["Gold", ch.gold_ms, "gold"], ["Silver", ch.silver_ms, "silver"], ["Bronze", ch.bronze_ms, "bronze"]]:
		var l := TmUi.label("%-8s %s" % [row[0], TmRace.time_text(int(row[1]))], 26, TmRaceHud.MEDAL_COLOURS[row[2]])
		_detail.add_child(l)
	_detail.add_child(HSeparator.new())
	_detail.add_child(TmUi.label("Your best  %s" % TmRace.time_text(ms), 28, Color.WHITE))
	_detail.add_child(TmUi.label(("%s medal" % m.capitalize()) if not m.is_empty() else ("Not finished yet" if ms < 0 else "No medal yet"), 22,
		TmRaceHud.MEDAL_COLOURS[m] if not m.is_empty() else TmUi.DIM))
	var go := TmUi.button("RACE", func() -> void: race(track), 240)
	go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(go)


func _page_options() -> void:
	var root := _root("OPTIONS")
	var col := _column(root, 200)
	for opt: Array in [["fullscreen", "Fullscreen"], ["shadows", "Shadows"], ["ghost", "Race against your best ghost"]]:
		var c := CheckButton.new()
		c.text = String(opt[1])
		c.button_pressed = bool(TmUi.setting(opt[0]))
		c.custom_minimum_size = Vector2(520, 54)
		var key: String = opt[0]
		c.toggled.connect(func(on: bool) -> void: TmUi.set_setting(key, on))
		col.add_child(c)
	var clear := TmUi.button("CLEAR ALL RECORDS", Callable(), 520)
	clear.pressed.connect(func() -> void:
		if _clear_armed:
			TmRecords.clear()
			clear.text = "RECORDS CLEARED"
			_clear_armed = false
		else:
			clear.text = "PRESS AGAIN TO CLEAR ALL RECORDS"
			_clear_armed = true)
	col.add_child(clear)
	var back := TmUi.button("BACK", func() -> void: show_page("main"), 200)
	col.add_child(back)
	(col.get_child(0) as Control).grab_focus.call_deferred()


func _page_notmnf() -> void:
	var root := _root("PLAY")
	var col := _column(root, 200)
	var text := TmUi.label("TrackMania Nations Forever isn't installed where the remake looks for it.\n" +
		"Install it (free, from Ubisoft/Nadeo or Steam) to race its campaign, start the remake with\n" +
		"--tmnf=\"<its folder>\" or set TMNF_DIR, or open any .Challenge.Gbx track file.", 22, TmUi.TEXT)
	col.add_child(text)
	var open := TmUi.button("OPEN A TRACK FILE", _open_file)
	col.add_child(open)
	col.add_child(TmUi.button("BACK", func() -> void: show_page("main"), 200))
	open.grab_focus.call_deferred()


func _open_file() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.Gbx ; TrackMania tracks"])
	fd.use_native_dialog = true
	fd.file_selected.connect(func(path: String) -> void: race("", path))
	_layer.add_child(fd)
	fd.popup_centered_ratio(0.7)


## Starts a race: a campaign track, or a track file (map).
func race(track: String, map := "") -> void:
	TestHooks.args.erase("map")
	TestHooks.args.erase("track")
	if not map.is_empty():
		TestHooks.args["map"] = map
	else:
		TestHooks.args["track"] = track
	raced.emit(track, map)
	if TestHooks.arg("menu_dry", false):
		return
	get_tree().change_scene_to_file("res://race/race.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and page != "main":
		show_page("main")
		get_viewport().set_input_as_handled()
