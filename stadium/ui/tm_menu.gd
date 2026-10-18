class_name TmMenu
extends Node3D
## The remake's menus (the project's main scene), laid out like TMNF's: the Stadium behind, out of
## focus, our car on the field with the camera slowly circling it; a bar across the top with our
## logo, where you are and your nickname; the pages in glass:
## - main: Solo, Online, Editors, Profile, Options, Quit;
## - solo: Campaign, Replays, Open a track file (any .Challenge.Gbx or .sftrack);
## - editors: the tracks you made (TmUserTracks) with New track, Edit (editor/editor.tscn), Play,
##   Delete;
## - replays: the replays kept (saved ones and your best run on each track), Watch, Delete;
## - campaign: the series' tabs (TmTracks.series), a card per track (its map, best time, medal),
##   the selected track's details (medal times, your best) and Race;
## - online: the server list (the official server, published in the repo) and joining by address;
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
const PAGES := {"main": "", "solo": "main", "campaign": "solo", "replays": "solo", "editors": "main", "online": "main", "profile": "main",
	"options": "main"}
const TITLES := {"main": [], "solo": ["SOLO"], "campaign": ["SOLO", "CAMPAIGN"], "replays": ["SOLO", "REPLAYS"], "editors": ["EDITORS"],
	"online": ["ONLINE"],
	"profile": ["PROFILE"], "options": ["OPTIONS"]}
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
var _grade: ColorRect


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
	tracks = TmTracks.ids()
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
	add_child(TmStadiumBuild.build())
	var field := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024, 1024)
	field.mesh = pm
	field.material_override = TmMaterials.get_material("grass")
	field.position = CENTRE
	add_child(field)
	_car_holder = Node3D.new()
	_car_holder.position = CENTRE + Vector3(0.0, 0.441, 0.0)
	_car_holder.rotation.y = 0.5
	add_child(_car_holder)
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
	_cam.position -= _cam.basis.x * lerpf(2.4, 1.9, v)   # the car off-centre, right of the menu column


func _process(delta: float) -> void:
	_orbit(delta)


func _clear() -> void:
	for c in _layer.get_children():
		if c != _grade:
			c.queue_free()
	_tiles.clear()
	_detail = null


## A page's frame: the bar across the top (logo, where you are, your nickname and zone), the key
## hints along the bottom. Returns the page's root.
func _root() -> Control:
	var root := Control.new()
	root.theme = TmUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", TmUi.glass("bar"))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 96)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var line := ColorRect.new()
	line.color = Color(TmUi.ACCENT, 0.7)
	line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	line.position.y = 96
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)
	var logo := TextureRect.new()
	logo.texture = TmUi.icon("logo")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.position = Vector2(34, 8)
	logo.size = Vector2(320, 80)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	var crumbs: Array = TITLES.get(page, [])
	if not crumbs.is_empty():
		var where := TmUi.label("  /  ".join(PackedStringArray(crumbs)), 24, TmUi.ACCENT, TmUi.HEAD, 3)
		where.position = Vector2(390, 30)
		root.add_child(where)
	# you, at the right: nickname, zone
	var me := VBoxContainer.new()
	me.anchor_left = 1.0
	me.anchor_right = 1.0
	me.offset_left = -640
	me.offset_right = -40
	me.offset_top = 14
	me.add_theme_constant_override("separation", 0)
	me.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(me)
	var nick := TmUi.nick_label(String(TmUi.setting("name")), 28)
	nick.size_flags_horizontal = Control.SIZE_SHRINK_END
	me.add_child(nick)
	var zone := String(TmUi.setting("zone"))
	var zl := TmUi.label((zone.replace("|", "  ·  ") if not zone.is_empty() else "World").to_upper(), 16, TmUi.DIM, TmUi.BOLD, 2)
	zl.size_flags_horizontal = Control.SIZE_SHRINK_END
	me.add_child(zl)
	var hint := TmUi.label("ARROWS / PAD  SELECT        ENTER  CONFIRM        ESC  BACK", 17, TmUi.DIM, TmUi.BOLD, 2)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	hint.position.x = 60
	root.add_child(hint)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	return root


func show_page(name: String) -> void:
	page = name if PAGES.has(name) else "main"
	_clear()
	(_grade.material as ShaderMaterial).set_shader_parameter("left_dark", 0.25 if page == "profile" else 0.55)
	match page:
		"solo":
			_page_solo()
		"campaign":
			_page_campaign()
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


