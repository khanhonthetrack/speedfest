extends Node
## Online client: one WebSocket to the SpeedFest server (server/), rooms, server clock sync and
## state relay. Works on web (browser WebSocket) and desktop (Godot's WebSocket + TLS).
##
## Protocol and API contract: docs/ARCHITECTURE.md ("Net" and "Network protocol").
## Module notes: docs/modules/networking.md.
##
## Typical flow:
##   Net.connect_to_server()            # "" -> Settings.resolve_server_url()
##   await Net.connected                # my_id is valid from here
##   Net.create_room() / Net.join_room("ABCD")   -> room_changed(room)
##   (host) Net.host_set_settings({"track": "arena", "duration_s": 300}); Net.host_start_round()
##   round_started(info) -> race; send_state() every physics tick; send_checkpoint/send_finish
##   round_ended(results) -> results screen; room phase returns to "lobby"
##
## Everything is polled from _process with PROCESS_MODE_ALWAYS, so pausing the tree doesn't
## stall the connection. Nothing here reconnects on its own: reconnecting is the UI's call.

signal connected
signal disconnected(reason: String)
signal rooms_listed(rooms: Array)                  # [{code, name, players, phase, track, max_players, host_name}]
signal room_changed(room: Dictionary)              # full room state ({} after leaving)
signal round_started(info: Dictionary)             # {round_id, track, duration_s, start_at_local_ms, end_at_local_ms, ...}
signal round_ended(results: Array)                 # [{id, name, car, best_ms, runs}] sorted, DNF (-1) last
signal leaderboard_changed(entries: Array)         # same shape as results, live during the round
signal player_state(id: int, state: Dictionary)    # snapshot from another player (+ "rx_ms": local receive time)
signal player_left(id: int)
signal chat(from_name: String, text: String)
signal net_error(message: String)
# --- additive (not in the original contract) ---
signal player_checkpoint(id: int, cp: int, ms: int)                        # another player passed a checkpoint
signal finish_result(accepted: bool, ms: int, best_ms: int, reason: String)  # server verdict on send_finish

const PROTOCOL_VERSION := 1
const STATE_INTERVAL_MS := 50          # 20 Hz state relay
const STATE_MIN_GAP_MS := 40           # tolerate frame jitter (60 fps -> sends every 3rd frame)
const PING_INTERVAL_MS := 2000
const PING_BURST := 5                  # pings right after connecting, for a fast clock fix
const PING_BURST_GAP_MS := 120
const CLOCK_SAMPLES := 16
const CLOCK_BEST_OF := 3               # offset = median offset of the lowest-RTT samples
const CONNECT_TIMEOUT_MS := 10000
const WELCOME_TIMEOUT_MS := 8000
const MAX_OUTBOUND_BUFFER := 32 * 1024 # skip state sends while the socket is backed up
const MAX_CHAT := 200

var my_id: int = -1
var room: Dictionary = {}              # latest room state ({} if not in a room)
# --- additive, read-only by convention ---
var current_round: Dictionary = {}     # last round_started payload ({} when none)
var leaderboard: Array = []            # last leaderboard entries
var last_results: Array = []           # last round_ended results
var server_version: int = -1
var server_url: String = ""            # URL of the current/last connection
var ping_ms: int:                      # smoothed round-trip time in ms (-1 until measured)
	get:
		return _ping_ms
	set(_value):
		push_warning("Net.ping_ms is read-only")

var _ws: WebSocketPeer = null
var _opened := false
var _welcomed := false
var _connect_started_ms := 0
var _open_ms := 0
var _ping_ms := -1
var _clock_offset := 0.0               # server_ms = local_ms + offset
var _clock_valid := false
var _samples: Array = []               # [[rtt, offset], ...]
var _pings_sent := 0
var _next_ping_ms := 0
var _pending_state: Dictionary = {}
var _last_state_ms := -100000
var _ignore_room_code := ""            # left this room; drop its in-flight messages until the server confirms
var _outbox: Array = []                # messages queued while connecting (sent right after welcome)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- connection ---------------------------------------------------------------------------------

