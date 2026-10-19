class_name TmMenu
extends Node3D
## The remake's menus (the project's main scene), laid out as TMNF's (compared side by side with
## TMNF running, M10-5): a green globe turning on black behind; down the left a dark column with a
## header card (the page's title, what to do, an icon) and the page's entries as icon rows (green
## when focused, the current choice ringed green), Back or Quit at its foot; on the right, panels
## with green title bars; a bar at the top right with your nickname, zone and the clock. The profile
## shows our car on the field instead of the globe. Pages:
## - main: Play Solo, Play Online, Editors, Profile, Options, Quit; your campaign's medals;
## - solo (also "campaign"): the series down the left (White .. Black), the series' tracks as cards
##   in a grid (a press races; the focused track's medal times and your best above the grid),
##   Replays, Browse (any .Challenge.Gbx or .sftrack), Back;
## - editors: the tracks you made (TmUserTracks) with New track, Edit (editor/editor.tscn), Play,
##   Delete;
## - replays: the replays kept (saved ones and your best run on each track), Watch, Delete;
## - online: your account (log in, register; ladder points and ranks), the servers (from the
##   master: name, mode, track, players), the world's and your zone's rankings, joining by address;
## - profile: your nickname (TMNF's $-codes, previewed), zone, car colour and medals;
## - options.
## Race starts race/race.tscn with the track in TestHooks' args.
## Args: --race=SF01 (straight into that track; exported builds can't be given a scene),
## --page=main|solo|campaign|replays|editors|online|profile|options, --track=SF01 (selected), --menu_dry (tests:
## Race only records the choice).

signal raced(track: String, map: String)
signal watched(replay: String)
signal edited(track_file: String)

const CENTRE := Vector3(-512.0, 9.0, 512.0)   ## the field's centre (Godot)
const PAGES := {"main": "", "solo": "main", "campaign": "main", "replays": "solo", "editors": "main", "online": "main", "profile": "main",
	"options": "main"}
const MEDALS := ["author", "gold", "silver", "bronze"]
## The backdrop's grade: dark green at the edges and behind the menu column (TMNF's menus sit
## on a dark green, blurred Stadium).
const GRADE := """shader_type canvas_item;
uniform float left_dark = 0.55;
void fragment() {
	vec2 d = (UV - vec2(0.64, 0.56)) * vec2(1.5, 1.25);
	float v = smoothstep(0.3, 1.15, length(d));
	float left = smoothstep(0.62, 0.0, UV.x) * left_dark;
	float top = smoothstep(0.16, 0.0, UV.y) * 0.4;
	COLOR = vec4(0.015, 0.06, 0.035, clamp(0.16 + 0.62 * v + left + top, 0.0, 0.9));
}
"""

var tracks: Array[String] = []     ## the campaign (TmTracks)
var page := ""
var selected := ""
var series := 0
var _layer: CanvasLayer
var _cam: Camera3D
var _car_holder: Node3D
var _angle := 0.6
var _view := 0.0                   ## 0: the menus' wide view, 1: close on the car (profile)
var _headers := {}
var _tiles := {}
var _detail: VBoxContainer
var _clear_armed := false
var _profile_focus := ""            ## after a pick rebuilds the profile page: "zone" or a swatch's index
var _account_asked := false         ## the online page asked the master for the account (this visit)
var _profile_changed := false
var _grade: ColorRect
var _world: Node3D                 ## the Stadium, the field and the car (shown on the profile page)
var _backdrop: Control             ## the globe on black (every other page)
var _globe: ShaderMaterial
var _spin := 0.4
var _rows: VBoxContainer           ## the left column's entries
var _rows_bottom: VBoxContainer    ## its entries at the foot (Back, Quit)
const COLUMN := Rect2(7, 4, 364, 892)
const BAR_WIDTH := 945.0           ## the top right bar (TMNF's: volume, display, clock; ours: you, the clock)
const BAR_HEIGHT := 38.0
const TOP := 48.0                  ## the panels start under the bar
const RIGHT := Rect2(400, 48, 1180, 0)   ## the right of the column, under the bar
var _clock: TmSegText
const GLOBE := preload("res://ui/tm_globe.gdshader")
const GLOBE_MAP := preload("res://assets/tex/globe_map_albedo.jpg")


func _ready() -> void:
	TmUi.apply()
	Music.play_list("menu")
	_scene()
	_layer = CanvasLayer.new()
	add_child(_layer)
	_grade = ColorRect.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = GRADE
	_grade.material = sm
	_layer.add_child(_grade)
	_make_backdrop()
	tracks = TmTracks.ids()
	_online_tab = int(TestHooks.arg("online_tab", 0))
	selected = String(TestHooks.arg("track", tracks[0] if not tracks.is_empty() else ""))
	Music.toast(self, 0.0, true)   # along the bottom, in line with the key hints
	var all := TmTracks.series()
	for i in all.size():
		if (all[i]["tracks"] as Array).has(selected):
			series = i
	show_page(String(TestHooks.arg("page", "main")))
	if TestHooks.has_arg("race") and not tracks.is_empty():
		var go := String(TestHooks.arg("race", tracks[0]))
		TestHooks.args.erase("race")
		race.call_deferred(go)


## The 3D backdrop: sky, the Stadium, a grass field and our car; the camera focuses on the car
## and leaves the Stadium soft behind it.
func _scene() -> void:
	TmStadiumEnv.add(self)
	_world = Node3D.new()
	add_child(_world)
	_world.add_child(TmStadiumBuild.build())
	var field := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024, 1024)
	field.mesh = pm
	field.material_override = TmMaterials.get_material("grass")
	field.position = CENTRE
	_world.add_child(field)
	_car_holder = Node3D.new()
	_car_holder.position = CENTRE + Vector3(0.0, 0.441, 0.0)
	_car_holder.rotation.y = 0.5
	_world.add_child(_car_holder)
	_paint_car()
	_cam = Camera3D.new()
	_cam.fov = 50
	var dof := CameraAttributesPractical.new()
	dof.dof_blur_far_enabled = true
	dof.dof_blur_far_distance = 13.0
	dof.dof_blur_far_transition = 30.0
	dof.dof_blur_amount = 0.16
	_cam.attributes = dof
	add_child(_cam)
	_cam.current = true
	_orbit(0.0)


func _paint_car() -> void:
	for c in _car_holder.get_children():
		c.queue_free()
	var look := TmCarVisual.new()
	look.paint_colour = TmUi.car_colour()
	_car_holder.add_child(look)


