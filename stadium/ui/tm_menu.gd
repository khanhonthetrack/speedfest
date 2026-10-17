class_name TmMenu
extends Node3D
## The remake's menus (the project's main scene), laid out like TMNF's: the Stadium behind, our
## car on the field with the camera slowly circling it, and on top the pages: main (Play, open a
## track file, options, quit), the campaign (the five series as tabs, each track with your best
## time and medal, the selected track's details and Race), options, and what to do when TMNF
## isn't installed. Race starts race/race.tscn with the track in TestHooks' args.
## Online: the server list (the official server, published in the repo, or any address),
## your name and car colour; Connect joins the server's round (race in online mode).
## Args: --page=main|campaign|online|options|notmnf, --track=B05 (selected), --menu_dry (tests: Race
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
	Music.play_list("menu")
	_scene()
	_layer = CanvasLayer.new()
	add_child(_layer)
	tmnf = TmStage.find_tmnf()
	if not tmnf.is_empty():
		tracks = TmStage.campaign_tracks(tmnf)
	selected = String(TestHooks.arg("track", tracks[0] if not tracks.is_empty() else ""))
	Music.toast(self)
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
	var look := TmCarVisual.new()
	look.paint_colour = TmUi.car_colour()
	holder.add_child(look)
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
	# a dark gradient behind the menu column, fading out to the right
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.02, 0.05, 0.86))
	g.set_color(1, Color(0.01, 0.02, 0.05, 0.0))
	g.add_point(0.55, Color(0.01, 0.02, 0.05, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(1000, 0)
	shade.size = Vector2(1000, 900)
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var title := VBoxContainer.new()
	title.position = Vector2(60, 36)
	title.add_theme_constant_override("separation", 2)
	root.add_child(title)
	var name_l := TmUi.label("SPEEDFEST", 70, Color.WHITE, TmUi.TITLE, 2)
	name_l.add_theme_color_override("font_shadow_color", Color(TmUi.ACCENT, 0.45))
	name_l.add_theme_constant_override("shadow_offset_x", 3)
	name_l.add_theme_constant_override("shadow_offset_y", 3)
	title.add_child(name_l)
	title.add_child(TmUi.label("STADIUM" + ("   /   " + subtitle if not subtitle.is_empty() else ""), 24, TmUi.ACCENT, TmUi.HEAD, 6))
	var bar := ColorRect.new()
	bar.color = TmUi.ACCENT
	bar.custom_minimum_size = Vector2(120, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.add_child(bar)
	# key hints along the bottom
	var hint := TmUi.label("ARROWS / PAD  SELECT        ENTER  CONFIRM        ESC  BACK", 17, TmUi.DIM, TmUi.BOLD, 2)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	hint.position.x = 60
	root.add_child(hint)
	# pages fade in
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	return root


func show_page(name: String) -> void:
	page = name
	_clear()
	match name:
		"campaign":
			_page_campaign() if not tracks.is_empty() else _page_notmnf()
		"options":
			_page_options()
		"online":
			_page_online()
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
	col.add_child(TmUi.button("ONLINE", func() -> void: show_page("online")))
	col.add_child(TmUi.button("OPEN A TRACK FILE", _open_file))
	col.add_child(TmUi.button("OPTIONS", func() -> void: show_page("options")))
	col.add_child(TmUi.button("QUIT", func() -> void: get_tree().quit()))
	var note := TmUi.label("TMNF found: %s" % tmnf if not tmnf.is_empty() else "TMNF not found: open a track file, or see Play", 18, TmUi.DIM)
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 56)
	note.position.x = 60
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
	for opt: Array in [["fullscreen", "Fullscreen"], ["hd", "HD graphics (textures, ambient occlusion)"], ["shadows", "Shadows"], ["sound", "Sound"], ["music", "Music"], ["ghost", "Race against your best ghost"]]:
		var c := CheckButton.new()
		c.text = String(opt[1])
		c.button_pressed = bool(TmUi.setting(opt[0]))
		c.custom_minimum_size = Vector2(520, 54)
		var key: String = opt[0]
		c.toggled.connect(func(on: bool) -> void: TmUi.set_setting(key, on))
		col.add_child(c)
	var vol := HBoxContainer.new()
	vol.add_child(TmUi.label("MUSIC VOLUME  ", 22, TmUi.TEXT, TmUi.BOLD, 1))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(TmUi.setting("music_volume"))
	slider.custom_minimum_size = Vector2(320, 40)
	slider.value_changed.connect(func(v: float) -> void: TmUi.set_setting("music_volume", v))
	vol.add_child(slider)
	col.add_child(vol)
	col.add_child(_cycle("GRAPHICS", "quality", TmRtx.QUALITY_NAMES))
	if TmRtx.is_fork():   # NVIDIA's RTX build of Godot
		col.add_child(_cycle("DLSS", "dlss", TmRtx.DLSS_NAMES))
		var pt := CheckButton.new()
		pt.text = "Path tracing (experimental, RTX 40/50)"
		pt.button_pressed = bool(TmUi.setting("path_tracing"))
		pt.custom_minimum_size = Vector2(520, 54)
		pt.toggled.connect(func(on: bool) -> void: TmUi.set_setting("path_tracing", on))
		col.add_child(pt)
		col.add_child(TmUi.label(TmRtx.status(), 18, TmUi.DIM, TmUi.BOLD))
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


var _online_status: Label
var _official_label: Label
var _official_url := ""


func _page_online() -> void:
	var root := _root("ONLINE")
	var col := _column(root, 190)
	col.add_child(TmUi.label("YOUR NAME", 18, TmUi.DIM, TmUi.BOLD, 2))
	var name_edit := LineEdit.new()
	name_edit.text = String(TmUi.setting("name"))
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(420, 46)
	name_edit.text_changed.connect(func(t: String) -> void: TmUi.set_setting("name", t.strip_edges()))
	col.add_child(name_edit)
	col.add_child(TmUi.label("CAR COLOUR", 18, TmUi.DIM, TmUi.BOLD, 2))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 8)
	col.add_child(swatches)
	for i in TmUi.CAR_COLOURS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 44)
		var st := StyleBoxFlat.new()
		st.bg_color = TmUi.CAR_COLOURS[i]
		st.set_corner_radius_all(22)
		st.set_border_width_all(4 if i == int(TmUi.setting("colour")) else 0)
		st.border_color = Color.WHITE
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.pressed.connect(func() -> void:
			TmUi.set_setting("colour", i)
			show_page("online"))
		swatches.add_child(b)
	col.add_child(HSeparator.new())
	var official := TmUi.button("JOIN THE OFFICIAL SERVER", func() -> void:
		if not _official_url.is_empty():
			_connect(_official_url), 520)
	col.add_child(official)
	_official_label = TmUi.label("Looking for the official server...", 20, TmUi.DIM, TmUi.BOLD)
	col.add_child(_official_label)
	col.add_child(TmUi.label("OR A SERVER'S ADDRESS", 18, TmUi.DIM, TmUi.BOLD, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var addr := LineEdit.new()
	addr.text = String(TmUi.setting("server"))
	addr.placeholder_text = "e.g. 192.168.1.20:8090 or https://name.trycloudflare.com"
	addr.custom_minimum_size = Vector2(520, 46)
	row.add_child(addr)
	row.add_child(TmUi.button("CONNECT", func() -> void:
		TmUi.set_setting("server", addr.text.strip_edges())
		_connect(addr.text.strip_edges()), 180))
	_online_status = TmUi.label("", 22, TmUi.ACCENT, TmUi.BOLD)
	col.add_child(_online_status)
	col.add_child(TmUi.button("BACK", func() -> void:
		Online.leave()
		show_page("main"), 200))
	official.grab_focus.call_deferred()
	_find_official()


## The official server's address (published in the repo) and its status line.
func _find_official() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 8.0
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var d: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not (d is Dictionary) or String(d.get("url", "")).is_empty():
			if is_instance_valid(_official_label):
				_official_label.text = "The official server is offline right now (type an address below)"
			return
		_official_url = String(d["url"])
		_server_status(_official_url))
	req.request(Online.OFFICIAL_LIST)


func _server_status(address: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 8.0
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if not is_instance_valid(_official_label):
			return
		var d: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not (d is Dictionary):
			_official_label.text = "The official server isn't answering"
			return
		var r: Dictionary = d.get("round", {})
		var left := maxi(0, int(float(r.get("end", 0)) - float(d.get("now", 0))))
		var trk := String(r.get("track", ""))
		var trk_name := trk
		if not tmnf.is_empty() and not trk.is_empty():
			trk_name = "%s  %s" % [trk, header(trk).name]
		_official_label.text = "%s   ·   %s   ·   %d/%d players   ·   %d:%02d left" % [String(d.get("name", "")), trk_name,
			int(d.get("players", 0)), int(d.get("maxPlayers", 0)), left / 60000, (left / 1000) % 60])
	req.request(Online.status_url(address))


func _connect(address: String) -> void:
	if address.is_empty():
		return
	if tmnf.is_empty():
		_online_status.text = "Online races use the campaign tracks: install TMNF first (see Play)"
		return
	_online_status.text = "Connecting to %s ..." % address
	for c in Online.connected.get_connections():
		Online.connected.disconnect(c["callable"])
	for c in Online.disconnected.get_connections():
		if c["callable"].get_object() == self:
			Online.disconnected.disconnect(c["callable"])
	Online.connected.connect(_joined, CONNECT_ONE_SHOT)
	Online.disconnected.connect(func(reason: String) -> void:
		if is_instance_valid(_online_status):
			_online_status.text = "Couldn't join: %s" % reason, CONNECT_ONE_SHOT)
	var who := String(TmUi.setting("name")).strip_edges()
	Online.join(address, who if not who.is_empty() else "Player", TmUi.car_colour())


## In the server: race its round's track.
func _joined() -> void:
	race(String(Online.round.get("track", "A01")))


## A button that steps through a setting's values (an index into names).
func _cycle(title: String, key: String, names: Array) -> Button:
	var b := TmUi.button("", Callable(), 520)
	var show := func() -> void: b.text = "%s:  %s" % [title, String(names[clampi(int(TmUi.setting(key)), 0, names.size() - 1)]).to_upper()]
	show.call()
	b.pressed.connect(func() -> void:
		TmUi.set_setting(key, (int(TmUi.setting(key)) + 1) % names.size())
		show.call())
	return b


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