func _column(root: Control, top := 200) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.position = Vector2(60, top)
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)
	return col


## A main menu entry: big, letter-spaced.
func _big(text: String, action: Callable) -> Button:
	var b := TmUi.button(text, action, 440)
	b.custom_minimum_size.y = 66
	b.add_theme_font_override("font", TmUi.font(TmUi.HEAD, 3))
	b.add_theme_font_size_override("font_size", 26)
	return b


func _back_button(width := 220) -> Button:
	return TmUi.button("BACK", back, width)


func _page_main() -> void:
	var root := _root()
	var col := _column(root, 200)
	var solo := _big("SOLO", func() -> void: show_page("solo"))
	col.add_child(solo)
	col.add_child(_big("ONLINE", func() -> void: show_page("online")))
	col.add_child(_big("EDITORS", func() -> void: show_page("editors")))
	col.add_child(_big("PROFILE", func() -> void: show_page("profile")))
	col.add_child(_big("OPTIONS", func() -> void: show_page("options")))
	col.add_child(_big("QUIT", func() -> void: get_tree().quit()))
	solo.grab_focus.call_deferred()


func _page_solo() -> void:
	var root := _root()
	var col := _column(root, 200)
	var camp := _big("CAMPAIGN", func() -> void: show_page("campaign"))
	col.add_child(camp)
	col.add_child(_big("REPLAYS", func() -> void: show_page("replays")))
	col.add_child(_big("OPEN A TRACK FILE", _open_file))
	col.add_child(_back_button(440))
	# your progress, under the entries
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 600)
	panel.custom_minimum_size = Vector2(440, 0)
	root.add_child(panel)
	panel.add_child(_medal_summary())
	camp.grab_focus.call_deferred()


