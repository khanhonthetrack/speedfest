class_name TmEditor
extends Node3D
## The track editor (TMNF's Stadium editor, our own): the Stadium's 32 x 32 grid, TMNF's blocks in
## a palette by family, a ghost of the chosen block on the cursor (green: it fits, red: it doesn't),
## roads joining their neighbours by themselves, pillars under raised road; undo and redo; save;
## TEST drives the track (race/race.tscn, Esc / EDITOR comes back), and finishing it validates the
## track (its medals). Files: TmUserTracks (.sftrack in user://tracks).
## Mouse: left places (or erases in erase mode), right drag turns the view, middle drag (or Shift +
## right) pans, wheel zooms. Keys: R / Q / E turn the block, Page Up / Down (or Shift + wheel) the
## level, X erase mode, Del erases under the cursor, I picks the block under the cursor, WASD pans,
## Ctrl+Z / Ctrl+Y undo / redo, Ctrl+S save, F5 test, Esc leaves.
## Args: --edit=<file.sftrack> (else a new track), --editor_cursor=x,level,z (tests, screenshots).

const LEVEL_Y := 8.0
const CATEGORIES := [
	["ROADS", ["RoadMain", "RoadTilt", "Ramp", "Loop", "RoadStretch", "StretchTilt", "Bump"]],
	["PLATFORM", ["Platform", "Hole"]],
	["DIRT", ["RoadDirt", "Dirt"]],
	["CIRCUIT", ["Circuit"]],
	["TUBES", ["Tube", "CheckpointRing"]],
	["DECORATION", ["Control", "Inflatable", "Fabric", "Sculpt", "Airship"]],
	["WAYPOINTS", []],
]

var model: TmEditorModel
var path := ""                       ## the track's file ("" until saved)
var lib := TmBlockLib.new()
var selected := "StadiumRoadMain"
var rot := 0
var level := TmUserTracks.G
var erasing := false
var cursor := Vector3i(16, TmUserTracks.G, 16)
var category := 0
var palette := {}                    ## category index -> [block ids]
var message := ""

var _cam: Camera3D
var _target := Vector3(-16 * 32.0, 9.0, 16 * 32.0)
var _yaw := 0.7
var _pitch := -0.75
var _dist := 220.0
var _built := {}                     ## block key -> Node3D (what the map shows)
var _blocks_root: Node3D
var _ghost: Node3D
var _ghost_key := ""
var _ghost_ok := StandardMaterial3D.new()
var _ghost_bad := StandardMaterial3D.new()
var _grid: MeshInstance3D
var _box: MeshInstance3D
var _ui: Control
var _status: Label
var _info: Label
var _name_edit: LineEdit
var _pal_box: HBoxContainer
var _tabs: HBoxContainer
var _medals_l: Label


func _ready() -> void:
	TmUi.apply()
	Music.play_list("menu")
	path = String(TestHooks.arg("edit", ""))
	var t := TmUserTracks.load_file(path) if not path.is_empty() else {}
	if t.is_empty():
		path = ""
	model = TmEditorModel.new(t)
	TmStadiumEnv.add(self)
	add_child(TmStadiumBuild.build())
	var field := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024, 1024)
	field.mesh = pm
	field.material_override = TmMaterials.get_material("grass")
	field.position = Vector3(-512.0, 9.0, 512.0)
	add_child(field)
	_blocks_root = Node3D.new()
	_blocks_root.name = "Blocks"
	add_child(_blocks_root)
	for m: StandardMaterial3D in [_ghost_ok, _ghost_bad]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_ok.albedo_color = Color(0.45, 1.0, 0.3, 0.42)
	_ghost_bad.albedo_color = Color(1.0, 0.25, 0.2, 0.42)
	_make_grid()
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = TmSkyline.FAR
	add_child(_cam)
	_cam.current = true
	_palette()
	_build_ui()
	if TestHooks.has_arg("editor_cursor"):
		var c := String(TestHooks.arg("editor_cursor", "")).split(",")
		if c.size() == 3:
			cursor = Vector3i(int(c[0]), int(c[1]), int(c[2]))
			level = cursor.y
			_target = cell_centre(cursor)
	rebuild()
	_place_camera()
	_update_cursor()