func _orbit(delta: float) -> void:
	_angle += delta * 0.12
	_view = move_toward(_view, 1.0 if page == "profile" else 0.0, delta * 1.5)
	var v := smoothstep(0.0, 1.0, _view)
	var at := CENTRE + Vector3(0.0, 0.75 - 0.15 * v, 0.0)
	var dist := lerpf(7.0, 5.4, v)
	_cam.position = at + Vector3(cos(_angle) * dist, lerpf(0.55, 0.45, v), sin(_angle) * dist)
	_cam.look_at(at)
	_cam.position -= _cam.basis.x * lerpf(2.4, 2.9, v)   # the car off-centre, right of the profile's panel


func _process(delta: float) -> void:
	_orbit(delta)
	_spin += delta * 0.05
	_globe.set_shader_parameter("spin", _spin)
	if is_instance_valid(_clock):
		_clock.text = _clock_text()


## The time of day for the bar's clock, as TMNF's (hh:mm:ss).
static func _clock_text() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [int(t["hour"]), int(t["minute"]), int(t["second"])]


## TMNF's backdrop: black, a green globe turning slowly right of the column.
func _make_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_backdrop)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(black)
	var g := ColorRect.new()
	_globe = ShaderMaterial.new()
	_globe.shader = GLOBE
	_globe.set_shader_parameter("globe_map", GLOBE_MAP)
	g.material = _globe
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.anchor_left = 0.5
	g.anchor_right = 0.5
	g.anchor_top = 0.5
	g.anchor_bottom = 0.5
	g.offset_left = -377
	g.offset_right = 447
	g.offset_top = -412
	g.offset_bottom = 412
	_backdrop.add_child(g)


func _clear() -> void:
	for c in _layer.get_children():
		if c != _grade and c != _backdrop:
			c.queue_free()
	_tiles.clear()
	_detail = null


## A page's frame as TMNF's: down the left the dark column, its header card (the page's title, what
## to do there, an icon) and the rows (_row) under it; your nickname and zone at the top right.
## Returns the page's root.
func _root(title := "", subtitle := "", icon_name := "") -> Control:
	var root := Control.new()
	root.theme = TmUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var col := Panel.new()
	col.add_theme_stylebox_override("panel", TmUi.glass("tm_column"))
	col.position = COLUMN.position
	col.size = COLUMN.size
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", TmUi.glass("tm_card"))
	card.position = COLUMN.position + Vector2(4, 4)
	card.custom_minimum_size = Vector2(COLUMN.size.x - 8, 74)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	var hb := HBoxContainer.new()
	card.add_child(hb)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -8)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(tv)
	var t := TmUi.label(title, 32, Color.WHITE, TmUi.SANS_ITALIC)
	t.add_theme_constant_override("outline_size", 0)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_x", 1)
	t.add_theme_constant_override("shadow_offset_y", 2)
	tv.add_child(t)
	var s := TmUi.label(subtitle, 19, Color(0.25, 0.25, 0.27), "cabin-latin-500-italic")
	s.add_theme_constant_override("outline_size", 0)
	tv.add_child(s)
	if not icon_name.is_empty():
		hb.add_child(_icon(icon_name, 60))
	_rows = VBoxContainer.new()
	_rows.position = COLUMN.position + Vector2(4, 96)
	_rows.add_theme_constant_override("separation", 4)
	root.add_child(_rows)
	_rows_bottom = VBoxContainer.new()
	_rows_bottom.add_theme_constant_override("separation", 4)
	root.add_child(_rows_bottom)
	_rows_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	_rows_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_rows_bottom.position = Vector2(COLUMN.position.x + 4, COLUMN.end.y - 4)
	# the bar at the top right, as TMNF's: your nickname and zone, the clock
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", TmUi.glass("tm_bar"))
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.offset_left = -BAR_WIDTH
	bar.offset_bottom = BAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END
	line.add_theme_constant_override("separation", 14)
	bar.add_child(line)
	var nick := TmUi.nick_label(String(TmUi.setting("name")), 21)
	nick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(nick)
	var zone := String(TmUi.setting("zone"))
	var zl := TmUi.label((zone.replace("|", "  ·  ") if not zone.is_empty() else "World").to_upper(), 15, TmUi.DIM, TmUi.SANS)
	line.add_child(zl)
	_clock = TmSegText.new()
	_clock.digit_height = 16.0
	_clock.custom_minimum_size = Vector2(118, 30)
	_clock.text = _clock_text()
	line.add_child(_clock)
	var pad := Control.new()
	pad.custom_minimum_size.x = 6
	line.add_child(pad)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	call_deferred("_settle_rows")
	return root


## Keeps the foot rows' box on the column's floor once its size is known.
func _settle_rows() -> void:
	if is_instance_valid(_rows_bottom):
		_rows_bottom.position.y = COLUMN.end.y - 4 - _rows_bottom.size.y


## An entry of the left column: an icon and a name; green when focused, ringed green when it's the
## page's current choice (chosen); at the column's foot with `bottom`.
func _row(text: String, icon_name: String, action: Callable, bottom := false, chosen := false) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = TmUi.icon(icon_name, 60)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(COLUMN.size.x - 8, 88)
	b.add_theme_constant_override("h_separation", 22)
	b.add_theme_stylebox_override("normal", TmUi.glass("tm_row_chosen" if chosen else "tm_row"))
	b.add_theme_stylebox_override("hover", TmUi.glass("tm_row_chosen" if chosen else "tm_row_hover"))
	b.add_theme_stylebox_override("pressed", TmUi.glass("tm_row_chosen" if chosen else "tm_row_hover"))
	b.add_theme_stylebox_override("hover_pressed", TmUi.glass("tm_row_chosen" if chosen else "tm_row_hover"))
	b.add_theme_stylebox_override("focus", TmUi.glass("tm_row_focus"))
	b.add_theme_font_override("font", TmUi.font(TmUi.SANS))
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_constant_override("outline_size", 0)
	var green := TmUi.TM_GREEN
	b.add_theme_color_override("font_color", green if chosen else Color.WHITE)
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, green)
	for c in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("shadow_offset_y", 2)
	if action.is_valid():
		b.pressed.connect(action)
	b.pressed.connect(TmUi.play.bind("click"))
	b.mouse_entered.connect(TmUi.play.bind("move"))
	b.mouse_entered.connect(b.grab_focus)
	(_rows_bottom if bottom else _rows).add_child(b)
	return b