func connect_to_server(url: String = "") -> void:
	var target := url.strip_edges()
	if target == "":
		target = Settings.resolve_server_url()
	if _ws != null:
		if target == server_url:
			if _welcomed:
				connected.emit.call_deferred()
			return
		_teardown()
	server_url = target
	_ws = WebSocketPeer.new()
	# Generous inbound limits: on web, a hidden tab stops our main loop while the browser keeps
	# queueing frames; when full, Godot drops the newest (reliable) messages. The server also stops
	# relaying state to silent clients (server/lib/lobby.js STALE_RX_MS), so this is a backstop.
	_ws.inbound_buffer_size = 1 << 22
	_ws.outbound_buffer_size = 1 << 18
	_ws.max_queued_packets = 1 << 14
	_opened = false
	_welcomed = false
	_connect_started_ms = local_ms()
	var err := _ws.connect_to_url(target)
	if err != OK:
		_ws = null
		var why := "Could not connect to %s (error %d)" % [target, err]
		disconnected.emit.call_deferred(why)


func disconnect_from_server() -> void:
	if _ws == null:
		return
	_teardown()
	disconnected.emit("Disconnected")


func is_online() -> bool:
	return _ws != null and _welcomed


## "offline", "connecting" (socket opening or waiting for welcome) or "online".
func connection_state() -> String:
	if _ws == null:
		return "offline"
	return "online" if _welcomed else "connecting"


func in_room() -> bool:
	return not room.is_empty()


func is_host() -> bool:
	return in_room() and int(room.get("host", -2)) == my_id


# --- rooms --------------------------------------------------------------------------------------

func list_rooms() -> void:
	_send({"type": "list_rooms"})


func create_room(room_name: String = "") -> void:
	_send_profile_now()
	_send({"type": "create_room", "name": room_name.strip_edges().substr(0, 24)})


func join_room(code: String) -> void:
	_send_profile_now()
	_send({"type": "join_room", "code": code.strip_edges().to_upper()})


## The garage/name may have changed since connecting: make sure the server has the latest
## before we appear in a room (the socket keeps message order).
func _send_profile_now() -> void:
	_send({"type": "profile", "name": Profile.player_name, "car": Profile.get_config()})


func leave_room() -> void:
	if in_room():
		_ignore_room_code = String(room.get("code", ""))
		_send({"type": "leave_room"})
	room = {}
	current_round = {}
	leaderboard = []
	_pending_state = {}
	room_changed.emit(room)


func set_profile(player_name: String, car_config: Dictionary) -> void:
	_send({"type": "profile", "name": player_name.strip_edges().substr(0, 16), "car": car_config})


func set_ready(ready: bool) -> void:
	_send({"type": "ready", "ready": ready})


## Host only. Keys are optional: {"track": String, "duration_s": int, "weather": "dry"|"rain"|"storm"}.
func host_set_settings(settings: Dictionary) -> void:
	var msg := {"type": "settings"}
	if settings.has("track"):
		msg["track"] = String(settings["track"])
	if settings.has("duration_s"):
		msg["duration_s"] = int(settings["duration_s"])
	if settings.has("weather"):
		msg["weather"] = Weather.sanitize(settings["weather"])
	_send(msg)


func host_start_round() -> void:
	_send({"type": "start"})


# --- racing -------------------------------------------------------------------------------------

## Call every physics tick while racing. Only the latest snapshot is kept; it goes out at ~20 Hz.
func send_state(state: Dictionary) -> void:
	if not is_online() or not in_room():
		return
	_pending_state = state
	_flush_state(local_ms())


func send_checkpoint(round_id: int, cp_index: int, time_ms: int) -> void:
	_send({"type": "cp", "round_id": round_id, "cp": cp_index, "ms": time_ms})


func send_finish(round_id: int, time_ms: int) -> void:
	_send({"type": "finish", "round_id": round_id, "ms": time_ms})