## Your medals over the campaign: a row per kind (icon, name, count) and how many you finished.
func _medal_summary() -> VBoxContainer:
	var counts := medal_counts()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(TmUi.label("YOUR CAMPAIGN", 18, TmUi.DIM, TmUi.HEAD, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for m: String in MEDALS:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(_icon("medal_" + m, 34))
		cell.add_child(TmUi.label(str(counts[m]), 28, TmUi.TEXT, TmUi.BOLD))
		row.add_child(cell)
	box.add_child(TmUi.label("%d of %d tracks finished" % [counts["finished"], tracks.size()], 20, TmUi.DIM, TmUi.BOLD))
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


## A series' colour: TMNF's for White..Black, our accent for the others.
static func series_colour(series_name: String) -> Color:
	for s: Array in TmUi.SERIES:
		if String(s[1]).to_lower() == series_name.to_lower():
			return s[2]
	return TmUi.ACCENT


func _page_campaign() -> void:
	var root := _root()
	var all := TmTracks.series()
	series = clampi(series, 0, maxi(all.size() - 1, 0))
	# the series' tabs
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(60, 124)
	tabs.add_theme_constant_override("separation", 6)
	root.add_child(tabs)
	var group := ButtonGroup.new()
	for i in all.size():
		var sname := String(all[i]["name"])
		var c := series_colour(sname)
		var b := TmUi.button(sname.to_upper(), Callable(), 170)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == series
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size.y = 50
		b.add_theme_font_override("font", TmUi.font(TmUi.HEAD, 2))
		b.add_theme_font_size_override("font_size", 18)
		var dark := c.v < 0.3
		var on := TmGlassBox.make({"top": c.lightened(0.15), "bottom": c.darkened(0.35), "gloss": 0.3, "radius": 8.0, "corners": 3,
			"border": c.lightened(0.3), "border_top": Color(1, 1, 1, 0.8)})
		var off := TmGlassBox.make({"top": Color(c.darkened(0.5), 0.75), "bottom": Color(c.darkened(0.8), 0.85), "gloss": 0.1,
			"radius": 8.0, "corners": 3, "border": Color(c, 0.4), "border_top": Color(c.lightened(0.3), 0.6)})
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		var ink := Color(0.03, 0.04, 0.03) if not dark else Color.WHITE
		b.add_theme_color_override("font_pressed_color", ink)
		b.add_theme_color_override("font_hover_pressed_color", ink)
		b.pressed.connect(func() -> void:
			series = i
			var first: Array = all[i]["tracks"]
			if not first.is_empty() and not first.has(selected):
				selected = first[0]
			show_page("campaign"))
		tabs.add_child(b)
	var grid := GridContainer.new()
	grid.position = Vector2(60, 186)
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	var focus: Button = null
	var ids: Array = all[series]["tracks"] if not all.is_empty() else []
	for t: String in ids:
		var card := _card(t)
		grid.add_child(card)
		_tiles[t] = card
		if t == selected:
			focus = card
	var back := _back_button()
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 64)
	back.position.x = 60
	back.position.y -= 24
	root.add_child(back)
	var panel := PanelContainer.new()
	panel.position = Vector2(60 + 5 * 178 + 40, 124)
	panel.custom_minimum_size = Vector2(540, 650)
	root.add_child(panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	panel.add_child(_detail)
	if not ids.is_empty():
		select(selected if _tiles.has(selected) else String(ids[0]), false)
	if focus:
		focus.grab_focus.call_deferred()


## A track's card: its map, its number and name, your best time and medal.
func _card(t: String) -> Button:
	var ch := header(t)
	var ms := int(TmRecords.best(ch).get("time_ms", -1))
	var m := TmRace.medal(ms, ch)
	var card := Button.new()
	card.custom_minimum_size = Vector2(168, 162)
	card.tooltip_text = ch.name
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var map := TmTrackMap.new(ch)
	map.custom_minimum_size = Vector2(152, 78)
	map.line_width = 2.0
	box.add_child(map)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var id_l := TmUi.label(t, 22, TmUi.ACCENT, TmUi.BOLD, 2)
	id_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(id_l)
	row.add_child(_icon("medal_" + (m if not m.is_empty() else "none"), 24))
	var name_l := TmUi.label(ch.name, 18, TmUi.TEXT, TmUi.BOLD)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size.x = 150
	name_l.clip_text = true
	box.add_child(name_l)
	box.add_child(TmUi.label(TmRace.time_text(ms) if ms >= 0 else "--:--.--", 16, TmUi.TEXT if ms >= 0 else TmUi.DIM, TmUi.HEAD))
	card.pressed.connect(func() -> void: select(t))
	card.pressed.connect(func() -> void: TmUi.play("click"))
	card.focus_entered.connect(func() -> void: select(t, false))
	card.mouse_entered.connect(card.grab_focus)
	return card


## Shows a track's details (and races it on a second press of its card).
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
	var all := TmTracks.series()
	var sname := String(all[series]["name"]).to_upper() if series < all.size() else ""
	_detail.add_child(TmUi.label("%s   ·   %s" % [track, sname], 22, TmUi.ACCENT, TmUi.BOLD, 3))
	_detail.add_child(TmUi.label(ch.name if ch.ok() else "(unreadable: %s)" % ch.error, 34, Color.WHITE, TmUi.HEAD))
	_detail.add_child(TmUi.label("by %s" % ch.author, 20, TmUi.DIM, TmUi.BOLD))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", TmUi.glass("field"))
	_detail.add_child(frame)
	var map := TmTrackMap.new(ch)
	map.custom_minimum_size = Vector2(480, 190)
	frame.add_child(map)
	for row: Array in [["author", "Author", ch.author_ms], ["gold", "Gold", ch.gold_ms], ["silver", "Silver", ch.silver_ms], ["bronze", "Bronze", ch.bronze_ms]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.add_child(_icon("medal_" + String(row[0]), 30))
		var l := TmUi.label(String(row[1]), 24, TmUi.TEXT, TmUi.BOLD, 1)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		line.add_child(TmUi.label(TmRace.time_text(int(row[2])), 24, TmRaceHud.MEDAL_COLOURS[row[0]], TmUi.HEAD))
		_detail.add_child(line)
	_detail.add_child(HSeparator.new())
	var mine := HBoxContainer.new()
	mine.add_theme_constant_override("separation", 12)
	mine.add_child(_icon("medal_" + (m if not m.is_empty() else "none"), 40))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(TmUi.label("YOUR BEST", 16, TmUi.DIM, TmUi.HEAD, 2))
	col.add_child(TmUi.label(("%s medal" % m.capitalize()) if not m.is_empty() else ("Not finished yet" if ms < 0 else "No medal yet"), 22,
		TmRaceHud.MEDAL_COLOURS[m] if not m.is_empty() else TmUi.DIM, TmUi.BOLD))
	mine.add_child(col)
	mine.add_child(TmUi.label(TmRace.time_text(ms), 30, Color.WHITE, TmUi.HEAD))
	_detail.add_child(mine)
	var go := TmUi.go(TmUi.button("RACE", func() -> void: race(track), 480))
	go.icon = TmUi.icon("play", 30)
	go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.custom_minimum_size.y = 64
	go.add_theme_font_override("font", TmUi.font(TmUi.HEAD, 4))
	_detail.add_child(go)


var replay_rows := {}               ## path -> the row's button (replays page)
var replay_selected := ""
const REPLAY_COLUMNS := [["TRACK", 330], ["TIME", 150], ["PLAYER", 330], ["DATE", 230]]


## The replays kept on this machine (TmReplay.list: saved ones and the autosaves of your best runs),
## newest first; a row selects, a second press (or WATCH) watches; DELETE asks twice.
func _page_replays() -> void:
	var root := _root()
	replay_rows.clear()
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 130)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var head := HBoxContainer.new()
	for c: Array in REPLAY_COLUMNS:
		var l := TmUi.label(String(c[0]), 16, TmUi.DIM, TmUi.BOLD, 2)
		l.custom_minimum_size.x = int(c[1])
		head.add_child(l)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1080, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var all := TmReplay.list()
	if all.is_empty():
		rows.add_child(TmUi.label("No replays yet. Finish a race and press SAVE REPLAY; your best run on each track is kept by itself.", 22, TmUi.DIM, TmUi.BOLD))
	var group := ButtonGroup.new()
	for e: Dictionary in all:
		var r: TmReplay = e["replay"]
		var path := String(e["path"])
		var row := Button.new()
		row.toggle_mode = true
		row.button_group = group
		row.custom_minimum_size = Vector2(1060, 52)
		row.add_theme_stylebox_override("pressed", TmUi.glass("hover"))
		row.add_theme_stylebox_override("hover_pressed", TmUi.glass("hover"))
		var cells := HBoxContainer.new()
		cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cells.offset_left = 18
		cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cells)
		var texts := [r.track_name + ("   BEST" if e["autosave"] else ""), TmRace.time_text(r.finish_ms), "", r.date.left(16)]
		for i in REPLAY_COLUMNS.size():
			var cell: Control
			if i == 2:
				cell = TmUi.nick_label(r.player, 22)
				cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			else:
				var l := TmUi.label(String(texts[i]), 22, TmUi.ACCENT if i == 1 else TmUi.TEXT, TmUi.BOLD)
				l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				l.size_flags_vertical = Control.SIZE_EXPAND_FILL
				l.clip_text = true
				cell = l
			cell.custom_minimum_size.x = int(REPLAY_COLUMNS[i][1])
			cells.add_child(cell)
		row.pressed.connect(func() -> void:
			TmUi.play("click")
			if replay_selected == path:
				watch(path)
			replay_selected = path)
		row.focus_entered.connect(func() -> void: replay_selected = path)
		row.mouse_entered.connect(row.grab_focus)
		rows.add_child(row)
		replay_rows[path] = row
	if not all.is_empty() and not replay_rows.has(replay_selected):
		replay_selected = String(all[0]["path"])
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var go := TmUi.go(TmUi.button("WATCH", func() -> void:
		if not replay_selected.is_empty():
			watch(replay_selected), 220))
	go.icon = TmUi.icon("play", 26)
	go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.disabled = all.is_empty()
	buttons.add_child(go)
	var del := TmUi.button("DELETE", Callable(), 220)
	del.alignment = HORIZONTAL_ALIGNMENT_CENTER
	del.disabled = all.is_empty()
	del.pressed.connect(func() -> void:
		if del.text == "DELETE":
			del.text = "PRESS AGAIN"
			return
		DirAccess.remove_absolute(replay_selected)
		replay_selected = ""
		show_page("replays"))
	buttons.add_child(del)
	buttons.add_child(_back_button())
	if replay_rows.has(replay_selected):
		var sel: Button = replay_rows[replay_selected]
		sel.button_pressed = true
		sel.grab_focus.call_deferred()
	else:
		go.grab_focus.call_deferred()


var track_rows := {}                ## path -> the row's button (editors page)
var track_selected := ""
const TRACK_COLUMNS := [["TRACK", 360], ["MEDALS", 300], ["BLOCKS", 130], ["CHANGED", 230]]


## The tracks you made (TmUserTracks.list, newest first): NEW TRACK opens the editor on a blank
## one; a row selects, a second press (or EDIT) edits it, PLAY races it, DELETE asks twice.
func _page_editors() -> void:
	var root := _root()
	track_rows.clear()
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 130)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var fresh := TmUi.go(TmUi.button("NEW TRACK", func() -> void: edit(""), 260))
	fresh.alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(fresh)
	top.add_child(TmUi.label("TRACK EDITOR: TMNF's Stadium blocks on its grid. Test a track to the finish to validate it.", 20, TmUi.DIM, TmUi.BOLD))
	var head := HBoxContainer.new()
	for c: Array in TRACK_COLUMNS:
		var l := TmUi.label(String(c[0]), 16, TmUi.DIM, TmUi.BOLD, 2)
		l.custom_minimum_size.x = int(c[1])
		head.add_child(l)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1080, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var all := TmUserTracks.list()
	if all.is_empty():
		rows.add_child(TmUi.label("No tracks yet: NEW TRACK opens the editor.", 22, TmUi.DIM, TmUi.BOLD))
	var group := ButtonGroup.new()
	for e: Dictionary in all:
		var t: Dictionary = e["track"]
		var p := String(e["path"])
		var row := Button.new()
		row.toggle_mode = true
		row.button_group = group
		row.custom_minimum_size = Vector2(1060, 52)
		row.add_theme_stylebox_override("pressed", TmUi.glass("hover"))
		row.add_theme_stylebox_override("hover_pressed", TmUi.glass("hover"))
		var cells := HBoxContainer.new()
		cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cells.offset_left = 18
		cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cells)
		var m: Dictionary = t.get("medals", {})
		var medal_text := ("AUTHOR %s" % TmRace.time_text(int(m["author"]))) if TmUserTracks.is_validated(t) else "not validated"
		var texts := [String(t.get("name", "")), medal_text, str((t.get("blocks", []) as Array).size()),
			Time.get_datetime_string_from_unix_time(int(e["time"]), true).left(16)]
		for i in TRACK_COLUMNS.size():
			var l := TmUi.label(String(texts[i]), 22, TmUi.ACCENT if i == 1 and TmUserTracks.is_validated(t) else (TmUi.DIM if i == 1 else TmUi.TEXT), TmUi.BOLD)
			l.custom_minimum_size.x = int(TRACK_COLUMNS[i][1])
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.size_flags_vertical = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			cells.add_child(l)
		row.pressed.connect(func() -> void:
			TmUi.play("click")
			if track_selected == p:
				edit(p)
			track_selected = p)
		row.focus_entered.connect(func() -> void: track_selected = p)
		row.mouse_entered.connect(row.grab_focus)
		rows.add_child(row)
		track_rows[p] = row
	if not all.is_empty() and not track_rows.has(track_selected):
		track_selected = String(all[0]["path"])
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var ed := TmUi.button("EDIT", func() -> void:
		if not track_selected.is_empty():
			edit(track_selected), 200)
	var play := TmUi.button("PLAY", func() -> void:
		if not track_selected.is_empty():
			race("", track_selected), 200)
	var del := TmUi.button("DELETE", Callable(), 200)
	del.pressed.connect(func() -> void:
		if del.text == "DELETE":
			del.text = "PRESS AGAIN"
			return
		DirAccess.remove_absolute(track_selected)
		track_selected = ""
		show_page("editors"))
	for b: Button in [ed, play, del]:
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.disabled = all.is_empty()
		buttons.add_child(b)
	buttons.add_child(_back_button())
	if track_rows.has(track_selected):
		var sel: Button = track_rows[track_selected]
		sel.button_pressed = true
		sel.grab_focus.call_deferred()
	else:
		fresh.grab_focus.call_deferred()


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
	get_tree().change_scene_to_file("res://race/replay.tscn")


