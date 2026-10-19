extends Node
## The menu's Community page (needs Node.js; skipped without it), against the stadium server's
## /api/community pass-through serving local fixtures in place of TrackMania Exchange and
## ManiaPark (--community-fixtures): the car and track lists show their previews, a car is
## downloaded (checked: it loads), driven (the menu's turntable and a race use it), a track is
## downloaded and played, a modded one is kept but can't be raced, MY CARS lists the library.

const PORT := 18095
const CAR_ID := "TestCarAsset01"
const TRACK_ID := "4242"
const MODDED_ID := "4343"

var _pid := -1


func _ready() -> void:
	TestHooks.args["settings"] = "user://test_settings_community.cfg"
	TestHooks.args["records"] = "user://test_records_community"
	TestHooks.args["community_dir"] = "user://test_community"
	TestHooks.args["menu_dry"] = "true"
	for p in ["user://test_settings_community.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_wipe(ProjectSettings.globalize_path("user://test_community"))
	var node := _node()
	var script := ProjectSettings.globalize_path("res://server/server.js")
	if node.is_empty() or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://server/node_modules/ws")):
		TestHooks.ok("community_skipped_no_node")
		TestHooks.finish()
		return
	var fx := ProjectSettings.globalize_path("user://test_community_fixtures")
	_wipe(fx)
	DirAccess.make_dir_recursive_absolute(fx)
	_fixtures(node, fx)
	var data := ProjectSettings.globalize_path("user://test_community_master")
	_wipe(data)
	_pid = OS.create_process(node, [script, "--port=%d" % PORT, "--host=127.0.0.1", "--data=%s" % data, "--community-fixtures=%s" % fx])
	var up := await _wait(func() -> bool: return _up_at(PORT), 8000)
	TestHooks.check(up, "community_server_up")
	if not up:
		_end()
		return
	TestHooks.args["community"] = "http://127.0.0.1:%d/api/community" % PORT
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	# cars: ManiaPark's car models, with their previews
	menu.show_page("community")
	var listed := await _wait(func() -> bool: return menu.comm_cards.has("model_" + CAR_ID), 8000)
	TestHooks.check(listed and menu.comm_tab == "cars", "community_cars_listed", str(menu.comm_cards.keys()))
	if not listed:
		_end()
		return
	var card: Button = menu.comm_cards["model_" + CAR_ID]
	var shown := await _wait(func() -> bool: return (card.find_child("Preview", true, false) as TextureRect).texture != null, 8000)
	TestHooks.check(shown, "community_car_preview_shown")
	var big := await _wait(func() -> bool:
		var p := menu._comm_detail.find_child("Preview", true, false) as TextureRect
		return p != null and p.texture != null, 8000)
	TestHooks.check(big and _has_button(menu._comm_detail, "DOWNLOAD"), "community_car_detail", str(_button_texts(menu._comm_detail)))
	menu.comm_download("model_" + CAR_ID)
	var got := await _wait(func() -> bool: return _has_button(menu._comm_detail, "DRIVE THIS CAR"), 15000)
	var entry: Dictionary = menu.community.library["cars"].get("model_" + CAR_ID, {})
	TestHooks.check(got and FileAccess.file_exists(String(entry.get("path", ""))) and TmCarPack.load_zip(String(entry["path"])).ok(),
		"community_car_downloaded", str(entry))
	TestHooks.check(_turntable_pack(menu) != null, "community_car_on_the_turntable")
	menu.comm_drive(String(entry.get("path", "")))
	await _wait(func() -> bool: return menu.comm_cards.has("model_" + CAR_ID), 8000)
	TestHooks.check(String(TmUi.setting("community_car")) == String(entry.get("path", "")) and TmCommunity.my_car_pack() != null,
		"community_car_driven")
	await _wait(func() -> bool: return _label_text(menu._comm_detail).contains("YOU DRIVE THIS CAR"), 3000)
	TestHooks.check(_label_text(menu._comm_detail).contains("YOU DRIVE THIS CAR"), "community_car_says_driving")
	# MY CARS: the library
	menu.comm_filter["cars"] = "mine"
	menu.show_page("community")
	await _wait(func() -> bool: return menu.comm_cards.has("model_" + CAR_ID), 3000)
	TestHooks.check(menu.comm_cards.size() == 1 and menu.comm_cards.has("model_" + CAR_ID), "community_my_cars", str(menu.comm_cards.keys()))
	# tracks: TrackMania Exchange's, with their previews
	menu.comm_tab = "tracks"
	menu.show_page("community")
	listed = await _wait(func() -> bool: return menu.comm_cards.has(TRACK_ID) and menu.comm_cards.has(MODDED_ID), 8000)
	TestHooks.check(listed, "community_tracks_listed", str(menu.comm_cards.keys()))
	if listed:
		card = menu.comm_cards[TRACK_ID]
		shown = await _wait(func() -> bool: return (card.find_child("Preview", true, false) as TextureRect).texture != null, 8000)
		TestHooks.check(shown, "community_track_preview_shown")
		menu.comm_select(TRACK_ID)
		menu.comm_download(TRACK_ID)
		got = await _wait(func() -> bool: return _has_button(menu._comm_detail, "PLAY"), 15000)
		TestHooks.check(got, "community_track_downloaded_playable", _label_text(menu._comm_detail))
		var raced := []
		menu.raced.connect(func(t: String, m: String) -> void: raced.append(m))
		if got:
			_press(menu._comm_detail, "PLAY")
		var path := String((menu.community.library["tracks"] as Dictionary).get(TRACK_ID, {}).get("path", ""))
		TestHooks.check(raced.size() == 1 and raced[0] == path and TmChallenge.load_file(path).ok(), "community_track_played", str(raced))
		menu.comm_select(MODDED_ID)
		menu.comm_download(MODDED_ID)
		var refused := await _wait(func() -> bool: return _label_text(menu._comm_detail).contains("CAN'T BE RACED"), 15000)
		TestHooks.check(refused and not _has_button(menu._comm_detail, "PLAY"), "community_modded_track_not_raced", _label_text(menu._comm_detail))
	menu.queue_free()
	# a race drives the community car
	TestHooks.args["track"] = "SF01"
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	await _wait(func() -> bool: return scene.ready_to_race, 20000)
	var look: TmCarVisual = null
	for c in scene.car.get_children():
		if c is TmCarVisual:
			look = c
	TestHooks.check(look != null and look.pack != null and look.pack == TmCommunity.my_car_pack(), "community_car_raced")
	scene.queue_free()
	TestHooks.args.erase("track")
	TmCommunity.drive("")
	_end()


func _end() -> void:
	if _pid > 0:
		OS.kill(_pid)
	TestHooks.finish()


## The fixtures: one car model (TmTestCar's pack) and two tracks (one built of TMNF Stadium blocks,
## one with a block that isn't one), with previews.
func _fixtures(node: String, fx: String) -> void:
	var png := Image.create(64, 36, false, Image.FORMAT_RGB8)
	png.fill(Color(0.2, 0.6, 0.3))
	png.save_png(fx.path_join("tmx_%s.png" % TRACK_ID))
	png.save_png(fx.path_join("tmx_%s.png" % MODDED_ID))
	png.save_png(fx.path_join("mp_img_TestImg01.png"))
	_write(fx.path_join("tmx_tracks.json"), JSON.stringify({"More": false, "Results": [
		{"TrackId": int(TRACK_ID), "TrackName": "$f80Community Loop", "Uploader": {"Name": "tester"}, "Awards": 12, "PrimaryType": 0, "AuthorTime": 31234},
		{"TrackId": int(MODDED_ID), "TrackName": "Modded", "Uploader": {"Name": "modder"}, "Awards": 1, "PrimaryType": 0, "AuthorTime": 20000}]}))
	_write(fx.path_join("mp_search_1.json"), JSON.stringify({"More": false, "Results": [
		{"AssetId": CAR_ID, "Name": "Test Car", "User": {"Name": "maker"}, "DownloadCount": 5, "AssetType": 1, "Images": [{"Id": "TestImg01"}]}]}))
	_write(fx.path_join("mp_search_2.json"), JSON.stringify({"More": false, "Results": []}))
	TmTestCar.write_pack(fx.path_join("mp_%s.zip" % CAR_ID))
	var lib := ProjectSettings.globalize_path("res://server/lib/gbx.js").replace("\\", "/")
	var js := "const fs=require('fs');const g=require('%s');const b=(name,z,flags)=>({name,dir:0,coord:[10,1,z],flags});" % lib \
		+ "const w=(f,uid,blocks)=>fs.writeFileSync(f,g.writeChallenge({uid,name:uid,author:'tester',compress:true,blocks}));" \
		+ "w('%s','CommunityLoop000000000000000',[b('StadiumRoadMainStartLine',10,0x1000),b('StadiumRoadMain',11,0x1003),b('StadiumRoadMainFinishLine',12,0x1000)]);" % fx.path_join("tmx_%s.Challenge.Gbx" % TRACK_ID).replace("\\", "/") \
		+ "w('%s','CommunityModded0000000000000',[b('StadiumRoadMainStartLine',10,0x1000),b('Minecraft_Wood16',11,0x1000),b('StadiumRoadMainFinishLine',12,0x1000)]);" % fx.path_join("tmx_%s.Challenge.Gbx" % MODDED_ID).replace("\\", "/")
	var out := []
	OS.execute(node, ["-e", js], out, true)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	DirAccess.remove_absolute(path)


func _turntable_pack(menu: TmMenu) -> TmCarPack:
	for c in menu._car_holder.get_children():
		if c is TmCarVisual and not c.is_queued_for_deletion():
			return (c as TmCarVisual).pack
	return null


func _buttons(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Button", true, false):
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


func _button_texts(n: Node) -> Array:
	return _buttons(n).map(func(b: Button) -> String: return b.text)


func _has_button(n: Node, text: String) -> bool:
	return n != null and is_instance_valid(n) and _button_texts(n).has(text)


func _press(n: Node, text: String) -> void:
	for b: Button in _buttons(n):
		if b.text == text:
			b.pressed.emit()
			return


func _label_text(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	var parts: PackedStringArray = []
	for c in n.find_children("*", "Label", true, false):
		if not c.is_queued_for_deletion():
			parts.append((c as Label).text)
	return " | ".join(parts)


func _up_at(port: int) -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", port) != OK:
		return false
	for i in 20:
		tcp.poll()
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			tcp.disconnect_from_host()
			return true
		OS.delay_msec(10)
	return false


func _wait(cond: Callable, ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return false


static func _node() -> String:
	for p in ["node", "C:/Program Files/nodejs/node.exe", "/usr/bin/node", "/usr/local/bin/node"]:
		var out := []
		if OS.execute(p, ["--version"], out) == 0:
			return p
	return ""
