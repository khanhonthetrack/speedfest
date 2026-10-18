class_name TmReplay
extends RefCounted
## A run to watch again (TMNF's replays): the car's state every INTERVAL_MS of race time (pose,
## velocity, steering, gas, brake, suspension, contacts and events), the run's checkpoint times
## and finish, and what it was raced on and by. Played back on a puppet TmCar (TmReplayPuppet),
## so the chase camera, the engine sound and the HUD work as in a race.
## Files (user://replays, or --replays=<dir>; zstd-compressed): magic, version, interval, a JSON header, the sample
## count, then STRIDE floats per sample. Your best run on each track is kept in autosave/.

const INTERVAL_MS := 20
const STRIDE := 18                ## position 3, quaternion 4, velocity 3, steer, gas, brake, suspension 4, flags
const MAGIC := 0x50524653         ## "SFRP"
const VERSION := 1
const DIR := "user://replays"
const AUTOSAVE := "autosave"
const EXT := ".replay"
const LAST := "_last"             ## the last run, kept to watch it from the finish (not listed)
## flags: bits 0-3 the wheels touching, then:
const F_GROUNDED := 16
const F_SLIDING := 32
const F_WALL := 64                ## hit a wall since the last sample
const F_TURBO := 128              ## a turbo started since the last sample
const F_CUT := 256                ## a respawn: don't blend into this sample

var samples := PackedFloat32Array()
var finish_ms := -1               ## the run's time; -1 if it didn't finish
var splits: Array = []            ## the clock at each checkpoint and lap line (ms)
var track := ""                   ## our track's id (TmTracks), or
var map := ""                     ## a track file's path
var uid := ""                     ## the track's uid when the run was raced
var track_name := ""
var player := ""                  ## the nickname, $-codes and all
var colour := Color(0.85, 0.08, 0.06)
var date := ""                    ## local time, "YYYY-MM-DD HH:MM:SS"
var path := ""                    ## where it was loaded from or saved to

var _events := 0                  ## event flags gathered since the last sample
var _turbo_seen := -1


## Where the replays live (tests pass --replays=user://test_replays).
static func dir() -> String:
	return String(TestHooks.arg("replays", DIR))


## A new recording of a run on a challenge, by the player (nickname and colour from the settings).
static func start(ch: TmChallenge, track_id: String, map_path: String) -> TmReplay:
	var r := TmReplay.new()
	r.track = track_id
	r.map = map_path
	r.uid = ch.uid
	r.track_name = ch.name
	r.player = String(TmUi.setting("name"))
	r.colour = TmUi.car_colour()
	r.date = Time.get_datetime_string_from_system(false, true)
	return r


func count() -> int:
	return samples.size() / STRIDE


## The run's length in ms (its finish, else its last sample).
func length_ms() -> int:
	return finish_ms if finish_ms >= 0 else maxi(0, (count() - 1) * INTERVAL_MS)


## Called every tick while racing, at race time t_ms: keeps one sample per INTERVAL_MS and the
## events (wall hits, turbos) between them.
func record(t_ms: int, car: TmCar) -> void:
	if car.body.wall_touch:
		_events |= F_WALL
	var m := car.model
	if m.turbo_until_ms != _turbo_seen:
		if m.turbo_until_ms > car.now_ms:
			_events |= F_TURBO
		_turbo_seen = m.turbo_until_ms
	if t_ms < count() * INTERVAL_MS:
		return
	var xf := car.global_transform
	var q := xf.basis.orthonormalized().get_rotation_quaternion()
	var flags := _events
	for i in 4:
		if car.wheel_contact[i]:
			flags |= 1 << i
	if m.grounded:
		flags |= F_GROUNDED
	if m.any_sliding:
		flags |= F_SLIDING
	_events = 0
	var v := car.lin_vel
	samples.append_array(PackedFloat32Array([xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w, v.x, v.y, v.z,
		m.steer, car.gas, car.brake, m.susp_len[0], m.susp_len[1], m.susp_len[2], m.susp_len[3], float(flags)]))


## The car jumped (a respawn): the next sample isn't blended with the one before.
func cut() -> void:
	_events |= F_CUT


## The flags of sample i.
func flags_at(i: int) -> int:
	return int(samples[clampi(i, 0, count() - 1) * STRIDE + 17])


