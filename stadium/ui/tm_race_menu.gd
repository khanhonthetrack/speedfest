class_name TmRaceMenu
extends CanvasLayer
## The race's own menus, in TMNF's dialog style (a dark panel with a green title bar over the
## blurred race, white pill buttons; M10-5): Escape opens the race menu (Restart; Resume and Quit at
## the bottom, as TMNF's) and after the finish a result panel (the time, its medal, the difference to
## the record, the medal times) offers Retry, watching or saving the run's replay, the next campaign
## track and the menu. The race connects the signals.

signal resumed
signal restarted
signal next_track
signal to_menu
signal watch_replay
signal save_replay
signal opponent_chosen(kind: String)
signal select_opponent
signal story_continue
signal story_settle
signal story_again

var has_next := false
var story := false                 ## a story night's map: the time to beat instead of medals
## story: its 7-minute session (StoryRace): "open" (RETRY, END SESSION), "pass" (CONTINUE, TRY
## AGAIN) or "fail" (TRY AGAIN)
var story_state := "open"
var online := false                ## in a server: "menu" leaves it
var editing := false               ## testing a track from the editor: "menu" goes back to it
var _panel: PanelContainer
var _box: VBoxContainer
var paused := false
var choosing := false              ## the opponent dialog is up (the race waits)
var opponents := false             ## the race offers opponents: the race menu lists Select Opponents
var finished := false
var _result := {}
var _replay_saved := false


const MEDALS := [["author", "Author"], ["gold", "Gold"], ["silver", "Silver"], ["bronze", "Bronze"]]
const FROST := """shader_type canvas_item;
// the race behind a dialog, blurred, inside the dialog's rounded outline (TMNF's dialogs are frosted
// glass; the race around them stays sharp)
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(100.0);
uniform float radius = 10.0;
void fragment() {
	vec2 q = abs(UV * rect_size - rect_size * 0.5) - rect_size * 0.5 + vec2(radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(textureLod(screen, SCREEN_UV, 3.5).rgb * 0.75, clamp(0.5 - d, 0.0, 1.0));
}
"""
var _frost: ColorRect
var _black: ColorRect              ## behind the opponent dialog: TMNF shows it on black, before the track


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.theme = TmUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_frost = ColorRect.new()
	var fm := ShaderMaterial.new()
	fm.shader = Shader.new()
	fm.shader.code = FROST
	_frost.material = fm
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost.visible = false
	root.add_child(_frost)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.visible = false
	root.add_child(_black)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", TmUi.glass("tm_dialog"))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	root.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_box)


## The panel: TMNF's green title bar, a card (the result) or the options as a column of pills,
## and the bottom row (`bottom`: Resume and Quit in the race menu, all of the finish's buttons).
func _fill(title: String, items: Array, card: Control = null, bottom: Array = []) -> void:
	for c in _box.get_children():
		_box.remove_child(c)       # out now, so the panel's size is the new content's
		c.queue_free()
	_box.add_child(TmUi.tm_title(title))
	var first: Button = null
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 40 if card == null else 26)
	pad.add_theme_constant_override("margin_top", 26 if card == null else 8)
	pad.add_theme_constant_override("margin_bottom", 22 if card == null else 4)
	pad.add_child(body)
	_box.add_child(pad)
	if card:
		body.add_child(card)
	for it: Array in items:
		var b := TmUi.tm_button(String(it[0]), it[1], 560)
		b.custom_minimum_size.y = 24          # TMNF's list pills: slim, small text
		b.add_theme_font_size_override("font_size", 18)
		body.add_child(b)
		if first == null:
			first = b
	if not bottom.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 60 if bottom.size() == 2 else 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_box.add_child(row)
		var lead: Button = null
		for it: Array in bottom:
			var b := TmUi.tm_button(String(it[0]), it[1], 300 if bottom.size() == 2 else 170)
			row.add_child(b)
			if lead == null:
				lead = b
		first = lead               # TMNF focuses the row's first: Resume, Retry
	_panel.visible = true
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_frost_under.call_deferred()
	if first:
		_focus.call_deferred(first)


