extends Control
## Online lobby: connect -> room browser (list / create / join by code) -> room view
## (players, host settings, ready, start, chat). Starts the race on Net.round_started.
## Built in code on top of UITheme; see docs/modules/ui_menus.md.

const VIEW_CONNECT := "connect"
const VIEW_BROWSER := "browser"
const VIEW_ROOM := "room"
const ROOM_LIST_REFRESH_S := 4.0
const CHAT_KEEP := 60

## Chat history survives scene changes (race <-> lobby <-> garage) for the current room.
static var chat_log: Array[String] = []
static var chat_room_code: String = ""

var current_view := ""

# header
var status_dot: ColorRect
var status_label: Label
var toast_label: Label
# connect view
var connect_view: Control
var name_edit: LineEdit
var url_edit: LineEdit
var connect_btn: Button
var connect_status: Label
# browser view
var browser_view: Control
var room_list: VBoxContainer
var room_list_empty: Label
var refresh_btn: Button
var room_name_edit: LineEdit
var create_btn: Button
var code_edit: LineEdit
var join_btn: Button
var browser_name_edit: LineEdit
var disconnect_btn: Button
# room view
var room_view: Control
var room_title: Label
var room_code_label: Label
var phase_label: Label
var lineup: LobbyLineup
var player_count_label: Label
var chat_text: RichTextLabel
var chat_edit: LineEdit
var track_row: HFlowContainer
var duration_row: HFlowContainer
var weather_row: HFlowContainer
const WEATHER_HINT := {"dry": "Dry: full grip", "rain": "Rain: puddles cut grip", "storm": "Storm: big puddles + lightning"}
var track_info: Label
var host_hint: Label
var ready_btn: Button
var start_btn: Button
var rejoin_btn: Button
var garage_btn: Button
var leave_btn: Button

var _room: Dictionary = {}
var live_btn: Button
var live_info: Label
var host_settings: VBoxContainer
var _starting := false
var _esc_armed_leave := false   # Esc pressed once in the room view: Leave focused, next Esc leaves
var _list_timer := 0.0
var _status_timer := 0.0
var _toast_tween: Tween
var _my_ready := false


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MenuKit.wire_focus_sounds(self)
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disconnected)
	Net.rooms_listed.connect(_on_rooms_listed)
	Net.room_changed.connect(_on_room_changed)
	Net.round_started.connect(_on_round_started)
	Net.chat.connect(_on_chat)
	Net.net_error.connect(_on_net_error)
	Audio.play_music("menu")
	_enter()


## Picks the initial view from the current Net state (we may come back from a race or the garage).
func _enter() -> void:
	if not leave_btn.focus_exited.is_connected(_disarm_leave):
		leave_btn.focus_exited.connect(_disarm_leave)
	match Net.connection_state():
		"online":
			if Net.in_room():
				_on_room_changed(Net.room)
				# A round that started while we were on our way back here (e.g. its round_start
				# arrived during the race scene's exit): join it now instead of waiting for a click.
				# A round we deliberately quit has round_id == Game.last_round_id and stays manual.
				var ph := String(Net.room.get("phase", ""))
				if (ph == "countdown" or ph == "racing") and not Net.current_round.is_empty() \
						and int(Net.current_round.get("round_id", -1)) != Game.last_round_id:
					_start_race(Net.current_round)
			elif Game.online_intent == "live":
				show_view(VIEW_BROWSER)
				_join_live()
			else:
				show_view(VIEW_BROWSER)
				Net.list_rooms()
		"connecting":
			show_view(VIEW_CONNECT)
			_set_connect_status("Connecting to %s ..." % Net.server_url, UITheme.AMBER)
		_:
			show_view(VIEW_CONNECT)
			if not TestHooks.has_arg("lobby_no_autoconnect"):
				_do_connect()


func _disarm_leave() -> void:
	_esc_armed_leave = false


func _process(delta: float) -> void:
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.5
		_update_status()
	if current_view == VIEW_ROOM and bool(_room.get("live", false)) and _status_timer >= 0.49:
		_refresh_live(String(_room.get("phase", "")))
	if current_view == VIEW_BROWSER and Net.is_online():
		_list_timer -= delta
		if _list_timer <= 0.0:
			_list_timer = ROOM_LIST_REFRESH_S
			Net.list_rooms()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	match current_view:
		VIEW_ROOM:
			# Leaving a room by accident is annoying: the first Esc only moves focus to the Leave
			# button; a second Esc leaves. Hovering Leave with the mouse doesn't arm it.
			if leave_btn.has_focus() and _esc_armed_leave:
				_on_leave()
			else:
				Audio.play_ui("back")
				leave_btn.grab_focus()
				_esc_armed_leave = true
		_:
			_on_back_to_menu()