## Space between groups of rows.
func _gap(h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(g)


## A panel as TMNF's: dark, a green title bar; returns its body.
func _panel(root: Control, title: String, rect: Rect2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = rect.position
	p.custom_minimum_size = rect.size
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(TmUi.tm_title(title))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	v.add_child(m)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	m.add_child(body)
	return body


func show_page(name: String) -> void:
	if page == "profile" and name != "profile" and _profile_changed:
		_profile_changed = false
		Master.push_profile()      # the account takes the profile's nickname and zone
	if name != page:
		_account_asked = false
	page = name if PAGES.has(name) else "main"
	if page == "campaign":
		page = "solo"              # TMNF's campaign is the Solo page
	_clear()
	(_grade.material as ShaderMaterial).set_shader_parameter("left_dark", 0.25)
	var car_view := page == "profile"
	_world.visible = car_view
	_grade.visible = car_view
	_backdrop.visible = not car_view
	match page:
		"solo":
			_page_solo()
		"replays":
			_page_replays()
		"editors":
			_page_editors()
		"options":
			_page_options()
		"online":
			_page_online()
		"profile":
			_page_profile()
		_:
			_page_main()


func back() -> void:
	if page == "online":
		Online.leave()
	show_page(String(PAGES.get(page, "")) if not String(PAGES.get(page, "")).is_empty() else "main")


func _page_main() -> void:
	var root := _root("Welcome!", "Choose an activity", "icon_car")
	var solo := _row("Play Solo", "icon_solo", func() -> void: show_page("solo"))
	_row("Play Online", "icon_online", func() -> void: show_page("online"))
	_gap(96)
	_row("Editors", "icon_editors", func() -> void: show_page("editors"))
	_row("Profile", "icon_profile", func() -> void: show_page("profile"))
	_row("Options", "icon_options", func() -> void: show_page("options"))
	_row("Quit", "icon_quit", func() -> void: get_tree().quit(), true)
	# your campaign at the right, where TMNF lists your buddies
	_campaign_panel(_panel(root, "Your Campaign", Rect2(1091, TOP, 440, 0)))
	solo.grab_focus.call_deferred()


## Your medals per series and over the campaign (the main page's panel).
func _campaign_panel(body: VBoxContainer) -> void:
	var all := TmTracks.series()
	for s: Dictionary in all:
		var ids: Array = s["tracks"]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.add_child(_icon(_flag(String(s["name"])), 44))
		var n := TmUi.label(String(s["name"]), 23, Color.WHITE, TmUi.SANS)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(n)
		var done := 0
		for t: String in ids:
			var ch := header(t)
			var ms := int(TmRecords.best(ch).get("time_ms", -1))
			if ms >= 0:
				done += 1
		line.add_child(TmUi.label("%d / %d" % [done, ids.size()], 21, TmUi.DIM, TmUi.SANS))
		body.add_child(line)
	body.add_child(HSeparator.new())
	body.add_child(_medal_summary())


## A series' flag icon (assets/ui/flag_<name>), the white one for others.
static func _flag(series_name: String) -> String:
	var n := "flag_" + series_name.to_lower()
	return n if ResourceLoader.exists("res://assets/ui/%s.png" % n) else "flag_white"


## Your medals over the campaign: a row per kind (icon, name, count) and how many you finished.
func _medal_summary() -> VBoxContainer:
	var counts := medal_counts()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for m: String in MEDALS:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(_icon("medal_" + m, 34))
		cell.add_child(TmUi.label(str(counts[m]), 26, TmUi.TEXT, TmUi.SANS_BOLD))
		row.add_child(cell)
	box.add_child(TmUi.label("%d of %d tracks finished" % [counts["finished"], tracks.size()], 20, TmUi.DIM, TmUi.SANS))
	return box


## How many campaign tracks you finished, and with which medal: {author, gold, silver, bronze,
## finished}. A medal counts only its best (an author time is not also a gold).
func medal_counts() -> Dictionary:
	var out := {"author": 0, "gold": 0, "silver": 0, "bronze": 0, "finished": 0}
	for t in tracks:
		var ch := header(t)
		var ms := int(TmRecords.best(ch).get("time_ms", -1))
		if ms < 0:
			continue
		out["finished"] += 1
		var m := TmRace.medal(ms, ch)
		if out.has(m):
			out[m] += 1
	return out


func _icon(name: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = TmUi.icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func header(track: String) -> TmChallenge:
	if not _headers.has(track):
		_headers[track] = TmTracks.challenge(track)
	return _headers[track]


## Solo as TMNF's: the series down the left (the current one ringed), its tracks as cards in a
## grid, the focused track's medal times and your best in the panel above them; a card's press
## races it.
func _page_solo() -> void:
	var root := _root("Play Solo", "Choose a difficulty", "icon_solo")
	var all := TmTracks.series()
	series = clampi(series, 0, maxi(all.size() - 1, 0))
	for i in all.size():
		var sname := String(all[i]["name"])
		_row(sname, _flag(sname), func() -> void:
			series = i
			var first: Array = all[i]["tracks"]
			if not first.is_empty() and not first.has(selected):
				selected = first[0]
			show_page("solo"), false, i == series)
	_row("Replays", "icon_replays", func() -> void: show_page("replays"), true)
	_row("Browse", "icon_browse", _open_file, true)
	_row("Back", "icon_back", back, true)
	_detail = _panel(root, "", Rect2(480, TOP, 1038, 0))
	var grid := GridContainer.new()
	grid.position = Vector2(480, 252)
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	root.add_child(grid)
	var focus: Button = null
	var ids: Array = all[series]["tracks"] if not all.is_empty() else []
	for t: String in ids:
		var card := _card(t)
		grid.add_child(card)
		_tiles[t] = card
		if t == selected:
			focus = card
	if not ids.is_empty():
		select(selected if _tiles.has(selected) else String(ids[0]), false)
	if focus:
		focus.grab_focus.call_deferred()


## A track's card as TMNF's: its picture above (assets/ui/thumbs, rendered by tools/icons/thumbs.sh;
## the map's outline on dark grass without one), its name on a light strip below; all green with a
## play mark when focused; your medal in the corner.
func _card(t: String) -> Button:
	var ch := header(t)
	var ms := int(TmRecords.best(ch).get("time_ms", -1))
	var m := TmRace.medal(ms, ch)
	var card := Button.new()
	card.custom_minimum_size = Vector2(190, 152)
	card.tooltip_text = ch.name
	var frame := TmUi.glass("tm_tile")
	var lit := TmUi.glass("tm_tile_lit")
	card.add_theme_stylebox_override("normal", frame)
	card.add_theme_stylebox_override("hover", lit)
	card.add_theme_stylebox_override("pressed", lit)
	card.add_theme_stylebox_override("hover_pressed", lit)
	card.add_theme_stylebox_override("focus", lit)      # TMNF's focused card: all green
	var pic := PanelContainer.new()
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0.09, 0.16, 0.08)
	dark.set_corner_radius_all(3)
	pic.add_theme_stylebox_override("panel", dark)
	pic.position = Vector2(5, 5)
	pic.size = Vector2(180, 114)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pic)
	var shot := "res://assets/ui/thumbs/%s.jpg" % t
	if ResourceLoader.exists(shot):      # a picture of the track, as TMNF's cards
		var tr := TextureRect.new()
		tr.texture = load(shot)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(tr)
	else:
		var map := TmTrackMap.new(ch)
		map.line_width = 2.5
		map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(map)
	var play := _icon("play", 64)
	play.position = Vector2(63, 30)
	play.size = Vector2(64, 64)
	play.visible = false
	card.add_child(play)
	if not m.is_empty():
		var medal := _icon("medal_" + m, 34)
		medal.position = Vector2(150, 8)
		medal.size = Vector2(34, 34)
		card.add_child(medal)
	var name_l := TmUi.label(ch.name, 19, TmUi.TM_INK, TmUi.SANS_BOLD)
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.clip_text = true
	name_l.position = Vector2(4, 120)
	name_l.size = Vector2(182, 28)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_l)
	# focused: the picture tinted green under a green play mark, the name light on the green
	play.modulate = Color(0.35, 1.0, 0.35)
	card.focus_entered.connect(func() -> void:
		play.visible = true
		pic.modulate = Color(0.55, 1.0, 0.5)
		name_l.add_theme_color_override("font_color", Color(0.85, 1.0, 0.8)))
	card.focus_exited.connect(func() -> void:
		play.visible = false
		pic.modulate = Color.WHITE
		name_l.add_theme_color_override("font_color", TmUi.TM_INK))
	card.pressed.connect(func() -> void: select(t))
	card.pressed.connect(func() -> void: TmUi.play("click"))
	card.focus_entered.connect(func() -> void: select(t, false))
	card.mouse_entered.connect(card.grab_focus)
	return card


