class_name TmLoading
extends CanvasLayer
## TMNF's loading screen (M10-5, drawn after TMNF's side by side): over a blurred picture of our
## car on a track, a keyboard with the race's keys lit orange (Esc, 1 2 3, Backspace and Delete,
## Enter, the arrows), each pointed at by a blue arrow from a white label (MENU, CHANGE VIEW,
## RESTART, RESPAWN, DRIVE), and an orange progress bar in a dark frame under it. Shown while a
## scene loads: TmLoading.change_scene(tree, path) puts it up, lets it draw, changes the scene, and
## when the new scene is in, fills the bar and fades out. A race holds its countdown while it covers
## the screen (covering()). --loading=hold keeps it up (screenshots).

const BG := "res://assets/ui/loading_bg.jpg"
const ORANGE_TOP := Color(1.0, 0.80, 0.28)
const ORANGE := Color(0.96, 0.58, 0.04)
const ORANGE_DARK := Color(0.80, 0.42, 0.0)
const KEY := Color(0.27, 0.28, 0.29)
const LABEL_BLUE := Color(0.08, 0.32, 0.72)
const ARROW_BLUE := Color(0.12, 0.30, 0.78)
const MIN_SHOWN_S := 1.2             ## up at least this long (a fast load doesn't just flash)

## Where the keyboard is (1600 x 900 canvas), its key pitch and size.
const BOARD := Rect2(206, 222, 1192, 288)
const PITCH := 58.0
const ROW := 43.5
const KEY_H := 32.0

static var _current: TmLoading

var progress := 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		if _bar:
			_bar.queue_redraw()
var _bar: Control
var _old: Node
var _shown_ms := 0
var _done := false


## Puts the loading screen up, then changes to the scene at path once it has been drawn.
static func change_scene(tree: SceneTree, path: String) -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	var l := TmLoading.new()
	tree.root.add_child(l)
	l._go(path)


## True while a loading screen covers the screen, its fade included (the race waits with its
## countdown until the track shows).
static func covering() -> bool:
	return is_instance_valid(_current) and not _current.is_queued_for_deletion()


func _ready() -> void:
	_current = self
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shown_ms = Time.get_ticks_msec()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP     # nothing under it takes clicks meanwhile
	root.theme = TmUi.theme()
	add_child(root)
	var black := ColorRect.new()
	black.color = Color(0.02, 0.02, 0.03)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(black)
	if ResourceLoader.exists(BG):
		var bg := TextureRect.new()
		bg.texture = load(BG)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)
	var board := Control.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.draw.connect(_draw_board.bind(board))
	root.add_child(board)
	for l: Array in _labels():
		var box := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1, 0.97)
		st.border_color = Color(0.55, 0.7, 0.55, 0.9)
		st.set_border_width_all(1)
		st.set_corner_radius_all(3)
		st.shadow_color = Color(0, 0, 0, 0.25)
		st.shadow_size = 3
		box.add_theme_stylebox_override("panel", st)
		box.position = (l[1] as Rect2).position
		box.size = (l[1] as Rect2).size
		root.add_child(box)
		var t := TmUi.label(String(l[0]), 22, LABEL_BLUE, "cabin-latin-500-italic")
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 0)
		box.add_child(t)
	_bar = Control.new()
	_bar.position = Vector2(254, 686)
	_bar.size = Vector2(1090, 50)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	root.add_child(_bar)


func _exit_tree() -> void:
	if _current == self:
		_current = null


func _go(path: String) -> void:
	_old = get_tree().current_scene
	progress = 0.12
	# two frames: the loading screen is on screen before the (blocking) load starts
	await get_tree().process_frame
	await get_tree().process_frame
	progress = 0.35
	await get_tree().process_frame
	get_tree().change_scene_to_file(path)


