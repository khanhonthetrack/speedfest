extends Node
## Integration-test autopilot. Inactive unless launched with --auto_online=host|guest.
## Drives the Net API without touching the UI so several clients (headless Godot or browsers
## through shell.html ?arg=...) can play a full online round unattended. Pair with --autodrive
## (race module) so the local car drives itself.
##
## Args:
##   --auto_online=host|guest   role
##   --url=ws://...             server (default Settings.resolve_server_url())
##   --name=Bot1 --car=brute    profile overrides
##   --track=arena --duration=60 --weather=rain  host: round settings
##   --expect=3                 host: wait for this many players before starting (default 2)
##   --rounds=1                 host: how many rounds to start
##   --code=ABCD                guest: room to join (default: first private room found; LIVE only with --code=LIVE)
##   --auto_solo=rails          instead: start a solo run on that track right after boot (pair
##                              with --autodrive; static web build test, tools/integration/web_static_test.js)
## Prints "AUTOPILOT <event> ..." lines for test harnesses.

var role := ""
var _rounds_started := 0
var _joining := false
var _list_timer := 0.0
var _start_pending := false
var _configured := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	role = String(TestHooks.arg("auto_online", ""))
	if role == "" and TestHooks.has_arg("auto_solo"):
		set_process(false)
		if TestHooks.has_arg("car"):
			Profile.set_selected_car(String(TestHooks.arg("car", "kaze")))
		var tid := String(TestHooks.arg("auto_solo", "arena"))
		_say("solo %s" % tid)
		get_tree().create_timer(1.0).timeout.connect(func() -> void: Game.start_solo(tid, String(TestHooks.arg("weather", ""))))
		return
	if role == "":
		set_process(false)
		return
	if TestHooks.has_arg("name"):
		Profile.set_player_name(String(TestHooks.arg("name", "Bot")))
	if TestHooks.has_arg("car"):
		Profile.set_selected_car(String(TestHooks.arg("car", "kaze")))
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(func(reason: String) -> void: _say("disconnected %s" % reason))
	Net.rooms_listed.connect(_on_rooms)
	Net.room_changed.connect(_on_room)
	Net.round_started.connect(_on_round_started)
	Net.round_ended.connect(func(results: Array) -> void: _say("round_end %s" % JSON.stringify(results)))
	Net.leaderboard_changed.connect(func(entries: Array) -> void: _say("leaderboard %s" % JSON.stringify(entries)))
	Net.net_error.connect(func(msg: String) -> void: _say("error %s" % msg))
	_say("start role=%s name=%s car=%s" % [role, Profile.player_name, Profile.selected_car])
	# Give the main scene a moment to load first.
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		Net.connect_to_server(String(TestHooks.arg("url", ""))))


func _say(text: String) -> void:
	print("AUTOPILOT %s" % text)


func _on_connected() -> void:
	_say("connected id=%d" % Net.my_id)
	if role == "host":
		Net.create_room("Autopilot room")
	else:
		_joining = true
		Net.list_rooms()


func _process(delta: float) -> void:
	if _joining and not Net.in_room():
		_list_timer += delta
		if _list_timer > 1.0:
			_list_timer = 0.0
			Net.list_rooms()


func _on_rooms(rooms: Array) -> void:
	if not _joining or Net.in_room():
		return
	var want := String(TestHooks.arg("code", ""))
	for r in rooms:
		# the always-on LIVE room is listed first (session 6): join it only when asked (--code=LIVE)
		if want == "" and bool(r.get("live", false)):
			continue
		if want == "" or String(r.get("code", "")) == want:
			_say("joining %s" % r.get("code", ""))
			Net.join_room(String(r.get("code", "")))
			return


func _on_room(room: Dictionary) -> void:
	if room.is_empty():
		return
	if _joining:
		_joining = false
		_say("joined %s" % room.get("code", ""))
		Net.set_profile(Profile.player_name, Profile.get_config())
		Net.set_ready(true)
	var phase := String(room.get("phase", ""))
	if role == "host" and phase == "lobby":
		if not _configured and int(room.get("host", -1)) == Net.my_id:
			_configured = true
			Net.set_profile(Profile.player_name, Profile.get_config())
			Net.host_set_settings({
				"track": String(TestHooks.arg("track", "arena")),
				"duration_s": int(TestHooks.arg("duration", 60)),
				"weather": String(TestHooks.arg("weather", "dry")),
			})
		var players: int = room.get("players", []).size()
		if players >= int(TestHooks.arg("expect", 2)) and _rounds_started < int(TestHooks.arg("rounds", 1)) and not _start_pending:
			_start_pending = true
			_say("starting with %d players" % players)
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				_start_pending = false
				_rounds_started += 1
				Net.host_start_round())


func _on_round_started(info: Dictionary) -> void:
	_say("round_start %s" % JSON.stringify(info))
	# The lobby screen starts the race itself; only act from other scenes (e.g. the main menu).
	var cur := get_tree().current_scene
	var path := cur.scene_file_path if cur else ""
	if path != Game.SCENE_RACE and path != Game.SCENE_LOBBY:
		Game.start_online_round(info)