## Shows a track in the panel above the grid (its name and author in the title bar, the medal
## times, your best); a press of its card (race_on_repeat) races it, as in TMNF.
func select(track: String, race_on_repeat := true) -> void:
	if race_on_repeat:
		selected = track
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
	var title := _detail.get_parent().get_parent().get_child(0) as PanelContainer
	((title.get_child(0)) as Label).text = "%s  ·  by %s" % [ch.name if ch.ok() else track, ch.author] if ch.ok() else "(unreadable: %s)" % ch.error
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_child(row)
	for r: Array in [["author", "Author", ch.author_ms], ["gold", "Gold", ch.gold_ms], ["silver", "Silver", ch.silver_ms], ["bronze", "Bronze", ch.bronze_ms]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(_icon("medal_" + String(r[0]), 34))
		cell.add_child(TmUi.label(TmRace.time_text(int(r[2])), 24, TmRaceHud.MEDAL_COLOURS[r[0]], TmUi.SANS_BOLD))
		row.add_child(cell)
	var mine := HBoxContainer.new()
	mine.add_theme_constant_override("separation", 10)
	mine.add_child(_icon("medal_" + (m if not m.is_empty() else "none"), 34))
	mine.add_child(TmUi.label("Your best", 22, TmUi.DIM, TmUi.SANS))
	mine.add_child(TmUi.label(TmRace.time_text(ms), 24, Color.WHITE, TmUi.SANS_BOLD))
	mine.add_child(TmUi.label(("%s medal" % m.capitalize()) if not m.is_empty() else ("Not finished yet" if ms < 0 else "No medal yet"), 22,
		TmRaceHud.MEDAL_COLOURS[m] if not m.is_empty() else TmUi.DIM, TmUi.SANS))
	row.add_child(mine)
	_online_records(track, ch)


var replay_rows := {}               ## path -> the row's button (replays page)
var replay_selected := ""
const REPLAY_COLUMNS := [["Track", 400], ["Time", 150], ["Player", 330], ["Date", 230]]


## The replays kept on this machine (TmReplay.list: saved ones and the autosaves of your best runs),
## newest first, in a panel right of the column; a row selects, a second press (or Watch) watches;
## Delete asks twice.
func _page_replays() -> void:
	var root := _root("Replays", "Choose a replay", "icon_replays")
	_row("Back", "icon_back", back, true)
	replay_rows.clear()
	var col := _panel(root, "Replays", RIGHT)
	col.add_child(_columns(REPLAY_COLUMNS))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1130, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true      # keyboard and pad focus scroll the list
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var all := TmReplay.list()
	if all.is_empty():
		rows.add_child(TmUi.label("No replays yet. Finish a race and press Save replay; your best run on each track is kept by itself.", 21, TmUi.DIM, TmUi.SANS))
	var group := ButtonGroup.new()
	for e: Dictionary in all:
		var r: TmReplay = e["replay"]
		var path := String(e["path"])
		var row := _list_row(group, 1110)
		var texts := [r.track_name + ("   (best)" if e["autosave"] else ""), TmRace.time_text(r.finish_ms), "", r.date.left(16)]
		for i in REPLAY_COLUMNS.size():
			var cell: Control
			if i == 2:
				cell = TmUi.nick_label(r.player, 21, TmUi.TM_INK)
				cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			else:
				cell = _cell(String(texts[i]), TmUi.TM_GREEN.darkened(0.25) if i == 1 else TmUi.TM_INK)
			cell.custom_minimum_size.x = int(REPLAY_COLUMNS[i][1])
			row.get_child(0).add_child(cell)
		row.pressed.connect(func() -> void:
			TmUi.play("click")
			if replay_selected == path:
				watch(path)
			replay_selected = path
			_disarm())
		rows.add_child(row)
		replay_rows[path] = row
	if not all.is_empty() and not replay_rows.has(replay_selected):
		replay_selected = String(all[0]["path"])
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var go := TmUi.tm_button("Watch", func() -> void:
		if not replay_selected.is_empty():
			watch(replay_selected), 240)
	go.disabled = all.is_empty()
	buttons.add_child(go)
	var del := TmUi.tm_button("Delete", Callable(), 240)
	del.disabled = all.is_empty()
	_del_btn = del
	del.pressed.connect(func() -> void:
		if _arm(del, replay_selected, (TmReplay.load_file(replay_selected, true).track_name if TmReplay.load_file(replay_selected, true) else "")):
			return
		DirAccess.remove_absolute(replay_selected)
		replay_selected = ""
		show_page("replays"))
	buttons.add_child(del)
	if replay_rows.has(replay_selected):
		var sel: Button = replay_rows[replay_selected]
		sel.button_pressed = true
		sel.grab_focus.call_deferred()
	else:
		go.grab_focus.call_deferred()


## A list's column heads (names and widths).
func _columns(cols: Array) -> HBoxContainer:
	var head := HBoxContainer.new()
	var pad := Control.new()
	pad.custom_minimum_size.x = 18
	head.add_child(pad)
	for c: Array in cols:
		var l := TmUi.label(String(c[0]), 18, TmUi.DIM, TmUi.SANS_BOLD)
		l.custom_minimum_size.x = int(c[1])
		head.add_child(l)
	return head


## A row of a list as TMNF's: a light grey strip with dark text, white with a green bar when
## picked (toggled in its group); its cells go in its first child.
func _list_row(group: ButtonGroup, width: float) -> Button:
	var row := Button.new()
	row.toggle_mode = true
	row.button_group = group
	row.custom_minimum_size = Vector2(width, 44)
	row.add_theme_stylebox_override("normal", TmUi.glass("tm_list"))
	row.add_theme_stylebox_override("hover", TmUi.glass("tm_list_hover"))
	row.add_theme_stylebox_override("pressed", TmUi.glass("tm_list_chosen"))
	row.add_theme_stylebox_override("hover_pressed", TmUi.glass("tm_list_chosen"))
	row.add_theme_stylebox_override("focus", TmUi.glass("tm_list_focus"))
	var cells := HBoxContainer.new()
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = 18
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cells)
	row.mouse_entered.connect(row.grab_focus)
	return row