func _process(_delta: float) -> void:
	if _done or TestHooks.arg("loading", "") == "hold":
		return
	var scene := get_tree().current_scene
	if scene == null or scene == _old or not scene.is_node_ready():
		return
	_done = true
	var wait := maxf(0.0, MIN_SHOWN_S - (Time.get_ticks_msec() - _shown_ms) / 1000.0)
	var tw := create_tween()
	tw.tween_property(self, "progress", 1.0, 0.35 + wait)
	tw.tween_interval(0.1)
	var root := get_child(0) as Control
	tw.tween_property(root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## The keys of a European keyboard (rows of [label, width in keys]; "" = a blank key), the
## function row's groups, the arrows and the block above them; returns [rect, lit, label] per key.
static func keys() -> Array:
	var out := []
	var lit := {"Esc": true, "1": true, "2": true, "3": true, "Back": true, "Enter": true, "Del": true,
		"Up": true, "Left": true, "Down": true, "Right": true}
	var x0 := BOARD.position.x + 32.0
	var y0 := BOARD.position.y + 20.0
	# the function row: Esc, then three groups of four
	out.append(_key(Rect2(x0, y0, PITCH - 10, KEY_H), "Esc", lit))
	for g in 3:
		for i in 4:
			out.append(_key(Rect2(x0 + PITCH * (1.5 + g * 4.4 + i), y0, PITCH - 10, KEY_H), "", lit))
	var rows := [
		[["`", 1], ["1", 1], ["2", 1], ["3", 1], ["4", 1], ["5", 1], ["6", 1], ["7", 1], ["8", 1], ["9", 1], ["0", 1], ["-", 1], ["=", 1], ["Back", 2]],
		[["Tab", 1.5], ["Q", 1], ["W", 1], ["E", 1], ["R", 1], ["T", 1], ["Y", 1], ["U", 1], ["I", 1], ["O", 1], ["P", 1], ["[", 1], ["]", 1], ["Enter", 1.5]],
		[["Caps", 1.75], ["A", 1], ["S", 1], ["D", 1], ["F", 1], ["G", 1], ["H", 1], ["J", 1], ["K", 1], ["L", 1], [";", 1], ["'", 1], ["#", 1], ["", 1.25]],
		[["Shift", 1.25], ["\\", 1], ["Z", 1], ["X", 1], ["C", 1], ["V", 1], ["B", 1], ["N", 1], ["M", 1], [",", 1], [".", 1], ["/", 1], ["Shift", 2.75]],
		[["Ctrl", 1.25], ["Win", 1.25], ["Alt", 1.25], ["Space", 6.25], ["AltGr", 1.25], ["Win", 1.25], ["Menu", 1.25], ["Ctrl", 1.25]],
	]
	for r in rows.size():
		var x := x0
		var y := y0 + ROW * (r + 1) + 6.0
		for k: Array in rows[r]:
			var w := PITCH * float(k[1]) - 10.0
			var kname := String(k[0])
			if kname == "Enter":         # the tall Enter of a European keyboard, over two rows
				out.append(_key(Rect2(x + PITCH * 0.25, y, PITCH * 1.25 - 10.0, ROW + KEY_H), kname, lit))
			elif not (r == 2 and k == rows[2][-1]):
				out.append(_key(Rect2(x, y, w, KEY_H), kname, lit))
			x += PITCH * float(k[1])
	# the block over the arrows (Ins Home PgUp / Del End PgDn) and the arrows
	var bx := x0 + PITCH * 15.4
	for r in 2:
		for i in 3:
			var kname: String = ["Ins", "Home", "PgUp", "Del", "End", "PgDn"][r * 3 + i]
			out.append(_key(Rect2(bx + PITCH * i, y0 + ROW * (r + 1) + 6.0, PITCH - 10, KEY_H), kname, lit))
	out.append(_key(Rect2(bx + PITCH, y0 + ROW * 4 + 6.0, PITCH - 10, KEY_H), "Up", lit))
	for i in 3:
		out.append(_key(Rect2(bx + PITCH * i, y0 + ROW * 5 + 6.0, PITCH - 10, KEY_H), ["Left", "Down", "Right"][i], lit))
	return out


static func _key(r: Rect2, kname: String, lit: Dictionary) -> Array:
	return [r, lit.has(kname), kname]


## The labels: [text, box, the key it points at].
static func _labels() -> Array:
	return [["MENU", Rect2(27, 115, 321, 62), "Esc"], ["CHANGE VIEW", Rect2(400, 115, 321, 62), "3"],
		["RESTART", Rect2(902, 115, 321, 62), "Back"], ["RESPAWN", Rect2(865, 564, 321, 62), "Enter"],
		["DRIVE", Rect2(1240, 564, 321, 62), "Right"]]


func _draw_board(c: Control) -> void:
	# the keyboard: a light grey glossy slab
	var slab := StyleBoxFlat.new()
	slab.bg_color = Color(0.90, 0.91, 0.92, 0.97)
	slab.border_color = Color(0.55, 0.57, 0.6)
	slab.set_border_width_all(2)
	slab.set_corner_radius_all(10)
	slab.shadow_color = Color(0, 0, 0, 0.35)
	slab.shadow_size = 8
	c.draw_style_box(slab, BOARD)
	c.draw_rect(Rect2(BOARD.position + Vector2(6, 4), Vector2(BOARD.size.x - 12, BOARD.size.y * 0.42)), Color(1, 1, 1, 0.35))
	var font := TmUi.font(TmUi.SANS_BOLD)
	var key_by_name := {}
	for k: Array in keys():
		var r: Rect2 = k[0]
		key_by_name[k[2]] = r
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(3)
		if k[1]:
			st.bg_color = ORANGE
			st.border_color = ORANGE_DARK
			st.set_border_width_all(1)
			st.shadow_color = Color(0, 0, 0, 0.3)
			st.shadow_size = 2
		else:
			st.bg_color = KEY
			st.border_color = Color(0.5, 0.52, 0.55)
			st.set_border_width_all(1)
		c.draw_style_box(st, r)
		if k[1]:
			c.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.4)), Color(ORANGE_TOP, 0.55))
			_glyph(c, font, String(k[2]), r)
	# the brand where TMNF has its logo: ours, small
	c.draw_string(font, Vector2(BOARD.position.x + 32.0 + PITCH * 15.4, BOARD.position.y + 20.0 + ROW * 3 + 32.0), "SPEEDFEST",
		HORIZONTAL_ALIGNMENT_CENTER, PITCH * 3 - 10, 15, Color(0.3, 0.3, 0.32))
	# the arrows from the labels to their keys
	for l: Array in _labels():
		var box: Rect2 = l[1]
		var kr: Rect2 = key_by_name.get(l[2], Rect2())
		var x := kr.get_center().x
		var above := box.position.y < kr.position.y
		var from := Vector2(x, box.end.y) if above else Vector2(x, box.position.y)
		var to := Vector2(x, kr.position.y + 2.0) if above else Vector2(x, kr.end.y - 2.0)
		if absf(x - box.get_center().x) > box.size.x * 0.5 - 12:      # the key isn't under the box: bend
			from.x = clampf(x, box.position.x + 20, box.end.x - 20)
		_arrow(c, from, to)


