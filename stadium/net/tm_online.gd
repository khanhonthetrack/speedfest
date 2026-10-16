extends Node
## The online client (autoload "Online"): one WebSocket to a SpeedFest Stadium server
## (stadium/server, like a TMNF time-attack server): the round (track, state, end), the players
## and their best times, the other cars' positions, chat. The menu's Online page connects; the
## race scene in online mode reads it and reports its car and finishes. The official server's
## current address is published in the repo (stadium/server/official.json), so the game finds it.

signal connected
signal disconnected(reason: String)
signal round_changed
signal players_changed
signal results_received(ranking: Array)
signal chat_received(from: String, text: String)

const VERSION := 1
const OFFICIAL_LIST := "https://raw.githubusercontent.com/khanhonthetrack/speedfest/stadium/stadium/server/official.json"

var ws: WebSocketPeer
var address := ""
var my_id := -1
var server_name := ""
var round := {}                    ## {id, track, state ("race" | "results"), start, end} (server ms)
var players: Array = []            ## [{id, name, colour, best}]
var states := {}                   ## player id -> [px, py, pz, qx, qy, qz, qw, speed, steer]
var ranking: Array = []            ## the last round's results
var chat_log: Array = []           ## [[from, text, local ms]]
var clock_offset := 0.0            ## server ms - local unix ms
var _name := ""
var _colour := Color(0.85, 0.08, 0.06)
var _was_open := false


## ws(s)://host[:port]/ws from what the player typed: https://x, http://x, x:8090, x.
static func ws_url(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("https://"):
		t = "wss://" + t.substr(8)
	elif t.begins_with("http://"):
		t = "ws://" + t.substr(7)
	elif not (t.begins_with("ws://") or t.begins_with("wss://")):
		t = "ws://" + t
	t = t.trim_suffix("/")
	if not t.ends_with("/ws"):
		t += "/ws"
	return t


## http(s)://host[:port]/status for a server's address (the server list's status line).
static func status_url(text: String) -> String:
	var u := ws_url(text).trim_suffix("/ws")
	return ("https://" + u.substr(6)) if u.begins_with("wss://") else ("http://" + u.substr(5))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func join(text: String, player_name: String, colour := Color(0.85, 0.08, 0.06)) -> void:
	leave()
	address = text
	_name = player_name
	_colour = colour
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


func send_finish(time_ms: int) -> void:
	_send({"t": "finish", "round": int(round.get("id", -1)), "track": String(round.get("track", "")), "time": time_ms})


func send_chat(text: String) -> void:
	_send({"t": "chat", "text": text})


func _process(_delta: float) -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		_send({"t": "hello", "name": _name, "version": VERSION, "colour": [_colour.r, _colour.g, _colour.b]})
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
			players = m["players"]
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
		"states":
			var s: Dictionary = m["s"]
			for k in s:
				if int(k) != my_id:
					states[int(k)] = s[k]
		"results":
			ranking = m["ranking"]
			results_received.emit(ranking)
		"chat":
			chat_log.append([String(m.get("from", "")), String(m.get("text", "")), Time.get_ticks_msec()])
			while chat_log.size() > 30:
				chat_log.pop_front()
			chat_received.emit(String(m.get("from", "")), String(m.get("text", "")))
		"error":
			chat_log.append(["", "Server: " + String(m.get("msg", "")), Time.get_ticks_msec()])
			disconnected.emit(String(m.get("msg", "error")))
