class_name TmRaceOnline
extends Node
## A race's online side, while the Online client is in a server (TMNF's modes: TimeAttack,
## Rounds, Team, Laps): the other players' cars (translucent, in their colours or their team's,
## with their names) following the positions the server relays, our car's position sent 10 times
## a second and our finishes reported, the round's clock and the live ranking (times, or points)
## on screen, chat (T to type, Enter to send), votes (V: call one; F1 / F2: yes / no on the running
## one), spectating (F3; Left / Right: whom to follow), the results when a round ends (the round's
## points, the map's standings, ladder points won or lost) and the server's next round: the same
## track again (Rounds) or the next one loaded.

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
var _vote_bar: Label
var _vote_menu: PanelContainer
var _wait_label: Label
var _spec_cam: Camera3D
var _follow := -1                  ## spectating: the player followed
const TEAM_COLOURS := [Color(0.25, 0.5, 1.0), Color(1.0, 0.3, 0.25)]
const TEAM_NAMES := ["BLUE", "RED"]


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
	_vote_bar = TmUi.label("", 22, TmUi.ACCENT, TmUi.BOLD, 1)
	_vote_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
	_vote_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_vote_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_vote_bar)
	_wait_label = TmUi.label("", 30, TmUi.TEXT, TmUi.HEAD, 2)
	_wait_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_wait_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wait_label.position.y += 120
	_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_wait_label)
	_vote_menu = PanelContainer.new()
	_vote_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_vote_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_vote_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_vote_menu.visible = false
	root.add_child(_vote_menu)
	_spec_cam = Camera3D.new()
	_spec_cam.far = 4000.0
	_spec_cam.fov = 72.0
	_spec_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_spec_cam)
	Online.vote_changed.connect(func(_passed: bool) -> void: _refresh_vote())
	Online.ladder_received.connect(func(_d: float) -> void: _on_results(Online.ranking))
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
	Online.send_finish(time_ms, scene.challenge.uid if scene and scene.challenge else "")


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
			var team := int(p.get("team", -1))
			v.ghost_tint = TEAM_COLOURS[team] if Online.mode == "Team" and team in [0, 1] \
				else Color(float(c[0]), float(c[1]), float(c[2])).lerp(Color.WHITE, 0.25)
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
	var r := Online.round
	if state != "race":
		_clock.text = ("NEXT MAP IN %d" if Online.map_over else "NEXT ROUND IN %d") % ceili(left / 1000.0)
	elif Online.synced():
		var head := "LAPS" if Online.mode == "Laps" else "ROUND %d / %d" % [int(r.get("number", 1)), int(r.get("max_rounds", 1))]
		if Online.mode == "Team" and (r.get("team_points") is Array):
			head += "   ·   BLUE %d - %d RED" % [int(r["team_points"][0]), int(r["team_points"][1])]
		_clock.text = "%s   ·   %d:%02d" % [head, left / 60000, (left / 1000) % 60]
	else:
		_clock.text = "%d:%02d" % [left / 60000, (left / 1000) % 60]
	_wait_label.text = ("SPECTATING   ·   %s   (LEFT / RIGHT: ANOTHER, F3: RACE)" % _follow_name()) if Online.is_spectator() \
		else ("WAITING FOR THE NEXT ROUND" if scene.waiting else "")
	_spectate(delta)
	if not Online.vote.is_empty():
		_refresh_vote()
	if not _input.visible and Online.chat_log.size() > 0:
		_refresh_chat()