func _page_options() -> void:
	var root := _root()
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 130)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	for opt: Array in [["fullscreen", "Fullscreen"], ["hd", "HD textures and shading"], ["shadows", "Shadows"], ["sound", "Sound"], ["music", "Music"], ["ghost", "Race against your best ghost"]]:
		var c := CheckButton.new()
		c.text = String(opt[1])
		c.button_pressed = bool(TmUi.setting(opt[0]))
		c.custom_minimum_size = Vector2(560, 52)
		var key: String = opt[0]
		c.toggled.connect(func(on: bool) -> void: TmUi.set_setting(key, on))
		c.mouse_entered.connect(c.grab_focus)
		col.add_child(c)
	var vol := HBoxContainer.new()
	vol.add_child(TmUi.label("MUSIC VOLUME  ", 22, TmUi.TEXT, TmUi.BOLD, 1))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(TmUi.setting("music_volume"))
	slider.custom_minimum_size = Vector2(340, 40)
	slider.value_changed.connect(func(v: float) -> void: TmUi.set_setting("music_volume", v))
	vol.add_child(slider)
	col.add_child(vol)
	col.add_child(_cycle("GRAPHICS", "quality", TmRtx.QUALITY_NAMES))
	if TmRtx.is_fork():   # NVIDIA's RTX build of Godot
		col.add_child(_cycle("DLSS", "dlss", TmRtx.DLSS_NAMES))
		var pt := CheckButton.new()
		pt.text = "Path tracing (experimental, RTX 40/50)"
		pt.button_pressed = bool(TmUi.setting("path_tracing"))
		pt.custom_minimum_size = Vector2(560, 52)
		pt.toggled.connect(func(on: bool) -> void: TmUi.set_setting("path_tracing", on))
		col.add_child(pt)
		col.add_child(TmUi.label(TmRtx.status(), 18, TmUi.DIM, TmUi.BOLD))
	var clear := TmUi.button("CLEAR ALL RECORDS", Callable(), 560)
	clear.pressed.connect(func() -> void:
		if _clear_armed:
			TmRecords.clear()
			clear.text = "RECORDS CLEARED"
			_clear_armed = false
		else:
			clear.text = "PRESS AGAIN TO CLEAR ALL RECORDS"
			_clear_armed = true)
	col.add_child(clear)
	col.add_child(_back_button())
	(col.get_child(0) as Control).grab_focus.call_deferred()


