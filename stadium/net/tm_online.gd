extends Node
## The online client (autoload "Online"): one WebSocket to a SpeedFest Stadium server
## (stadium/server/lib/game.js, like a TMNF dedicated server in one of its modes: TimeAttack,
## Rounds, Team, Laps): the round (track, state, start, end; synced modes start everyone at
## once), the players (best times, points, teams, spectators), the other cars' positions, chat,
## votes, ladder points won or lost; the community content its admins put on it (tracks from
## TrackMania Exchange, TMNF car skins and models from ManiaPark: lib/content.js), downloaded from
## the server once and kept by their SHA-256 in user://content. The menu's Online page connects; the
## race scene in online mode reads it and reports its car and finishes. The official server's
## current address is published in the repo (stadium/server/official.json), so the game finds it.

signal connected
signal disconnected(reason: String)
signal round_changed
signal players_changed
signal results_received(ranking: Array)
signal chat_received(from: String, text: String)
signal vote_changed(passed: bool)
signal ladder_received(delta: float)
signal cars_changed
signal download_progress(done: int, total: int)

const VERSION := 2
const OFFICIAL_LIST := "https://raw.githubusercontent.com/khanhonthetrack/speedfest/stadium/stadium/server/official.json"
const CONTENT_DIR := "user://content"
const DOWNLOAD_TIMEOUT := 120.0

var ws: WebSocketPeer
var address := ""
var my_id := -1
var server_name := ""
var round := {}                    ## {mode, id, track, state ("race" | "results"), start, end, synced, number, ...} (server ms)
var mode := "TimeAttack"
var players: Array = []            ## [{id, name, colour, best, points, team, spectator, login, car, model}]
var cars: Array = []               ## the server's car packs [{id, name, sha256, size, url, mesh, skin, sounds}]
var forced_car := ""               ## a car pack everyone drives on this server ("" none)
var vote := {}                     ## the running vote {kind, target, target_name, by, yes, no, needed, ends}; {} none
var last_round: Array = []         ## the last round's places [{id, name, time, points}] (Rounds, Team, Laps)
var team_points: Array = []        ## [blue, red] (Team)
var round_teams: Array = []        ## the last round's team scores [blue, red] (Team)
var map_over := true               ## the last results ended the map
var ladder_delta := 0.0            ## your ladder points from the last ranked results
var states := {}                   ## player id -> [px, py, pz, qx, qy, qz, qw, speed, steer]
var ranking: Array = []            ## the last round's results
var chat_log: Array = []           ## [[from, text, local ms]]
var clock_offset := 0.0            ## server ms - local unix ms
var _name := ""
var _colour := Color(0.85, 0.08, 0.06)
var _token := ""
var _spectator := false
var _was_open := false