# --- the grid ----------------------------------------------------------------------------------

## A cell's centre on its level's floor (Godot).
static func cell_centre(c: Vector3i) -> Vector3:
	return Vector3(-(c.x + 0.5) * 32.0, c.y * LEVEL_Y + 1.0, (c.z + 0.5) * 32.0)


## The cell under a point at a level.
static func cell_of(p: Vector3, lvl: int) -> Vector3i:
	return Vector3i(floori(-p.x / 32.0), lvl, floori(p.z / 32.0))


func _make_grid() -> void:
	_grid = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024, 1024)
	_grid.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 line_colour : source_color = vec4(0.8, 1.0, 0.5, 0.32);
uniform vec3 centre = vec3(0.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// the cell lines, thin at any distance, fading out away from the cursor
	vec2 g = abs(fract(world.xz / 32.0 + 0.5) - 0.5) * 32.0;
	float w = fwidth(world.x) * 1.0 + 0.05;
	float line = 1.0 - smoothstep(0.0, w, min(g.x, g.y));
	float near = 1.0 - smoothstep(90.0, 230.0, distance(world.xz, centre.xz));
	ALBEDO = line_colour.rgb;
	ALPHA = (line * line_colour.a + 0.025) * near;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_grid.material_override = mat
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)
	_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(32.0, LEVEL_Y, 32.0)
	_box.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1, 1, 1, 0.12)
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box.material_override = bmat
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_box)


# --- what the map shows -------------------------------------------------------------------------

static func _key(b: Dictionary) -> String:
	var c: Vector3i = b["coord"]
	return "%s|%d|%d,%d,%d|%d|%d" % [b["name"], int(b["dir"]), c.x, c.y, c.z, int(b["flags"]), int(b["ground"])]


## Rebuilds what changed: road variants and pillars follow from the blocks
## (TmUserTracks.challenge_blocks); blocks whose shape, place or variant is unchanged stay.
func rebuild() -> void:
	var want := {}
	for b: Dictionary in TmUserTracks.challenge_blocks(model.track):
		want[_key(b)] = b
	for k: String in _built.keys():
		if not want.has(k):
			(_built[k] as Node3D).queue_free()
			_built.erase(k)
	for k: String in want:
		if _built.has(k):
			continue
		var n := _make_block(want[k])
		if n != null:
			_blocks_root.add_child(n)
			_built[k] = n
	_refresh_status()


func _make_block(b: Dictionary) -> Node3D:
	var entry := TmBlockCatalogue.info(String(b["name"]))
	var ground := bool(b["ground"])
	var flags := int(b["flags"])
	var shape := TmBlockCatalogue.shape_name(entry, ground, flags & 0x3F, (flags >> 6) & 0x3F)
	var n := lib.make(shape, entry, ground)
	if n == null:
		return null
	n.transform = TmBlockCatalogue.block_transform(entry, b["coord"], int(b["dir"]), ground)
	n.set_meta("coord", b["coord"])
	return n


## The ghost of the selected block at the cursor, green where it fits, red where it doesn't.
func _update_ghost() -> void:
	var coord := TmEditorModel.anchor(selected, rot, cursor)
	var entry := TmBlockCatalogue.info(selected)
	var ground := coord.y == TmUserTracks.G and TmUserTracks.has_ground(selected)
	var key := "%s|%d|%d" % [selected, rot, int(ground)]
	if key != _ghost_key:
		if _ghost:
			_ghost.queue_free()
		_ghost = null
		_ghost_key = key
		var group := 3 if TmUserTracks.is_road(selected) else 0     # a road shows as a straight
		var shape := TmBlockCatalogue.shape_name(entry, ground, group, 0)
		var n := lib.make(shape, entry, ground)
		if n != null:
			_strip(n)
			_ghost = n
			add_child(_ghost)
	if _ghost == null:
		return
	_ghost.visible = not erasing
	_ghost.transform = TmBlockCatalogue.block_transform(entry, coord, rot, ground)
	var why := model.why_not(selected, rot, coord)
	_paint(_ghost, _ghost_ok if why.is_empty() else _ghost_bad)
	message = why


