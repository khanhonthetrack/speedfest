class_name TmRaceMenu
extends CanvasLayer
## The race's own menus: Escape pauses (Resume, Restart, Menu) and after the finish a panel offers
## Retry, the next campaign track and the menu. The race connects the signals.

signal resumed
signal restarted
signal next_track
signal to_menu

var has_next := false
var _panel: PanelContainer
var _box: VBoxContainer
var paused := false
var finished := false


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


func _fill(title: String, items: Array, low := false) -> void:
	for c in _box.get_children():
		c.queue_free()
	if not title.is_empty():
		var t := TmUi.label(title, 34, TmUi.ACCENT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(t)
	var first: Button = null
	for it: Array in items:
		var b := TmUi.button(String(it[0]), it[1], 360)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(b)
		if first == null:
			first = b
	_panel.visible = true
	_panel.reset_size()
	# the finish panel sits low, under the HUD's time and medal; the pause menu in the middle
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM if low else Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	if low:
		_panel.position.y -= 150.0
	if first:
		first.grab_focus.call_deferred()


## Pauses the race (or resumes it if the pause menu is open).
func toggle_pause() -> void:
	if paused:
		resume()
		return
	paused = true
	get_tree().paused = true
	_fill("PAUSED", [["RESUME", resume], ["RESTART", func() -> void: _emit(restarted)], ["MENU", func() -> void: _emit(to_menu)]])


func resume() -> void:
	paused = false
	get_tree().paused = false
	_panel.visible = finished
	if finished:
		show_finish()
	resumed.emit()


## The panel after the finish.
func show_finish() -> void:
	finished = true
	var items := [["RETRY", func() -> void: _emit(restarted)]]
	if has_next:
		items.append(["NEXT TRACK", func() -> void: _emit(next_track)])
	items.append(["MENU", func() -> void: _emit(to_menu)])
	_fill("", items, true)


func hide_all() -> void:
	paused = false
	finished = false
	get_tree().paused = false
	_panel.visible = false


func _emit(sig: Signal) -> void:
	hide_all()
	sig.emit()