## The blur under the panel, once the panel has its size.
func _frost_under() -> void:
	_frost.position = _panel.position
	_frost.size = _panel.size
	(_frost.material as ShaderMaterial).set_shader_parameter("rect_size", _panel.size)
	_frost.visible = _panel.visible


## Pauses the race (or resumes it if the pause menu is open).
func toggle_pause() -> void:
	if paused:
		resume()
		return
	paused = true
	get_tree().paused = not online   # a server's round runs on: online, the menu only overlays
	var items := [["Select Opponents", func() -> void: _emit(select_opponent)]] if opponents else []
	items.append(["Restart", func() -> void: _emit(restarted)])
	_fill("Race menu", items, null,
		[["Resume", resume], [_menu_text(), func() -> void: _emit(to_menu)]])


func resume() -> void:
	paused = false
	get_tree().paused = false
	_panel.visible = finished
	_frost.visible = finished
	if finished:
		show_finish()
	resumed.emit()


## The panel after the finish, with the run's result (kept for when the pause menu closes):
## {name, time_ms, prev_ms (the record before this run, -1: none), record (a new one),
## medals: {author, gold, silver, bronze: ms, -1 if the track has none}, way / ways (several
## finishes: which one it crossed, of how many), way_label (optional: what that finish means)}.
func show_finish(result := {}) -> void:
	finished = true
	if not result.is_empty():
		_result = result
		_replay_saved = false
	var items := [["Retry", func() -> void: _emit(restarted)]]
	if story:
		var st: Dictionary = _result.get("story", {})
		match story_state:
			"pass":
				items = [["Continue", func() -> void: _emit(story_continue)], ["Try again", func() -> void: _emit(story_again)]]
			"fail":
				items = [["Try again", func() -> void: _emit(story_again)]]
			_:
				if int(st.get("best_ms", -1)) > 0:
					items.append(["End session", func() -> void: _emit(story_settle)])
	if not online:
		items.append(["Replay", func() -> void: _emit(watch_replay)])
		items.append(["Save replay", func() -> void: save_replay.emit()])
	if has_next:
		items.append(["Next track", func() -> void: _emit(next_track)])
	items.append([_menu_text(), func() -> void: _emit(to_menu)])
	_fill(String(_result.get("name", "Finish")), [], _result_card(_result) if not _result.is_empty() else null, items)
	if _replay_saved:
		mark_saved()