## A ghost has no collision (picking and the camera ignore it) and one translucent material.
func _strip(n: Node) -> void:
	for c in n.get_children():
		if c is CollisionObject3D:
			n.remove_child(c)
			c.queue_free()
		else:
			_strip(c)


func _paint(n: Node, m: Material) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_override = m
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_paint(c, m)


# --- the palette ----------------------------------------------------------------------------------

## The blocks the editor offers, by category: catalogue blocks whose shapes are recreated (no
## terrain zones or auto clips), most used in TMNF's campaign first; waypoints also in the last.
func _palette() -> void:
	palette = palette_ids(lib)


static func palette_ids(library: TmBlockLib) -> Dictionary:
	var out := {}
	var ids: Array = TmBlockCatalogue.data().keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ua := int(TmBlockCatalogue.info(a).get("campaign_uses", 0))
		var ub := int(TmBlockCatalogue.info(b).get("campaign_uses", 0))
		return ua > ub or (ua == ub and a < b))
	for i in CATEGORIES.size():
		out[i] = []
	for id: String in ids:
		if icon_shape(id).is_empty() or not library.handles(icon_shape(id)):
			continue
		var cat := category_of(id)
		if cat >= 0:
			(out[cat] as Array).append(id)
		if TmEditorModel.waypoint(id) != TmBlockCatalogue.Waypoint.NONE:
			(out[CATEGORIES.size() - 1] as Array).append(id)
	return out


## The shape a block shows in the palette and as a ghost (a road as a straight; the air variant,
## else the ground one); "" for blocks the editor doesn't offer (terrain zones, auto clips).
static func icon_shape(id: String) -> String:
	var entry := TmBlockCatalogue.info(id)
	var kind := String(entry.get("kind", ""))
	if kind not in ["classic", "road", "rectasym"]:
		return ""
	var group := 3 if kind == "road" else 0
	var shape := TmBlockCatalogue.shape_name(entry, false, group, 0)
	return shape if not shape.is_empty() else TmBlockCatalogue.shape_name(entry, true, group, 0)


static func category_of(id: String) -> int:
	var n := id.trim_prefix("Stadium")
	var best := -1
	var best_len := 0
	for i in CATEGORIES.size():
		for p: String in CATEGORIES[i][1]:
			if n.begins_with(p) and p.length() > best_len:
				best = i
				best_len = p.length()
	return best


## A block's name for the palette: its words without "Stadium" and its family's.
static func display_name(id: String) -> String:
	var n := id.trim_prefix("Stadium")
	for p: String in ["RoadMain", "RoadDirt", "Platform", "Circuit"]:
		if n.begins_with(p) and n.length() > p.length():
			n = n.trim_prefix(p)
			break
	var words := ""
	for i in n.length():
		var ch := n[i]
		if i > 0 and ch != ch.to_lower() and n[i - 1] == n[i - 1].to_lower():
			words += " "
		elif i > 0 and ch.is_valid_int() and not n[i - 1].is_valid_int():
			words += " "
		words += ch
	return words.strip_edges()


func select_block(id: String) -> void:
	selected = id
	erasing = false
	_ghost_key = ""
	_update_cursor()
	_fill_palette()


# --- the camera and the cursor ------------------------------------------------------------------

func _place_camera() -> void:
	_pitch = clampf(_pitch, -1.45, -0.12)
	_dist = clampf(_dist, 30.0, 900.0)
	var off := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.global_transform = Transform3D(Basis(), _target + off).looking_at(_target, Vector3.UP)