# --- views ----------------------------------------------------------------------------------------

func show_view(v: String) -> void:
	if v == current_view:
		return
	current_view = v
	connect_view.visible = v == VIEW_CONNECT
	browser_view.visible = v == VIEW_BROWSER
	room_view.visible = v == VIEW_ROOM
	match v:
		VIEW_CONNECT:
			connect_btn.grab_focus.call_deferred()
		VIEW_BROWSER:
			_list_timer = 0.0
			browser_name_edit.text = Profile.player_name
			live_btn.grab_focus.call_deferred()
		VIEW_ROOM:
			if bool(_room.get("live", false)):
				garage_btn.grab_focus.call_deferred()
			else:
				ready_btn.grab_focus.call_deferred()


func _update_status() -> void:
	var st := Net.connection_state()
	match st:
		"online":
			status_dot.color = UITheme.LIME
			var ping := Net.ping_ms
			status_label.text = "ONLINE  ·  %s" % ("%d ms" % ping if ping >= 0 else "-- ms")
		"connecting":
			status_dot.color = UITheme.AMBER
			status_label.text = "CONNECTING"
		_:
			status_dot.color = UITheme.BAD
			status_label.text = "OFFLINE"


# --- actions --------------------------------------------------------------------------------------

func _do_connect() -> void:
	_apply_name(name_edit.text)
	var url := url_edit.text.strip_edges()
	# Remember a custom server; an empty field (or the default) means "auto".
	var auto := Settings.server_url == "" and url == _default_url()
	if not auto and url != Settings.server_url:
		Settings.server_url = "" if url == _default_url() else url
		Settings.save()
	_set_connect_status("Connecting to %s ..." % (url if url != "" else _default_url()), UITheme.AMBER)
	connect_btn.disabled = true
	Net.connect_to_server(url)


func _default_url() -> String:
	var saved := Settings.server_url
	Settings.server_url = ""
	var d := Settings.resolve_server_url()
	Settings.server_url = saved
	return d


func _apply_name(n: String) -> void:
	var clean := n.strip_edges()
	if clean == "" or clean == Profile.player_name:
		return
	Profile.set_player_name(clean)
	Profile.save()
	if Net.is_online():
		Net.set_profile(Profile.player_name, Profile.get_config())


## LIVE map rotation: the server drops us into the running round (round_start -> race).
func _join_live() -> void:
	Game.online_intent = ""
	Net.join_live()
	_toast("Jumping into LIVE ...", UITheme.LIME)


func _on_create() -> void:
	if not Net.is_online():
		return
	var rn := room_name_edit.text.strip_edges()
	if rn == "":
		rn = "%s's room" % Profile.player_name
	Net.create_room(rn)
	_toast("Creating room ...", UITheme.TEXT_DIM)


func _on_join_code() -> void:
	var code := code_edit.text.strip_edges().to_upper()
	if code.length() != 4:
		_toast("Room codes have 4 letters", UITheme.AMBER)
		Audio.play_ui("error")
		return
	Net.join_room(code)
	_toast("Joining %s ..." % code, UITheme.TEXT_DIM)


func _on_leave() -> void:
	Audio.play_ui("back")
	Net.leave_room()
	_my_ready = false


func _on_back_to_menu() -> void:
	Audio.play_ui("back")
	if Net.in_room():
		Net.leave_room()
	Game.to_menu()


func _on_ready_toggle() -> void:
	_my_ready = not _my_ready
	Net.set_ready(_my_ready)
	_refresh_ready_button()


func _on_start() -> void:
	if not Net.is_host():
		return
	Audio.play_ui("confirm")
	Net.host_start_round()


func _on_rejoin() -> void:
	if not Net.current_round.is_empty():
		_start_race(Net.current_round)


func _on_garage() -> void:
	Game.to_garage(Game.SCENE_LOBBY)


