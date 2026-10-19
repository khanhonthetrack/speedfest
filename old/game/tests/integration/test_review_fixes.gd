extends Node
## Regression tests for integration review fixes (see docs/PROGRESS.md, 2026-10-15):
## CarVisual double build keeps wheels, hover doesn't steal focus from a text field being edited,
## hidden remote EngineAudio mutes, Game remembers the last online round id.


func _ready() -> void:
	await _test_double_build()
	await _test_hover_focus()
	await _test_remote_engine_mutes()
	_test_last_round_id()
	TestHooks.finish()


func _test_double_build() -> void:
	var cv := CarVisual.new()
	add_child(cv)
	cv.build("kaze", CarDefs.default_style("kaze"))
	await get_tree().process_frame
	cv.build("brute", CarDefs.default_style("brute"))
	await get_tree().process_frame
	await get_tree().process_frame
	TestHooks.check(cv.get_node_or_null("Wheels") != null, "double_build_keeps_wheels", "no Wheels node after 2nd build")
	TestHooks.check(cv.get_node_or_null("Calipers") != null, "double_build_keeps_calipers", "no Calipers node after 2nd build")
	cv.queue_free()


func _test_hover_focus() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	var le := LineEdit.new()
	var b := Button.new()
	b.text = "START"
	box.add_child(le)
	box.add_child(b)
	MenuKit.wire_button(b)
	await get_tree().process_frame
	le.grab_focus()
	le.edit()
	b.mouse_entered.emit()
	TestHooks.check(le.has_focus(), "hover_keeps_chat_focus", "button stole focus from an editing LineEdit")
	le.unedit()
	b.mouse_entered.emit()
	TestHooks.check(b.has_focus(), "hover_focuses_when_not_typing", "hover no longer focuses buttons")
	box.queue_free()


func _test_remote_engine_mutes() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var ea := EngineAudio.new()
	holder.add_child(ea)
	ea.setup("kaze", false)
	for i in 10:
		ea.set_params(0.7, 1.0, 120.0, 0.0, false, true)
		await get_tree().process_frame
	holder.visible = false
	for i in 3:
		await get_tree().process_frame
	var players: Dictionary = ea.get("_players")
	var all_paused := not players.is_empty()
	for k in players:
		if not bool(players[k].get("stream_paused")):
			all_paused = false
	TestHooks.check(all_paused, "hidden_remote_engine_mutes", "a hidden remote car's engine keeps playing")
	holder.queue_free()


func _test_last_round_id() -> void:
	# start_online_round changes scene; check the bookkeeping only (goto is deferred, so quit first).
	var before := Game.last_round_id
	Game.last_round_id = -1
	var info := {"round_id": 7, "track": "arena"}
	Game.mode = "online"
	Game.round_info = info
	Game.last_round_id = int(info.get("round_id", -1))
	TestHooks.check(Game.last_round_id == 7, "last_round_id_field", "Game.last_round_id missing")
	TestHooks.check(Game.get_script().source_code.contains("last_round_id = int(info.get(\"round_id\""),
		"start_online_round_sets_last_round_id", "start_online_round doesn't record the round id")
	Game.last_round_id = before
