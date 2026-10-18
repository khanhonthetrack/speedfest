extends Node
## The master server's client (autoload "Master"; stadium/server/lib/master.js): your account
## (logging in keeps a token in the settings, never the password), ladder points and ranks, the
## server list, rankings, online records. The master runs where the official servers do: its
## address is the official address (stadium/server/official.json, read from GitHub), or
## --master=<url> (tests, a LAN party). Calls are awaited: `var r := await Master.call_api(...)`
## gives {code (0: unreachable), body (Dictionary)}.

signal account_changed

const TIMEOUT := 8.0

var base := ""                     ## the master's address (https://host), "" until found
var account := {}                  ## {login, nickname, zone, ladder, created}; {} when logged out
var ranks := {}                    ## {world, zone, continent, players}
var _finding := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func token() -> String:
	return String(TmUi.setting("token"))


func logged_in() -> bool:
	return not token().is_empty()


## Finds the master's address (the official address published in the repo) if not known yet.
func find() -> bool:
	if TestHooks.has_arg("master"):
		base = String(TestHooks.arg("master", "")).trim_suffix("/")
	if not base.is_empty():
		return true
	if TestHooks.is_testing():
		return false             # tests reach a master only when given one (--master)
	if _finding:
		while _finding:
			await get_tree().process_frame
		return not base.is_empty()
	_finding = true
	var r := await _request(Online.OFFICIAL_LIST, HTTPClient.METHOD_GET, "", [])
	_finding = false
	var url := String((r["body"] as Dictionary).get("url", "")) if r["code"] == 200 else ""
	if not url.is_empty():
		base = url.trim_suffix("/")
	return not base.is_empty()


## An API call: path under /api ("/me"), a JSON body for POST. {code, body}.
func call_api(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	if not await find():
		return {"code": 0, "body": {"error": "the master server isn't reachable"}}
	var headers := ["content-type: application/json"]
	if logged_in():
		headers.append("authorization: Bearer %s" % token())
	var m := HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET
	var r := await _request(base + "/api" + path, m, JSON.stringify(body) if m == HTTPClient.METHOD_POST else "", headers)
	if r["code"] == 401 and logged_in() and path != "/login":
		_forget()
	return r


func _request(url: String, method: int, data: String, headers: Array) -> Dictionary:
	var req := HTTPRequest.new()
	# the timeout runs on game time: tests (--fixed-fps) race through it before any answer
	req.timeout = 0.0 if TestHooks.is_testing() else TIMEOUT
	add_child(req)
	var err := req.request(url, PackedStringArray(headers), method, data)
	if err != OK:
		req.queue_free()
		return {"code": 0, "body": {"error": error_string(err)}}
	var res: Array = await req.request_completed
	req.queue_free()
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.strip_edges().is_empty() else null
	var code := int(res[1]) if int(res[0]) == HTTPRequest.RESULT_SUCCESS else 0
	return {"code": code, "body": parsed if parsed is Dictionary else {"error": "no answer" if code == 0 else "bad answer"}}


func _signed_in(r: Dictionary) -> String:
	if r["code"] != 200:
		return String((r["body"] as Dictionary).get("error", "the master server isn't reachable"))
	TmUi.set_setting("token", String(r["body"].get("token", "")))
	account = r["body"].get("account", {})
	account_changed.emit()
	await refresh()
	return ""


## Registers with the profile's nickname and zone. Returns "" or why not.
func register(login: String, password: String) -> String:
	var r := await call_api("POST", "/register", {"login": login, "password": password,
		"nickname": String(TmUi.setting("name")), "zone": _zone()})
	return await _signed_in(r)


func log_in(login: String, password: String) -> String:
	var r := await call_api("POST", "/login", {"login": login, "password": password})
	return await _signed_in(r)


func log_out() -> void:
	if logged_in():
		await call_api("POST", "/logout")
	_forget()


func _forget() -> void:
	TmUi.set_setting("token", "")
	account = {}
	ranks = {}
	account_changed.emit()


## Your account and ranks, fresh. Returns "" or why not.
func refresh() -> String:
	if not logged_in():
		return "not logged in"
	var r := await call_api("GET", "/me")
	if r["code"] != 200:
		return String((r["body"] as Dictionary).get("error", "the master server isn't reachable"))
	account = r["body"].get("account", {})
	ranks = r["body"].get("ranks", {})
	account_changed.emit()
	return ""


## Sends the profile's nickname and zone to the account (when logged in).
func push_profile() -> String:
	if not logged_in():
		return ""
	var r := await call_api("POST", "/me", {"nickname": String(TmUi.setting("name")), "zone": _zone()})
	if r["code"] == 200:
		account = r["body"].get("account", account)
		account_changed.emit()
		return ""
	return String((r["body"] as Dictionary).get("error", "the master server isn't reachable"))


static func _zone() -> String:
	var z := String(TmUi.setting("zone"))
	return z if not z.is_empty() else "World"


## The server list: [{id, name, address, mode, track, players, max, official}].
func servers() -> Array:
	var r := await call_api("GET", "/servers")
	return r["body"].get("servers", []) if r["code"] == 200 else []


## The ladder ranking of a zone: {zone, total, players: [{rank, login, nickname, zone, ladder}]}.
func rankings(zone := "World", limit := 50) -> Dictionary:
	var r := await call_api("GET", "/rankings?zone=%s&limit=%d" % [zone.uri_encode(), limit])
	return r["body"] if r["code"] == 200 else {}


## A track's online records: {track, count, top, zone_top, mine}.
func records(uid: String, zone := "") -> Dictionary:
	var r := await call_api("GET", "/records?track=%s&zone=%s&limit=5" % [uid.uri_encode(), zone.uri_encode()])
	return r["body"] if r["code"] == 200 else {}


## A finish of yours (solo), for the online records (when logged in). {improved, time, rank} or {}.
func submit_record(uid: String, time_ms: int) -> Dictionary:
	if not logged_in() or uid.is_empty():
		return {}
	var r := await call_api("POST", "/records", {"track": uid, "time": time_ms})
	return r["body"] if r["code"] == 200 else {}
