class_name TmCommunity
extends Node
## The Community page's source: TrackMania Exchange's tracks (tmnf.exchange) and ManiaPark's
## TrackMania car models and skins and texture mods (maniapark.com: TMNF/TMUF's, and ManiaPlanet's
## mods), searched with their preview images, and downloaded into the player's library
## (user://community: tracks/<id>.Challenge.Gbx, cars/<kind>_<id>.zip, mods/mod_<id>.zip,
## library.json with each one's name, author and preview), each checked with the game's own readers
## first (TmChallenge + TmTrackCheck, TmCarPack, TmTextureMod). The car we drive is the setting
## community_car (a pack's path; "" our own car): races use it (my_car_pack()); the mod the
## Stadium wears, community_mod (a Stadium mod; my_mod()).
## A browser can't call those sites (they send no CORS headers): the web build goes through the
## master server's /api/community pass-through (stadium/server/lib/community.js); tests pass
## --community=<a server's /api/community> (one serving local fixtures).

const SITES := {"tmx": "https://tmnf.exchange", "maniapark": "https://maniapark.com"}
const TRACK_FIELDS := "TrackId,TrackName,Uploader.Name,Awards,PrimaryType,AuthorTime,UploadedAt"
const TRACK_TYPES := ["RACE", "PUZZLE", "PLATFORM", "STUNTS"]
const TRACK_ORDERS := {"awards": 6, "newest": 2, "downloads": 18}
const MOD_GAMES := {"tm1": 0, "maniaplanet": 1}     ## ManiaPark's games: TrackMania (TMNF/TMUF), ManiaPlanet
const KINDS := ["cars", "tracks", "mods"]
const PAGE := 12
const DIR := "user://community"    ## the library (tests: --community_dir)
const TIMEOUT := 30.0                    ## a search or a preview (s)
const FILE_TIMEOUT := 900.0              ## a whole download: a 40 MB car or a 200 MB mod on a slow line
const MAX_FILE := 40 * 1024 * 1024
const MAX_MOD := 200 * 1024 * 1024        ## mods ship 4K textures (ManiaPark's run to ~150 MB)
const UA := "SpeedFestStadium/1.0 (+https://github.com/khanhonthetrack/speedfest)"

static var _images := {}            ## preview URL -> Texture2D (this session)
var library := {"cars": {}, "tracks": {}, "mods": {}}   ## key -> {name, author, kind, image, path, playable, why}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	library = load_library()


## The library as saved: {cars: {key: entry}, tracks: {..}, mods: {..}} (entries whose file is gone
## left out).
static func load_library() -> Dictionary:
	var out := {"cars": {}, "tracks": {}, "mods": {}}
	var f := FileAccess.open(_dir().path_join("library.json"), FileAccess.READ)
	if f == null:
		return out
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return out
	for kind: String in KINDS:
		var part: Variant = (d as Dictionary).get(kind, {})
		if part is Dictionary:
			for key: String in part:
				var e: Variant = part[key]
				if e is Dictionary and FileAccess.file_exists(String((e as Dictionary).get("path", ""))):
					out[kind][key] = e
	return out


static func _dir() -> String:
	return String(TestHooks.arg("community_dir", DIR))


