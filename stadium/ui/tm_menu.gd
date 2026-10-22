class_name TmMenu
extends Node3D
## The game's menus (the project's main scene) in our own look (PLAN M16; SfUi: charcoal, a hint of
## red and violet, Montserrat): our header across the top (SfHeader: the wordmark, the tabs Home,
## Solo, Multiplayer, Story (locked), Community, Editor; you, options, quit), the backdrop's slow
## glows behind (sf_backdrop.gdshader). The home page is picture panels (SfTile, after RaceRoom's
## DRIVE page the owner pointed to); the other pages keep a column of entries down the left (the
## page's title above them, the current one marked red, Back at its foot) and panels beside it. The
## profile shows our car on the field instead of the backdrop. Pages:
## - main (home): Solo and Multiplayer large; Story (locked: Story mode is still to be built),
##   Community, Track editor and Replays; your campaign's medals along the foot;
## - solo (also "campaign"): the series down the left (White .. City), the series' tracks as cards
##   in a grid (a press races; the focused track's medal times and your best above the grid),
##   Replays, Browse (any .Challenge.Gbx or .sftrack), Back;
## - editors: the tracks you made (TmUserTracks) with New track, Edit (editor/editor.tscn), Play,
##   Delete;
## - replays: the replays kept (saved ones and your best run on each track), Watch, Delete;
## - online (Multiplayer): your account (log in, register; ladder points and ranks), the servers
##   (from the master: name, mode, track, players), the world's and your zone's rankings, joining
##   by address;
## - profile: your nickname (TMNF's $-codes, previewed), zone, car colour and medals;
## - options;
## - community: ManiaPark's cars and TrackMania Exchange's tracks by their previews: download, drive
##   a car (races, online, the profile), play a track (_page_community).
## Race starts race/race.tscn with the track in TestHooks' args.
## Args: --race=SF01 (straight into that track; exported builds can't be given a scene),
## --page=main|solo|campaign|replays|editors|online|profile|options|community (--community_tab=tracks),
## --track=SF01 (selected), --menu_dry (tests: Race only records the choice).

signal raced(track: String, map: String)
signal watched(replay: String)
signal edited(track_file: String)

const CENTRE := Vector3(-512.0, 9.0, 512.0)   ## the field's centre (Godot)
const PAGES := {"main": "", "solo": "main", "campaign": "main", "replays": "solo", "editors": "main", "online": "main", "profile": "main",
	"options": "main", "community": "main", "garage": "main", "tuning": "garage"}
