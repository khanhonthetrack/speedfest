class_name TmRaceOnline
extends Node
## A race's online side, while the Online client is in a server (TMNF-style time attack): the
## other players' cars (translucent, in their colours, with their names) following the positions
## the server relays, our car's position sent 10 times a second and our finishes reported, the
## round's time left and the live ranking on screen, chat (T to type, Enter to send), the results
## when a round ends and the server's next track loaded when the next round starts.

var scene: Node                    ## the race scene (race.gd)
var _cars := {}                    ## player id -> Node3D (a ghost TmCarVisual and a name tag)
var _send_left := 0.0
var _round_id := -1
var _layer: CanvasLayer
var _clock: Label
var _board: Label
var _chat: Label
var _input: LineEdit
var _results: PanelContainer
var _results_text: Label


func _ready() -> void:
	_round_id = int(Online.round.get("id", -1))
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var root := Control.new()
	root.theme = TmUi.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_clock = TmUi.label("", 30, TmUi.ACCENT, TmUi.HEAD)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	_clock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_clock)
	_board = TmUi.label("", 21, TmUi.TEXT, TmUi.BOLD)
	_board.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	_board.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_board.position.y = 120
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_board)
	_chat = TmUi.label("", 19, TmUi.TEXT, TmUi.BOLD)
	_chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 28)
	_chat.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chat.position.y -= 70
	root.add_child(_chat)
	_input = LineEdit.new()
	_input.placeholder_text = "Say something (Enter to send, Esc to cancel)"
	_input.max_length = 120
	_input.custom_minimum_size = Vector2(520, 40)
	_input.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 28)
	_input.position.y -= 24
	_input.visible = false
	_input.text_submitted.connect(_send_chat)
	root.add_child(_input)
	_results = PanelContainer.new()
	_results.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results.visible = false
	root.add_child(_results)
	_results_text = TmUi.label("", 26, TmUi.TEXT, TmUi.BOLD)
	_results.add_child(_results_text)
	Online.round_changed.connect(_on_round)
	Online.players_changed.connect(_refresh_board)
	Online.results_received.connect(_on_results)
	Online.chat_received.connect(func(_f: String, _t: String) -> void: _refresh_chat())
	Online.disconnected.connect(_on_lost)
	_refresh_board()
	_refresh_chat()
	if String(Online.round.get("state", "")) == "results":
		_on_results(Online.ranking)


## Our finish, reported to the server.
func on_finish(time_ms: int) -> void:
	Online.send_finish(time_ms)


func _car(id: int) -> Node3D:
	if _cars.has(id):
		return _cars[id]
	var n := Node3D.new()
	n.name = "Player%d" % id
	var v := TmCarVisual.new()
	v.ghost = true
	for p: Dictionary in Online.players:
		if int(p["id"]) == id:
			var c: Array = p.get("colour", [0.85, 0.08, 0.06])
			v.ghost_tint = Color(float(c[0]), float(c[1]), float(c[2])).lerp(Color.WHITE, 0.25)
			var tag := Label3D.new()
			tag.text = TmNick.strip(String(p["name"]))
			tag.font = TmUi.font(TmUi.BOLD)
			tag.font_size = 48
			tag.pixel_size = 0.01
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.no_depth_test = true
			tag.fixed_size = false
			tag.outline_size = 8
			tag.position = Vector3(0, 1.6, 0)
			n.add_child(tag)
	n.add_child(v)
	scene.add_child(n)
	_cars[id] = n
	return n


func _process(delta: float) -> void:
	if not Online.is_online():
		return
	# the other cars, eased towards their last relayed pose
	var k := 1.0 - exp(-delta * 14.0)
	for id: int in Online.states:
		var s: Array = Online.states[id]
		var target := Transform3D(Basis(Quaternion(float(s[3]), float(s[4]), float(s[5]), float(s[6])).normalized()), Vector3(float(s[0]), float(s[1]), float(s[2])))
		var c := _car(id)
		if c.global_position.distance_to(target.origin) > 30.0:
			c.global_transform = target
		else:
			c.global_transform = c.global_transform.interpolate_with(target, k)
		var v := c.get_child(c.get_child_count() - 1) as TmCarVisual
		v.ghost_speed = float(s[7])
		v.ghost_steer = float(s[8])
	var live := {}
	for p: Dictionary in Online.players:
		live[int(p["id"])] = true
	for id: int in _cars.keys():
		if not live.has(id) or not Online.states.has(id):
			(_cars[id] as Node).queue_free()
			_cars.erase(id)
	# ours, 10 times a second
	_send_left -= delta
	if _send_left <= 0.0 and scene.car:
		_send_left = 0.1
		Online.send_state(scene.car.global_transform, scene.car.local_velocity().z, scene.car.model.steer)
	var left := Online.time_left_ms()
	var state := String(Online.round.get("state", ""))
	_clock.text = ("%d:%02d" % [left / 60000, (left / 1000) % 60]) if state == "race" else "NEXT TRACK IN %d" % ceili(left / 1000.0)
	if not _input.visible and Online.chat_log.size() > 0:
		_refresh_chat()


func _refresh_board() -> void:
	var rows := Online.players.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := int(a["best"])
		var tb := int(b["best"])
		if (ta < 0) != (tb < 0):
			return tb < 0
		return ta < tb)
	var lines := ["%s  ·  %d PLAYERS" % [Online.server_name.to_upper(), rows.size()]]
	var i := 1
	for p: Dictionary in rows:
		var me := int(p["id"]) == Online.my_id
		lines.append("%s%d. %s   %s" % ["> " if me else "", i, TmNick.strip(String(p["name"])), TmRace.time_text(int(p["best"]))])
		i += 1
	_board.text = "\n".join(lines)


func _refresh_chat() -> void:
	var now := Time.get_ticks_msec()
	var lines := []
	for e: Array in Online.chat_log.slice(-6):
		if now - int(e[2]) < 12000 or _input.visible:
			lines.append(("%s: %s" % [TmNick.strip(String(e[0])), e[1]]) if not String(e[0]).is_empty() else "* " + TmNick.strip(String(e[1])))
	_chat.text = "\n".join(lines)


func _on_results(ranking: Array) -> void:
	var lines := ["ROUND OVER", ""]
	var i := 1
	for r: Dictionary in ranking.slice(0, 10):
		lines.append("%d.  %s   %s" % [i, TmNick.strip(String(r["name"])), TmRace.time_text(int(r["time"]))])
		i += 1
	if ranking.is_empty():
		lines.append("No finishes this round")
	_results_text.text = "\n".join(lines)
	_results.visible = true


func _on_round() -> void:
	var r := Online.round
	if String(r.get("state", "")) == "race" and int(r.get("id", -1)) != _round_id:
		_round_id = int(r["id"])
		scene.load_track(String(r["track"]))


func _on_lost(reason: String) -> void:
	_results_text.text = "DISCONNECTED\n%s\n\nPress Escape for the menu" % reason
	_results.visible = true


func _send_chat(text: String) -> void:
	if not text.strip_edges().is_empty():
		Online.send_chat(text)
	_input.text = ""
	_input.visible = false
	_input.release_focus()
	scene.car.controls_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_T and not _input.visible:
		_input.visible = true
		_input.grab_focus.call_deferred()
		scene.car.controls_enabled = false
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and _input.visible:
		_send_chat("")
		get_viewport().set_input_as_handled()