func _on_pick_track(i: int) -> void:
	if not Net.is_host():
		_refresh_settings()
		return
	# picking a stage also picks its signature weather (downtown = rain); the host can change it
	Net.host_set_settings({"track": TrackDefs.IDS[i], "weather": Weather.default_for(TrackDefs.IDS[i])})


func _on_pick_weather(i: int) -> void:
	if not Net.is_host():
		_refresh_settings()
		return
	Net.host_set_settings({"weather": Weather.MODES[i]})


func _on_pick_duration(i: int) -> void:
	if not Net.is_host():
		_refresh_settings()
		return
	Net.host_set_settings({"duration_s": TrackDefs.DURATIONS_S[i]})


func _on_chat_submit(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	Net.send_chat(t)
	chat_edit.text = ""


# --- Net events -----------------------------------------------------------------------------------

func _on_connected() -> void:
	connect_btn.disabled = false
	_set_connect_status("Connected", UITheme.LIME)
	Audio.play_ui("confirm")
	if Net.in_room():
		_on_room_changed(Net.room)
	else:
		show_view(VIEW_BROWSER)
		Net.list_rooms()
		if Game.online_intent == "live":
			_join_live()


func _on_disconnected(reason: String) -> void:
	connect_btn.disabled = false
	_room = {}
	show_view(VIEW_CONNECT)
	_set_connect_status(reason, UITheme.BAD)
	_toast(reason, UITheme.BAD)
	Audio.play_ui("error")


func _on_net_error(message: String) -> void:
	_toast(message, UITheme.BAD)
	Audio.play_ui("error")


func _on_round_started(info: Dictionary) -> void:
	_start_race(info)


func _start_race(info: Dictionary) -> void:
	if _starting:
		return
	_starting = true
	Audio.play_ui("confirm")
	Game.start_online_round(info)


func _on_chat(from_name: String, text: String) -> void:
	_add_chat_line("[color=#%s][b]%s[/b][/color]  %s" % [UITheme.CYAN.to_html(false), _esc(from_name), _esc(text)])


func _on_rooms_listed(rooms: Array) -> void:
	_clear(room_list)
	room_list_empty.visible = rooms.is_empty()
	for r in rooms:
		if typeof(r) == TYPE_DICTIONARY:
			room_list.add_child(_room_entry(r))


func _on_room_changed(room: Dictionary) -> void:
	if room.is_empty():
		_room = {}
		if Net.is_online():
			show_view(VIEW_BROWSER)
			Net.list_rooms()
		else:
			show_view(VIEW_CONNECT)
		return
	var first := _room.is_empty() or String(_room.get("code", "")) != String(room.get("code", ""))
	_room = room
	var code := String(room.get("code", ""))
	if code != chat_room_code:
		chat_room_code = code
		chat_log.clear()
		if bool(room.get("live", false)):
			_add_chat_line("[color=#%s]Joined LIVE: tracks rotate non-stop. Drive as many runs as you like, best time wins the round.[/color]" % UITheme.TEXT_DIM.to_html(false))
		else:
			_add_chat_line("[color=#%s]Joined room %s. Share the code with your friends![/color]" % [UITheme.TEXT_DIM.to_html(false), code])
	elif first:
		_render_chat()
	for p in room.get("players", []):
		if int(p.get("id", -1)) == Net.my_id:
			_my_ready = bool(p.get("ready", false))
	show_view(VIEW_ROOM)
	_refresh_room()


# --- room view rendering --------------------------------------------------------------------------

func _refresh_room() -> void:
	var r := _room
	room_title.text = String(r.get("name", "Room")).to_upper()
	room_code_label.text = String(r.get("code", "----"))
	var players: Array = r.get("players", [])
	var host_id := int(r.get("host", -1))
	player_count_label.text = "%d / %d" % [players.size(), int(r.get("max_players", 8))]
	lineup.set_players(players, Net.my_id, host_id)
	_refresh_settings()
	_refresh_ready_button()
	var phase := String(r.get("phase", "lobby"))
	var am_host := host_id == Net.my_id
	var ready_n := 0
	for p in players:
		if bool(p.get("ready", false)):
			ready_n += 1
	start_btn.visible = am_host
	var can_start := phase == "lobby" or phase == "results"
	start_btn.disabled = not can_start
	start_btn.text = "START RACE  (%d/%d ready)" % [ready_n, players.size()]
	var in_round := (phase == "countdown" or phase == "racing") and not Net.current_round.is_empty()
	rejoin_btn.visible = in_round
	match phase:
		"lobby":
			phase_label.text = "WAITING FOR HOST" if not am_host else "READY WHEN YOU ARE"
			phase_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		"countdown":
			phase_label.text = "ROUND STARTING"
			phase_label.add_theme_color_override("font_color", UITheme.AMBER)
		"racing":
			phase_label.text = "ROUND IN PROGRESS"
			phase_label.add_theme_color_override("font_color", UITheme.LIME)
		"results":
			phase_label.text = "RESULTS  ·  BACK TO LOBBY SOON"
			phase_label.add_theme_color_override("font_color", UITheme.MAGENTA)
	host_hint.text = "You're the host: pick track, length and weather, then start." if am_host \
		else "The host picks the track and starts the round."
	var live := bool(r.get("live", false))
	host_settings.visible = not live
	ready_btn.visible = not live
	if live:
		start_btn.visible = false
		_refresh_live(phase)


## LIVE room: no host, no settings; show what's on now and what's next.
func _refresh_live(phase: String) -> void:
	var rd: Dictionary = _room.get("round", {})
	var nx: Variant = _room.get("next", null)
	var now_id := String(rd.get("track", ""))
	var lines: Array[String] = []
	if now_id != "" and phase != "lobby":
		var wx := Weather.sanitize(rd.get("weather", "dry"))
		lines.append("NOW  %s  ·  %s" % [TrackDefs.display_name(now_id), Weather.display_name(wx)])
	if typeof(nx) == TYPE_DICTIONARY and String(nx.get("track", "")) != "":
		lines.append("NEXT  %s  ·  %s" % [TrackDefs.display_name(String(nx["track"])), Weather.display_name(Weather.sanitize(nx.get("weather", "dry")))])
	track_info.text = "\n".join(lines)
	host_hint.text = "Tracks rotate by themselves, round after round. Jump in any time: your best run of the round counts."
	var left_s := maxi(0, int(ceil(float(int(_room.get("phase_end_at", 0)) - Net.server_now_ms()) / 1000.0)))
	match phase:
		"results":
			phase_label.text = "LIVE  ·  NEXT ROUND IN %d s" % left_s if left_s > 0 else "LIVE  ·  NEXT ROUND"
			phase_label.add_theme_color_override("font_color", UITheme.MAGENTA)
		"countdown", "racing":
			phase_label.text = "LIVE  ·  ROUND IN PROGRESS"
			phase_label.add_theme_color_override("font_color", UITheme.LIME)
		_:
			phase_label.text = "LIVE  ·  STARTING"
			phase_label.add_theme_color_override("font_color", UITheme.AMBER)


func _refresh_settings() -> void:
	var s: Dictionary = _room.get("settings", {})
	var tid := String(s.get("track", "arena"))
	var dur := int(s.get("duration_s", TrackDefs.DEFAULT_DURATION_S))
	var wx := Weather.sanitize(s.get("weather", "dry"))
	MenuKit.select_chip(track_row, TrackDefs.IDS.find(tid))
	MenuKit.select_chip(weather_row, Weather.MODES.find(wx))
	var di := TrackDefs.DURATIONS_S.find(dur)
	MenuKit.select_chip(duration_row, di)
	var am_host := Net.is_host() or int(_room.get("host", -1)) == Net.my_id
	for c in track_row.get_children():
		(c as BaseButton).disabled = not am_host and not (c as BaseButton).button_pressed
	for c in duration_row.get_children():
		(c as BaseButton).disabled = not am_host and not (c as BaseButton).button_pressed
	for c in weather_row.get_children():
		(c as BaseButton).disabled = not am_host and not (c as BaseButton).button_pressed
	var d := TrackDefs.get_def(tid)
	var pb := Profile.get_pb(Weather.pb_key(tid, wx))
	var dur_txt := "%d min" % (dur / 60) if dur % 60 == 0 else "%d s" % dur
	track_info.text = "%s  ·  ~%d s per run  ·  round %s\n%s  ·  your PB %s" % [
		String(d["name"]), int(d["target_s"]), dur_txt,
		WEATHER_HINT.get(wx, ""), UITheme.format_time(pb)]


func _refresh_ready_button() -> void:
	ready_btn.text = "READY!" if _my_ready else "NOT READY"
	ready_btn.add_theme_color_override("font_color", UITheme.LIME if _my_ready else UITheme.TEXT)
	ready_btn.add_theme_color_override("font_focus_color", UITheme.LIME if _my_ready else UITheme.CYAN)
	ready_btn.add_theme_stylebox_override("normal", UITheme.panel_style(
		Color(UITheme.LIME, 0.18) if _my_ready else UITheme.PANEL,
		UITheme.LIME if _my_ready else UITheme.CYAN.darkened(0.35), 2))


func _badge(text: String, color: Color) -> Label:
	var l := UITheme.label(text, "head", 12, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.14)
	sb.border_color = Color(color, 0.8)
	sb.set_border_width_all(1)
	sb.skew = Vector2(UITheme.SKEW, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	return l


func _room_entry(r: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	MenuKit.wire_button(b)
	var code := String(r.get("code", ""))
	b.pressed.connect(func() -> void:
		Net.join_room(code)
		_toast("Joining %s ..." % code, UITheme.TEXT_DIM))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -22
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 16)
	b.add_child(h)
	var is_live := bool(r.get("live", false))
	var cl := UITheme.label(code, "heavy", 22, UITheme.LIME if is_live else UITheme.CYAN)
	cl.custom_minimum_size = Vector2(90, 0)
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(cl)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", -4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := UITheme.label(String(r.get("name", "Room")), "body_bold", 21, UITheme.TEXT)
	nm.clip_text = true
	info.add_child(nm)
	var tname := TrackDefs.display_name(String(r.get("track", "arena")))
	var host_name := String(r.get("host_name", ""))
	if is_live:
		var on_now := int(r.get("players", 0)) > 0
		info.add_child(UITheme.label("Non-stop rotation%s" % (("  ·  now " + tname) if on_now else ""), "body", 17, UITheme.TEXT_DIM))
	else:
		info.add_child(UITheme.label("%s%s" % [tname, ("  ·  host " + host_name) if host_name != "" else ""], "body", 17, UITheme.TEXT_DIM))
	h.add_child(info)
	var phase := String(r.get("phase", "lobby"))
	if is_live:
		phase = "racing" if int(r.get("players", 0)) > 0 else "lobby"
	var phase_col := UITheme.TEXT_DIM if phase == "lobby" else (UITheme.LIME if phase == "racing" else UITheme.AMBER)
	var pl := _badge(("ALWAYS ON" if is_live else "IN LOBBY") if phase == "lobby" else ("LIVE" if is_live else phase.to_upper()), phase_col)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pl)
	var cnt := UITheme.label("%d/%d" % [int(r.get("players", 0)), int(r.get("max_players", 8))], "num", 17, UITheme.TEXT)
	cnt.custom_minimum_size = Vector2(52, 0)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(cnt)
	return b


static func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# --- chat / toast ---------------------------------------------------------------------------------

func _add_chat_line(bb: String) -> void:
	chat_log.append(bb)
	while chat_log.size() > CHAT_KEEP:
		chat_log.pop_front()
	_render_chat()


func _render_chat() -> void:
	if chat_text == null:
		return
	chat_text.text = "\n".join(chat_log)


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _toast(text: String, color: Color = UITheme.TEXT) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func _set_connect_status(text: String, color: Color) -> void:
	connect_status.text = text
	connect_status.add_theme_color_override("font_color", color)


# --- building -------------------------------------------------------------------------------------

func _build() -> void:
	add_child(MenuKit.backdrop(UITheme.CYAN))
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 48)
	root.add_theme_constant_override("margin_top", 28)
	root.add_theme_constant_override("margin_bottom", 22)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	# header row
	var top := HBoxContainer.new()
	top.add_child(MenuKit.header("ONLINE", "Time Attack with friends", UITheme.CYAN))
	top.add_child(MenuKit.spacer(0, 0, true))
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 10)
	status.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	status_dot = ColorRect.new()
	status_dot.custom_minimum_size = Vector2(12, 12)
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(status_dot)
	status_label = UITheme.label("OFFLINE", "head", 16, UITheme.TEXT)
	status.add_child(status_label)
	top.add_child(status)
	col.add_child(top)

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	connect_view = _build_connect_view()
	browser_view = _build_browser_view()
	room_view = _build_room_view()
	for v in [connect_view, browser_view, room_view]:
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.visible = false
		body.add_child(v)

	var bottom := HBoxContainer.new()
	toast_label = UITheme.label("", "body_bold", 20, UITheme.TEXT)
	toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(toast_label)
	bottom.add_child(MenuKit.key_hints([["ENTER", "Select"], ["ESC", "Back"]]))
	col.add_child(bottom)