## A list row's cell: one line, dark on the row's light grey.
func _cell(text: String, colour: Color) -> Label:
	var l := TmUi.label(text, 21, colour, TmUi.SANS)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


var track_rows := {}                ## path -> the row's button (editors page)
var track_selected := ""
const TRACK_COLUMNS := [["Track", 420], ["Medals", 300], ["Blocks", 130], ["Changed", 230]]


## The local time's offset from UTC in seconds (file times are UTC; the lists show local time).
static func _utc_bias_s() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## The tracks you made (TmUserTracks.list, newest first): New Track (a row of the column) opens the
## editor on a blank one; a row selects, a second press (or Edit) edits it, Play races it, Delete
## asks twice.
func _page_editors() -> void:
	var root := _root("Editors", "Choose a track", "icon_editors")
	var fresh := _row("New Track", "icon_editors", func() -> void: edit(""))
	_row("Back", "icon_back", back, true)
	track_rows.clear()
	var col := _panel(root, "Your Tracks", RIGHT)
	var tip := TmUi.label("TMNF's Stadium blocks on its grid. Drive a track to the finish in the editor to validate it.", 19, TmUi.DIM, TmUi.SANS)
	col.add_child(tip)
	col.add_child(_columns(TRACK_COLUMNS))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1130, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true      # keyboard and pad focus scroll the list
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var all := TmUserTracks.list()
	if all.is_empty():
		rows.add_child(TmUi.label("No tracks yet: New Track opens the editor.", 21, TmUi.DIM, TmUi.SANS))
	var group := ButtonGroup.new()
	for e: Dictionary in all:
		var t: Dictionary = e["track"]
		var p := String(e["path"])
		var row := _list_row(group, 1110)
		var m: Dictionary = t.get("medals", {})
		var ok := TmUserTracks.is_validated(t)
		var medal_text := ("Author %s" % TmRace.time_text(int(m["author"]))) if ok else "Not validated"
		var texts := [String(t.get("name", "")), medal_text, str((t.get("blocks", []) as Array).size()),
			Time.get_datetime_string_from_unix_time(int(e["time"]) + _utc_bias_s(), true).left(16)]
		for i in TRACK_COLUMNS.size():
			var colour := TmUi.TM_INK
			if i == 1:
				colour = TmUi.TM_GREEN.darkened(0.25) if ok else Color(TmUi.TM_INK, 0.55)
			var l := _cell(String(texts[i]), colour)
			l.custom_minimum_size.x = int(TRACK_COLUMNS[i][1])
			row.get_child(0).add_child(l)
		row.pressed.connect(func() -> void:
			TmUi.play("click")
			if track_selected == p:
				edit(p)
			track_selected = p
			_disarm())
		rows.add_child(row)
		track_rows[p] = row
	if not all.is_empty() and not track_rows.has(track_selected):
		track_selected = String(all[0]["path"])
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var ed := TmUi.tm_button("Edit", func() -> void:
		if not track_selected.is_empty():
			edit(track_selected), 220)
	var note := TmUi.label("", 20, TmUi.DIM, TmUi.SANS)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var play := TmUi.tm_button("Play", func() -> void:
		if track_selected.is_empty():
			return
		var lack := TmEditorModel.new(TmUserTracks.load_file(track_selected)).missing()
		if not lack.is_empty():
			note.text = lack + " in the editor first"
			return
		race("", track_selected), 220)
	var del := TmUi.tm_button("Delete", Callable(), 220)
	_del_btn = del
	del.pressed.connect(func() -> void:
		if _arm(del, track_selected, String(TmUserTracks.load_file(track_selected).get("name", ""))):
			return
		DirAccess.remove_absolute(track_selected)
		track_selected = ""
		show_page("editors"))
	for b: Button in [ed, play, del]:
		b.disabled = all.is_empty()
		buttons.add_child(b)
	col.add_child(note)
	if track_rows.has(track_selected):
		var sel: Button = track_rows[track_selected]
		sel.button_pressed = true
		sel.grab_focus.call_deferred()
	else:
		fresh.grab_focus.call_deferred()


var _del_btn: Button                ## the page's DELETE (re-armed when the selection changes)


## DELETE asks first, naming what it deletes: true while it is only asking (the first press, or
## the selection changed since).
func _arm(del: Button, path: String, what: String) -> bool:
	if path.is_empty():
		return true
	if String(del.get_meta("armed", "")) == path:
		return false
	del.set_meta("armed", path)
	del.text = "Delete %s?" % (what if not what.is_empty() else path.get_file()).left(18)
	return true


func _disarm() -> void:
	if is_instance_valid(_del_btn):
		_del_btn.remove_meta("armed")
		_del_btn.text = "Delete"


## Opens the track editor on a track file ("" a new track).
func edit(track_file: String) -> void:
	TestHooks.args.erase("edit")
	if not track_file.is_empty():
		TestHooks.args["edit"] = track_file
	edited.emit(track_file)
	if TestHooks.arg("menu_dry", false):
		return
	get_tree().change_scene_to_file("res://editor/editor.tscn")


## Watches a replay (race/replay.tscn; Esc there comes back to this page).
func watch(path: String) -> void:
	TestHooks.args["replay"] = path
	TestHooks.args["replay_back"] = "menu"
	TestHooks.args.erase("replay_at")
	watched.emit(path)
	if TestHooks.arg("menu_dry", false):
		return
	TmLoading.change_scene(get_tree(), "res://race/replay.tscn")