func send_chat(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	_send({"type": "chat", "text": t.substr(0, MAX_CHAT)})


# --- clock --------------------------------------------------------------------------------------

func local_ms() -> int:
	return Time.get_ticks_msec()


func server_to_local_ms(server_ms: int) -> int:
	return server_ms - int(round(_clock_offset))


## Additive: current server time estimate in ms.
func server_now_ms() -> int:
	return local_ms() + int(round(_clock_offset))


## Additive: ms left in the current round (0 when over, -1 when no round).
func round_time_left_ms() -> int:
	if current_round.is_empty():
		return -1
	return maxi(0, int(current_round.get("end_at_local_ms", 0)) - local_ms())


func get_player(id: int) -> Dictionary:
	for p in room.get("players", []):
		if typeof(p) == TYPE_DICTIONARY and int(p.get("id", -1)) == id:
			return p
	return {}


# --- internals: polling -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _ws == null:
		return
	var ws := _ws
	ws.poll()
	var now := local_ms()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _opened:
		_opened = true
		_open_ms = now
		_on_open()
	# Read everything available, also while closing (the server may send an error before closing).
	while _ws == ws and ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			_handle_text(pkt.get_string_from_utf8())
	if _ws != ws:
		return # a signal handler disconnected or reconnected
	match st:
		WebSocketPeer.STATE_CONNECTING:
			if now - _connect_started_ms > CONNECT_TIMEOUT_MS:
				_drop("Connection timed out (%s)" % server_url)
		WebSocketPeer.STATE_OPEN:
			if not _welcomed and now - _open_ms > WELCOME_TIMEOUT_MS:
				_drop("The server did not answer (wrong address or version?)")
				return
			_tick_pings(now)
			_flush_state(now)
		WebSocketPeer.STATE_CLOSED:
			_drop(_close_reason(ws))


func _close_reason(ws: WebSocketPeer) -> String:
	if not _opened:
		return "Could not reach the server at %s" % server_url
	var code := ws.get_close_code()
	var why := ws.get_close_reason()
	if why != "":
		return "Connection closed: %s" % why
	if code == 1000 or code == 1001:
		return "The server closed the connection"
	return "Connection lost" if code == -1 or code == 1006 else "Connection lost (code %d)" % code


func _on_open() -> void:
	_send_raw({"type": "hello", "name": Profile.player_name, "version": PROTOCOL_VERSION})
	_samples.clear()
	_pings_sent = 0
	_next_ping_ms = local_ms()


## Lost the connection (not user initiated): clean up and tell everyone once.
func _drop(reason: String) -> void:
	_teardown()
	push_warning("Net: " + reason)
	disconnected.emit(reason)


func _teardown() -> void:
	if _ws != null:
		var st := _ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN or st == WebSocketPeer.STATE_CONNECTING:
			_ws.close(1000, "bye")
	_ws = null
	_opened = false
	_welcomed = false
	my_id = -1
	room = {}
	current_round = {}
	leaderboard = []
	_pending_state = {}
	_ignore_room_code = ""
	_outbox.clear()
	_ping_ms = -1
	_clock_valid = false


## Reliable send. While still connecting, messages are queued and go out right after welcome,
## so callers may e.g. connect_to_server() and create_room() back to back.
func _send(msg: Dictionary) -> bool:
	if _ws == null:
		return false
	if not _welcomed:
		if _outbox.size() < 32:
			_outbox.append(msg)
		return true
	return _send_raw(msg)


func _send_raw(msg: Dictionary) -> bool:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	return _ws.send_text(JSON.stringify(msg, "", false)) == OK


func _tick_pings(now: int) -> void:
	if now < _next_ping_ms:
		return
	_send_raw({"type": "ping", "t": now})
	_pings_sent += 1
	_next_ping_ms = now + (PING_BURST_GAP_MS if _pings_sent < PING_BURST else PING_INTERVAL_MS)


func _flush_state(now: int) -> void:
	if _pending_state.is_empty() or _ws == null or not _welcomed:
		return
	if now - _last_state_ms < STATE_MIN_GAP_MS:
		return
	if _ws.get_current_outbound_buffered_amount() > MAX_OUTBOUND_BUFFER:
		return # backed up: keep only the latest and try next frame
	var msg := _compact_state(_pending_state)
	msg["type"] = "state"
	_pending_state = {}
	_last_state_ms = now
	_send_raw(msg)


## Rounds floats (mm positions, 4-digit quaternions) to keep frames small, and accepts
## Vector3/Quaternion values for convenience.
static func _compact_state(s: Dictionary) -> Dictionary:
	var out := {}
	for key in s:
		var v: Variant = s[key]
		var step := 0.001
		match String(key):
			"q":
				step = 0.0001
			"v":
				step = 0.01
		match typeof(v):
			TYPE_VECTOR3:
				out[key] = [snappedf(v.x, step), snappedf(v.y, step), snappedf(v.z, step)]
			TYPE_QUATERNION:
				out[key] = [snappedf(v.x, step), snappedf(v.y, step), snappedf(v.z, step), snappedf(v.w, step)]
			TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
				var arr: Array = []
				for x in v:
					arr.append(snappedf(float(x), step) if typeof(x) == TYPE_FLOAT else x)
				out[key] = arr
			TYPE_FLOAT:
				out[key] = snappedf(v, step)
			_:
				out[key] = v
	return out


# --- internals: inbound messages ----------------------------------------------------------------

func _handle_text(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var m: Dictionary = json.data
	var kind: String = _str(m.get("type"))
	match kind:
		"welcome":
			_on_welcome(m)
		"pong":
			_on_pong(m)
		"rooms":
			var rooms: Array = []
			for r in _arr(m.get("rooms")):
				if typeof(r) == TYPE_DICTIONARY:
					rooms.append(_norm_ints(r, ["players", "max_players"]))
			rooms_listed.emit(rooms)
		"room":
			_on_room(m.get("room"))
		"round_start":
			_on_round_start(m)
		"round_end":
			if _ignore_room_code != "" or not in_room():
				return
			last_results = _norm_entries(m.get("results"))
			round_ended.emit(last_results)
		"leaderboard":
			if _ignore_room_code != "" or not in_room():
				return
			leaderboard = _norm_entries(m.get("entries"))
			leaderboard_changed.emit(leaderboard)
		"state":
			_on_state(m)
		"cp":
			if _ignore_room_code == "" and in_room():
				player_checkpoint.emit(_int(m.get("id"), -1), _int(m.get("cp"), 0), _int(m.get("ms"), 0))
		"finish_ack":
			finish_result.emit(m.get("ok") == true, _int(m.get("ms"), -1), _int(m.get("best_ms"), -1), _str(m.get("reason")))
		"left":
			if _ignore_room_code == "" and in_room():
				player_left.emit(_int(m.get("id"), -1))
		"chat":
			if _ignore_room_code == "" and in_room():
				chat.emit(_str(m.get("name")), _str(m.get("text")))
		"error":
			net_error.emit(_str(m.get("message"), "Server error"))


func _on_welcome(m: Dictionary) -> void:
	my_id = _int(m.get("id"), -1)
	server_version = _int(m.get("version"), -1)
	if not _clock_valid and typeof(m.get("server_t")) == TYPE_FLOAT:
		_clock_offset = float(m["server_t"]) - float(local_ms())
		_clock_valid = true
	var first := not _welcomed
	_welcomed = true
	if first:
		# The server learns our car before we create/join anything.
		_send_raw({"type": "profile", "name": Profile.player_name, "car": Profile.get_config()})
		for queued in _outbox:
			_send_raw(queued)
		_outbox.clear()
		if server_version != PROTOCOL_VERSION:
			net_error.emit("Server protocol v%d, game v%d: please reload the page" % [server_version, PROTOCOL_VERSION])
		connected.emit()


func _on_pong(m: Dictionary) -> void:
	if typeof(m.get("t")) != TYPE_FLOAT or typeof(m.get("server_t")) != TYPE_FLOAT:
		return
	var now := local_ms()
	var sent := int(m["t"])
	var rtt := now - sent
	if rtt < 0 or rtt > 30000:
		return
	var offset := float(m["server_t"]) + rtt * 0.5 - float(now)
	_samples.append([rtt, offset])
	while _samples.size() > CLOCK_SAMPLES:
		_samples.pop_front()
	_ping_ms = rtt if _ping_ms < 0 else int(round(lerpf(_ping_ms, rtt, 0.3)))
	# Low-RTT samples have the least asymmetric-delay error: use the median of the best few.
	var sorted := _samples.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best: Array = []
	for i in mini(CLOCK_BEST_OF, sorted.size()):
		best.append(sorted[i][1])
	best.sort()
	_clock_offset = best[best.size() >> 1]
	_clock_valid = true


func _on_room(r: Variant) -> void:
	if typeof(r) != TYPE_DICTIONARY:
		# null: the server confirmed we left (or we are not in a room).
		_ignore_room_code = ""
		if in_room():
			room = {}
			current_round = {}
			room_changed.emit(room)
		return
	var rd: Dictionary = r
	if _ignore_room_code != "":
		if String(rd.get("code", "")) == _ignore_room_code:
			return # stale update for the room we just left
		_ignore_room_code = ""
	room = _norm_room(rd)
	room_changed.emit(room)


func _on_round_start(m: Dictionary) -> void:
	if _ignore_room_code != "" or not in_room():
		return
	var start_at := _int(m.get("start_at"), 0)
	var end_at := _int(m.get("end_at"), 0)
	var info := {
		"round_id": _int(m.get("round_id"), 0),
		"track": _str(m.get("track"), "arena"),
		"duration_s": _int(m.get("duration_s"), 0),
		"weather": Weather.sanitize(m.get("weather", "dry")),
		"start_at_local_ms": server_to_local_ms(start_at),
		"end_at_local_ms": server_to_local_ms(end_at),
		# additive
		"start_at": start_at,
		"end_at": end_at,
		"late_join": server_now_ms() > start_at,
	}
	current_round = info
	leaderboard = []
	round_started.emit(info)


func _on_state(m: Dictionary) -> void:
	if _ignore_room_code != "" or not in_room():
		return
	var id := _int(m.get("id"), -1)
	if id < 0 or id == my_id:
		return
	var s := m.duplicate()
	s.erase("type")
	s.erase("id")
	for k in ["t", "fl"]:
		if s.has(k):
			s[k] = _int(s[k], 0)
	s["rx_ms"] = local_ms()
	player_state.emit(id, s)


# --- internals: normalization (JSON numbers arrive as floats) ------------------------------------

static func _int(v: Variant, def: int) -> int:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return int(v)
	return def


static func _str(v: Variant, def: String = "") -> String:
	return String(v) if typeof(v) == TYPE_STRING else def


static func _arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


static func _norm_ints(d: Dictionary, keys: Array) -> Dictionary:
	for k in keys:
		if d.has(k):
			d[k] = _int(d[k], 0)
	return d


static func _norm_entries(v: Variant) -> Array:
	var out: Array = []
	for e in _arr(v):
		if typeof(e) == TYPE_DICTIONARY:
			var d: Dictionary = _norm_ints(e, ["id", "best_ms", "runs"])
			d["name"] = _str(d.get("name"), "?")
			d["car"] = _str(d.get("car"), "")
			out.append(d)
	return out


static func _norm_room(r: Dictionary) -> Dictionary:
	_norm_ints(r, ["host", "max_players", "phase_end_at", "server_t"])
	r["code"] = _str(r.get("code"))
	r["name"] = _str(r.get("name"))
	r["phase"] = _str(r.get("phase"), "lobby")
	var settings: Dictionary = r.get("settings") if typeof(r.get("settings")) == TYPE_DICTIONARY else {}
	settings["track"] = _str(settings.get("track"), "arena")
	settings["duration_s"] = _int(settings.get("duration_s"), 300)
	r["settings"] = settings
	var rnd: Dictionary = r.get("round") if typeof(r.get("round")) == TYPE_DICTIONARY else {}
	_norm_ints(rnd, ["round_id", "duration_s", "start_at", "end_at"])
	rnd["track"] = _str(rnd.get("track"), settings["track"])
	r["round"] = rnd
	var players: Array = []
	for p in _arr(r.get("players")):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = _norm_ints(p, ["id", "best_ms", "runs"])
		pd["name"] = _str(pd.get("name"), "?")
		pd["ready"] = pd.get("ready") == true
		pd["car"] = CarDefs.sanitize_config(pd.get("car", {}))
		players.append(pd)
	r["players"] = players
	return r