## ws(s)://host[:port]/ws[/<server>] from what the player typed or the server list gave:
## https://x, http://x/ws/rounds, x:8090, x (a bare host: its first server, /ws).
static func ws_url(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("https://"):
		t = "wss://" + t.substr(8)
	elif t.begins_with("http://"):
		t = "ws://" + t.substr(7)
	elif not (t.begins_with("ws://") or t.begins_with("wss://")):
		t = "ws://" + t
	t = t.trim_suffix("/")
	var slash := t.find("/", t.find("://") + 3)
	var path := t.substr(slash) if slash >= 0 else ""
	if not (path == "/ws" or path.begins_with("/ws/")):
		t += "/ws"
	return t


## A server's status as JSON over http(s) (the server list's line): /ws/<id>/status, or /status
## for a bare host's first server.
static func status_url(text: String) -> String:
	var u := ws_url(text)
	u = u.trim_suffix("/ws") + "/status" if u.ends_with("/ws") else u + "/status"
	return ("https://" + u.substr(6)) if u.begins_with("wss://") else ("http://" + u.substr(5))


## The server's HTTP address (scheme, host, port) for its files: https://a.b, http://x:8090.
static func http_base(text: String) -> String:
	var u := ws_url(text)
	u = ("https://" + u.substr(6)) if u.begins_with("wss://") else ("http://" + u.substr(5))
	var slash := u.find("/", u.find("://") + 3)
	return u.substr(0, slash) if slash >= 0 else u


## Where a server file (its SHA-256 and extension) is kept once downloaded.
static func cached_path(sha256: String, ext: String) -> String:
	return CONTENT_DIR.path_join(sha256 + ext)


## Whether a file with this SHA-256 is already here (and unchanged).
static func has_cached(sha256: String, ext: String) -> bool:
	var path := cached_path(sha256, ext)
	return FileAccess.file_exists(path) and _sha256_of(path) == sha256


static func _sha256_of(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


## A file of the server (a round's track, a car pack: {sha256, size, url}): the local copy's path,
## downloaded first if it isn't here yet (checked against its SHA-256); "" if that fails.
func fetch(file: Dictionary, ext: String) -> String:
	var sha := String(file.get("sha256", ""))
	var url := String(file.get("url", ""))
	if sha.length() != 64 or not url.begins_with("/content/"):
		return ""
	if has_cached(sha, ext):
		return cached_path(sha, ext)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTENT_DIR))
	var tmp := cached_path(sha, ext) + ".part"
	var req := HTTPRequest.new()
	req.download_file = ProjectSettings.globalize_path(tmp)
	req.timeout = 0.0 if TestHooks.is_testing() else DOWNLOAD_TIMEOUT
	req.body_size_limit = maxi(int(file.get("size", 0)) * 2, 1 << 20)
	add_child(req)
	var total := int(file.get("size", 0))
	var watch := func() -> void: download_progress.emit(req.get_downloaded_bytes(), total)
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(watch)
	req.add_child(timer)
	timer.autostart = true
	var err := req.request(http_base(address) + url)
	if err != OK:
		req.queue_free()
		return ""
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200 or _sha256_of(tmp) != sha:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return ""
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(cached_path(sha, ext)))
	download_progress.emit(total, total)
	return cached_path(sha, ext)


## The round's track as a local file when an admin uploaded it ("" for the game's own tracks):
## downloaded if needed. Its uid is the round's track id.
func round_track_file() -> String:
	var f: Variant = round.get("file", null)
	if not f is Dictionary:
		return ""
	return await fetch(f, ".Challenge.Gbx")


## A car pack of this server by id ({} if none).
func car(id: String) -> Dictionary:
	for c: Dictionary in cars:
		if String(c.get("id", "")) == id:
			return c
	return {}


## Our car on this server: one of its car packs ("" our own car); remembered (by its file) for the
## next servers that have it.
func pick_car(id: String) -> void:
	_send({"t": "car", "id": id})
	TmUi.set_setting("car_pack", String(car(id).get("sha256", "")))