## The track's online records under its details (the world record, yours), when the master answers.
func _online_records(track: String, ch: TmChallenge) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	_detail.add_child(line)
	var r: Dictionary = await Master.records(ch.uid, String(TmUi.setting("zone")))
	if not is_instance_valid(line) or selected != track or r.is_empty():
		return
	var top: Array = r.get("top", [])
	line.add_child(TmUi.label("World record", 20, TmUi.DIM, TmUi.SANS))
	if top.is_empty():
		line.add_child(TmUi.label("none yet", 20, TmUi.DIM, TmUi.SANS))
		return
	line.add_child(TmUi.label(TmRace.time_text(int(top[0]["time"])), 21, TmUi.TM_GREEN, TmUi.SANS_BOLD))
	line.add_child(TmUi.nick_label(String(top[0].get("nickname", "")), 20))
	var mine: Variant = r.get("mine")
	if mine is Dictionary:
		line.add_child(TmUi.label("   You: #%d of %d" % [int(mine["rank"]), int(r.get("count", 0))], 20, TmUi.TEXT, TmUi.SANS))


func _page_options() -> void:
	_clear_armed = false          # a first press on an earlier visit doesn't count
	var root := _root("Options", "Set up the game", "icon_options")
	_row("Back", "icon_back", back, true)
	var col := _panel(root, "Options", Rect2(RIGHT.position, Vector2(640, 0)))
	for opt: Array in [["fullscreen", "Fullscreen"], ["hd", "HD textures and shading"], ["shadows", "Shadows"], ["sound", "Sound"], ["music", "Music"], ["ghost", "Race against your best ghost"]]:
		var c := CheckButton.new()
		c.text = String(opt[1])
		c.button_pressed = bool(TmUi.setting(opt[0]))
		c.custom_minimum_size = Vector2(590, 46)
		var key: String = opt[0]
		c.toggled.connect(func(on: bool) -> void: TmUi.set_setting(key, on))
		c.mouse_entered.connect(c.grab_focus)
		col.add_child(c)
	var vol := HBoxContainer.new()
	vol.add_child(TmUi.label("Music volume  ", 22, TmUi.TEXT, TmUi.SANS))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(TmUi.setting("music_volume"))
	slider.custom_minimum_size = Vector2(380, 40)
	slider.value_changed.connect(func(v: float) -> void: TmUi.set_setting("music_volume", v))
	vol.add_child(slider)
	col.add_child(vol)
	col.add_child(_cycle("Graphics", "quality", TmRtx.QUALITY_NAMES))
	if TmRtx.is_fork():   # NVIDIA's RTX build of Godot
		col.add_child(_cycle("DLSS", "dlss", TmRtx.DLSS_NAMES))
		var pt := CheckButton.new()
		pt.text = "Path tracing (experimental, RTX 40/50)"
		pt.button_pressed = bool(TmUi.setting("path_tracing"))
		pt.custom_minimum_size = Vector2(590, 46)
		pt.toggled.connect(func(on: bool) -> void: TmUi.set_setting("path_tracing", on))
		col.add_child(pt)
		col.add_child(TmUi.label(TmRtx.status(), 18, TmUi.DIM, TmUi.SANS))
	var clear := TmUi.tm_button("Clear all records", Callable(), 590)
	clear.pressed.connect(func() -> void:
		if _clear_armed:
			TmRecords.clear()
			clear.text = "Records cleared"
			_clear_armed = false
		else:
			clear.text = "Press again to clear all records"
			_clear_armed = true)
	col.add_child(clear)
	(col.get_child(0) as Control).grab_focus.call_deferred()


## Your profile: the nickname with TMNF's $-codes (previewed as you type), your zone, your car's
## colour (our car on the field behind, turning to show it) and your medals.
func _page_profile() -> void:
	var root := _root("Profile", "Who you are", "icon_profile")
	_row("Back", "icon_back", back, true)
	var col := _panel(root, "Player", Rect2(RIGHT.position, Vector2(640, 0)))
	col.add_child(TmUi.label("Nickname", 20, TmUi.DIM, TmUi.SANS_BOLD))
	var preview := TmUi.nick_label(String(TmUi.setting("name")), 36)
	var edit := LineEdit.new()
	edit.text = String(TmUi.setting("name"))
	edit.max_length = TmNick.MAX_LENGTH
	edit.custom_minimum_size = Vector2(590, 46)
	edit.text_changed.connect(func(t: String) -> void:
		TmUi.set_setting("name", t.strip_edges())
		_profile_changed = true
		preview.text = TmNick.to_bbcode(t.strip_edges(), TmUi.TEXT))
	col.add_child(edit)
	col.add_child(preview)
	col.add_child(TmUi.label("$f00 colour (3 hex digits)    $o bold    $i italic    $w wide    $n narrow\n$s shadow    $t capitals    $g default colour    $z reset    $$ a dollar",
		17, TmUi.DIM, TmUi.SANS))
	col.add_child(HSeparator.new())
	col.add_child(TmUi.label("Zone", 20, TmUi.DIM, TmUi.SANS_BOLD))
	var zone := _zone_picker()
	col.add_child(zone)
	col.add_child(HSeparator.new())
	col.add_child(TmUi.label("Car colour", 20, TmUi.DIM, TmUi.SANS_BOLD))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 10)
	col.add_child(swatches)
	for i in TmUi.CAR_COLOURS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		var chosen := i == int(TmUi.setting("colour"))
		var c: Color = TmUi.CAR_COLOURS[i]
		var st := TmGlassBox.make({"top": c.lightened(0.2), "bottom": c.darkened(0.3), "gloss": 0.35, "radius": 23.0,
			"border": Color.WHITE if chosen else Color(0.6, 0.62, 0.6), "border_top": Color.WHITE, "border_width": 3.0 if chosen else 1.5,
			"glow": Color(TmUi.TM_GREEN, 0.9) if chosen else Color(0, 0, 0, 0), "glow_size": 6.0})
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_stylebox_override("focus", TmUi.glass("tm_button_focus"))
		b.pressed.connect(func() -> void:
			TmUi.set_setting("colour", i)
			_paint_car()
			_profile_focus = str(i)
			show_page("profile"))
		swatches.add_child(b)
	_medal_summary_panel(root, Rect2(RIGHT.position.x, 0, 640, 0))
	# after a pick (the page is rebuilt) the focus stays on what was picked
	var focus: Control = edit
	if _profile_focus == "zone":
		focus = zone
	elif _profile_focus.is_valid_int() and int(_profile_focus) < swatches.get_child_count():
		focus = swatches.get_child(int(_profile_focus)) as Control
	_profile_focus = ""
	focus.grab_focus.call_deferred()