## The result card: the track, the time, the medal it earns, the difference to the record before
## this run (or a new record), and the medal times, the ones beaten bright, the others with the
## time still to find.
static func _result_card(r: Dictionary) -> Control:
	var ms := int(r.get("time_ms", -1))
	var medals: Dictionary = r.get("medals", {})
	var story: Dictionary = r.get("story", {})
	var won := ""
	for m: Array in MEDALS:
		var t := int(medals.get(m[0], -1))
		if won.is_empty() and t > 0 and ms <= t:
			won = m[0]
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.custom_minimum_size = Vector2(640, 0)
	var time := TmSegText.new()
	time.text = TmRace.time_text(ms)
	time.digit_height = 54.0
	time.custom_minimum_size = Vector2(0, 76)
	card.add_child(time)
	# the medal and the record, side by side
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 22)
	var colour: Color = TmRaceHud.MEDAL_COLOURS[won]
	if not story.is_empty():
		# story mode: beaten or not, against the time to beat on the finish crossed
		var ok := bool(story.get("pass", false))
		var over := bool(story.get("settled", false))
		var say := ("Target beaten" if ok else "Beat %s to go on" % TmRace.time_text(int(story.get("target", -1))))
		if over:
			say = ("Session over: target beaten" if ok else "Session over: not beaten") if ms > 0 else "Session over: no finish"
		line.add_child(TmUi.label(say, 28, TmUi.TM_GREEN if ok else TmRaceHud.BEHIND, TmUi.SANS_BOLD))
	elif won.is_empty():
		line.add_child(TmUi.label("No medal", 28, TmUi.DIM, TmUi.SANS_BOLD))
	else:
		line.add_child(_medal(won, 44))
		line.add_child(TmUi.label("%s medal" % won.capitalize(), 28, colour, TmUi.SANS_BOLD))
	var prev := int(r.get("prev_ms", -1))
	if bool(r.get("record", false)):
		line.add_child(TmUi.label("New record", 28, TmUi.TM_GREEN, TmUi.SANS_BOLD))
	if prev > 0:
		var d := ms - prev
		line.add_child(TmUi.label(TmRaceHud.delta_text(d), 28, TmRaceHud.AHEAD if d <= 0 else TmRaceHud.BEHIND, TmUi.SANS_BOLD))
	card.add_child(line)
	if not story.is_empty() and not bool(story.get("settled", false)) and int(story.get("best_ms", -1)) > 0:
		var b := TmUi.label("Best this session %s   ·   %s left" % [TmRace.time_text(int(story["best_ms"])),
			TmRace.time_text(int(story.get("left_ms", 0))).left(-3)], 22, TmUi.DIM, TmUi.SANS_BOLD)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(b)
	if int(r.get("ways", 1)) > 1:
		# several finishes: which one this run crossed (story mode names it: the decision it makes)
		var label := String(r.get("way_label", ""))
		var w := TmUi.label(label if not label.is_empty() else "Finish %d of %d" % [int(r.get("way", 0)) + 1, int(r["ways"])],
			24, TmUi.TEXT, TmUi.SANS_BOLD)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(w)
	if bool(r.get("validated", false)):
		var v := TmUi.label("Track validated: its medals are set from this run", 22, TmUi.TM_GREEN, TmUi.SANS_BOLD)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(v)
	# the medal times
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	for m: Array in MEDALS:
		var t := int(medals.get(m[0], -1))
		if t <= 0:
			continue
		var beaten := ms <= t
		var c: Color = TmRaceHud.MEDAL_COLOURS[m[0]]
		var icon := _medal(m[0], 26)
		if not beaten:
			icon.modulate = Color(0.45, 0.45, 0.45, 0.8)
		grid.add_child(icon)
		grid.add_child(TmUi.label("Target" if not story.is_empty() else m[1], 22, c if beaten else TmUi.DIM, TmUi.SANS_BOLD))
		var tl := TmUi.label(TmRace.time_text(t), 22, TmUi.TEXT if beaten else TmUi.DIM, TmUi.SANS_BOLD)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(tl)
		grid.add_child(TmUi.label("" if beaten else TmRaceHud.delta_text(ms - t), 22, TmRaceHud.BEHIND.lerp(TmUi.DIM, 0.4), TmUi.SANS_BOLD))
	var centre := CenterContainer.new()
	centre.add_child(grid)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	card.add_child(gap)
	card.add_child(centre)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	card.add_child(gap2)
	return card


## A medal's disc (assets/ui/medal_<kind>).
static func _medal(kind: String, size: int) -> Control:
	var r := TextureRect.new()
	r.texture = TmUi.icon("medal_" + kind)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## TMNF's "Select Opponent", before the first run on a track loaded from the menu: a row per
## opponent ([kind, name, time ms (-1: none)]: the medal ghosts, your best, None) with its disc,
## name and time; the race waits (the tree is paused) until one is picked (opponent_chosen).
func show_opponents(options: Array, focus_kind := "") -> void:
	choosing = true
	get_tree().paused = true
	_black.visible = true
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_box.add_child(TmUi.tm_title("Select Opponent"))
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 40)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 34)
	_box.add_child(pad)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	pad.add_child(body)
	var focus: Button = null
	for o: Array in options:
		var b := _opponent_row(String(o[0]), String(o[1]), int(o[2]))
		body.add_child(b)
		if focus == null or String(o[0]) == focus_kind:
			focus = b
	_panel.visible = true
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_frost_under.call_deferred()
	if focus:
		_focus.call_deferred(focus)