## A lit key's mark: its number or an arrow.
func _glyph(c: Control, font: Font, kname: String, r: Rect2) -> void:
	var ink := Color(0.15, 0.1, 0.02)
	var mid := r.get_center()
	match kname:
		"1", "2", "3":
			c.draw_string(font, Vector2(r.position.x, mid.y + 7), kname, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, ink)
		"Up", "Down", "Left", "Right":
			var d: Vector2 = {"Up": Vector2.UP, "Down": Vector2.DOWN, "Left": Vector2.LEFT, "Right": Vector2.RIGHT}[kname]
			var s := Vector2(-d.y, d.x)
			c.draw_colored_polygon(PackedVector2Array([mid + d * 7, mid - d * 3 + s * 6, mid - d * 3 - s * 6]), ink)
			c.draw_line(mid - d * 3, mid - d * 8, ink, 3.0)
		"Back":
			c.draw_line(mid + Vector2(14, 0), mid - Vector2(10, 0), ink, 2.5)
			c.draw_colored_polygon(PackedVector2Array([mid - Vector2(16, 0), mid - Vector2(8, 5), mid - Vector2(8, -5)]), ink)
		"Enter":
			var e := Vector2(mid.x + 10, mid.y - 2)
			c.draw_line(e + Vector2(0, -10), e, ink, 2.5)
			c.draw_line(e, e - Vector2(18, 0), ink, 2.5)
			c.draw_colored_polygon(PackedVector2Array([e - Vector2(24, 0), e - Vector2(16, 5), e - Vector2(16, -5)]), ink)
		"Esc", "Del":
			c.draw_string(font, Vector2(r.position.x, mid.y + 6), kname, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, ink)


func _arrow(c: Control, from: Vector2, to: Vector2) -> void:
	var d := (to - from).normalized()
	var tip := to - d * 4.0
	c.draw_line(from, tip - d * 10.0, ARROW_BLUE, 5.0)
	var s := Vector2(-d.y, d.x)
	c.draw_colored_polygon(PackedVector2Array([tip, tip - d * 14.0 + s * 9.0, tip - d * 14.0 - s * 9.0]), ARROW_BLUE)


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.06, 0.06, 0.07, 0.92)
	frame.border_color = Color(0.45, 0.46, 0.48)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(25)
	frame.shadow_color = Color(0, 0, 0, 0.4)
	frame.shadow_size = 4
	_bar.draw_style_box(frame, r)
	var inner := r.grow(-9.0)
	var fill := Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * progress), inner.size.y))
	var st := StyleBoxFlat.new()
	st.bg_color = ORANGE
	st.set_corner_radius_all(16)
	st.border_color = ORANGE_DARK
	st.set_border_width_all(1)
	_bar.draw_style_box(st, fill)
	# the gloss: a light band over its top half
	var gl := StyleBoxFlat.new()
	gl.bg_color = Color(ORANGE_TOP, 0.75)
	gl.set_corner_radius_all(10)
	_bar.draw_style_box(gl, Rect2(fill.position + Vector2(8, 3), Vector2(maxf(0.0, fill.size.x - 16), fill.size.y * 0.38)))