## Your medals in a panel at the column's foot (the profile).
func _medal_summary_panel(root: Control, rect: Rect2) -> void:
	var body := _panel(root, "Your Campaign", rect)
	body.add_child(_medal_summary())
	var p := body.get_parent().get_parent().get_parent() as Control
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = rect.position.x
	p.offset_bottom = -COLUMN.position.y


## The zone: World, or a country (data/zones.json, by continent), stored as "Continent|Country".
func _zone_picker() -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(590, 48)
	pick.add_item("World")
	pick.set_item_metadata(0, "")
	var zones: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones.json"))
	var current := String(TmUi.setting("zone"))
	if zones is Dictionary:
		var continents: Array = (zones as Dictionary).keys()
		continents.sort()
		for cont: String in continents:
			pick.add_separator(cont)
			for country: String in zones[cont]:
				var path := "%s|%s" % [cont, country]
				pick.add_item(country)
				pick.set_item_metadata(pick.item_count - 1, path)
				if path == current:
					pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		var path: Variant = pick.get_item_metadata(i)
		TmUi.set_setting("zone", path if path is String else "")
		_profile_changed = true
		_profile_focus = "zone"
		show_page("profile"))
	return pick


var _online_status: Label
var _online_tab := 0                ## 0 servers, 1 rankings (--online_tab=1: screenshots)
var _rank_zone := false             ## rankings: false the world, true your zone
var server_rows: Array = []         ## the listed servers' rows (tests)
var server_selected := ""           ## the picked server's address (a row's first press; JOIN, SPECTATE)
const SERVER_COLUMNS := [["Server", 230], ["Mode", 100], ["Track", 190], ["Players", 90]]
const RANK_COLUMNS := [["#", 50], ["Player", 260], ["Zone", 220], ["Ladder", 100]]