## Your profile: the nickname with TMNF's $-codes (previewed as you type), your zone, your car's
## colour (the car turns to show it) and your medals.
func _page_profile() -> void:
	var root := _root()
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 130)
	panel.custom_minimum_size = Vector2(640, 0)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(TmUi.label("NICKNAME", 18, TmUi.DIM, TmUi.HEAD, 2))
	var preview := TmUi.nick_label(String(TmUi.setting("name")), 38)
	var edit := LineEdit.new()
	edit.text = String(TmUi.setting("name"))
	edit.max_length = TmNick.MAX_LENGTH
	edit.custom_minimum_size = Vector2(590, 48)
	edit.text_changed.connect(func(t: String) -> void:
		TmUi.set_setting("name", t.strip_edges())
		preview.text = TmNick.to_bbcode(t.strip_edges(), TmUi.TEXT))
	col.add_child(edit)
	col.add_child(preview)
	col.add_child(TmUi.label("$f00 colour (3 hex digits)    $o bold    $i italic    $w wide    $n narrow\n$s shadow    $t capitals    $g default colour    $z reset    $$ a dollar",
		17, TmUi.DIM, TmUi.BOLD))
	col.add_child(HSeparator.new())
	col.add_child(TmUi.label("ZONE", 18, TmUi.DIM, TmUi.HEAD, 2))
	col.add_child(_zone_picker())
	col.add_child(HSeparator.new())
	col.add_child(TmUi.label("CAR COLOUR", 18, TmUi.DIM, TmUi.HEAD, 2))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 10)
	col.add_child(swatches)
	for i in TmUi.CAR_COLOURS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		var chosen := i == int(TmUi.setting("colour"))
		var c: Color = TmUi.CAR_COLOURS[i]
		var st := TmGlassBox.make({"top": c.lightened(0.2), "bottom": c.darkened(0.3), "gloss": 0.35, "radius": 23.0,
			"border": Color.WHITE if chosen else Color(0.6, 0.7, 0.65), "border_top": Color.WHITE, "border_width": 3.0 if chosen else 1.5,
			"glow": Color(TmUi.ACCENT, 0.9) if chosen else Color(0, 0, 0, 0), "glow_size": 6.0})
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.pressed.connect(func() -> void:
			TmUi.set_setting("colour", i)
			_paint_car()
			show_page("profile"))
		swatches.add_child(b)
	col.add_child(HSeparator.new())
	col.add_child(_medal_summary())
	col.add_child(_back_button())
	edit.grab_focus.call_deferred()


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
		show_page("profile"))
	return pick