func _save_library() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir()))
	var f := FileAccess.open(_dir().path_join("library.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(library, " "))


## The community car we drive (null: our own car, or its file is gone or doesn't read).
## The texture mod we wear (a Stadium mod from the Community page; --mod=<zip> for one run), or null.
static func my_mod() -> TmTextureMod:
	var path := String(TestHooks.arg("mod", TmUi.setting("community_mod")))
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var m := TmTextureMod.load_zip(path)
	return m if m.is_stadium() else null


## Wears a texture mod from now on (a mod's path; "" our own look).
static func wear(path: String) -> void:
	TmUi.set_setting("community_mod", path)


static func my_car_pack() -> TmCarPack:
	var path := String(TmUi.setting("community_car"))
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var pack := TmCarPack.load_zip(path)
	return pack if pack.ok() else null


## A site's path, where we reach it: the site itself, the master's pass-through (the web build), or
## the tests' server.
func site_url(site: String, path: String) -> String:
	if TestHooks.has_arg("community"):
		return String(TestHooks.arg("community", "")).trim_suffix("/") + "/" + site + path
	if OS.has_feature("web"):
		await Master.find()
		if not Master.base.is_empty():
			return Master.base + "/api/community/" + site + path
	return String(SITES[site]) + path


static func _query(q: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in q:
		parts.append("%s=%s" % [k, String(str(q[k])).uri_encode()])
	return "&".join(parts)


# --- searches ---------------------------------------------------------------------------------------

## A page of tracks: {items: [{key, id, name, author, awards, type, author_ms, image, shot}], more,
## after (pass it back for the next page), error}. order: "awards", "newest" or "downloads".
func search_tracks(text: String, order := "awards", after := "") -> Dictionary:
	var q := {"fields": TRACK_FIELDS, "count": PAGE, "order1": TRACK_ORDERS.get(order, 6)}
	if not text.strip_edges().is_empty():
		q["name"] = text.strip_edges()
	if not after.is_empty():
		q["after"] = after
	var r := await _json(await site_url("tmx", "/api/tracks?" + _query(q)))
	var out := {"items": [], "more": false, "after": "", "error": String(r.get("error", ""))}
	var res: Variant = r.get("Results", [])
	if not res is Array:
		return out
	for t: Variant in res:
		if not t is Dictionary:
			continue
		var id := str(int((t as Dictionary).get("TrackId", 0)))
		var type := int(t.get("PrimaryType", 0))
		out["items"].append({"key": id, "id": id, "name": TmNick.strip(String(t.get("TrackName", ""))),
			"author": TmNick.strip(String((t.get("Uploader", {}) as Dictionary).get("Name", "")) if t.get("Uploader") is Dictionary else ""),
			"awards": int(t.get("Awards", 0)), "type": TRACK_TYPES[type] if type >= 0 and type < TRACK_TYPES.size() else "",
			"author_ms": int(t.get("AuthorTime", -1)),
			"image": await site_url("tmx", "/trackshow/%s/image/0" % id), "shot": await site_url("tmx", "/trackshow/%s/image/1" % id)})
		out["after"] = id
	out["more"] = bool(r.get("More", false))
	return out


## A page of cars: kind "model" (car models) or "skin": {items: [{key, id, kind, name, author,
## downloads, image, shot}], more, after, error}.
func search_cars(kind: String, text: String, after := "") -> Dictionary:
	return await _search_assets(1 if kind == "model" else 2, 0, kind, text, after)


## ManiaPark's texture mods for a game ("tm1": TMNF/TMUF, "maniaplanet"), as search_cars.
func search_mods(game: String, text: String, after := "") -> Dictionary:
	var r := await _search_assets(0, int(MOD_GAMES.get(game, 0)), "mod", text, after)
	for it: Dictionary in r["items"]:
		it["game"] = game
	return r


## ManiaPark's assets of a type (0 texture mods, 1 car models, 2 car skins) for a game (0 TrackMania,
## 1 ManiaPlanet): {items: [{key, id, kind, name, author, downloads, image, shot}], more, after, error}.
func _search_assets(asset: int, game: int, kind: String, text: String, after: String) -> Dictionary:
	var q := {"asset": asset, "game": game, "count": PAGE}
	if not text.strip_edges().is_empty():
		q["name"] = text.strip_edges()
	if not after.is_empty():
		q["after"] = after
	var r := await _json(await site_url("maniapark", "/api/search?" + _query(q)))
	var out := {"items": [], "more": false, "after": "", "error": String(r.get("error", ""))}
	var res: Variant = r.get("Results", [])
	if not res is Array:
		return out
	for c: Variant in res:
		if not c is Dictionary:
			continue
		var id := String((c as Dictionary).get("AssetId", ""))
		if not _is_asset_id(id):
			continue
		var images: Array = c.get("Images", []) if c.get("Images") is Array else []
		var img := String((images[0] as Dictionary).get("Id", "")) if not images.is_empty() and images[0] is Dictionary else ""
		out["items"].append({"key": "%s_%s" % [kind, id], "id": id, "kind": kind, "name": String(c.get("Name", "")),
			"author": String((c.get("User", {}) as Dictionary).get("Name", "")) if c.get("User") is Dictionary else "",
			"downloads": int(c.get("DownloadCount", 0)),
			"image": (await site_url("maniapark", "/image/%s?hq=false" % img)) if _is_asset_id(img) else "",
			"shot": (await site_url("maniapark", "/image/%s?hq=true" % img)) if _is_asset_id(img) else ""})
		out["after"] = id
	out["more"] = bool(r.get("More", false))
	return out


static func _is_asset_id(s: String) -> bool:
	if s.is_empty() or s.length() > 40:
		return false
	for ch in s:
		if not (ch.is_valid_identifier() or ch == "-" or (ch >= "0" and ch <= "9")):
			return false
	return true


# --- previews ---------------------------------------------------------------------------------------

## A preview image (JPEG, PNG or WebP), downloaded once (kept in user://community/img).
func image(url: String) -> Texture2D:
	if url.is_empty():
		return null
	if _images.has(url):
		return _images[url]
	var cache := _dir().path_join("img").path_join(url.md5_text())
	var bytes := FileAccess.get_file_as_bytes(cache) if FileAccess.file_exists(cache) else PackedByteArray()
	if bytes.is_empty():
		bytes = await _bytes(url, 8 * 1024 * 1024)
		if not bytes.is_empty():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir().path_join("img")))
			var f := FileAccess.open(cache, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
	var tex := decode_image(bytes)
	if tex:
		_images[url] = tex
	return tex


static func decode_image(bytes: PackedByteArray) -> Texture2D:
	if bytes.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	if img.get_width() > 1024:     # previews: no need for 4K screenshots in memory
		img.resize(1024, maxi(1, 1024 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- downloads --------------------------------------------------------------------------------------

## Downloads a track into the library and checks it: {path, entry, error}. A track we can't race
## (a modded one: TMUnlimiter, custom blocks) is kept with playable false and the reason.
func download_track(item: Dictionary) -> Dictionary:
	var id := String(item.get("id", ""))
	if not id.is_valid_int():
		return {"error": "not a track"}
	var got := await _fetch(await site_url("tmx", "/trackgbx/%s" % id), MAX_FILE)
	var bytes: PackedByteArray = got["bytes"]
	if bytes.is_empty():
		return {"error": "TrackMania Exchange: " + String(got["error"])}
	var ch := TmChallenge.new()
	ch.parse(bytes)
	if not ch.ok():
		return {"error": "not a track the game can read (%s)" % ch.error}
	if not ch.environment.is_empty() and ch.environment != "Stadium":
		return {"error": "a %s track: this game races Stadium tracks" % ch.environment}
	var check := TmTrackCheck.check(ch, TmBlockLib.new())
	var path := _dir().path_join("tracks").path_join("%s.Challenge.Gbx" % id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"error": "can't save the track"}
	f.store_buffer(bytes)
	f.close()
	var entry := {"name": String(item.get("name", ch.name)), "author": String(item.get("author", ch.author)),
		"kind": "track", "image": String(item.get("image", "")), "shot": String(item.get("shot", "")), "path": path,
		"playable": bool(check["raceable"]) and (check["missing"] as Dictionary).is_empty() and not bool(check["modded"]),
		"why": String(check["why"]) if not String(check["why"]).is_empty() else ("blocks we don't build" if not (check["missing"] as Dictionary).is_empty() else "")}
	library["tracks"][id] = entry
	_save_library()
	return {"path": path, "entry": entry, "error": ""}


## Downloads a car pack into the library and checks that it loads: {path, entry, error}.
func download_car(item: Dictionary) -> Dictionary:
	var id := String(item.get("id", ""))
	var kind := String(item.get("kind", "model"))
	if not _is_asset_id(id) or not kind in ["model", "skin"]:
		return {"error": "not a car"}
	var got := await _fetch(await site_url("maniapark", "/%s/%s/download" % [kind, id]), MAX_FILE)
	var bytes: PackedByteArray = got["bytes"]
	if bytes.is_empty():
		return {"error": "ManiaPark: " + String(got["error"])}
	var path := _dir().path_join("cars").path_join("%s_%s.zip" % [kind, id])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"error": "can't save the car"}
	f.store_buffer(bytes)
	f.close()
	var pack := TmCarPack.load_zip(ProjectSettings.globalize_path(path))
	if not pack.ok():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return {"error": "the car doesn't load (%s)" % pack.error}
	var entry := {"name": String(item.get("name", "")), "author": String(item.get("author", "")), "kind": kind,
		"image": String(item.get("image", "")), "shot": String(item.get("shot", "")),
		"path": ProjectSettings.globalize_path(path), "playable": true, "why": ""}
	library["cars"][String(item.get("key", "%s_%s" % [kind, id]))] = entry
	_save_library()
	return {"path": entry["path"], "entry": entry, "error": ""}


## Downloads a texture mod into the library and opens it (TmTextureMod: every texture must decode);
## {path, entry, error}. A Stadium mod can be worn (entry.playable); another environment's opens but
## the game has the Stadium only (entry.why).
func download_mod(item: Dictionary) -> Dictionary:
	var id := String(item.get("id", ""))
	if not _is_asset_id(id):
		return {"error": "not a mod"}
	var got := await _fetch(await site_url("maniapark", "/mod/%s/download" % id), MAX_MOD)
	var bytes: PackedByteArray = got["bytes"]
	if bytes.is_empty():
		return {"error": "ManiaPark: " + String(got["error"])}
	if bytes.slice(0, 2).get_string_from_ascii() != "PK":
		return {"error": "the mod isn't a zip"}
	var path := _dir().path_join("mods").path_join("mod_%s.zip" % id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"error": "can't save the mod"}
	f.store_buffer(bytes)
	f.close()
	var full := ProjectSettings.globalize_path(path)
	TmTextureMod.forget(full)
	var mod := TmTextureMod.load_zip(full, String(item.get("name", "")))
	if not mod.ok():
		TmTextureMod.forget(full)
		DirAccess.remove_absolute(full)
		return {"error": "the mod doesn't open (%s)" % mod.error}
	var env := mod.environment if not mod.environment.is_empty() else "an unknown"
	var entry := {"name": String(item.get("name", "")), "author": String(item.get("author", "")), "kind": "mod",
		"game": mod.game if not mod.game.is_empty() else String(item.get("game", "")), "environment": mod.environment,
		"textures": mod.images.size(), "image": String(item.get("image", "")), "shot": String(item.get("shot", "")),
		"path": full, "playable": mod.is_stadium(),
		"why": "" if mod.is_stadium() else "a mod for %s environment: this game has the Stadium only" % (("the " + env) if env != "an unknown" else env)}
	library["mods"][String(item.get("key", "mod_" + id))] = entry
	_save_library()
	return {"path": full, "entry": entry, "error": ""}


## Drives a community car from now on (a pack's path; "" our own car).
static func drive(path: String) -> void:
	TmUi.set_setting("community_car", path)


# --- HTTP -------------------------------------------------------------------------------------------

func _json(url: String) -> Dictionary:
	var got := await _fetch(url, 4 * 1024 * 1024)
	var bytes: PackedByteArray = got["bytes"]
	if bytes.is_empty():
		return {"error": String(got["error"])}
	var d: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return d if d is Dictionary else {"error": "an unexpected answer"}


func _bytes(url: String, limit: int) -> PackedByteArray:
	return (await _fetch(url, limit))["bytes"]


## A GET: {bytes (empty unless it worked), error (why not, for the player; "" when it worked)}.
func _fetch(url: String, limit: int) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 0.0 if TestHooks.is_testing() else (FILE_TIMEOUT if limit >= MAX_FILE else TIMEOUT)
	req.body_size_limit = limit
	req.max_redirects = 4
	add_child(req)
	if req.request(url, PackedStringArray(["user-agent: " + UA])) != OK:
		req.queue_free()
		return {"bytes": PackedByteArray(), "error": "the request couldn't be made"}
	var res: Array = await req.request_completed
	req.queue_free()
	var why := failure(int(res[0]), int(res[1]))
	return {"bytes": PackedByteArray() if not why.is_empty() else res[3], "error": why}


## Why a request failed, for the player ("" if it didn't), from an HTTPRequest result and status:
## a site's own failure (5xx; ManiaPark's downloads answered 500 to everyone on 21 Oct 2026) reads
## apart from a connection the player's side can't make.
static func failure(result: int, status: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			if status == 200:
				return ""
			if status >= 500:
				return "the site's server failed (HTTP %d), a problem on its side: try again later" % status
			if status == 404:
				return "not there any more (HTTP 404)"
			return "the site refused it (HTTP %d)" % status
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "the site's address can't be found (no internet connection?)"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "a secure connection to the site couldn't be made (TLS)"
		HTTPRequest.RESULT_TIMEOUT:
			return "the site took too long to answer"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "the file is too big"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "the site redirected too many times"
	return "the site can't be reached"