## TMNF's online page: the servers (from the master: name, mode, track, players; Join) or the
## rankings (the world's or your zone's) as rows of the column, the list in a panel beside it with
## joining by address, your account (log in or register; ladder points and ranks) at the right.
func _page_online() -> void:
	var root := _root("Play Online", "Choose a server", "icon_online")
	var tabs: Array[Button] = []
	for i in 2:
		tabs.append(_row(["Servers", "Rankings"][i], ["icon_online", "star"][i], func() -> void:
			_online_tab = i
			show_page("online"), false, i == _online_tab))
	_row("Back", "icon_back", back, true)
	var col := _panel(root, ["Servers", "Rankings"][_online_tab], Rect2(RIGHT.position, Vector2(700, 0)))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.custom_minimum_size = Vector2(0, 430)
	col.add_child(body)
	if _online_tab == 0:
		_servers_tab(body)
	else:
		_rankings_tab(body)
	col.add_child(HSeparator.new())
	col.add_child(TmUi.label("Join by address", 20, TmUi.DIM, TmUi.SANS_BOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var addr := LineEdit.new()
	addr.text = String(TmUi.setting("server"))
	addr.placeholder_text = "IP:port or https://address"
	addr.custom_minimum_size = Vector2(430, 44)
	row.add_child(addr)
	row.add_child(TmUi.tm_button("Connect", func() -> void:
		TmUi.set_setting("server", addr.text.strip_edges())
		_connect(addr.text.strip_edges()), 200))
	_online_status = TmUi.label("", 20, TmUi.DIM, TmUi.SANS)
	col.add_child(_online_status)
	var acc := _panel(root, "Your Account", Rect2(1124, TOP, 456, 0))
	_account_panel(acc)
	tabs[_online_tab].grab_focus.call_deferred()


func _account_panel(acc: VBoxContainer) -> void:
	acc.add_theme_constant_override("separation", 10)
	if Master.logged_in():
		var a := Master.account
		acc.add_child(TmUi.nick_label(String(a.get("nickname", TmUi.setting("name"))), 32))
		var zone := String(a.get("zone", "World"))
		acc.add_child(TmUi.label("%s   ·   %s" % [String(a.get("login", "")), zone.replace("|", "  ·  ")], 19, TmUi.DIM, TmUi.SANS))
		var lad := HBoxContainer.new()
		lad.add_theme_constant_override("separation", 12)
		lad.add_child(_icon("star", 40))
		lad.add_child(TmUi.label("%d ladder points" % int(a.get("ladder", 0)), 25, TmUi.TM_GREEN, TmUi.SANS_BOLD))
		acc.add_child(lad)
		var r := Master.ranks
		if not r.is_empty():
			acc.add_child(TmUi.label("World  #%d of %d\nZone  #%d" % [int(r.get("world", 0)), int(r.get("players", 0)), int(r.get("zone", 0))],
				22, TmUi.TEXT, TmUi.SANS))
		acc.add_child(TmUi.label("Your nickname and zone come from Profile.", 18, TmUi.DIM, TmUi.SANS))
		acc.add_child(TmUi.tm_button("Log out", func() -> void:
			await Master.log_out()
			if page == "online":
				show_page("online"), 220))
		if (a.is_empty() or r.is_empty()) and not _account_asked:
			_account_asked = true
			_refresh_account()
		return
	var intro := TmUi.label("Log in to climb the ladder and keep online records. Or just join a server as a guest.", 19, TmUi.DIM, TmUi.SANS)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 410
	acc.add_child(intro)
	var login := LineEdit.new()
	login.placeholder_text = "login"
	login.max_length = 20
	login.custom_minimum_size = Vector2(410, 44)
	acc.add_child(login)
	var pw := LineEdit.new()
	pw.placeholder_text = "password (8 characters or more)"
	pw.secret = true
	pw.max_length = 200
	pw.custom_minimum_size = Vector2(410, 44)
	acc.add_child(pw)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	acc.add_child(row)
	var note := TmUi.label("New here? Register uses your Profile's nickname and zone.", 18, TmUi.DIM, TmUi.SANS)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 410
	var go := func(register: bool) -> void:
		note.text = "Registering..." if register else "Logging in..."
		var why := ""
		if register:
			why = await Master.register(login.text.strip_edges(), pw.text)
		else:
			why = await Master.log_in(login.text.strip_edges(), pw.text)
		if why.is_empty():
			if page == "online":
				show_page("online")
		elif is_instance_valid(note):
			note.text = why
	row.add_child(TmUi.tm_button("Log in", func() -> void: go.call(false), 200))
	row.add_child(TmUi.tm_button("Register", func() -> void: go.call(true), 200))
	pw.text_submitted.connect(func(_t: String) -> void: go.call(false))
	acc.add_child(note)


## Asks the master for the account (once per visit to the page); rebuilds the page with it, or
## with the log-in form when the master no longer knows the token.
func _refresh_account() -> void:
	var why := await Master.refresh()
	if (why.is_empty() or not Master.logged_in()) and page == "online":
		show_page("online")


func _servers_tab(body: VBoxContainer) -> void:
	server_rows.clear()
	body.add_child(_columns(SERVER_COLUMNS))
	var wait := TmUi.label("Looking for servers...", 20, TmUi.DIM, TmUi.SANS)
	body.add_child(wait)
	var list: Array = await Master.servers()
	if not is_instance_valid(wait):
		return
	wait.text = "" if not list.is_empty() else "No servers are online right now (join one by its address below)"
	var scroll := ScrollContainer.new()     # many servers scroll instead of pushing the page down
	scroll.custom_minimum_size = Vector2(660, mini(list.size(), 6) * 49)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	scroll.add_child(rows)
	var group := ButtonGroup.new()
	for s: Dictionary in list:
		var row := _list_row(group, 650)
		var trk := String(s.get("track", ""))
		var trk_name := ("%s  %s" % [trk, header(trk).name]) if TmTracks.has(trk) else trk
		var texts := [String(s.get("name", "")), String(s.get("mode", "")), trk_name,
			"%d / %d" % [int(s.get("players", 0)), int(s.get("max", 0))]]
		for i in SERVER_COLUMNS.size():
			var green: bool = i == 1 or (i == 0 and bool(s.get("official", false)))
			var l := _cell(texts[i], TmUi.TM_GREEN.darkened(0.25) if green else TmUi.TM_INK)
			l.custom_minimum_size.x = int(SERVER_COLUMNS[i][1])
			row.get_child(0).add_child(l)
		var address := String(s.get("address", ""))
		row.button_pressed = address == server_selected
		row.pressed.connect(func() -> void:
			if server_selected == address:
				_connect(address)            # a second press joins
			server_selected = address)
		rows.add_child(row)
		server_rows.append(row)
	if not server_rows.is_empty():
		if not list.any(func(x: Dictionary) -> bool: return String(x.get("address", "")) == server_selected):
			server_selected = String(list[0].get("address", ""))
			(server_rows[0] as Button).button_pressed = true
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_child(buttons)
		buttons.add_child(TmUi.tm_button("Join", func() -> void: _connect(server_selected), 220))
		buttons.add_child(TmUi.tm_button("Spectate", func() -> void: _connect(server_selected, true), 220))


func _rankings_tab(body: VBoxContainer) -> void:
	var mine := String(Master.account.get("zone", TmUi.setting("zone")))
	var zone := mine if _rank_zone and not mine.is_empty() else "World"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	for z: Array in [["World", false], ["My zone", true]]:
		var b := TmUi.tm_button(String(z[0]), func() -> void:
			_rank_zone = bool(z[1])
			show_page("online"), 160)
		if bool(z[1]) == _rank_zone:
			b.add_theme_stylebox_override("normal", TmUi.glass("tm_list_chosen"))
			b.add_theme_color_override("font_color", TmUi.TM_GREEN.darkened(0.15))
		row.add_child(b)
	row.add_child(TmUi.label("  " + zone.replace("|", "  ·  "), 20, TmUi.DIM, TmUi.SANS))
	body.add_child(_columns(RANK_COLUMNS))
	var wait := TmUi.label("Loading...", 20, TmUi.DIM, TmUi.SANS)
	body.add_child(wait)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true      # keyboard and pad focus scroll the list
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	var r: Dictionary = await Master.rankings(zone)
	if not is_instance_valid(wait):
		return
	var players: Array = r.get("players", [])
	wait.text = "" if not players.is_empty() else ("Nobody ranked here yet" if not r.is_empty() else "The master server isn't reachable")
	for p: Dictionary in players:
		var line := HBoxContainer.new()
		var pad := Control.new()
		pad.custom_minimum_size.x = 18
		line.add_child(pad)
		var me := String(p.get("login", "")) == String(Master.account.get("login", "-"))
		var cells: Array[Control] = [TmUi.label("%d" % int(p.get("rank", 0)), 21, TmUi.TM_GREEN if me else TmUi.DIM, TmUi.SANS_BOLD),
			TmUi.nick_label(String(p.get("nickname", "")), 21), TmUi.label(String(p.get("zone", "")).replace("|", " · "), 19, TmUi.DIM, TmUi.SANS),
			TmUi.label("%d" % int(p.get("ladder", 0)), 21, TmUi.TM_GREEN if me else TmUi.TEXT, TmUi.SANS_BOLD)]
		for i in cells.size():
			cells[i].custom_minimum_size.x = int(RANK_COLUMNS[i][1])
			line.add_child(cells[i])
		rows.add_child(line)


func _connect(address: String, spectator := false) -> void:
	if address.is_empty():
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
	Online.join(address, who if not who.is_empty() else "Player", TmUi.car_colour(), Master.token(), spectator)


## In the server: race its round's track.
func _joined() -> void:
	race(String(Online.round.get("track", tracks[0] if not tracks.is_empty() else "")))


## A button that steps through a setting's values (an index into names).
func _cycle(title: String, key: String, names: Array) -> Button:
	var b := TmUi.tm_button("", Callable(), 590)
	var show := func() -> void: b.text = "%s:  %s" % [title, String(names[clampi(int(TmUi.setting(key)), 0, names.size() - 1)])]
	show.call()
	b.pressed.connect(func() -> void:
		TmUi.set_setting(key, (int(TmUi.setting(key)) + 1) % names.size())
		show.call())
	return b


func _open_file() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.Gbx, *.sftrack ; Tracks (TrackMania, SpeedFest)"])
	fd.use_native_dialog = true
	fd.file_selected.connect(func(path: String) -> void: race("", path))
	_layer.add_child(fd)
	fd.popup_centered_ratio(0.7)


## Starts a race: a campaign track, or a track file (map).
func race(track: String, map := "") -> void:
	TestHooks.args.erase("map")
	TestHooks.args.erase("track")
	TestHooks.args.erase("back")      # a race from the menu, not a test drive from the editor
	TestHooks.args["return_page"] = page if page != "main" else "solo"   # the race's MENU comes back here
	if not map.is_empty():
		TestHooks.args["map"] = map
	else:
		TestHooks.args["track"] = track
	raced.emit(track, map)
	if TestHooks.arg("menu_dry", false):
		return
	TmLoading.change_scene(get_tree(), "res://race/race.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and page != "main":
		back()
		get_viewport().set_input_as_handled()