func _refresh_board() -> void:
	var rows := Online.players.filter(func(p: Dictionary) -> bool: return not bool(p.get("spectator", false)))
	var by_points := Online.mode in ["Rounds", "Team"]
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if by_points:
			return int(a.get("points", 0)) > int(b.get("points", 0))
		var ta := int(a["best"])
		var tb := int(b["best"])
		if (ta < 0) != (tb < 0):
			return tb < 0
		return ta < tb)
	var specs := Online.players.size() - rows.size()
	var lines := ["%s  ·  %s  ·  %d PLAYERS%s" % [Online.server_name.to_upper(), Online.mode.to_upper(), rows.size(),
		("  ·  %d WATCHING" % specs) if specs > 0 else ""]]
	var i := 1
	for p: Dictionary in rows:
		var me := int(p["id"]) == Online.my_id
		var team := int(p.get("team", -1))
		var tag := ("[%s] " % TEAM_NAMES[team]) if Online.mode == "Team" and team in [0, 1] else ""
		var score := ("%d PTS" % int(p.get("points", 0))) if by_points else TmRace.time_text(int(p["best"]))
		lines.append("%s%d. %s%s   %s" % ["> " if me else "", i, tag, TmNick.strip(String(p["name"])), score])
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
	var lines := []
	if Online.mode == "TimeAttack":
		lines.append("ROUND OVER")
		lines.append("")
		var i := 1
		for r: Dictionary in ranking.slice(0, 10):
			lines.append("%d.  %s   %s" % [i, TmNick.strip(String(r["name"])), TmRace.time_text(int(r.get("time", -1)))])
			i += 1
		if ranking.is_empty():
			lines.append("No finishes this round")
	else:
		lines.append(("MAP OVER" if Online.map_over else "ROUND OVER") if Online.mode != "Laps" else "RACE OVER")
		if Online.mode == "Team" and Online.round_teams.size() == 2:
			lines.append("BLUE %d  -  %d RED   (MAP: %s)" % [int(Online.round_teams[0]), int(Online.round_teams[1]),
				"%d - %d" % [int(Online.team_points[0]), int(Online.team_points[1])] if Online.team_points.size() == 2 else "-"])
		lines.append("")
		var i := 1
		for r: Dictionary in Online.last_round.slice(0, 10):
			lines.append("%d.  %s   %s   %s" % [i, TmNick.strip(String(r["name"])), TmRace.time_text(int(r["time"])),
				("+%d" % int(r.get("points", 0))) if Online.mode != "Laps" else ""])
			i += 1
		if Online.last_round.is_empty():
			lines.append("Nobody finished")
		if Online.map_over and Online.mode == "Rounds":
			lines.append("")
			lines.append("THE MAP")
			var j := 1
			for r: Dictionary in ranking.slice(0, 5):
				lines.append("%d.  %s   %d PTS" % [j, TmNick.strip(String(r["name"])), int(r.get("points", 0))])
				j += 1
	if absf(Online.ladder_delta) > 0.0:
		lines.append("")
		lines.append("LADDER  %+.1f" % Online.ladder_delta)
	_results_text.text = "\n".join(lines)
	_results.visible = true


func _on_round() -> void:
	var r := Online.round
	if String(r.get("state", "")) == "race" and int(r.get("id", -1)) != _round_id:
		_round_id = int(r["id"])
		_results.visible = false
		var trk := String(r["track"])
		if trk == String(scene.track_id) and Online.synced():
			scene.restart(true)             # the next round of this map: everyone starts again together
		else:
			scene.load_track(trk)


func _on_lost(reason: String) -> void:
	_results_text.text = "DISCONNECTED\n%s\n\nPress Escape for the menu" % reason
	_results.visible = true


func _send_chat(text: String) -> void:
	if not text.strip_edges().is_empty():
		Online.send_chat(text)
	_input.text = ""
	_input.visible = false
	_input.release_focus()
	scene.car.controls_enabled = not scene.waiting


## The running vote at the top: who called it, for what, the count, F1 / F2.
func _refresh_vote() -> void:
	var v := Online.vote
	if v.is_empty():
		_vote_bar.text = ""
		return
	var what := String({"next": "THE NEXT MAP", "restart": "THIS MAP AGAIN"}.get(String(v.get("kind", "")),
		"KICKING %s" % TmNick.strip(String(v.get("target_name", "")))))
	var left := maxi(0, int(float(v.get("ends", 0)) - Online.now_ms()) / 1000)
	_vote_bar.text = "VOTE BY %s: %s   ·   YES %d / %d   ·   F1 YES   F2 NO   ·   %d s" % [TmNick.strip(String(v.get("by", ""))).to_upper(),
		what, int(v.get("yes", 0)), int(v.get("needed", 1)), left]