## A player of this server by id ({} if none).
func player(id: int) -> Dictionary:
	for p: Dictionary in players:
		if int(p.get("id", -1)) == id:
			return p
	return {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Joins a server: as the account the master's token belongs to (its nickname), or as a guest.
func join(text: String, player_name: String, colour := Color(0.85, 0.08, 0.06), token := "", spectator := false) -> void:
	leave()
	address = text
	_name = player_name
	_colour = colour
	_token = token
	_spectator = spectator
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	var err := ws.connect_to_url(ws_url(text))
	if err != OK:
		ws = null
		disconnected.emit("cannot connect (%s)" % error_string(err))


func leave() -> void:
	if ws:
		ws.close()
	ws = null
	my_id = -1
	_was_open = false
	round = {}
	players = []
	cars = []
	forced_car = ""
	states = {}


func is_online() -> bool:
	return ws != null and my_id >= 0


## The server's clock now (ms), and what is left of the round.
func now_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0 + clock_offset


func time_left_ms() -> int:
	return maxi(0, int(float(round.get("end", 0)) - now_ms()))


func _send(msg: Dictionary) -> void:
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


func send_state(xf: Transform3D, speed: float, steer: float) -> void:
	var q := xf.basis.get_rotation_quaternion()
	_send({"t": "state", "p": [xf.origin.x, xf.origin.y, xf.origin.z], "q": [q.x, q.y, q.z, q.w], "v": speed, "s": steer})


## A finish; uid: the track's (TmChallenge.uid), for the online records.
func send_finish(time_ms: int, uid := "") -> void:
	_send({"t": "finish", "round": int(round.get("id", -1)), "track": String(round.get("track", "")), "time": time_ms, "uid": uid})


func send_chat(text: String) -> void:
	_send({"t": "chat", "text": text})


## Calls a vote: "next" (map), "restart" (map), "kick" (target: a player id).
func call_vote(kind: String, target := 0) -> void:
	_send({"t": "callvote", "kind": kind, "target": target})


func send_vote(yes: bool) -> void:
	_send({"t": "vote", "yes": yes})


func set_spectator(on: bool) -> void:
	_spectator = on
	_send({"t": "spectate", "on": on})


## The round's rules start everyone together (Rounds, Team, Laps).
func synced() -> bool:
	return bool(round.get("synced", false))


func me() -> Dictionary:
	for p: Dictionary in players:
		if int(p["id"]) == my_id:
			return p
	return {}


func is_spectator() -> bool:
	return bool(me().get("spectator", _spectator))


func _process(_delta: float) -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		var hello := {"t": "hello", "name": _name, "version": VERSION, "colour": [_colour.r, _colour.g, _colour.b],
			"model": TmUi.car_model(), "livery": TmUi.car_livery()}
		if not _token.is_empty():
			hello["token"] = _token
		if _spectator:
			hello["spectator"] = true
		_send(hello)
	if st == WebSocketPeer.STATE_CLOSED:
		var reason := ws.get_close_reason()
		var was := my_id >= 0
		ws = null
		my_id = -1
		_was_open = false
		disconnected.emit(reason if not reason.is_empty() else ("connection lost" if was else "could not reach the server"))
		return
	while ws and ws.get_available_packet_count() > 0:
		var msg: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if msg is Dictionary:
			_handle(msg)


func _handle(m: Dictionary) -> void:
	match String(m.get("t", "")):
		"welcome":
			my_id = int(m["id"])
			server_name = String(m.get("name", ""))
			clock_offset = float(m["now"]) - Time.get_unix_time_from_system() * 1000.0
			round = m["round"]
			mode = String(m.get("mode", round.get("mode", "TimeAttack")))
			players = m["players"]
			vote = m["vote"] if m.get("vote") is Dictionary else {}
			cars = m["cars"] if m.get("cars") is Array else []
			forced_car = String(m.get("forced_car", ""))
			# the car pack we drove last time on any server, if this one has it too
			var want := String(TmUi.setting("car_pack"))
			for c: Dictionary in cars:
				if String(c.get("sha256", "")) == want:
					pick_car(String(c["id"]))
			connected.emit()
			round_changed.emit()
			players_changed.emit()
		"round":
			clock_offset = float(m["now"]) - Time.get_unix_time_from_system() * 1000.0
			round = m["round"]
			if String(round.get("state", "")) == "race":
				states.clear()
			round_changed.emit()
		"players":
			players = m["players"]
			players_changed.emit()
		"cars":
			cars = m["cars"] if m.get("cars") is Array else []
			forced_car = String(m.get("forced_car", ""))
			cars_changed.emit()
		"states":
			var s: Dictionary = m["s"]
			for k in s:
				if int(k) != my_id:
					states[int(k)] = s[k]
		"results":
			ranking = m["ranking"]
			last_round = m["last_round"] if m.get("last_round") is Array else []
			round_teams = m["teams"] if m.get("teams") is Array else []
			team_points = m["team_points"] if m.get("team_points") is Array else []
			map_over = bool(m.get("map_over", true))
			ladder_delta = 0.0
			results_received.emit(ranking)
		"ladder":
			for d: Dictionary in m.get("deltas", []):
				if int(d.get("id", -1)) == my_id:
					ladder_delta = float(d.get("delta", 0.0))
					ladder_received.emit(ladder_delta)
		"vote":
			vote = m["vote"] if m.get("vote") is Dictionary else {}
			vote_changed.emit(bool(m.get("passed", false)))
		"chat":
			chat_log.append([String(m.get("from", "")), String(m.get("text", "")), Time.get_ticks_msec()])
			while chat_log.size() > 30:
				chat_log.pop_front()
			chat_received.emit(String(m.get("from", "")), String(m.get("text", "")))
		"error":
			chat_log.append(["", "Server: " + String(m.get("msg", "")), Time.get_ticks_msec()])
			disconnected.emit(String(m.get("msg", "error")))