const MEDALS := ["author", "gold", "silver", "bronze"]
## The profile's grade over the car on the field: dark behind the page's panels at the left.
const GRADE := """shader_type canvas_item;
uniform float left_dark = 0.55;
void fragment() {
	vec2 d = (UV - vec2(0.64, 0.56)) * vec2(1.5, 1.25);
	float v = smoothstep(0.3, 1.15, length(d));
	float left = smoothstep(0.62, 0.0, UV.x) * left_dark;
	float top = smoothstep(0.16, 0.0, UV.y) * 0.4;
	COLOR = vec4(0.03, 0.03, 0.045, clamp(0.16 + 0.62 * v + left + top, 0.0, 0.9));
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
var _backdrop: ColorRect           ## the glows on charcoal (every other page)
var _rows: VBoxContainer           ## the left column's entries
var _rows_bottom: VBoxContainer    ## its entries at the foot (Back, Quit)
var home_tiles := {}                ## the home page's panels by page ("solo", "online", "story", ...)
const COLUMN := Rect2(32, 100, 330, 768)  ## under the header (SfHeader, 76 px)
const TOP := 100.0                 ## the panels start under the header
const RIGHT := Rect2(390, 100, 1178, 0)  ## the right of the column, under the header
var nav: SfHeader                   ## the header: the tabs across the top; you, options, quit
const CARD := Vector2(220, 168)    ## a track's card on the Solo page (5 across)
const LOCKED_NOTE := "Story mode is on its way: it is one of the next steps."


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
	nav = SfHeader.new()
	nav.page_pressed.connect(show_page)
	nav.back_pressed.connect(back)
	nav.quit_pressed.connect(func() -> void: get_tree().quit())
	nav.locked_pressed.connect(func(_p: String) -> void: notice(LOCKED_NOTE))
	_layer.add_child(nav)
	tracks = TmTracks.ids()
	_online_tab = int(TestHooks.arg("online_tab", 0))
	selected = String(TestHooks.arg("track", tracks[0] if not tracks.is_empty() else ""))
	Music.toast(self, -12.0, true)   # along the bottom, under the pages' column
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


## The car on the profile's turntable: ours, or the community car we drive (TmCommunity).
func _paint_car(pack: TmCarPack = null) -> void:
	for c in _car_holder.get_children():
		c.queue_free()
	var look := TmCarVisual.new()
	look.paint_colour = TmUi.car_colour()
	look.model = TmUi.car_model()
	look.livery = TmUi.car_livery()
	look.tuning = TmUi.car_tuning()
	look.pack = pack if pack else TmCommunity.my_car_pack()
	_car_holder.add_child(look)


func _orbit(delta: float) -> void:
	_angle += delta * 0.12
	_view = move_toward(_view, 1.0 if page in ["profile", "garage", "tuning"] else 0.0, delta * 1.5)
	var v := smoothstep(0.0, 1.0, _view)
	var at := CENTRE + Vector3(0.0, 0.75 - 0.15 * v, 0.0)
	var dist := lerpf(7.0, 5.4, v)
	_cam.position = at + Vector3(cos(_angle) * dist, lerpf(0.55, 0.45, v), sin(_angle) * dist)
	_cam.look_at(at)
	_cam.position -= _cam.basis.x * lerpf(2.4, 2.9, v)   # the car off-centre, right of the profile's panel


func _process(delta: float) -> void:
	if _world.visible:
		_orbit(delta)
	if is_instance_valid(_comm_pivot):
		_comm_pivot.rotation.y += delta * 0.4     # the Community page's car turns


## The backdrop of every page but the profile: charcoal, a red glow from the bottom left and a violet
## one from the top right (ui/sf_backdrop.gdshader).
func _make_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://ui/sf_backdrop.gdshader")
	_backdrop.material = m
	_backdrop.resized.connect(func() -> void: m.set_shader_parameter("aspect", _backdrop.size.x / maxf(_backdrop.size.y, 1.0)))
	_layer.add_child(_backdrop)


func _clear() -> void:
	for c in _layer.get_children():
		if c != _grade and c != _backdrop and c != nav:
			c.queue_free()
	_tiles.clear()
	home_tiles.clear()
	_detail = null


## A label of the menus' pages (SfUi.label; sizes given as in TMNF's Cabin, Montserrat being wider).
static func _text(text: String, size := 22, colour := SfUi.TEXT, key := SfUi.MEDIUM) -> Label:
	return SfUi.label(text, roundi(size * 0.8), colour, key)


## A page's frame: down the left a dark column with the page's title and what to do there, the
## rows (_row) under it; its foot rows (Back) at the bottom. Returns the page's root.
func _root(title := "", subtitle := "", _icon_name := "") -> Control:
	var root := Control.new()
	root.theme = SfUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_layer.move_child(nav, -1)      # the header over the page (its tooltips, the underline)
	var col := Panel.new()
	col.add_theme_stylebox_override("panel", SfUi.box("column"))
	col.position = COLUMN.position
	col.size = COLUMN.size
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.position = COLUMN.position + Vector2(22, 20)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)
	head.add_child(SfUi.label(title, 26, SfUi.TEXT, SfUi.BLACK, 0, true))
	head.add_child(SfUi.caption(subtitle, 12))
	var line := SfUi.accent_line(2.0, 40.0)
	head.add_child(line)
	_rows = VBoxContainer.new()
	_rows.position = COLUMN.position + Vector2(0, 104)
	_rows.add_theme_constant_override("separation", 2)
	root.add_child(_rows)
	_rows_bottom = VBoxContainer.new()
	_rows_bottom.add_theme_constant_override("separation", 2)
	root.add_child(_rows_bottom)
	_rows_bottom.position = Vector2(COLUMN.position.x, COLUMN.end.y - 8)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	call_deferred("_settle_rows")
	return root


## Keeps the foot rows' box on the column's floor once its size is known.
func _settle_rows() -> void:
	if is_instance_valid(_rows_bottom):
		_rows_bottom.position.y = COLUMN.end.y - 8 - _rows_bottom.size.y


## An entry of the left column: an icon (series flags; others none) and a name in capitals; white
## when focused, a red bar at the left when it's the page's current choice (chosen); at the
## column's foot with `bottom`.
func _row(text: String, icon_name: String, action: Callable, bottom := false, chosen := false) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name.begins_with("flag_"):
		b.icon = TmUi.icon(icon_name, 26)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(COLUMN.size.x, 54)
	b.add_theme_constant_override("h_separation", 14)
	var normal := SfUi.box("row_chosen" if chosen else "row")
	var hover := SfUi.box("row_chosen" if chosen else "row_hover")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", SfUi.box("focus"))
	b.add_theme_font_override("font", TmUi.font(SfUi.BOLD, 2))
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_color_override("font_color", SfUi.TEXT if chosen else SfUi.DIM)
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, SfUi.TEXT)
	for c in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.text = text.to_upper()
	b.set_meta("name", text)
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


## A panel: dark, a hairline border, its title in small capitals after a red-to-violet bar; returns
## its body (the title's Label: _title_of(body)).
func _panel(root: Control, title: String, rect: Rect2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", SfUi.box("panel"))
	p.position = rect.position
	p.custom_minimum_size = rect.size
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := SfUi.title(title)
	v.add_child(t)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	body.set_meta("title", t.get_child(1))
	return body


## The title of a panel made by _panel.
static func _title_of(body: Control) -> Label:
	return body.get_meta("title") as Label


## A short line at the bottom of the screen that fades (the locked Story, ...).
func notice(text: String) -> void:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", SfUi.box("chip_violet"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(SfUi.label(text, 15, SfUi.TEXT, SfUi.SEMI))
	_layer.add_child(chip)
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chip.name = "Notice"
	var tw := chip.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(chip, "modulate:a", 0.0, 0.6)
	tw.tween_callback(chip.queue_free)


func show_page(name: String) -> void:
	if page == "profile" and name != "profile" and _profile_changed:
		_profile_changed = false
		Master.push_profile()      # the account takes the profile's nickname and zone
	if name != page:
		_account_asked = false
	if page == "community" and name != "community":
		_paint_car()               # the car we drive back on the turntable
	page = name if PAGES.has(name) else "main"
	if page == "campaign":
		page = "solo"              # the campaign is the Solo page
	_clear()
	if is_instance_valid(nav):
		nav.refresh()
		nav.set_page(page)
	(_grade.material as ShaderMaterial).set_shader_parameter("left_dark", 0.25)
	var car_view := page in ["profile", "garage", "tuning"]
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
		"community":
			_page_community()
		"profile":
			_page_profile()
		"garage":
			_page_garage()
		"tuning":
			_page_tuning()
		_:
			_page_main()


func back() -> void:
	if page == "online":
		Online.leave()
	show_page(String(PAGES.get(page, "")) if not String(PAGES.get(page, "")).is_empty() else "main")


## Home: picture panels as RaceRoom's DRIVE page (the owner's reference), in our look: Solo,
## Multiplayer and the Garage large on top; Story (locked), Community, Track editor and Replays
## under them; your campaign's medals along the foot.
func _page_main() -> void:
	var root := Control.new()
	root.theme = SfUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_layer.move_child(nav, -1)
	var grid := VBoxContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 64
	grid.offset_right = -64
	grid.offset_top = SfHeader.HEIGHT + 40
	grid.offset_bottom = -84
	grid.add_theme_constant_override("separation", 14)
	root.add_child(grid)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 1.5
	grid.add_child(top)
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 14)
	low.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_child(low)
	var counts := medal_counts()
	var solo := _home_tile(top, "solo", "Solo", "Our campaign against the clock", "solo", true)
	solo.info = "%d / %d tracks finished" % [counts["finished"], tracks.size()]
	solo.focus_point = Vector2(0.62, 0.5)
	_home_tile(top, "online", "Multiplayer", "Race the world online", "multiplayer", true)
	_home_tile(top, "garage", "Garage", "Your cars, liveries and tuning", "garage", true)
	var story := _home_tile(low, "story", "Story", "Chapter one is on its way", "story")
	story.locked = true
	story.badge = "Coming soon"
	story.tooltip_text = LOCKED_NOTE
	story.locked_pressed.connect(func() -> void: notice(LOCKED_NOTE))
	_home_tile(low, "community", "Community", "Cars, tracks and mods", "community")
	_home_tile(low, "editors", "Track editor", "Build your own tracks", "editor")
	_home_tile(low, "replays", "Replays", "Watch your best runs", "replays")
	for t: SfTile in home_tiles.values():
		(t.get_meta("parent_row") as HBoxContainer).add_child(t)      # SfTile reads its settings in _ready
	# your campaign along the foot
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = 64
	foot.offset_bottom = -30
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(foot)
	var cap := SfUi.caption("Your campaign", 12)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(cap)
	for m: String in MEDALS:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(_icon("medal_" + m, 24))
		var n := SfUi.label(str(counts[m]), 16, SfUi.TEXT, SfUi.BOLD)
		cell.add_child(n)
		foot.add_child(cell)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	(home_tiles["solo"] as SfTile).grab_focus.call_deferred()


## A home panel that opens a page (added to its row by _page_main once set up).
func _home_tile(row: HBoxContainer, to: String, title: String, sub: String, pic: String, big := false) -> SfTile:
	var t := SfTile.new(title, sub, pic, big)
	t.name = "Tile_" + to
	t.set_meta("parent_row", row)
	if to != "story":
		t.pressed.connect(func() -> void: show_page(to))
	home_tiles[to] = t
	return t


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
		cell.add_child(_text(str(counts[m]), 26, SfUi.TEXT, SfUi.BOLD))
		row.add_child(cell)
	box.add_child(_text("%d of %d tracks finished" % [counts["finished"], tracks.size()], 20, SfUi.DIM, SfUi.MEDIUM))
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


## Solo: the series down the left (the current one marked), its tracks as cards in a grid, the
## focused track's medal times and your best in the panel above them; a card's press races it.
func _page_solo() -> void:
	var root := _root("Solo", "Choose a series", "icon_solo")
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
	_detail = _panel(root, "", Rect2(RIGHT.position, Vector2(RIGHT.size.x, 112)))
	var grid := GridContainer.new()
	grid.position = Vector2(RIGHT.position.x, TOP + 130)
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", int((RIGHT.size.x - 5 * CARD.x) / 4.0))
	grid.add_theme_constant_override("v_separation", 18)
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


## A track's card: its picture (assets/ui/thumbs, rendered by tools/icons/thumbs.sh; the map's
## outline on the dark without one) over its name; focused: a red frame, the picture brighter
## under a play mark; your medal in the corner.
func _card(t: String) -> Button:
	var ch := header(t)
	var ms := int(TmRecords.best(ch).get("time_ms", -1))
	var m := TmRace.medal(ms, ch)
	var card := Button.new()
	card.custom_minimum_size = CARD
	card.tooltip_text = ch.name
	card.add_theme_stylebox_override("normal", SfUi.box("tile"))
	for s in ["hover", "pressed", "hover_pressed"]:
		card.add_theme_stylebox_override(s, SfUi.box("tile"))
	card.add_theme_stylebox_override("focus", SfUi.box("tile"))
	var pic := Panel.new()
	pic.add_theme_stylebox_override("panel", SfUi.box("column"))
	pic.position = Vector2(2, 2)
	pic.size = Vector2(CARD.x - 4, CARD.y - 38)
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pic)
	var shot := "res://assets/ui/thumbs/%s.jpg" % t
	if ResourceLoader.exists(shot):      # a picture of the track
		var tr := TextureRect.new()
		tr.texture = load(shot)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(tr)
	else:
		var map := TmTrackMap.new(ch)
		map.line_width = 2.5
		map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(map)
	pic.modulate = Color(0.8, 0.8, 0.84)
	var play := SfHeader.Glyph.new("play", "")
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.focus_mode = Control.FOCUS_NONE
	play.colour = Color.WHITE
	play.custom_minimum_size = Vector2(48, 48)
	play.size = Vector2(48, 48)
	play.position = (pic.size - play.size) * 0.5 + pic.position
	play.visible = false
	card.add_child(play)
	if not m.is_empty():
		var medal := _icon("medal_" + m, 28)
		medal.position = Vector2(CARD.x - 36, 8)
		medal.size = Vector2(28, 28)
		card.add_child(medal)
	var name_l := SfUi.label(ch.name, 14, SfUi.DIM, SfUi.SEMI)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.clip_text = true
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.position = Vector2(12, CARD.y - 36)
	name_l.size = Vector2(CARD.x - 24, 34)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_l)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", SfUi.box("tile_lit"))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	card.add_child(frame)
	card.focus_entered.connect(func() -> void:
		play.visible = true
		frame.visible = true
		pic.modulate = Color.WHITE
		name_l.add_theme_color_override("font_color", SfUi.TEXT))
	card.focus_exited.connect(func() -> void:
		play.visible = false
		frame.visible = false
		pic.modulate = Color(0.8, 0.8, 0.84)
		name_l.add_theme_color_override("font_color", SfUi.DIM))
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
	_title_of(_detail).text = "%s  ·  by %s" % [ch.name if ch.ok() else track, ch.author] if ch.ok() else "(unreadable: %s)" % ch.error
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_child(row)
	for r: Array in [["author", "Author", ch.author_ms], ["gold", "Gold", ch.gold_ms], ["silver", "Silver", ch.silver_ms], ["bronze", "Bronze", ch.bronze_ms]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(_icon("medal_" + String(r[0]), 34))
		cell.add_child(_text(TmRace.time_text(int(r[2])), 24, TmRaceHud.MEDAL_COLOURS[r[0]], SfUi.BOLD))
		row.add_child(cell)
	var mine := HBoxContainer.new()
	mine.add_theme_constant_override("separation", 10)
	mine.add_child(_icon("medal_" + (m if not m.is_empty() else "none"), 34))
	mine.add_child(_text("Your best", 22, SfUi.DIM, SfUi.MEDIUM))
	mine.add_child(_text(TmRace.time_text(ms), 24, Color.WHITE, SfUi.BOLD))
	mine.add_child(_text(("%s medal" % m.capitalize()) if not m.is_empty() else ("Not finished yet" if ms < 0 else "No medal yet"), 22,
		TmRaceHud.MEDAL_COLOURS[m] if not m.is_empty() else SfUi.DIM, SfUi.MEDIUM))
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
		rows.add_child(_text("No replays yet. Finish a race and press Save replay; your best run on each track is kept by itself.", 21, SfUi.DIM, SfUi.MEDIUM))
	var group := ButtonGroup.new()
	for e: Dictionary in all:
		var r: TmReplay = e["replay"]
		var path := String(e["path"])
		var row := _list_row(group, 1110)
		var texts := [r.track_name + ("   (best)" if e["autosave"] else ""), TmRace.time_text(r.finish_ms), "", r.date.left(16)]
		for i in REPLAY_COLUMNS.size():
			var cell: Control
			if i == 2:
				cell = TmUi.nick_label(r.player, 21, SfUi.TEXT)
				cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			else:
				cell = _cell(String(texts[i]), SfUi.HOT if i == 1 else SfUi.TEXT)
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
	var go := SfUi.button("Watch", func() -> void:
		if not replay_selected.is_empty():
			watch(replay_selected), 240)
	go.disabled = all.is_empty()
	buttons.add_child(go)
	var del := SfUi.button("Delete", Callable(), 240)
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


## A list's column heads (names and widths): small capitals.
func _columns(cols: Array) -> HBoxContainer:
	var head := HBoxContainer.new()
	var pad := Control.new()
	pad.custom_minimum_size.x = 17
	head.add_child(pad)
	for c: Array in cols:
		var l := SfUi.caption(String(c[0]), 12)
		l.custom_minimum_size.x = int(c[1])
		head.add_child(l)
	return head


## A row of a list: a faint strip with light text, red-tinted with a red bar at the left when picked
## (toggled in its group); its cells go in its first child.
func _list_row(group: ButtonGroup, width: float) -> Button:
	var row := Button.new()
	row.toggle_mode = true
	row.button_group = group
	row.custom_minimum_size = Vector2(width, 42)
	row.add_theme_stylebox_override("normal", SfUi.box("list"))
	row.add_theme_stylebox_override("hover", SfUi.box("list_hover"))
	row.add_theme_stylebox_override("pressed", SfUi.box("list_chosen"))
	row.add_theme_stylebox_override("hover_pressed", SfUi.box("list_chosen"))
	row.add_theme_stylebox_override("focus", SfUi.box("list_focus"))
	var cells := HBoxContainer.new()
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = 17
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cells)
	row.mouse_entered.connect(row.grab_focus)
	return row


## A list row's cell: one line.
func _cell(text: String, colour: Color) -> Label:
	var l := SfUi.label(text, 16, colour, SfUi.MEDIUM)
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
	var root := _root("Editor", "Your tracks", "icon_editors")
	var fresh := _row("New Track", "icon_editors", func() -> void: edit(""))
	_row("Back", "icon_back", back, true)
	track_rows.clear()
	var col := _panel(root, "Your Tracks", RIGHT)
	var tip := _text("Stadium blocks on a 32 x 32 grid. Drive a track to the finish in the editor to validate it.", 19, SfUi.DIM, SfUi.MEDIUM)
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
		rows.add_child(_text("No tracks yet: New Track opens the editor.", 21, SfUi.DIM, SfUi.MEDIUM))
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
			var colour := SfUi.TEXT
			if i == 1:
				colour = SfUi.HOT if ok else Color(SfUi.TEXT, 0.55)
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
	var ed := SfUi.button("Edit", func() -> void:
		if not track_selected.is_empty():
			edit(track_selected), 220)
	var note := _text("", 20, SfUi.DIM, SfUi.MEDIUM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var play := SfUi.button("Play", func() -> void:
		if track_selected.is_empty():
			return
		var lack := TmEditorModel.new(TmUserTracks.load_file(track_selected)).missing()
		if not lack.is_empty():
			note.text = lack + " in the editor first"
			return
		race("", track_selected), 220)
	var del := SfUi.button("Delete", Callable(), 220)
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
	line.add_child(_text("World record", 20, SfUi.DIM, SfUi.MEDIUM))
	if top.is_empty():
		line.add_child(_text("none yet", 20, SfUi.DIM, SfUi.MEDIUM))
		return
	line.add_child(_text(TmRace.time_text(int(top[0]["time"])), 21, SfUi.HOT, SfUi.BOLD))
	line.add_child(TmUi.nick_label(String(top[0].get("nickname", "")), 20))
	var mine: Variant = r.get("mine")
	if mine is Dictionary:
		line.add_child(_text("   You: #%d of %d" % [int(mine["rank"]), int(r.get("count", 0))], 20, SfUi.TEXT, SfUi.MEDIUM))


## Options as rows (after RaceRoom's settings page the owner showed, in our look): each setting's
## name in capitals with a line saying what it does, its control at the right (a switch, a slider
## with its value, a choice between arrows, a button), in sections: Graphics, Sound, Gameplay.
func _page_options() -> void:
	_clear_armed = false          # a first press on an earlier visit doesn't count
	var root := _root("Options", "Set up the game", "icon_options")
	_row("Back", "icon_back", back, true)
	var col := _panel(root, "Options", Rect2(RIGHT.position, Vector2(900, 0)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(864, COLUMN.size.y - 74)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_section(list, "Graphics")
	_setting(list, "Fullscreen", "Play in a window or on the whole screen.", _switch("fullscreen"))
	_setting(list, "Graphics", "Low for older cards; High adds detail; Ultra adds global illumination, reflections and haze.",
		_choice("quality", TmRtx.QUALITY_NAMES))
	_setting(list, "HD textures", "Sharper textures and finer shading on the track and the cars.", _switch("hd"))
	_setting(list, "Shadows", "Shadows of the cars, the blocks and the Stadium.", _switch("shadows"))
	if TmRtx.is_fork():   # NVIDIA's RTX build of Godot
		_setting(list, "DLSS", "NVIDIA's upscaling: more frames for a little sharpness.", _choice("dlss", TmRtx.DLSS_NAMES))
		_setting(list, "Path tracing", "Experimental, RTX 40/50. %s" % TmRtx.status(), _switch("path_tracing"))
	_section(list, "Sound")
	_setting(list, "Sound", "Engines, tyres, impacts and the menus.", _switch("sound"))
	_setting(list, "Sound volume", "How loud the game's sounds are.", _slider("sound_volume"))
	_setting(list, "Music", "The soundtrack in the menus and the races.", _switch("music"))
	_setting(list, "Music volume", "How loud the music is.", _slider("music_volume"))
	_section(list, "Gameplay")
	_setting(list, "Ghost", "Race against the ghost of your best run on each track.", _switch("ghost"))
	var clear := SfUi.button("Clear all records", Callable(), 300)
	clear.pressed.connect(func() -> void:
		if _clear_armed:
			TmRecords.clear()
			clear.text = "Records cleared"
			_clear_armed = false
		else:
			clear.text = "Press again to clear all records"
			_clear_armed = true)
	_setting(list, "Records", "Forget every best time and its ghost on this computer (asks again first).", clear)
	var first: Control = list.get_child(1).get_child(1) if list.get_child_count() > 1 else null
	if first:
		first.grab_focus.call_deferred()


## A section's heading in the options' list.
func _section(list: VBoxContainer, title: String) -> void:
	var l := SfUi.caption(title, 12, SfUi.HOT)
	l.custom_minimum_size.y = 40 if list.get_child_count() > 0 else 22
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list.add_child(l)


## A setting's row: its name and what it does at the left, its control at the right.
func _setting(list: VBoxContainer, title: String, what: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.custom_minimum_size.y = 54
	list.add_child(row)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(SfUi.label(title, 15, SfUi.TEXT, SfUi.BOLD, 1, true))
	var w := SfUi.label(what, 13, SfUi.DIM, SfUi.MEDIUM)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.custom_minimum_size.x = 430
	text.add_child(w)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	var line := ColorRect.new()
	line.color = SfUi.LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(line)


## A setting's switch (on / off).
func _switch(key: String) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = bool(TmUi.setting(key))
	c.custom_minimum_size = Vector2(64, 40)
	c.toggled.connect(func(on: bool) -> void:
		TmUi.set_setting(key, on)
		TmUi.play("click"))
	c.mouse_entered.connect(c.grab_focus)
	return c


## A setting's slider (0-1) with its value in per cent.
func _slider(key: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(TmUi.setting(key))
	slider.custom_minimum_size = Vector2(250, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := SfUi.label("", 15, SfUi.TEXT, SfUi.SEMI)
	v.custom_minimum_size.x = 52
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(x: float) -> void:
		TmUi.set_setting(key, x)
		v.text = "%d%%" % roundi(x * 100.0))
	box.add_child(slider)
	box.add_child(v)
	return box


## A setting's choice among names (an index): the current one between two arrows.
func _choice(key: String, names: Array) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var v := SfUi.label("", 15, SfUi.TEXT, SfUi.SEMI)
	v.custom_minimum_size.x = 150
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var show := func() -> void: v.text = String(names[clampi(int(TmUi.setting(key)), 0, names.size() - 1)]).to_upper()
	show.call()
	for d: int in [-1, 1]:
		var b := SfHeader.Glyph.new("back" if d < 0 else "next", "Previous" if d < 0 else "Next")
		b.custom_minimum_size = Vector2(40, 40)
		b.pressed.connect(func() -> void:
			TmUi.set_setting(key, posmod(int(TmUi.setting(key)) + d, names.size()))
			show.call())
		box.add_child(b)
		if d < 0:
			box.add_child(v)
	return box


## Your profile: the nickname with TMNF's $-codes (previewed as you type), your zone, your car's
## colour (our car on the field behind, turning to show it) and your medals.
func _page_profile() -> void:
	var root := _root("Profile", "Who you are", "icon_profile")
	_row("Back", "icon_back", back, true)
	var col := _panel(root, "Player", Rect2(RIGHT.position, Vector2(640, 0)))
	col.add_child(SfUi.caption("Nickname"))
	var preview := TmUi.nick_label(String(TmUi.setting("name")), 36)
	var edit := LineEdit.new()
	edit.text = String(TmUi.setting("name"))
	edit.max_length = TmNick.MAX_LENGTH
	edit.custom_minimum_size = Vector2(590, 46)
	edit.text_changed.connect(func(t: String) -> void:
		TmUi.set_setting("name", t.strip_edges())
		_profile_changed = true
		preview.text = TmNick.to_bbcode(t.strip_edges(), SfUi.TEXT))
	col.add_child(edit)
	col.add_child(preview)
	col.add_child(_text("$f00 colour (3 hex digits)    $o bold    $i italic    $w wide    $n narrow\n$s shadow    $t capitals    $g default colour    $z reset    $$ a dollar",
		17, SfUi.DIM, SfUi.MEDIUM))
	col.add_child(HSeparator.new())
	col.add_child(SfUi.caption("Zone"))
	var zone := _zone_picker()
	col.add_child(zone)
	col.add_child(HSeparator.new())
	col.add_child(SfUi.caption("Car"))
	var model := _model_picker()
	col.add_child(model)
	col.add_child(SfUi.caption("Car colour"))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 10)
	col.add_child(swatches)
	for i in TmUi.CAR_COLOURS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		var chosen := i == int(TmUi.setting("colour"))
		var c: Color = TmUi.CAR_COLOURS[i]
		var st := StyleBoxFlat.new()       # a flat disc of the colour, ringed white when it's yours
		st.bg_color = c
		st.set_corner_radius_all(23)
		st.anti_aliasing = true
		st.border_color = Color.WHITE if chosen else Color(1, 1, 1, 0.2)
		st.set_border_width_all(3 if chosen else 1)
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_corner_radius_all(27)
		ring.anti_aliasing = true
		ring.border_color = SfUi.RED
		ring.set_border_width_all(2)
		ring.set_expand_margin_all(4)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_stylebox_override("focus", ring)
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
	elif _profile_focus == "model":
		focus = model
	elif _profile_focus.is_valid_int() and int(_profile_focus) < swatches.get_child_count():
		focus = swatches.get_child(int(_profile_focus)) as Control
	_profile_focus = ""
	focus.grab_focus.call_deferred()


var garage_cars: Array = []          ## the garage's line-up ([model, name, ...]: TmUi.car_models())
var garage_liveries: Array[Button] = []   ## the shown car's livery buttons (tests)
var _garage_focus := ""              ## after a pick rebuilds the page: "prev", "next" or a livery's index


## The garage (PLAN M17): our cars one at a time on the turntable, as NFS's garage shows them: the
## car's name, its place in the line-up and what it is in a panel at the foot, the previous and
## next car down the column, the car's five liveries as swatches. A pick is the car we drive from
## then on (settings car_model, car_liveries); a community car (Community page) still draws instead.
func _page_garage() -> void:
	var root := _root("Garage", "Pick your car and its livery", "icon_car")
	garage_cars = TmUi.car_models()
	var cur := TmUi.car_model()
	var idx := maxi(0, garage_cars.find_custom(func(c: Array) -> bool: return String(c[0]) == cur))
	var prev := _row("Previous car", "icon_back", func() -> void: garage_step(-1))
	var next := _row("Next car", "play", func() -> void: garage_step(1))
	if TmRoadCars.tunable(String(garage_cars[idx][0])):
		_gap(16)
		_row("Tuning", "icon_options", func() -> void: show_page("tuning"))
	_row("Back", "icon_back", back, true)
	var body := _foot_panel(root, "Car  %d / %d" % [idx + 1, garage_cars.size()])
	var car: Array = garage_cars[idx]
	body.add_child(SfUi.label(String(car[1]), 40, SfUi.TEXT, SfUi.BLACK, 1, true))
	body.add_child(SfUi.label(TmRoadCars.blurb(String(car[0])), 17, SfUi.DIM, SfUi.MEDIUM))
	garage_liveries.clear()
	var lvs := TmRoadCars.liveries(String(car[0])) if String(car[0]) != "" else []
	if lvs.is_empty():
		body.add_child(SfUi.label("Its colour is picked on the Profile page.", 16, SfUi.DIM, SfUi.MEDIUM))
	else:
		body.add_child(SfUi.caption("Livery"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		body.add_child(row)
		var picked := TmUi.car_livery(String(car[0]))
		for i in lvs.size():
			row.add_child(_livery_swatch(String(car[0]), i, lvs[i], i == picked))
	var focus: Control = next
	if _garage_focus == "prev":
		focus = prev
	elif _garage_focus.is_valid_int() and int(_garage_focus) < garage_liveries.size():
		focus = garage_liveries[int(_garage_focus)]
	_garage_focus = ""
	focus.grab_focus.call_deferred()


## Drives the previous (-1) or next (+1) car of the line-up, and shows it.
func garage_step(dir: int) -> void:
	var cars := TmUi.car_models()
	var cur := TmUi.car_model()
	var idx := maxi(0, cars.find_custom(func(c: Array) -> bool: return String(c[0]) == cur))
	TmUi.set_setting("car_model", String(cars[posmod(idx + dir, cars.size())][0]))
	_paint_car()
	_garage_focus = "prev" if dir < 0 else "next"
	show_page("garage")


## Drives car `model` in livery i, and shows it.
func garage_livery(model: String, i: int) -> void:
	TmUi.set_setting("car_model", model)
	TmUi.set_car_livery(model, i)
	_paint_car()
	_garage_focus = str(i)
	show_page("garage")


var tuning_rows := {}                ## the tuning page's rows by part (tests)
var _tuning_focus := ""              ## after a pick rebuilds the page: the part whose row keeps the focus


## The garage's tuning (PLAN M18): the car's spoiler, rims, underglow and hood, ten choices each,
## live on the turntable. Each row shows its part and pick; Enter or a click takes the next choice,
## left and right step either way. Picks are kept per car (settings car_tuning) and go wherever
## the car does (races, ghosts, replays, online).
func _page_tuning() -> void:
	var model := TmUi.car_model()
	var root := _root("Tuning", "Spoiler, rims, underglow and hood", "icon_options")
	tuning_rows.clear()
	var t := TmUi.car_tuning(model)
	for part: String in TmRoadCars.TUNING if TmRoadCars.tunable(model) else []:
		var opts := TmRoadCars.options(part)
		var i := int(t.get(part, 0))
		# two lines: the part, then its pick (the longest picks don't fit beside it)
		var b := _row("%s\n%s" % [TmRoadCars.TUNING_NAMES[part], opts[i]["name"]], "icon_options",
			func() -> void: tuning_step(part, 1), false, i > 0)
		b.custom_minimum_size.y = 62
		b.gui_input.connect(func(e: InputEvent) -> void:
			if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
				b.accept_event()
				TmUi.play("click")
				tuning_step(part, -1 if e.is_action_pressed("ui_left") else 1))
		tuning_rows[part] = b
	_row("Back", "icon_back", back, true)
	var body := _foot_panel(root, TmRoadCars.car_name(model) if TmRoadCars.is_road(model) else ("Hypercar" if model == "hyper" else "Formula"))
	if tuning_rows.is_empty():
		body.add_child(SfUi.label("This car isn't tuned: pick one of our hypercar or road cars in the Garage.", 17, SfUi.DIM, SfUi.MEDIUM))
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 48)
		body.add_child(grid)
		for part: String in TmRoadCars.TUNING:
			var opts := TmRoadCars.options(part)
			var i := int(t.get(part, 0))
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 2)
			col.custom_minimum_size.x = 220
			col.add_child(SfUi.caption(TmRoadCars.TUNING_NAMES[part]))
			col.add_child(SfUi.label(String(opts[i]["name"]), 22, SfUi.HOT if i > 0 else SfUi.TEXT, SfUi.BOLD))
			col.add_child(SfUi.label("%d / %d" % [i + 1, opts.size()], 13, SfUi.FAINT, SfUi.SEMI))
			grid.add_child(col)
		body.add_child(SfUi.label("Enter: the next choice.  Left / right: step through them.", 14, SfUi.DIM, SfUi.MEDIUM))
	var focus: Control = tuning_rows.get(_tuning_focus, tuning_rows.get("spoiler"))
	_tuning_focus = ""
	if focus != null:
		focus.grab_focus.call_deferred()


## Takes tuning part `part`'s next (+1) or previous (-1) choice for the car we drive, and shows it.
func tuning_step(part: String, dir: int) -> void:
	var model := TmUi.car_model()
	var n := TmRoadCars.options(part).size()
	TmUi.set_car_tuning(model, part, posmod(int(TmUi.car_tuning(model).get(part, 0)) + dir, n))
	_paint_car()
	_tuning_focus = part
	show_page("tuning")


## A livery's swatch: its paint with a band of its vinyl's colour along the foot, its name under
## it; a white border when it's the one picked (its name red), a red ring when focused.
func _livery_swatch(model: String, i: int, lv: Dictionary, chosen: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 60)
	var base: Color = lv.get("base", TmUi.car_colour()) if String(lv.get("pattern", "")) != "hyper" else TmUi.car_colour()
	var a: Color = lv.get("a", base)
	var st := StyleBoxFlat.new()
	st.bg_color = base
	st.border_color = SfUi.TEXT if chosen else SfUi.LINE
	st.set_border_width_all(2 if chosen else 1)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = SfUi.RED
	ring.set_border_width_all(2)
	ring.set_expand_margin_all(4)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, st)
	b.add_theme_stylebox_override("focus", ring)
	var band := ColorRect.new()          # the vinyl's colour along the foot
	band.color = a
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -16
	band.offset_left = 2 if chosen else 1
	band.offset_right = -2 if chosen else -1
	band.offset_bottom = -2 if chosen else -1
	b.add_child(band)
	b.pressed.connect(func() -> void: garage_livery(model, i))
	b.pressed.connect(TmUi.play.bind("click"))
	b.mouse_entered.connect(b.grab_focus)
	box.add_child(b)
	garage_liveries.append(b)
	var l := SfUi.label(String(lv.get("name", "Livery %d" % (i + 1))), 14, SfUi.HOT if chosen else SfUi.TEXT, SfUi.SEMI)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(196, 0)
	box.add_child(l)
	return box


## A panel along the foot of the page, right of the column (the garage's and tuning's: the car
## stands above it on the turntable); returns its body.
func _foot_panel(root: Control, title: String) -> VBoxContainer:
	var body := _panel(root, title, Rect2(RIGHT.position.x, 0, 1180, 0))
	var p := body.get_parent().get_parent() as Control      # _panel: the PanelContainer > its box > body
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = RIGHT.position.x
	p.offset_bottom = -(900.0 - COLUMN.end.y)
	return body


## Your medals in a panel at the column's foot (the profile).
func _medal_summary_panel(root: Control, rect: Rect2) -> void:
	var body := _panel(root, "Your Campaign", rect)
	body.add_child(_medal_summary())
	var p := body.get_parent().get_parent() as Control      # _panel: the PanelContainer > its box > body
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = rect.position.x
	p.offset_bottom = -(900.0 - COLUMN.end.y)


## Which of our own cars we drive (TmUi.car_models(): the open-wheeler, the hypercar, the road
## cars; their liveries on the Garage page); a community car from the Community page is drawn
## instead while it is picked there.
func _model_picker() -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(590, 48)
	for c: Array in TmUi.car_models():
		pick.add_item(String(c[1]))
		pick.set_item_metadata(pick.item_count - 1, String(c[0]))
		if String(c[0]) == TmUi.car_model():
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		TmUi.set_setting("car_model", String(pick.get_item_metadata(i)))
		_paint_car()
		_profile_focus = "model"
		show_page("profile"))
	return pick


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


## Multiplayer (TMNF's online page in our look): the servers (from the master: name, mode, track, players; Join) or the
## rankings (the world's or your zone's) as rows of the column, the list in a panel beside it with
## joining by address, your account (log in or register; ladder points and ranks) at the right.
func _page_online() -> void:
	var root := _root("Multiplayer", "Choose a server", "icon_online")
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
	col.add_child(SfUi.caption("Join by address"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var addr := LineEdit.new()
	addr.text = String(TmUi.setting("server"))
	addr.placeholder_text = "IP:port or https://address"
	addr.custom_minimum_size = Vector2(430, 44)
	row.add_child(addr)
	row.add_child(SfUi.button("Connect", func() -> void:
		TmUi.set_setting("server", addr.text.strip_edges())
		_connect(addr.text.strip_edges()), 200))
	_online_status = _text("", 20, SfUi.DIM, SfUi.MEDIUM)
	col.add_child(_online_status)
	var acc := _panel(root, "Your Account", Rect2(1110, TOP, 458, 0))
	_account_panel(acc)
	tabs[_online_tab].grab_focus.call_deferred()


func _account_panel(acc: VBoxContainer) -> void:
	acc.add_theme_constant_override("separation", 10)
	if Master.logged_in():
		var a := Master.account
		acc.add_child(TmUi.nick_label(String(a.get("nickname", TmUi.setting("name"))), 32))
		var zone := String(a.get("zone", "World"))
		acc.add_child(_text("%s   ·   %s" % [String(a.get("login", "")), zone.replace("|", "  ·  ")], 19, SfUi.DIM, SfUi.MEDIUM))
		var lad := HBoxContainer.new()
		lad.add_theme_constant_override("separation", 12)
		lad.add_child(_icon("star", 40))
		lad.add_child(_text("%d ladder points" % int(a.get("ladder", 0)), 25, SfUi.HOT, SfUi.BOLD))
		acc.add_child(lad)
		var r := Master.ranks
		if not r.is_empty():
			acc.add_child(_text("World  #%d of %d\nZone  #%d" % [int(r.get("world", 0)), int(r.get("players", 0)), int(r.get("zone", 0))],
				22, SfUi.TEXT, SfUi.MEDIUM))
		acc.add_child(_text("Your nickname and zone come from Profile.", 18, SfUi.DIM, SfUi.MEDIUM))
		acc.add_child(SfUi.button("Log out", func() -> void:
			await Master.log_out()
			if page == "online":
				show_page("online"), 220))
		if (a.is_empty() or r.is_empty()) and not _account_asked:
			_account_asked = true
			_refresh_account()
		return
	var intro := _text("Log in to climb the ladder and keep online records. Or just join a server as a guest.", 19, SfUi.DIM, SfUi.MEDIUM)
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
	var note := _text("New here? Register uses your Profile's nickname and zone.", 18, SfUi.DIM, SfUi.MEDIUM)
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
	row.add_child(SfUi.button("Log in", func() -> void: go.call(false), 200))
	row.add_child(SfUi.button("Register", func() -> void: go.call(true), 200))
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
	var wait := _text("Looking for servers...", 20, SfUi.DIM, SfUi.MEDIUM)
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
			var l := _cell(texts[i], SfUi.HOT if green else SfUi.TEXT)
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
		buttons.add_child(SfUi.button("Join", func() -> void: _connect(server_selected), 220))
		buttons.add_child(SfUi.button("Spectate", func() -> void: _connect(server_selected, true), 220))


func _rankings_tab(body: VBoxContainer) -> void:
	var mine := String(Master.account.get("zone", TmUi.setting("zone")))
	var zone := mine if _rank_zone and not mine.is_empty() else "World"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	for z: Array in [["World", false], ["My zone", true]]:
		var b := SfUi.button(String(z[0]), func() -> void:
			_rank_zone = bool(z[1])
			show_page("online"), 160)
		if bool(z[1]) == _rank_zone:
			b.add_theme_stylebox_override("normal", SfUi.box("list_chosen"))
			b.add_theme_color_override("font_color", SfUi.HOT)
		row.add_child(b)
	row.add_child(_text("  " + zone.replace("|", "  ·  "), 20, SfUi.DIM, SfUi.MEDIUM))
	body.add_child(_columns(RANK_COLUMNS))
	var wait := _text("Loading...", 20, SfUi.DIM, SfUi.MEDIUM)
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
		var cells: Array[Control] = [_text("%d" % int(p.get("rank", 0)), 21, SfUi.HOT if me else SfUi.DIM, SfUi.BOLD),
			TmUi.nick_label(String(p.get("nickname", "")), 21), _text(String(p.get("zone", "")).replace("|", " · "), 19, SfUi.DIM, SfUi.MEDIUM),
			_text("%d" % int(p.get("ladder", 0)), 21, SfUi.HOT if me else SfUi.TEXT, SfUi.BOLD)]
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


## In the server: race its round's track (a track its admins uploaded is downloaded first).
func _joined() -> void:
	var f: Variant = Online.round.get("file", null)
	if f is Dictionary:
		if is_instance_valid(_online_status):
			_online_status.text = "Downloading %s ..." % TmNick.strip(String((f as Dictionary).get("name", "the track")))
		var path: String = await Online.round_track_file()
		if path.is_empty():
			if is_instance_valid(_online_status):
				_online_status.text = "Couldn't download the server's track"
			Online.leave()
			return
		race("", path, String(Online.round.get("track", "")))
		return
	race(String(Online.round.get("track", tracks[0] if not tracks.is_empty() else "")))


func _open_file() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.Gbx, *.sftrack ; Tracks (TrackMania, SpeedFest)"])
	fd.use_native_dialog = true
	fd.file_selected.connect(func(path: String) -> void: race("", path))
	_layer.add_child(fd)
	fd.popup_centered_ratio(0.7)


## Starts a race: a campaign track, or a track file (map; online_track: the server's id for it, a
## track its admins uploaded).
func race(track: String, map := "", online_track := "") -> void:
	TestHooks.args.erase("map")
	TestHooks.args.erase("track")
	TestHooks.args.erase("online_track")
	if not online_track.is_empty():
		TestHooks.args["online_track"] = online_track
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


# --- community: TrackMania Exchange's tracks, ManiaPark's cars and texture mods ---------------------

var community: TmCommunity          ## the page's source (made on the first visit)
var comm_tab := "cars"              ## "cars", "tracks" or "mods"
## the list shown per tab: cars: model, skin, mine; tracks: awards, newest, downloads, mine;
## mods: tm1 (TMNF/TMUF), maniaplanet, mine
var comm_filter := {"cars": "model", "tracks": "awards", "mods": "tm1"}
var comm_text := ""                 ## the search
var comm_items: Array = []          ## the page's items (TmCommunity's)
var comm_cards := {}                ## item key -> its card
var comm_selected := ""             ## the selected item's key
var comm_car_look: TmCarVisual      ## the selected car (downloaded), turning in the detail panel
var _comm_after: Array = [""]       ## the pages so far: each one's "after" (back: pop)
var _comm_more := false
var _comm_gen := 0                  ## bumped on every listing: late answers for an old one are dropped
var _comm_grid: GridContainer
var _comm_scroll: ScrollContainer
var _comm_status: Label
var _comm_detail: VBoxContainer     ## the detail panel's body
var _comm_title: Label              ## its title bar
var _comm_nav: HBoxContainer
var _comm_state: Label              ## the selected item's state line (downloading, errors)
var _comm_busy := {}                ## item keys being downloaded
var _comm_pivot: Node3D             ## turns comm_car_look
## The column's rows: tab, name, icon; each tab's lists (pills over its cards): filter, name.
const COMM_TABS := [["cars", "Cars", "icon_car"], ["tracks", "Tracks", "icon_tracks"], ["mods", "Texture Mods", "icon_options"]]
const COMM_LISTS := {"cars": [["model", "Car Models"], ["skin", "Car Skins"], ["mine", "My Cars"]],
	"tracks": [["awards", "Top Tracks"], ["newest", "New Tracks"], ["downloads", "Popular Tracks"], ["mine", "My Tracks"]],
	"mods": [["tm1", "TMNF / TMUF"], ["maniaplanet", "ManiaPlanet"], ["mine", "My Mods"]]}
const COMM_SOURCES := {"cars": "ManiaPark", "tracks": "TrackMania Exchange", "mods": "ManiaPark"}
const COMM_CARD := Vector2(216, 150)   ## a card: its preview above, its name on a strip (5 across)
const COMM_PIC := Vector2(336, 189)    ## the selected one's preview (and its car turning, or the mod's textures)


## The Community page: Cars, Tracks and Texture Mods down the column; the selected
## one in the panel at the top (its big preview; a downloaded car turning beside it, a downloaded mod's
## textures; what it is; Download, Drive this car, Play, Wear this mod); the tab's lists as pills
## over the previews' cards (ManiaPark's car models and skins; TrackMania Exchange's tracks by awards,
## newest, downloads; ManiaPark's texture mods for TMNF/TMUF and ManiaPlanet; the ones downloaded),
## a search. A car driven is ours from then on (races, online, the profile's turntable), a Stadium
## mod worn dresses the Stadium; the downloads are kept (My Cars, My Tracks, My Mods).
func _page_community() -> void:
	if community == null:
		community = TmCommunity.new()
		add_child(community)
		var t := String(TestHooks.arg("community_tab", comm_tab))
		comm_tab = t if COMM_LISTS.has(t) else "cars"
	var root := _root("Community", "Cars, tracks and mods", "icon_browse")
	var focus: Button = null
	for tab: Array in COMM_TABS:
		var key := String(tab[0])
		var b := _row(String(tab[1]), String(tab[2]), func() -> void:
			if comm_tab != key:
				comm_tab = key
				comm_selected = ""
				_comm_after = [""]
				show_page("community"), false, comm_tab == key)
		if comm_tab == key:
			focus = b
	_row("Back", "icon_back", back, true)
	# the selected one
	_comm_detail = _panel(root, "", Rect2(RIGHT.position.x, TOP, RIGHT.size.x, 0))
	_comm_detail.custom_minimum_size.y = COMM_PIC.y
	_comm_title = _title_of(_comm_detail)
	# the list: its pills, the search, then the cards
	var list := _panel(root, String(COMM_TABS.filter(func(t: Array) -> bool: return t[0] == comm_tab)[0][1]) + "  ·  " + String(COMM_SOURCES[comm_tab]),
		Rect2(RIGHT.position.x, TOP + COMM_PIC.y + 96, RIGHT.size.x, 0))
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 10)
	list.add_child(pills)
	var group := ButtonGroup.new()
	for l: Array in COMM_LISTS[comm_tab]:
		var key := String(l[0])
		var pill := SfUi.button(String(l[1]), func() -> void:
			if comm_filter[comm_tab] != key:
				comm_filter[comm_tab] = key
				comm_selected = ""
				_comm_after = [""]
				comm_load(), 180)
		pill.toggle_mode = true
		pill.button_group = group
		pill.button_pressed = comm_filter[comm_tab] == key
		pill.add_theme_stylebox_override("pressed", SfUi.box("focus"))
		pills.add_child(pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pills.add_child(spacer)
	_comm_nav = HBoxContainer.new()
	_comm_nav.add_theme_constant_override("separation", 10)
	pills.add_child(_comm_nav)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	list.add_child(bar)
	var search := LineEdit.new()
	search.text = comm_text
	search.placeholder_text = "Search by name"
	search.custom_minimum_size = Vector2(320, 40)
	search.text_submitted.connect(func(t: String) -> void:
		comm_text = t.strip_edges()
		_comm_after = [""]
		comm_load())
	bar.add_child(search)
	bar.add_child(SfUi.button("Search", func() -> void:
		comm_text = search.text.strip_edges()
		_comm_after = [""]
		comm_load(), 140))
	_comm_status = _text("", 21, SfUi.DIM, SfUi.MEDIUM)
	_comm_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comm_status.add_theme_constant_override("outline_size", 0)
	bar.add_child(_comm_status)
	_comm_scroll = ScrollContainer.new()
	_comm_scroll.custom_minimum_size = Vector2(RIGHT.size.x - 36, 2 * COMM_CARD.y + 14)
	_comm_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_comm_scroll.follow_focus = true          # the pad's focus scrolls the list
	list.add_child(_comm_scroll)
	_comm_grid = GridContainer.new()
	_comm_grid.columns = 5
	_comm_grid.add_theme_constant_override("h_separation", 14)
	_comm_grid.add_theme_constant_override("v_separation", 14)
	_comm_scroll.add_child(_comm_grid)
	if focus:
		focus.grab_focus.call_deferred()
	comm_load()


## Lists the current page: a search on the site, or the library (My Cars, My Tracks).
func comm_load() -> void:
	_comm_gen += 1
	var gen := _comm_gen
	for c in _comm_grid.get_children():
		c.queue_free()
	comm_cards.clear()
	comm_items = []
	_comm_scroll.scroll_vertical = 0
	var filter: String = comm_filter[comm_tab]
	var r := {}
	if filter == "mine":
		community.library = TmCommunity.load_library()
		var items: Array = []
		var lib: Dictionary = community.library[comm_tab]
		for key: String in lib:
			var e: Dictionary = (lib[key] as Dictionary).duplicate()
			e["key"] = key
			e["id"] = key.trim_prefix("model_").trim_prefix("skin_").trim_prefix("mod_")
			if comm_text.is_empty() or String(e.get("name", "")).to_lower().contains(comm_text.to_lower()):
				items.append(e)
		r = {"items": items, "more": false, "error": ""}
		_comm_status.text = "Nothing downloaded yet" if items.is_empty() else ""
	else:
		_comm_status.text = "Loading ..."
		var after: String = _comm_after.back()
		if comm_tab == "cars":
			r = await community.search_cars(filter, comm_text, after)
		elif comm_tab == "mods":
			r = await community.search_mods(filter, comm_text, after)
		else:
			r = await community.search_tracks(comm_text, filter, after)
		if gen != _comm_gen or not is_instance_valid(_comm_grid):
			return
		_comm_status.text = "" if String(r.get("error", "")).is_empty() else ("%s: %s" % [COMM_SOURCES[comm_tab], String(r["error"])])
		if (r["items"] as Array).is_empty() and _comm_status.text.is_empty():
			_comm_status.text = "Nothing found"
		_comm_more = bool(r.get("more", false))
		if _comm_more:
			r["next"] = String(r.get("after", ""))
	comm_items = r["items"]
	for item: Dictionary in comm_items:
		var card := _comm_card(item, gen)
		_comm_grid.add_child(card)
		comm_cards[String(item["key"])] = card
	# paging
	for c in _comm_nav.get_children():
		c.queue_free()
	if _comm_after.size() > 1:
		_comm_nav.add_child(SfUi.button("Previous", func() -> void:
			_comm_after.pop_back()
			comm_load(), 150))
	if filter != "mine" and _comm_more:
		var next := String(r.get("next", ""))
		_comm_nav.add_child(SfUi.button("Next", func() -> void:
			_comm_after.append(next)
			comm_load(), 150))
	if not comm_items.is_empty():
		comm_select(comm_selected if comm_cards.has(comm_selected) else String(comm_items[0]["key"]))
	else:
		_comm_title.text = ""
		for c in _comm_detail.get_children():
			_comm_detail.remove_child(c)
			c.queue_free()


## An item's card as the Solo page's track cards: its preview above (it loads in after), its name
## below, a red frame when focused; a tick in the corner once downloaded, a star on the car we drive.
func _comm_card(item: Dictionary, gen: int) -> Button:
	var key := String(item["key"])
	var card := Button.new()
	card.custom_minimum_size = COMM_CARD
	card.tooltip_text = String(item.get("name", "")) + ("\nby %s" % String(item["author"]) if not String(item.get("author", "")).is_empty() else "")
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		card.add_theme_stylebox_override(st, SfUi.box("tile"))
	var back_pic := PanelContainer.new()
	back_pic.add_theme_stylebox_override("panel", SfUi.box("column"))
	back_pic.position = Vector2(2, 2)
	back_pic.size = Vector2(COMM_CARD.x - 4, COMM_CARD.y - 36)
	back_pic.clip_contents = true
	back_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(back_pic)
	var pic := TextureRect.new()
	pic.name = "Preview"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_pic.add_child(pic)
	var badge := _icon("check_on", 30)
	badge.name = "Badge"
	badge.position = Vector2(COMM_CARD.x - 40, 9)
	badge.size = Vector2(30, 30)
	card.add_child(badge)
	var name_l := SfUi.label(String(item.get("name", "")), 13, SfUi.DIM, SfUi.SEMI)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.clip_text = true
	name_l.position = Vector2(10, COMM_CARD.y - 33)
	name_l.size = Vector2(COMM_CARD.x - 20, 30)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_l)
	var lit := Panel.new()
	lit.add_theme_stylebox_override("panel", SfUi.box("tile_lit"))
	lit.set_anchors_preset(Control.PRESET_FULL_RECT)
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lit.visible = false
	card.add_child(lit)
	card.focus_entered.connect(func() -> void:
		lit.visible = true
		name_l.add_theme_color_override("font_color", SfUi.TEXT)
		comm_select(key))
	card.focus_exited.connect(func() -> void:
		lit.visible = false
		name_l.add_theme_color_override("font_color", SfUi.DIM))
	card.pressed.connect(func() -> void: comm_select(key))
	card.pressed.connect(TmUi.play.bind("click"))
	card.mouse_entered.connect(card.grab_focus)
	_comm_mark(card, key)
	_comm_preview(pic, String(item.get("image", "")), gen)
	return card


## A card's corner: a tick once downloaded, a star on the car we drive or the mod we wear.
func _comm_mark(card: Button, key: String) -> void:
	var badge := card.get_node_or_null("Badge") as TextureRect
	if badge == null:
		return
	var have: Dictionary = (community.library[comm_tab] as Dictionary).get(key, {})
	var setting: String = {"cars": "community_car", "mods": "community_mod"}.get(comm_tab, "")
	var driving: bool = not setting.is_empty() and not have.is_empty() and String(have.get("path", "")) == String(TmUi.setting(setting))
	badge.visible = not have.is_empty()
	badge.texture = TmUi.icon("star" if driving else "check_on")


func _comm_preview(pic: TextureRect, url: String, gen: int) -> void:
	if url.is_empty():
		return
	var tex: Texture2D = await community.image(url)
	if gen == _comm_gen and is_instance_valid(pic):
		pic.texture = tex


## Shows an item in the top panel: its name (the title bar), its big preview, a downloaded car turning
## beside it, its author, what it is, and what can be done with it.
func comm_select(key: String) -> void:
	var item := {}
	for it: Dictionary in comm_items:
		if String(it["key"]) == key:
			item = it
	if item.is_empty() or not is_instance_valid(_comm_detail):
		return
	comm_selected = key
	for c in _comm_detail.get_children():
		_comm_detail.remove_child(c)
		c.queue_free()
	comm_car_look = null
	_comm_pivot = null
	_comm_title.text = String(item.get("name", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_comm_detail.add_child(row)
	var back_pic := PanelContainer.new()
	back_pic.add_theme_stylebox_override("panel", SfUi.box("column"))
	back_pic.custom_minimum_size = COMM_PIC
	row.add_child(back_pic)
	var pic := TextureRect.new()
	pic.name = "Preview"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back_pic.add_child(pic)
	var lib: Dictionary = community.library[comm_tab]
	var have: Dictionary = lib.get(key, {})
	if comm_tab == "cars" and not have.is_empty():
		row.add_child(_comm_car_view(TmCarPack.load_zip(String(have.get("path", "")))))
	elif comm_tab == "mods" and not have.is_empty():
		row.add_child(_comm_mod_view(TmTextureMod.load_zip(String(have.get("path", "")), String(have.get("name", "")))))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	if not String(item.get("author", "")).is_empty():
		var by := _text("by %s" % String(item["author"]), 23, SfUi.TEXT, SfUi.SEMI)
		by.add_theme_constant_override("outline_size", 0)
		info.add_child(by)
	var facts: PackedStringArray = []
	if comm_tab == "tracks":
		if not String(item.get("type", "")).is_empty():
			facts.append(String(item["type"]).capitalize())
		if int(item.get("author_ms", -1)) > 0:
			facts.append("Author %s" % TmRace.time_text(int(item["author_ms"])))
		if int(item.get("awards", 0)) > 0:
			facts.append("%d awards" % int(item["awards"]))
		facts.append("TrackMania Exchange")
	elif comm_tab == "mods":
		var game := String(have.get("game", item.get("game", "")))
		facts.append("Texture mod")
		facts.append("ManiaPlanet" if game == "maniaplanet" else "TMNF / TMUF")
		if not String(have.get("environment", "")).is_empty():
			facts.append(String(have["environment"]))
		if int(have.get("textures", 0)) > 0:
			facts.append("%d textures" % int(have["textures"]))
		if int(item.get("downloads", 0)) > 0:
			facts.append("%d downloads" % int(item["downloads"]))
		facts.append("ManiaPark")
	else:
		facts.append("Car model" if String(item.get("kind", "")) == "model" else "Skin")
		if int(item.get("downloads", 0)) > 0:
			facts.append("%d downloads" % int(item["downloads"]))
		facts.append("ManiaPark")
	var facts_l := _text("  ·  ".join(facts), 20, SfUi.HOT, SfUi.BOLD)
	facts_l.add_theme_constant_override("outline_size", 0)
	facts_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(facts_l)
	var state := _text("Downloading ..." if _comm_busy.has(key) else "", 21, SfUi.DIM, SfUi.MEDIUM)
	state.name = "State"
	state.add_theme_constant_override("outline_size", 0)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comm_state = state
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	if comm_tab == "cars":
		var path := String(have.get("path", ""))
		var driving := not path.is_empty() and path == String(TmUi.setting("community_car"))
		if have.is_empty():
			actions.add_child(SfUi.button("Download", func() -> void: comm_download(key), 300))
		elif driving:
			state.text = "You drive this car"
			state.add_theme_color_override("font_color", SfUi.HOT)
		else:
			actions.add_child(SfUi.button("Drive this car", func() -> void: comm_drive(path), 300))
		if not String(TmUi.setting("community_car")).is_empty():
			actions.add_child(SfUi.button("Drive our own car", func() -> void: comm_drive(""), 300))
	elif comm_tab == "mods":
		var path := String(have.get("path", ""))
		var wearing := not path.is_empty() and path == String(TmUi.setting("community_mod"))
		if have.is_empty():
			actions.add_child(SfUi.button("Download", func() -> void: comm_download(key), 300))
		elif not bool(have.get("playable", false)):
			state.text = "Opens fine (%d textures); %s." % [int(have.get("textures", 0)), String(have.get("why", ""))]
		elif wearing:
			state.text = "The Stadium wears this mod"
			state.add_theme_color_override("font_color", SfUi.HOT)
		else:
			actions.add_child(SfUi.button("Wear this mod", func() -> void: comm_wear(path), 300))
		if not String(TmUi.setting("community_mod")).is_empty():
			actions.add_child(SfUi.button("Our own look", func() -> void: comm_wear(""), 300))
	else:
		if have.is_empty():
			actions.add_child(SfUi.button("Download", func() -> void: comm_download(key), 300))
		elif bool(have.get("playable", false)):
			var path := String(have["path"])
			actions.add_child(SfUi.button("Play", func() -> void: race("", path), 300))
		else:
			state.text = "Can't be raced here: %s" % String(have.get("why", ""))
	info.add_child(state)
	info.add_child(actions)
	var url := String(item.get("shot", item.get("image", "")))
	_comm_big_preview(pic, url, String(item.get("image", "")), key)


func _comm_big_preview(pic: TextureRect, url: String, small: String, key: String) -> void:
	var tex: Texture2D = await community.image(small)      # the card's, at once (cached)
	if is_instance_valid(pic) and comm_selected == key and tex:
		pic.texture = tex
	if url != small:
		tex = await community.image(url)
		if is_instance_valid(pic) and comm_selected == key and tex:
			pic.texture = tex


## A downloaded car as the game draws it, turning slowly in a little world of its own beside its
## preview (the menus show the globe, not the Stadium).
func _comm_car_view(pack: TmCarPack) -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = COMM_PIC
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.82, 0.86)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	_comm_pivot = Node3D.new()
	_comm_pivot.rotation.y = 0.7
	vp.add_child(_comm_pivot)
	comm_car_look = TmCarVisual.new()
	comm_car_look.paint_colour = TmUi.car_colour()
	comm_car_look.pack = pack
	_comm_pivot.add_child(comm_car_look)
	var cam := Camera3D.new()
	cam.fov = 30.0
	var eye := Vector3(0.0, 1.7, 5.9)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.5, 0.0) - eye), eye)
	vp.add_child(cam)
	return box


## Downloads a car or track into the library (and checks it).
func comm_download(key: String) -> void:
	var item := {}
	for it: Dictionary in comm_items:
		if String(it["key"]) == key:
			item = it
	if item.is_empty() or _comm_busy.has(key):
		return
	_comm_busy[key] = true
	if is_instance_valid(_comm_state) and comm_selected == key:
		_comm_state.text = "Downloading ..."
	var r: Dictionary = {}
	if comm_tab == "cars":
		r = await community.download_car(item)
	elif comm_tab == "mods":
		r = await community.download_mod(item)
	else:
		r = await community.download_track(item)
	_comm_busy.erase(key)
	if page != "community" or not is_instance_valid(_comm_detail):
		return
	var selected := comm_selected == key
	if not String(r.get("error", "")).is_empty():
		if selected and is_instance_valid(_comm_state):
			_comm_state.text = String(r["error"])
		return
	if comm_cards.has(key):      # its card says so now
		_comm_mark(comm_cards[key], key)
	if selected:
		comm_select(key)


## Drives a community car from now on ("" our own).
func comm_drive(path: String) -> void:
	TmCommunity.drive(path)
	for k: String in comm_cards:
		_comm_mark(comm_cards[k], k)
	comm_select(comm_selected)


## Wears a texture mod from now on ("" our own look): the next race's Stadium wears it.
func comm_wear(path: String) -> void:
	TmCommunity.wear(path)
	for k: String in comm_cards:
		_comm_mark(comm_cards[k], k)
	comm_select(comm_selected)


## A downloaded mod's textures beside its preview: the ones the Stadium takes first (road, grass,
## platform, circuit) for a Stadium mod, else its first four (it opened: they decoded).
func _comm_mod_view(mod: TmTextureMod) -> Control:
	var grid := GridContainer.new()
	grid.name = "ModTextures"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.custom_minimum_size = COMM_PIC
	if not mod.ok():
		return grid
	var names: Array = []
	for k: String in ["asphalt", "grass", "platform", "circuit_panel", "dirt", "fabric"]:
		var n := mod.first(TmMaterials.MOD_MAP[k][0])
		if not n.is_empty() and not names.has(n.to_lower()):
			names.append(n.to_lower())
	var all: Array = mod.images.keys()
	all.sort()
	for n: String in all:
		if names.size() >= 4:
			break
		if not names.has(n) and not n.contains("/") and not n.ends_with("n") and not n.ends_with("_n") and not n.ends_with("s"):
			names.append(n)
	for n: String in names.slice(0, 4):
		var t := TextureRect.new()
		t.texture = mod.texture(n)
		t.tooltip_text = String(mod.images.get(n, n)).get_file()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.clip_contents = true
		t.custom_minimum_size = Vector2((COMM_PIC.x - 4) / 2.0, (COMM_PIC.y - 4) / 2.0)
		grid.add_child(t)
	return grid