## The car at race time t_ms, between the samples around it: {xform, vel, steer, gas, brake,
## susp (4), contact (4 bools), grounded, sliding, index (the sample at or before t)}; {} if empty.
func state(t_ms: float) -> Dictionary:
	var n := count()
	if n == 0:
		return {}
	var f := clampf(t_ms / INTERVAL_MS, 0.0, float(n - 1))
	var i := mini(int(f), n - 1)
	var j := mini(i + 1, n - 1)
	var u := f - i
	if flags_at(j) & F_CUT:
		u = 0.0
	var s := samples
	var a := i * STRIDE
	var b := j * STRIDE
	var qa := Quaternion(s[a + 3], s[a + 4], s[a + 5], s[a + 6]).normalized()
	var qb := Quaternion(s[b + 3], s[b + 4], s[b + 5], s[b + 6]).normalized()
	var pos := Vector3(s[a], s[a + 1], s[a + 2]).lerp(Vector3(s[b], s[b + 1], s[b + 2]), u)
	var vel := Vector3(s[a + 7], s[a + 8], s[a + 9]).lerp(Vector3(s[b + 7], s[b + 8], s[b + 9]), u)
	var susp := PackedFloat32Array()
	for k in 4:
		susp.append(lerpf(s[a + 13 + k], s[b + 13 + k], u))
	var fl := int(s[a + 17]) if u < 0.5 else int(s[b + 17])
	var contact: Array[bool] = []
	for k in 4:
		contact.append(fl & (1 << k) != 0)
	return {"xform": Transform3D(Basis(qa.slerp(qb, u)), pos), "vel": vel, "steer": lerpf(s[a + 10], s[b + 10], u),
		"gas": lerpf(s[a + 11], s[b + 11], u), "brake": lerpf(s[a + 12], s[b + 12], u), "susp": susp, "contact": contact,
		"grounded": fl & F_GROUNDED != 0, "sliding": fl & F_SLIDING != 0, "index": i}


## The run as a ghost (TmGhost: pose, steering and speed), e.g. to race against it.
func to_ghost() -> TmGhost:
	var g := TmGhost.new()
	for i in count():
		var st := state(i * INTERVAL_MS)
		var xf: Transform3D = st["xform"]
		g.record(i * INTERVAL_MS, xf, float(st["steer"]), (st["vel"] as Vector3).dot(xf.basis.z))
	g.finish_ms = finish_ms
	return g


func header() -> Dictionary:
	return {"track": track, "map": map, "uid": uid, "track_name": track_name, "player": player,
		"colour": [colour.r, colour.g, colour.b], "date": date, "finish_ms": finish_ms, "splits": splits}


func _set_header(h: Dictionary) -> void:
	track = String(h.get("track", ""))
	map = String(h.get("map", ""))
	uid = String(h.get("uid", ""))
	track_name = String(h.get("track_name", ""))
	player = String(h.get("player", ""))
	var c: Array = h.get("colour", [0.85, 0.08, 0.06])
	if c.size() >= 3:
		colour = Color(float(c[0]), float(c[1]), float(c[2]))
	date = String(h.get("date", ""))
	finish_ms = int(h.get("finish_ms", -1))
	splits = (h.get("splits", []) as Array).map(func(v: Variant) -> int: return int(v))


func save(to: String) -> bool:
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	var f := FileAccess.open_compressed(to, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	f.store_32(MAGIC)
	f.store_32(VERSION)
	f.store_32(INTERVAL_MS)
	f.store_pascal_string(JSON.stringify(header()))
	f.store_32(count())
	f.store_buffer(samples.to_byte_array())
	f.close()
	path = to
	return true


## A replay from a file (null if it isn't one); header_only skips the samples (the lists).
static func load_file(from: String, header_only := false) -> TmReplay:
	var f := FileAccess.open_compressed(from, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null or f.get_32() != MAGIC or f.get_32() != VERSION or f.get_32() != INTERVAL_MS:
		return null
	var h: Variant = JSON.parse_string(f.get_pascal_string())
	if not h is Dictionary:
		return null
	var r := TmReplay.new()
	r._set_header(h)
	r.path = from
	if header_only:
		return r
	var n := f.get_32()
	r.samples = f.get_buffer(n * STRIDE * 4).to_float32_array()
	if r.samples.size() != n * STRIDE:
		return null
	return r


## The replays kept on this machine, newest first: saved ones and the autosaves of your best
## runs ({path, replay (header only), autosave}).
static func list() -> Array:
	var out: Array = []
	for sub: String in ["", AUTOSAVE]:
		var d := dir().path_join(sub) if not sub.is_empty() else dir()
		if not DirAccess.dir_exists_absolute(d):
			continue
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(EXT) or f.begins_with("_"):
				continue
			var r := load_file(d.path_join(f), true)
			if r != null:
				out.append({"path": d.path_join(f), "replay": r, "autosave": not sub.is_empty()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["replay"] as TmReplay).date > (b["replay"] as TmReplay).date)
	return out


## A file name for a saved replay: "<track> <time> <date>.replay", file-safe.
func file_name() -> String:
	var text := "%s %s %s" % [track_name if not track_name.is_empty() else "track", TmRace.time_text(finish_ms).replace(":", "m").replace(".", "s"),
		date.replace(":", "-")]
	var out := ""
	for c in text:
		out += c if (c.is_valid_identifier() or c.is_valid_int() or c in "- ") else "_"
	return out.strip_edges() + EXT


## Where the last run is kept to watch it straight from the finish.
static func last_path() -> String:
	return dir().path_join(LAST + EXT)


## Your best run on a track, kept as its autosave.
static func autosave_path(ch: TmChallenge) -> String:
	return dir().path_join(AUTOSAVE).path_join(TmRecords.key(ch) + EXT)


## Removes every replay in dir() (tests).
static func clear() -> void:
	for sub: String in ["", AUTOSAVE]:
		var d := dir().path_join(sub) if not sub.is_empty() else dir()
		if not DirAccess.dir_exists_absolute(d):
			continue
		for f in DirAccess.get_files_at(d):
			if f.ends_with(EXT):
				DirAccess.remove_absolute(d.path_join(f))