## V: the vote menu (the next map, this map again, kicking a player).
func toggle_vote_menu() -> void:
	if _vote_menu.visible:
		_vote_menu.visible = false
		return
	for c in _vote_menu.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_vote_menu.add_child(col)
	col.add_child(TmUi.label("CALL A VOTE", 26, TmUi.ACCENT, TmUi.HEAD, 2))
	var pick := func(kind: String, target: int) -> void:
		Online.call_vote(kind, target)
		_vote_menu.visible = false
	col.add_child(TmUi.button("NEXT MAP", func() -> void: pick.call("next", 0), 380))
	col.add_child(TmUi.button("THIS MAP AGAIN", func() -> void: pick.call("restart", 0), 380))
	for p: Dictionary in Online.players:
		if int(p["id"]) != Online.my_id:
			var id := int(p["id"])
			col.add_child(TmUi.button("KICK %s" % TmNick.strip(String(p["name"])), func() -> void: pick.call("kick", id), 380))
	col.add_child(TmUi.button("CANCEL", func() -> void: _vote_menu.visible = false, 380))
	_vote_menu.visible = true
	(col.get_child(1) as Control).grab_focus.call_deferred()


## Spectating (F3): the camera follows another player's car from behind.
func set_spectating(on: bool) -> void:
	Online.set_spectator(on)
	if on:
		scene.waiting = true
		scene.car.visible = false
		scene.car.controls_enabled = false
		_follow = _next_follow(0)
		_spec_cam.current = true
	else:
		scene.cam.current = true
		scene.restart(true)


func _next_follow(step: int) -> int:
	var ids: Array = Online.states.keys()
	ids.sort()
	if ids.is_empty():
		return -1
	var i := ids.find(_follow)
	return int(ids[posmod(i + step, ids.size())]) if i >= 0 else int(ids[0])


func _follow_name() -> String:
	for p: Dictionary in Online.players:
		if int(p["id"]) == _follow:
			return TmNick.strip(String(p["name"])).to_upper()
	return "NOBODY YET"


func _spectate(delta: float) -> void:
	if not Online.is_spectator():
		return
	if not _spec_cam.current:
		_spec_cam.current = true
	if not _cars.has(_follow):
		_follow = _next_follow(0)
	if not _cars.has(_follow):
		return
	var t := (_cars[_follow] as Node3D).global_transform
	var fwd := t.basis.z.normalized()
	var want := t.origin - fwd * 7.0 + Vector3.UP * 2.6
	var k := 1.0 - exp(-delta * 5.0)
	_spec_cam.global_position = _spec_cam.global_position.lerp(want, k) if _spec_cam.global_position.distance_to(want) < 60.0 else want
	if _spec_cam.global_position.distance_to(t.origin) > 0.5:
		_spec_cam.look_at(t.origin + Vector3.UP * 0.8 + fwd * 2.0, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if _input.visible:
		if key == KEY_ESCAPE:
			_send_chat("")
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_T:
			_input.visible = true
			_input.grab_focus.call_deferred()
			scene.car.controls_enabled = false
		KEY_V:
			toggle_vote_menu()
		KEY_F1:
			Online.send_vote(true)
		KEY_F2:
			Online.send_vote(false)
		KEY_F3:
			set_spectating(not Online.is_spectator())
		KEY_LEFT, KEY_RIGHT:
			if not Online.is_spectator():
				return
			_follow = _next_follow(-1 if key == KEY_LEFT else 1)
		_:
			return
	get_viewport().set_input_as_handled()
