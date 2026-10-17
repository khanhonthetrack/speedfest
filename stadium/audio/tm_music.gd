extends Node
## The music (autoload "Music"): open-licensed dark trap and hip-hop instrumentals downloaded from
## OpenGameArt (CC0, CC BY, CC BY-SA; audio/music/CREDITS.md), one playlist for the menus and one
## for racing, shuffled, crossfading from track to track and across scenes; a "now playing" toast.
## Settings: "music" (on/off), "music_volume" (0..1).

signal now_playing(title: String, artist: String)

## [file, title, artist, playlists]
const TRACKS := [
	["trappist.ogg", "Trappist", "Axton Crolley", ["menu", "race"]],
	["friendly_trap_mix.ogg", "Friendly Trap", "Of Far Different Nature, extenz, vitalezzz", ["menu"]],
	["prophesy_of_domination.ogg", "Prophesy of Domination", "Gichco", ["menu", "race"]],
	["cauliflower.ogg", "Cauliflower - Day 27", "Zane Little Music", ["race"]],
	["wrong_vergin.ogg", "ZeWrungVergeun", "Sudocolon", ["race"]],
	["wifi_trasherino.ogg", "WiFi Trasherino", "Sudocolon", ["race"]],
	["battle_city.ogg", "Baeddle;Ceity", "Sudocolon", ["race"]],
	["dark_waves.ogg", "Dark-Waves-Hip-Hop", "Dogers", ["race"]],
]
const FADE := 1.5
const DIR := "res://audio/music/"

var playlist := ""
var current := -1
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _bag: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		p.finished.connect(_on_finished.bind(p))
		_players.append(p)


## Plays from a playlist ("menu", "race"); keeps the current track if it already is that list's.
func play_list(list: String) -> void:
	if list == playlist and current >= 0 and _players[_active].playing:
		return
	playlist = list
	_bag.clear()
	_next()


func stop() -> void:
	playlist = ""
	for p in _players:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -80.0, FADE)
		tw.tween_callback(p.stop)


func level_db() -> float:
	if not bool(TmUi.setting("music")):
		return -80.0
	return linear_to_db(clampf(float(TmUi.setting("music_volume")), 0.0, 1.0) * (0.55 if playlist == "race" else 0.8) + 1e-4)


## The setting changed: follow it at once.
func apply_volume() -> void:
	if current >= 0:
		_players[_active].volume_db = level_db()


func _next() -> void:
	if playlist.is_empty() or DisplayServer.get_name() == "headless" and not TestHooks.has_arg("music_test"):
		return
	if _bag.is_empty():
		for i in TRACKS.size():
			if playlist in (TRACKS[i][3] as Array) and i != current:
				_bag.append(i)
		_bag.shuffle()
	if _bag.is_empty():
		return
	current = _bag.pop_back()
	var t: Array = TRACKS[current]
	var stream: AudioStream = load(DIR + String(t[0]))
	var old := _players[_active]
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "volume_db", level_db(), FADE)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.chain().tween_callback(old.stop)
	now_playing.emit(String(t[1]), String(t[2]))


func _on_finished(p: AudioStreamPlayer) -> void:
	if p == _players[_active]:
		_next()


## A "now playing" toast for a scene: bottom right, fades after a few seconds.
static func toast(parent: Node) -> void:
	var music: Node = parent.get_node_or_null("/root/Music")
	if music == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 8
	parent.add_child(layer)
	var l := TmUi.label("", 18, TmUi.DIM, TmUi.BOLD, 1)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 28)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.position.y -= 92
	l.modulate.a = 0.0
	layer.add_child(l)
	var show := func(title: String, artist: String) -> void:
		if not is_instance_valid(l):
			return
		l.text = "NOW PLAYING\n%s  ·  %s" % [title, artist]
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.4)
		tw.tween_interval(4.0)
		tw.tween_property(l, "modulate:a", 0.0, 0.8)
	music.now_playing.connect(show)
	l.tree_exiting.connect(func() -> void:
		if music.now_playing.is_connected(show):
			music.now_playing.disconnect(show))
	if music.current >= 0:
		var t: Array = TRACKS[music.current]
		show.call(String(t[1]), String(t[2]))