func _update_cursor() -> void:
	cursor.y = level
	_grid.position = Vector3(-512.0, level * LEVEL_Y + 1.02, 512.0)
	(_grid.material_override as ShaderMaterial).set_shader_parameter("centre", cell_centre(cursor))
	_box.position = Vector3(-(cursor.x + 0.5) * 32.0, level * LEVEL_Y + LEVEL_Y * 0.5, (cursor.z + 0.5) * 32.0)
	_update_ghost()
	_refresh_info()


func _mouse_cell(screen: Vector2) -> Vector3i:
	var from := _cam.project_ray_origin(screen)
	var dir := _cam.project_ray_normal(screen)
	var y := level * LEVEL_Y + 1.0
	if absf(dir.y) < 1e-4:
		return cursor
	var t := (y - from.y) / dir.y
	if t <= 0.0:
		return cursor
	var c := cell_of(from + dir * t, level)
	c.x = clampi(c.x, 0, TmUserTracks.MAP - 1)
	c.z = clampi(c.z, 0, TmUserTracks.MAP - 1)
	return c


## The placed block under the mouse (its cell), by a ray against the blocks; else the cursor's cell.
func _pick_cell(screen: Vector2) -> Vector3i:
	var from := _cam.project_ray_origin(screen)
	var to := from + _cam.project_ray_normal(screen) * 3000.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if not hit.is_empty():
		var p: Vector3 = hit["position"] - (hit["normal"] as Vector3) * 0.2
		var c := Vector3i(floori(-p.x / 32.0), floori(p.y / LEVEL_Y), floori(p.z / 32.0))
		if not model.block_at(c).is_empty():
			return c
	return cursor


# --- actions --------------------------------------------------------------------------------------

func place() -> bool:
	var coord := TmEditorModel.anchor(selected, rot, cursor)
	if model.place(selected, rot, coord):
		TmUi.play("click")
		rebuild()
		_update_ghost()              # the cell is taken now: the ghost turns red, the reason shows
		_refresh_info()
		return true
	message = model.why_not(selected, rot, coord)
	_refresh_info()
	return false


func erase(c: Vector3i) -> bool:
	if model.erase_at(c):
		TmUi.play("move")
		rebuild()
		_update_ghost()
		return true
	return false


## Picks the block under the cursor as the one to place (TMNF's eyedropper).
func pick(c: Vector3i) -> void:
	var b := model.block_at(c)
	if b.is_empty():
		return
	rot = int(b[1])
	select_block(String(b[0]))
	for i in CATEGORIES.size():
		if (palette[i] as Array).has(selected) and i != CATEGORIES.size() - 1:
			category = i
	_fill_tabs()
	_fill_palette()


func undo() -> void:
	if model.undo():
		rebuild()
		_update_ghost()


func redo() -> void:
	if model.redo():
		rebuild()
		_update_ghost()


## Saves the track (to its file, or a new one named after it). Returns false if it couldn't.
func save() -> bool:
	model.track["name"] = _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "My Track"
	if String(model.track.get("author", "")).is_empty():
		model.track["author"] = String(TmUi.setting("name"))
	if path.is_empty():
		path = TmUserTracks.path_for(model.track)
	var ok := TmUserTracks.save(model.track, path)
	if ok:
		model.dirty = false
	message = ("Saved to %s" % path.get_file()) if ok else "Couldn't save"
	_refresh_status()
	_refresh_info()
	return ok


## Drives the track (saved first): the race comes back here.
func test() -> void:
	var lack := model.missing()
	if not lack.is_empty():
		message = lack + " to test the track"
		_refresh_info()
		return
	if not save():
		return
	TestHooks.args.erase("track")
	TestHooks.args["map"] = path
	TestHooks.args["back"] = "editor"
	if get_tree().current_scene == self:
		TmLoading.change_scene(get_tree(), "res://race/race.tscn")


func leave() -> void:
	if model.dirty and not message.begins_with("Unsaved"):
		message = "Unsaved changes: Esc again leaves without saving, Ctrl+S saves"
		_refresh_info()
		return
	TestHooks.args.erase("back")
	TestHooks.args["page"] = "editors"
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://ui/menu.tscn")


