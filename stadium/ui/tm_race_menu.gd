class_name TmRaceMenu
extends CanvasLayer
## The race's own menus: Escape pauses (Resume, Restart, Menu) and after the finish a result panel
## (the time, its medal, the difference to the record, the medal times) offers Retry, watching or
## saving the run's replay, the next campaign track and the menu. The race connects the signals.

signal resumed
signal restarted
signal next_track
signal to_menu
signal watch_replay
signal save_replay

var has_next := false
var online := false                ## in a server: "menu" leaves it
var editing := false               ## testing a track from the editor: "menu" goes back to it
var _panel: PanelContainer
var _box: VBoxContainer
var paused := false
var finished := false
var _result := {}
var _replay_saved := false


const MEDALS := [["author", "AUTHOR"], ["gold", "GOLD"], ["silver", "SILVER"], ["bronze", "BRONZE"]]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.theme = TmUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	root.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_box)


## The panel: a title, a card above the buttons (the result), the buttons in a column or, under a
## card, in a row.
func _fill(title: String, items: Array, card: Control = null) -> void:
	for c in _box.get_children():
		_box.remove_child(c)       # out now, so the panel's size is the new content's
		c.queue_free()
	if not title.is_empty():
		var t := TmUi.label(title, 34, TmUi.ACCENT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(t)
	if card:
		_box.add_child(card)
	var row: BoxContainer = HBoxContainer.new() if card else VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	var first: Button = null
	for it: Array in items:
		var b := TmUi.button(String(it[0]), it[1], 180 if card else 360)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(b)
		if first == null:
			first = b
	# the result card on a darker, roomier panel than the pause menu's glass
	if card:
		var s := TmUi.glass("panel")
		s.top = Color(0.06, 0.11, 0.08, 0.94)
		s.bottom = Color(0.01, 0.03, 0.02, 0.96)
		s.content_margin_left = 34
		s.content_margin_right = 34
		s.content_margin_top = 18
		s.content_margin_bottom = 24
		_panel.add_theme_stylebox_override("panel", s)
	else:
		_panel.remove_theme_stylebox_override("panel")
	_panel.visible = true
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	if first:
		_focus.call_deferred(first)


## Pauses the race (or resumes it if the pause menu is open).
func toggle_pause() -> void:
	if paused:
		resume()
		return
	paused = true
	get_tree().paused = not online   # a server's round runs on: online, the menu only overlays
	_fill("PAUSED", [["RESUME", resume], ["RESTART", func() -> void: _emit(restarted)], [_menu_text(), func() -> void: _emit(to_menu)]])


func resume() -> void:
	paused = false
	get_tree().paused = false
	_panel.visible = finished
	if finished:
		show_finish()
	resumed.emit()


## The panel after the finish, with the run's result (kept for when the pause menu closes):
## {name, time_ms, prev_ms (the record before this run, -1: none), record (a new one),
## medals: {author, gold, silver, bronze: ms, -1 if the track has none}}.
func show_finish(result := {}) -> void:
	finished = true
	if not result.is_empty():
		_result = result
		_replay_saved = false
	var items := [["RETRY", func() -> void: _emit(restarted)]]
	if not online:
		items.append(["REPLAY", func() -> void: _emit(watch_replay)])
		items.append(["SAVE REPLAY", func() -> void: save_replay.emit()])
	if has_next:
		items.append(["NEXT TRACK", func() -> void: _emit(next_track)])
	items.append([_menu_text(), func() -> void: _emit(to_menu)])
	_fill("", items, _result_card(_result) if not _result.is_empty() else null)
	if _replay_saved:
		mark_saved()


## The result card: the track, the time, the medal it earns, the difference to the record before
## this run (or a new record), and the medal times, the ones beaten bright, the others with the
## time still to find.
static func _result_card(r: Dictionary) -> Control:
	var ms := int(r.get("time_ms", -1))
	var medals: Dictionary = r.get("medals", {})
	var won := ""
	for m: Array in MEDALS:
		var t := int(medals.get(m[0], -1))
		if won.is_empty() and t > 0 and ms <= t:
			won = m[0]
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.custom_minimum_size = Vector2(640, 0)
	var head := TmUi.label("%s  ·  FINISH" % String(r.get("name", "")).to_upper(), 22, TmUi.DIM, TmUi.HEAD, 2)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(head)
	var time := TmUi.label(TmRace.time_text(ms), 72, TmUi.TEXT, TmUi.TITLE)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(time)
	# the medal and the record, side by side
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 22)
	var colour: Color = TmRaceHud.MEDAL_COLOURS[won]
	if won.is_empty():
		line.add_child(TmUi.label("NO MEDAL", 30, TmUi.DIM, TmUi.HEAD, 2))
	else:
		line.add_child(_medal(won, 44))
		line.add_child(TmUi.label("%s MEDAL" % won.to_upper(), 30, colour, TmUi.HEAD, 2))
	var prev := int(r.get("prev_ms", -1))
	if bool(r.get("record", false)):
		line.add_child(TmUi.label("NEW RECORD", 30, TmUi.ACCENT, TmUi.HEAD, 2))
	if prev > 0:
		var d := ms - prev
		line.add_child(TmUi.label(TmRaceHud.delta_text(d), 30, TmRaceHud.AHEAD if d <= 0 else TmRaceHud.BEHIND, TmUi.HEAD))
	card.add_child(line)
	if bool(r.get("validated", false)):
		var v := TmUi.label("TRACK VALIDATED  ·  ITS MEDALS SET FROM THIS RUN", 22, TmUi.ACCENT, TmUi.HEAD, 2)
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
		grid.add_child(TmUi.label(m[1], 22, c if beaten else TmUi.DIM, TmUi.BOLD, 1))
		var tl := TmUi.label(TmRace.time_text(t), 22, TmUi.TEXT if beaten else TmUi.DIM, TmUi.BOLD)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(tl)
		grid.add_child(TmUi.label("" if beaten else TmRaceHud.delta_text(ms - t), 22, TmRaceHud.BEHIND.lerp(TmUi.DIM, 0.4), TmUi.BOLD))
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


func _menu_text() -> String:
	return "LEAVE SERVER" if online else ("EDITOR" if editing else "MENU")


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
		if (b as Button).text == "SAVE REPLAY":
			(b as Button).text = "SAVED"
			(b as Button).disabled = true


func hide_all() -> void:
	paused = false
	finished = false
	get_tree().paused = false
	_panel.visible = false


func _emit(sig: Signal) -> void:
	hide_all()
	sig.emit()
