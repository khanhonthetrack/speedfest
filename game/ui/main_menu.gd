extends Control
## PLACEHOLDER: the UI module replaces this with the real main menu.


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	add_child(box)
	var title := Label.new()
	title.text = "SPEEDFEST"
	box.add_child(title)
	for t in TrackDefs.IDS:
		var b := Button.new()
		b.text = "Solo: %s" % TrackDefs.display_name(t)
		b.pressed.connect(Game.start_solo.bind(t))
		box.add_child(b)