# --- input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var turn := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_key_pressed(KEY_SHIFT)
		var pan := Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.is_key_pressed(KEY_SHIFT))
		if turn:
			_yaw -= mm.relative.x * 0.006
			_pitch -= mm.relative.y * 0.005
			_place_camera()
		elif pan:
			var right := _cam.global_basis.x
			var fwd := Vector3(-_cam.global_basis.z.x, 0.0, -_cam.global_basis.z.z).normalized()
			_target += (-right * mm.relative.x + fwd * mm.relative.y) * _dist * 0.0015
			_place_camera()
		var c := _mouse_cell(mm.position)
		if c != cursor:
			cursor = c
			_update_cursor()
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				cursor = _mouse_cell(mb.position)
				if erasing:
					erase(_pick_cell(mb.position))
				else:
					place()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
				if mb.shift_pressed:
					set_level(level + (1 if up else -1))
				else:
					_dist *= 0.88 if up else 1.0 / 0.88
					_place_camera()
		return
	if not (event is InputEventKey and event.pressed):
		return
	var k := event as InputEventKey
	if k.echo and k.keycode not in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_R]:
		return                       # held keys repeat only the moves (Esc twice must be two presses)
	var ctrl := k.ctrl_pressed or k.meta_pressed
	match k.keycode:
		KEY_R, KEY_E:
			turn_block(1)
		KEY_Q:
			turn_block(-1)
		KEY_PAGEUP:
			set_level(level + 1)
		KEY_PAGEDOWN:
			set_level(level - 1)
		KEY_X:
			erasing = not erasing
			_update_cursor()
		KEY_DELETE, KEY_BACKSPACE:
			erase(cursor)
		KEY_I:
			pick(cursor)
		KEY_Z:
			if ctrl:
				if k.shift_pressed:
					redo()
				else:
					undo()
		KEY_Y:
			if ctrl:
				redo()
		KEY_S:
			if ctrl:
				save()
			else:
				_pan(Vector3(0, 0, 1))
		KEY_F5:
			test()
		KEY_ESCAPE:
			leave()
		KEY_W:
			_pan(Vector3(0, 0, -1))
		KEY_A:
			_pan(Vector3(-1, 0, 0))
		KEY_D:
			_pan(Vector3(1, 0, 0))
		_:
			return
	get_viewport().set_input_as_handled()


func turn_block(step: int) -> void:
	rot = posmod(rot + step, 4)
	_update_cursor()


func set_level(l: int) -> void:
	level = clampi(l, TmUserTracks.G, TmUserTracks.MAX_LEVEL)
	_update_cursor()


func _pan(v: Vector3) -> void:
	var b := _cam.global_basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	_target += (right * v.x - fwd * v.z) * 32.0
	_place_camera()


