class_name PauseOverlay
extends CanvasLayer
## Esc during a race: dims the city, stops the clock and offers the way out. Also shows the
## current quality setting, so the owner can see what the renderer is doing on this machine.

signal resume_requested
signal restart_requested
signal garage_requested
signal menu_requested

var open := false

var _root: Control
var _status: Label


func _init() -> void:
	layer = 20


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.02, 0.72)
	_root.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-150, -170)
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 12)
	_root.add_child(box)
	box.add_child(UiTheme.label("PAUSED", 56, UiTheme.WHITE, true))
	var resume := UiTheme.button("RESUME", UiTheme.LIME)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume)
	var restart := UiTheme.button("RESTART", UiTheme.CYAN)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(restart)
	var garage := UiTheme.button("GARAGE", UiTheme.MAGENTA)
	garage.pressed.connect(func() -> void: garage_requested.emit())
	box.add_child(garage)
	var menu := UiTheme.button("MAIN MENU", UiTheme.DIM)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	box.add_child(menu)
	var quality := UiTheme.button("QUALITY: %s" % Settings.quality_name(), UiTheme.AMBER)
	quality.pressed.connect(func() -> void:
		Settings.quality = (Settings.quality + 1) % 4
		Settings.apply_and_save()
		quality.text = "QUALITY: %s" % Settings.quality_name()
		_status.text = Settings.render_status())
	box.add_child(quality)
	_status = UiTheme.label(Settings.render_status(), 15, UiTheme.DIM)
	box.add_child(_status)


func toggle() -> void:
	if open:
		close()
	else:
		show_menu()


func show_menu() -> void:
	open = true
	_root.visible = true
	get_tree().paused = true


func close() -> void:
	open = false
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo() \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