## An opponent's row as TMNF's: a dark pill, lighter and its text green when focused; the medal's
## disc, the name above, the time in a grey pill under it.
func _opponent_row(kind: String, label: String, ms: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(430, 68)
	var dark := TmGlassBox.make({"top": Color(0.17, 0.17, 0.18, 0.95), "bottom": Color(0.11, 0.11, 0.12, 0.95), "gloss": 0.05,
		"radius": 100.0, "border": Color(0.27, 0.27, 0.29, 0.9), "border_width": 1.5})
	var lit := TmGlassBox.make({"top": Color(0.45, 0.46, 0.47, 1.0), "bottom": Color(0.27, 0.28, 0.29, 1.0), "gloss": 0.2,
		"radius": 100.0, "border": Color(0.6, 0.61, 0.63, 1.0), "border_top": Color(0.8, 0.8, 0.82), "border_width": 1.5})
	b.add_theme_stylebox_override("normal", dark)
	for st in ["hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, lit)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 40
	row.offset_right = -30
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var disc := TextureRect.new()
	disc.texture = TmUi.icon("medal_" + kind if kind in ["author", "gold", "silver", "bronze"] else "medal_none")
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	disc.custom_minimum_size = Vector2(54, 54)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(disc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_l := TmUi.label(label, 21, Color.WHITE, TmUi.SANS)
	name_l.add_theme_constant_override("outline_size", 0)
	col.add_child(name_l)
	var pill := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.36, 0.37, 0.40, 0.9)
	ps.set_corner_radius_all(10)
	ps.content_margin_left = 8
	ps.content_margin_right = 8
	pill.add_theme_stylebox_override("panel", ps)
	pill.custom_minimum_size = Vector2(200, 24)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pill)
	var time := TmSegText.new()
	time.text = TmRace.time_text(ms) if ms > 0 else ""
	time.digit_height = 14.0
	time.colour = Color(0.18, 0.18, 0.2)
	time.shadow = Color(0, 0, 0, 0)
	time.h_align = HORIZONTAL_ALIGNMENT_LEFT
	time.custom_minimum_size = Vector2(180, 22)
	pill.add_child(time)
	var on := func(lit_up: bool) -> void:
		name_l.add_theme_color_override("font_color", TmUi.TM_GREEN if lit_up else Color.WHITE)
		time.colour = TmUi.TM_GREEN if lit_up else Color(0.18, 0.18, 0.2)
	b.focus_entered.connect(on.bind(true))
	b.focus_exited.connect(on.bind(false))
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func() -> void:
		TmUi.play("click")
		choosing = false
		hide_all()
		opponent_chosen.emit(kind))
	return b


func _menu_text() -> String:
	return "Leave server" if online else ("Editor" if editing else "Quit")


## Focus on a button if it's still shown (a second fill in the same frame took the first's away).
func _focus(b: Control) -> void:
	if is_instance_valid(b) and b.is_inside_tree():
		b.grab_focus()


## Whether SAVE REPLAY was pressed for this finish.
func replay_saved() -> bool:
	return _replay_saved


## The replay was saved: its button says so (and saves no second copy).
func mark_saved() -> void:
	_replay_saved = true
	for b in _box.find_children("*", "Button", true, false):
		if (b as Button).text == "Save replay":
			(b as Button).text = "Saved"
			(b as Button).disabled = true


func hide_all() -> void:
	paused = false
	choosing = false
	_black.visible = false
	finished = false
	get_tree().paused = false
	_panel.visible = false
	_frost.visible = false


func _emit(sig: Signal) -> void:
	hide_all()
	sig.emit()