# --- the interface ------------------------------------------------------------------------------

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_ui = Control.new()
	_ui.theme = TmUi.theme()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_ui)
	# the bar across the top: what this is, the track's name, its medals, the tools
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", TmUi.glass("bar"))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 76
	_ui.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	row.add_child(TmUi.label("TRACK EDITOR", 22, TmUi.ACCENT, TmUi.HEAD, 3))
	_name_edit = LineEdit.new()
	_name_edit.text = String(model.track.get("name", "My Track"))
	_name_edit.custom_minimum_size = Vector2(260, 46)
	_name_edit.max_length = 40
	_name_edit.text_changed.connect(func(t: String) -> void:
		model.track["name"] = t.strip_edges()
		model.dirty = true)
	row.add_child(_name_edit)
	_medals_l = TmUi.label("", 20, TmUi.DIM, TmUi.BOLD, 1)
	_medals_l.custom_minimum_size.x = 200
	_medals_l.clip_text = true
	_medals_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_medals_l)
	for b: Array in [["UNDO", undo], ["REDO", redo], ["ERASE", func() -> void:
			erasing = not erasing
			_update_cursor()], ["SAVE", save], ["TEST", test], ["EXIT", leave]]:
		var btn := TmUi.button(String(b[0]), b[1], 96)
		btn.add_theme_font_size_override("font_size", 22)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		if b[0] == "TEST":
			TmUi.go(btn)
		row.add_child(btn)
	# the palette along the bottom: the families, then their blocks
	var pal := PanelContainer.new()
	pal.add_theme_stylebox_override("panel", TmUi.glass("bar"))
	pal.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pal.offset_top = -196
	_ui.add_child(pal)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	pal.add_child(col)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	col.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 124
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_pal_box = HBoxContainer.new()
	_pal_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_pal_box)
	# the state at the left: level, turn, mode, the message; the keys
	var state := PanelContainer.new()
	state.add_theme_stylebox_override("panel", TmUi.glass("panel"))
	state.position = Vector2(20, 92)
	_ui.add_child(state)
	_info = TmUi.label("", 20, TmUi.TEXT, TmUi.BOLD, 1)
	state.add_child(_info)
	var help := PanelContainer.new()
	help.add_theme_stylebox_override("panel", TmUi.glass("panel"))
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.offset_left = -600
	help.offset_right = -20
	help.offset_top = 92
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(help)
	_status = TmUi.label("", 17, TmUi.DIM, TmUi.BOLD, 1)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_child(_status)
	_fill_tabs()
	_fill_palette()


func _fill_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for i in CATEGORIES.size():
		var b := TmUi.button(String(CATEGORIES[i][0]), Callable(), 140)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == category
		b.custom_minimum_size.y = 40
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func() -> void:
			category = i
			_fill_palette())
		_tabs.add_child(b)


func _fill_palette() -> void:
	if _pal_box == null:
		return
	for c in _pal_box.get_children():
		c.queue_free()
	for id: String in palette.get(category, []):
		var b := TmUi.button(display_name(id), Callable(), 0)
		b.custom_minimum_size = Vector2(150, 116)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = id
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_constant_override("icon_max_width", 120)
		b.add_theme_stylebox_override("normal", TmUi.glass("tm_tile"))
		b.add_theme_stylebox_override("hover", TmUi.glass("tm_tile_lit"))
		b.add_theme_stylebox_override("pressed", TmUi.glass("tm_tile_lit"))
		var icon := "res://assets/ui/blocks/%s.png" % id
		if ResourceLoader.exists(icon):
			b.icon = load(icon)
			b.expand_icon = true
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if id == selected and not erasing:
			b.add_theme_stylebox_override("normal", TmUi.glass("tm_tile_lit"))
			b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(func() -> void: select_block(id))
		_pal_box.add_child(b)


func _refresh_info() -> void:
	if _info == null:
		return
	var lines := ["LEVEL  %d" % (level - TmUserTracks.G), "TURN  %d°" % (rot * 90), "MODE  %s" % ("ERASE" if erasing else "PLACE"),
		"BLOCK  %s" % display_name(selected)]
	if not message.is_empty():
		lines.append("")
		lines.append(message)
	_info.text = "\n".join(lines)


func _refresh_status() -> void:
	if _medals_l == null:
		return
	var t := model.track
	var m: Dictionary = t.get("medals", {})
	_medals_l.text = ("AUTHOR %s   GOLD %s" % [TmRace.time_text(int(m["author"])), TmRace.time_text(int(m["gold"]))]) \
		if TmUserTracks.is_validated(t) else "NOT VALIDATED: TEST IT TO THE FINISH"
	_status.text = "%d BLOCKS%s\nLEFT PLACE   RIGHT TURN VIEW   WHEEL ZOOM   SHIFT+WHEEL LEVEL\nR / Q TURN BLOCK   X ERASE   I PICK   CTRL+Z UNDO   F5 TEST" % [
		(t["blocks"] as Array).size(), "   ·   UNSAVED" if model.dirty else ""]