var _online_status: Label
var _server_row: Button
var _server_cells: Array[Label] = []
var _official_url := ""
const SERVER_COLUMNS := [["SERVER", 330], ["TRACK", 330], ["PLAYERS", 130], ["TIME LEFT", 130]]


## The server list (today: the official server, published in the repo) and joining by address.
func _page_online() -> void:
	var root := _root()
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 130)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(TmUi.label("SERVERS", 18, TmUi.DIM, TmUi.HEAD, 2))
	var head := HBoxContainer.new()
	for c: Array in SERVER_COLUMNS:
		var l := TmUi.label(String(c[0]), 16, TmUi.DIM, TmUi.BOLD, 2)
		l.custom_minimum_size.x = int(c[1])
		head.add_child(l)
	col.add_child(head)
	_server_row = Button.new()
	_server_row.custom_minimum_size = Vector2(920, 54)
	_server_row.pressed.connect(func() -> void:
		if not _official_url.is_empty():
			_connect(_official_url))
	_server_row.mouse_entered.connect(_server_row.grab_focus)
	var cells := HBoxContainer.new()
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = 18
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_server_row.add_child(cells)
	_server_cells.clear()
	for c: Array in SERVER_COLUMNS:
		var l := TmUi.label("", 22, TmUi.TEXT, TmUi.BOLD)
		l.custom_minimum_size.x = int(c[1])
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		cells.add_child(l)
		_server_cells.append(l)
	_server_cells[0].text = "Looking for the official server..."
	col.add_child(_server_row)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var join := TmUi.go(TmUi.button("JOIN", func() -> void:
		if not _official_url.is_empty():
			_connect(_official_url), 220))
	join.alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(join)
	buttons.add_child(TmUi.button("REFRESH", func() -> void: show_page("online"), 220))
	col.add_child(HSeparator.new())
	col.add_child(TmUi.label("JOIN BY ADDRESS", 18, TmUi.DIM, TmUi.HEAD, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var addr := LineEdit.new()
	addr.text = String(TmUi.setting("server"))
	addr.placeholder_text = "IP:port or https://address"
	addr.custom_minimum_size = Vector2(560, 48)
	row.add_child(addr)
	row.add_child(TmUi.button("CONNECT", func() -> void:
		TmUi.set_setting("server", addr.text.strip_edges())
		_connect(addr.text.strip_edges()), 200))
	_online_status = TmUi.label("You race as your profile's nickname and car colour.", 20, TmUi.DIM, TmUi.BOLD)
	col.add_child(_online_status)
	col.add_child(_back_button())
	_server_row.grab_focus.call_deferred()
	_find_official()


## The official server's address (published in the repo), then its status.
func _find_official() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 8.0
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var d: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not (d is Dictionary) or String(d.get("url", "")).is_empty():
			_show_server(["The official server is offline right now (join by address below)", "", "", ""])
			return
		_official_url = String(d["url"])
		_server_status(_official_url))
	req.request(Online.OFFICIAL_LIST)


func _show_server(cells: Array) -> void:
	if _server_cells.is_empty() or not is_instance_valid(_server_cells[0]):
		return
	for i in mini(cells.size(), _server_cells.size()):
		_server_cells[i].text = String(cells[i])


func _server_status(address: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 8.0
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var d: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not (d is Dictionary):
			_show_server(["The official server isn't answering", "", "", ""])
			return
		var r: Dictionary = d.get("round", {})
		var left := maxi(0, int(float(r.get("end", 0)) - float(d.get("now", 0))))
		var trk := String(r.get("track", ""))
		var trk_name := trk
		if TmTracks.has(trk):
			trk_name = "%s  %s" % [trk, header(trk).name]
		_show_server([String(d.get("name", "")), trk_name, "%d / %d" % [int(d.get("players", 0)), int(d.get("maxPlayers", 0))],
			"%d:%02d" % [left / 60000, (left / 1000) % 60]]))
	req.request(Online.status_url(address))


func _connect(address: String) -> void:
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
	Online.join(address, who if not who.is_empty() else "Player", TmUi.car_colour())


## In the server: race its round's track.
func _joined() -> void:
	race(String(Online.round.get("track", tracks[0] if not tracks.is_empty() else "")))


## A button that steps through a setting's values (an index into names).
func _cycle(title: String, key: String, names: Array) -> Button:
	var b := TmUi.button("", Callable(), 560)
	var show := func() -> void: b.text = "%s:  %s" % [title, String(names[clampi(int(TmUi.setting(key)), 0, names.size() - 1)]).to_upper()]
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
		back()
		get_viewport().set_input_as_handled()