func _build_connect_view() -> Control:
	var center := CenterContainer.new()
	var p := MenuKit.panel()
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(MenuKit.caption("Player name"))
	name_edit = LineEdit.new()
	name_edit.text = Profile.player_name
	name_edit.max_length = 16
	name_edit.placeholder_text = "Your name"
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.text_submitted.connect(func(_t: String) -> void: _do_connect())
	v.add_child(name_edit)
	v.add_child(MenuKit.caption("Server address"))
	url_edit = LineEdit.new()
	url_edit.text = Settings.resolve_server_url()
	url_edit.custom_minimum_size = Vector2(0, 46)
	url_edit.text_submitted.connect(func(_t: String) -> void: _do_connect())
	v.add_child(url_edit)
	var hint := UITheme.label("Playing in the browser? The address is filled in for you.", "body", 18, UITheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	v.add_child(MenuKit.spacer(0, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var back := MenuKit.button("BACK", 150)
	back.pressed.connect(_on_back_to_menu)
	row.add_child(back)
	connect_btn = MenuKit.button("CONNECT", 0, 52)
	connect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connect_btn.pressed.connect(_do_connect)
	row.add_child(connect_btn)
	v.add_child(row)
	connect_status = UITheme.label("", "body_bold", 20, UITheme.TEXT_DIM)
	connect_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connect_status.custom_minimum_size = Vector2(0, 52)
	v.add_child(connect_status)
	return center


func _build_browser_view() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	# room list
	var lp := MenuKit.panel()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.6
	h.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lp.add_child(lv)
	# LIVE first: the always-on rotation is the quickest way into a race (owner, session 6).
	var lvh := HBoxContainer.new()
	lvh.add_theme_constant_override("separation", 16)
	var lvt := VBoxContainer.new()
	lvt.add_theme_constant_override("separation", 2)
	lvt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvt.add_child(MenuKit.caption("LIVE · non-stop rotation", UITheme.LIME))
	live_info = UITheme.label("No lobby, no waiting: tracks rotate round after round. Your best run counts.", "body", 17, UITheme.TEXT_DIM)
	live_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lvt.add_child(live_info)
	lvh.add_child(lvt)
	live_btn = MenuKit.button("JUMP IN", 200, 58)
	live_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	live_btn.add_theme_font_override("font", UITheme.font("head"))
	live_btn.add_theme_font_size_override("font_size", 22)
	live_btn.add_theme_color_override("font_color", UITheme.LIME)
	live_btn.add_theme_stylebox_override("normal", UITheme.panel_style(Color(UITheme.LIME, 0.18), UITheme.LIME, 2))
	live_btn.add_theme_stylebox_override("hover", UITheme.panel_style(Color(UITheme.LIME, 0.32), UITheme.LIME.lightened(0.3), 2))
	live_btn.pressed.connect(_join_live)
	lvh.add_child(live_btn)
	lv.add_child(lvh)
	lv.add_child(HSeparator.new())
	var lh := HBoxContainer.new()
	var cap := MenuKit.caption("Open rooms")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(cap)
	refresh_btn = MenuKit.button("REFRESH", 150, 40)
	refresh_btn.pressed.connect(func() -> void:
		_list_timer = ROOM_LIST_REFRESH_S
		Net.list_rooms())
	lh.add_child(refresh_btn)
	lv.add_child(lh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)
	room_list_empty = UITheme.label("No rooms yet. Create one and send the code to your friends!", "body", 20, UITheme.TEXT_DIM)
	room_list_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(room_list_empty)
	room_list = VBoxContainer.new()
	room_list.add_theme_constant_override("separation", 8)
	list_box.add_child(room_list)

	# right column
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 16)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rv)
	var cp := MenuKit.panel()
	rv.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cp.add_child(cv)
	cv.add_child(MenuKit.caption("Create a room", UITheme.MAGENTA))
	room_name_edit = LineEdit.new()
	room_name_edit.placeholder_text = "Room name (optional)"
	room_name_edit.max_length = 24
	room_name_edit.custom_minimum_size = Vector2(0, 44)
	room_name_edit.text_submitted.connect(func(_t: String) -> void: _on_create())
	cv.add_child(room_name_edit)
	create_btn = MenuKit.button("CREATE ROOM", 0, 50)
	create_btn.pressed.connect(_on_create)
	cv.add_child(create_btn)

	var jp := MenuKit.panel()
	rv.add_child(jp)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 8)
	jp.add_child(jv)
	jv.add_child(MenuKit.caption("Join with a code", UITheme.MAGENTA))
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 12)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "ABCD"
	code_edit.max_length = 4
	code_edit.custom_minimum_size = Vector2(130, 50)
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.add_theme_font_override("font", UITheme.font("heavy"))
	code_edit.add_theme_font_size_override("font_size", 24)
	code_edit.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			var caret := code_edit.caret_column
			code_edit.text = up
			code_edit.caret_column = caret)
	code_edit.text_submitted.connect(func(_t: String) -> void: _on_join_code())
	jr.add_child(code_edit)
	join_btn = MenuKit.button("JOIN", 0, 50)
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn.pressed.connect(_on_join_code)
	jr.add_child(join_btn)
	jv.add_child(jr)

	var pp := MenuKit.panel()
	rv.add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pp.add_child(pv)
	pv.add_child(MenuKit.caption("You"))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 12)
	browser_name_edit = LineEdit.new()
	browser_name_edit.max_length = 16
	browser_name_edit.custom_minimum_size = Vector2(0, 44)
	browser_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_name_edit.text_submitted.connect(func(t: String) -> void:
		_apply_name(t)
		name_edit.text = Profile.player_name
		_toast("Name set to %s" % Profile.player_name, UITheme.LIME))
	browser_name_edit.focus_exited.connect(func() -> void:
		_apply_name(browser_name_edit.text)
		name_edit.text = Profile.player_name)
	nr.add_child(browser_name_edit)
	var gb := MenuKit.button("GARAGE", 140, 44)
	gb.pressed.connect(_on_garage)
	nr.add_child(gb)
	pv.add_child(nr)
	rv.add_child(MenuKit.spacer(0, 0, true))
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 12)
	var back := MenuKit.button("MAIN MENU", 0, 46)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_on_back_to_menu)
	br.add_child(back)
	disconnect_btn = MenuKit.button("DISCONNECT", 0, 46)
	disconnect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disconnect_btn.pressed.connect(func() -> void: Net.disconnect_from_server())
	br.add_child(disconnect_btn)
	rv.add_child(br)
	return h


func _build_room_view() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	# left: players + chat
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.45
	left.add_theme_constant_override("separation", 14)
	h.add_child(left)
	var pp := MenuKit.panel()
	pp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pp.size_flags_stretch_ratio = 1.3
	left.add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pp.add_child(pv)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_title = UITheme.label("ROOM", "head", 22, UITheme.TEXT)
	room_title.clip_text = true
	tv.add_child(room_title)
	phase_label = UITheme.label("", "head", 13, UITheme.TEXT_DIM)
	tv.add_child(phase_label)
	title_row.add_child(tv)
	var code_box := VBoxContainer.new()
	code_box.add_theme_constant_override("separation", -6)
	var ccap := UITheme.label("ROOM CODE", "head", 11, UITheme.TEXT_DIM)
	ccap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	code_box.add_child(ccap)
	room_code_label = UITheme.label("----", "heavy", 36, UITheme.MAGENTA)
	room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_code_label.add_theme_color_override("font_shadow_color", Color(UITheme.MAGENTA, 0.4))
	code_box.add_child(room_code_label)
	title_row.add_child(code_box)
	pv.add_child(title_row)
	var ph := HBoxContainer.new()
	var pcap := MenuKit.caption("Players")
	pcap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pcap)
	player_count_label = UITheme.label("0 / 8", "num", 14, UITheme.TEXT_DIM)
	ph.add_child(player_count_label)
	pv.add_child(ph)
	# Rocket League-style lineup: everyone's car, live (owner, session 4)
	lineup = LobbyLineup.new()
	lineup.name = "Lineup"
	lineup.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lineup.size_flags_stretch_ratio = 2.2
	lineup.custom_minimum_size = Vector2(0, 200)
	pv.add_child(lineup)

	var cp := MenuKit.panel()
	cp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cp.add_child(cv)
	cv.add_child(MenuKit.caption("Chat"))
	chat_text = RichTextLabel.new()
	chat_text.bbcode_enabled = true
	chat_text.scroll_following = true
	chat_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_text.custom_minimum_size = Vector2(0, 60)
	chat_text.add_theme_font_size_override("normal_font_size", 19)
	chat_text.add_theme_font_size_override("bold_font_size", 19)
	chat_text.focus_mode = Control.FOCUS_NONE
	cv.add_child(chat_text)
	chat_edit = LineEdit.new()
	chat_edit.placeholder_text = "Say something ... (Enter to send)"
	chat_edit.max_length = 200
	chat_edit.custom_minimum_size = Vector2(0, 40)
	chat_edit.add_theme_font_size_override("font_size", 19)
	chat_edit.text_submitted.connect(_on_chat_submit)
	cv.add_child(chat_edit)
	_render_chat()

	# right: settings + actions
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	var sp := MenuKit.panel()
	right.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sp.add_child(sv)
	host_settings = VBoxContainer.new()
	host_settings.add_theme_constant_override("separation", 8)
	sv.add_child(host_settings)
	host_settings.add_child(MenuKit.caption("Track", UITheme.MAGENTA))
	var tnames: Array = []
	for id in TrackDefs.IDS:
		tnames.append(TrackDefs.short_name(id))   # one row of chips; the full name is in track_info
	track_row = MenuKit.chip_row(tnames, _on_pick_track)
	# 30+ tracks since M7-6: two rows visible, the rest scrolls (follows keyboard focus)
	var track_scroll := ScrollContainer.new()
	track_scroll.custom_minimum_size = Vector2(0, 96)
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.follow_focus = true
	track_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_scroll.add_child(track_row)
	host_settings.add_child(track_scroll)
	host_settings.add_child(MenuKit.caption("Round length", UITheme.MAGENTA))
	var dnames: Array = []
	for d in TrackDefs.DURATIONS_S:
		dnames.append("%d MIN" % (d / 60))
	duration_row = MenuKit.chip_row(dnames, _on_pick_duration, 80)
	host_settings.add_child(duration_row)
	host_settings.add_child(MenuKit.caption("Weather", UITheme.MAGENTA))
	var wnames: Array = []
	for m in Weather.MODES:
		wnames.append(Weather.display_name(m).to_upper())
	weather_row = MenuKit.chip_row(wnames, _on_pick_weather, 80)
	host_settings.add_child(weather_row)
	track_info = UITheme.label("", "body", 18, UITheme.TEXT_DIM)
	track_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(track_info)
	host_hint = UITheme.label("", "body", 17, UITheme.TEXT_DIM)
	host_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(host_hint)

	right.add_child(MenuKit.spacer(0, 0, true))
	rejoin_btn = MenuKit.button("JOIN THE RUNNING ROUND", 0, 48)
	rejoin_btn.add_theme_color_override("font_color", UITheme.LIME)
	rejoin_btn.pressed.connect(_on_rejoin)
	rejoin_btn.visible = false
	right.add_child(rejoin_btn)
	ready_btn = MenuKit.button("NOT READY", 0, 48)
	ready_btn.pressed.connect(_on_ready_toggle)
	right.add_child(ready_btn)
	start_btn = MenuKit.button("START RACE", 0, 54)
	start_btn.add_theme_font_override("font", UITheme.font("head"))
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.add_theme_stylebox_override("normal", UITheme.panel_style(Color(UITheme.MAGENTA, 0.25), UITheme.MAGENTA, 2))
	start_btn.add_theme_stylebox_override("hover", UITheme.panel_style(Color(UITheme.MAGENTA, 0.45), UITheme.MAGENTA.lightened(0.3), 2))
	start_btn.pressed.connect(_on_start)
	right.add_child(start_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	garage_btn = MenuKit.button("GARAGE", 0, 44)
	garage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage_btn.pressed.connect(_on_garage)
	row.add_child(garage_btn)
	leave_btn = MenuKit.button("LEAVE ROOM", 0, 44)
	leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave_btn.pressed.connect(_on_leave)
	row.add_child(leave_btn)
	right.add_child(row)
	return h
