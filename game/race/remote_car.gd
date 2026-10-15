class_name RemoteCar
extends Node3D
## Another player's car in an online round: visuals only (no physics body, no collisions).
##
## Snapshots (Net.player_state) are buffered and shown INTERP_DELAY_MS in the past, interpolated
## with cubic Hermite curves (positions + velocities) and slerped rotations. Timing uses the
## sender's clock ("ts", added by race.gd, ms) mapped to ours with a jitter-robust offset estimate
## (the minimum of rx_ms - ts over recent packets), falling back to rx_ms. On packet loss the car
## extrapolates for up to MAX_EXTRAPOLATE_MS, then holds; after SILENCE_HIDE_MS it hides.

const INTERP_DELAY_MS := 100.0
const MAX_EXTRAPOLATE_MS := 250.0
const SILENCE_HIDE_MS := 3000
const BUFFER_SIZE := 32
const MAX_STEER_RAD := 0.55
const TELEPORT_DIST := 30.0          # jumps bigger than this between snapshots snap (respawn/restart)
const FADE_NEAR := 3.0               # camera distance (m) where the car is most transparent
const FADE_FAR := 9.0                # camera distance (m) where the car is fully opaque
const FADE_MIN_ALPHA := 0.08

var player_id := -1
var player_name := ""
var car_id := "kaze"
var visual: CarVisual
var name_tag: Label3D
var engine_audio: Node3D
var snapshot_count := 0

## Latest decoded values (for the minimap, leaderboards, tests).
var last_flags := 0
var last_run_ms := -1
var current_speed_kmh := 0.0

var _buf: Array = []                  # [{ts: float, p: Vector3, q: Quaternion, v: Vector3, st, rpm, fl, t}]
var _offset := 0.0                    # local_ms ≈ ts + _offset (min one-way delay + clock offset)
var _offset_valid := false
var _applied_offset := 0.0            # _offset, eased so the playback clock never jumps
var _applied_valid := false
var _last_pose_ms := -1.0
var _last_rx_ms := -100000
var _last_offset_update_ms := 0
var _last_ts := -1.0
var _spin := 0.0
var _alpha := 1.0
var _wheel_radius := 0.33
var _time_source := Callable()        # optional override of "now" (tests)


func setup(id: int, display_name: String, config: Dictionary) -> void:
	player_id = id
	player_name = display_name
	name = "Remote_%d" % id
	var cfg := CarDefs.sanitize_config(config)
	car_id = cfg["car"]
	_wheel_radius = float(CarDefs.geometry(car_id)["wheel_radius"])
	if visual == null:
		visual = CarVisual.new()
		add_child(visual)
	# Up to 7 remote cars: on the web renderer each extra light costs a pass per lit object, so
	# remote cars keep the emissive glow blob but only get a real underglow light on Forward+.
	if "underglow_light_allowed" in visual:
		visual.set("underglow_light_allowed", not Settings.is_compat() and Settings.quality >= 1)
	visual.build(car_id, cfg["style"])
	visual.set_underglow_enabled(Settings.quality >= 1)
	if name_tag == null:
		name_tag = Label3D.new()
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.fixed_size = true
		name_tag.pixel_size = 0.0009
		name_tag.font_size = 30
		name_tag.outline_size = 10
		name_tag.modulate = Color(1, 1, 1)
		name_tag.outline_modulate = Color(0.02, 0.04, 0.1, 0.9)
		name_tag.no_depth_test = true
		name_tag.render_priority = 10
		name_tag.outline_render_priority = 9
		var font: Font = load("res://assets/fonts/rajdhani-latin-700-normal.woff2") as Font
		if font:
			name_tag.font = font
		add_child(name_tag)
	name_tag.text = display_name
	name_tag.position = Vector3(0, float(CarDefs.geometry(car_id)["height"]) + 0.6, 0)
	visible = false


func set_engine_audio(node: Node3D) -> void:
	engine_audio = node
	add_child(node)


## Update the car config (e.g. the player changed car between rounds).
func update_config(display_name: String, config: Dictionary) -> void:
	var cfg := CarDefs.sanitize_config(config)
	if cfg["car"] != car_id or display_name != player_name:
		var car_changed: bool = cfg["car"] != car_id
		setup(player_id, display_name, cfg)
		if car_changed and engine_audio and engine_audio.has_method("setup"):
			engine_audio.call("setup", car_id, false)


func _now_ms() -> float:
	if _time_source.is_valid():
		return float(_time_source.call())
	return float(Time.get_ticks_msec())


## For tests: use a custom clock (Callable returning ms).
func set_time_source(c: Callable) -> void:
	_time_source = c


## Feed a snapshot from Net.player_state (with "rx_ms" added by Net).
func push_state(s: Dictionary) -> void:
	var p: Variant = _vec3(s.get("p"))
	if p == null:
		return
	var rx := float(s.get("rx_ms", _now_ms()))
	var ts := rx
	var has_ts := typeof(s.get("ts")) in [TYPE_FLOAT, TYPE_INT]
	if has_ts:
		ts = float(s["ts"])
		# Sender clock wrapped/restarted: reset the mapping.
		if _last_ts >= 0.0 and (ts < _last_ts - 1000.0 or ts > _last_ts + 60000.0):
			_buf.clear()
			_offset_valid = false
			_applied_valid = false
		if not _buf.is_empty() and ts <= float(_buf[-1]["ts"]):
			return # duplicate or out of order
		_last_ts = ts
		var off := rx - ts
		if not _offset_valid:
			_offset = off
			_offset_valid = true
		else:
			# Track the minimum delay; let it creep up slowly (route change, clock drift).
			var dt := maxf(0.0, rx - float(_last_offset_update_ms))
			_offset = minf(off, _offset + dt * 0.02)
		_last_offset_update_ms = int(rx)
	else:
		_offset = 0.0
		_offset_valid = true
		if not _buf.is_empty() and ts <= float(_buf[-1]["ts"]):
			ts = float(_buf[-1]["ts"]) + 1.0
	var q := Quaternion.IDENTITY
	var qa: Variant = s.get("q")
	if typeof(qa) == TYPE_ARRAY and (qa as Array).size() >= 4:
		q = Quaternion(float(qa[0]), float(qa[1]), float(qa[2]), float(qa[3]))
		q = q.normalized() if q.length_squared() > 0.0001 else Quaternion.IDENTITY
	var v: Variant = _vec3(s.get("v"))
	var entry := {
		"ts": ts,
		"p": p,
		"q": q,
		"v": v if v != null else Vector3.ZERO,
		"st": clampf(float(s.get("st", 0.0)), -1.0, 1.0),
		"rpm": clampf(float(s.get("rpm", 0.0)), 0.0, 1.0),
		"fl": int(s.get("fl", 0)),
		"t": int(s.get("t", -1)),
	}
	_buf.append(entry)
	while _buf.size() > BUFFER_SIZE:
		_buf.pop_front()
	_last_rx_ms = int(rx)
	snapshot_count += 1
	last_flags = entry["fl"]
	last_run_ms = entry["t"]


func is_stale() -> bool:
	return _now_ms() - float(_last_rx_ms) > SILENCE_HIDE_MS


func _process(_delta: float) -> void:
	update_pose()


## Computes the pose for "now". Returns false if hidden.
func update_pose() -> bool:
	if _buf.is_empty() or is_stale():
		visible = false
		return false
	visible = true
	var now := _now_ms()
	var frame_ms := clampf(now - _last_pose_ms, 0.0, 100.0) if _last_pose_ms >= 0.0 else 0.0
	_last_pose_ms = now
	if not _applied_valid or absf(_offset - _applied_offset) > 500.0:
		_applied_offset = _offset
		_applied_valid = true
	else:
		# Play 10% faster/slower until the clock mapping matches the estimate.
		_applied_offset = move_toward(_applied_offset, _offset, frame_ms * 0.1)
	var render_ts := now - _applied_offset - INTERP_DELAY_MS
	var pose := sample(render_ts)
	global_transform = pose["xf"]
	_apply_visuals(pose)
	return true


## Pose at sender time ts: {xf, v, st, rpm, fl}.
func sample(ts: float) -> Dictionary:
	var n := _buf.size()
	var first: Dictionary = _buf[0]
	if n == 1 or ts <= float(first["ts"]):
		return _pose_of(first, Transform3D(Basis(first["q"]), first["p"]))
	var last: Dictionary = _buf[n - 1]
	if ts >= float(last["ts"]):
		# Extrapolate along the last velocity for a short time, then hold.
		var ahead := minf(ts - float(last["ts"]), MAX_EXTRAPOLATE_MS) / 1000.0
		var p: Vector3 = last["p"] + (last["v"] as Vector3) * ahead
		return _pose_of(last, Transform3D(Basis(last["q"]), p))
	var i := n - 2
	while i > 0 and float(_buf[i]["ts"]) > ts:
		i -= 1
	var a: Dictionary = _buf[i]
	var b: Dictionary = _buf[i + 1]
	var span := (float(b["ts"]) - float(a["ts"])) / 1000.0
	var f := clampf((ts - float(a["ts"])) / 1000.0 / maxf(span, 0.0001), 0.0, 1.0)
	var pa: Vector3 = a["p"]
	var pb: Vector3 = b["p"]
	var pos: Vector3
	if pa.distance_to(pb) > TELEPORT_DIST or span > 0.5:
		pos = pb if f >= 0.5 else pa
	else:
		pos = hermite(pa, a["v"], pb, b["v"], span, f)
	var rot: Quaternion = (a["q"] as Quaternion).slerp(b["q"], f)
	var src: Dictionary = b if f >= 0.5 else a
	var out := _pose_of(src, Transform3D(Basis(rot), pos))
	out["v"] = (a["v"] as Vector3).lerp(b["v"], f)
	out["st"] = lerpf(float(a["st"]), float(b["st"]), f)
	out["rpm"] = lerpf(float(a["rpm"]), float(b["rpm"]), f)
	return out


static func hermite(p0: Vector3, v0: Vector3, p1: Vector3, v1: Vector3, span_s: float, f: float) -> Vector3:
	var f2 := f * f
	var f3 := f2 * f
	var h00 := 2.0 * f3 - 3.0 * f2 + 1.0
	var h10 := f3 - 2.0 * f2 + f
	var h01 := -2.0 * f3 + 3.0 * f2
	var h11 := f3 - f2
	return p0 * h00 + v0 * (h10 * span_s) + p1 * h01 + v1 * (h11 * span_s)


func _pose_of(e: Dictionary, xf: Transform3D) -> Dictionary:
	return {"xf": xf, "v": e["v"], "st": e["st"], "rpm": e["rpm"], "fl": e["fl"]}


func _apply_visuals(pose: Dictionary) -> void:
	var v: Vector3 = pose["v"]
	var xf: Transform3D = pose["xf"]
	var fwd_speed := -v.dot(xf.basis.z)
	current_speed_kmh = fwd_speed * 3.6
	var dt := get_process_delta_time()
	_spin = fmod(_spin + fwd_speed * dt / _wheel_radius, TAU)
	var fl := int(pose["fl"])
	if visual:
		visual.set_wheel_state(float(pose["st"]) * MAX_STEER_RAD, [_spin, _spin, _spin, _spin], [0.0, 0.0, 0.0, 0.0])
		visual.set_lights(fl & 1 != 0, fl & 8 != 0)
		visual.set_nitro(fl & 2 != 0)
	if engine_audio and engine_audio.has_method("set_params"):
		var rpm := float(pose["rpm"])
		engine_audio.call("set_params", rpm, 1.0 if rpm > 0.3 and fl & 1 == 0 else 0.2,
			absf(current_speed_kmh), 0.7 if fl & 4 != 0 else 0.0, fl & 2 != 0, fl & 16 != 0)
	_update_fade()


## Fade out when close to the active camera so the player can see through.
func _update_fade() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var a := 1.0
	if cam:
		var d := cam.global_position.distance_to(global_position)
		a = clampf(remap(d, FADE_NEAR, FADE_FAR, FADE_MIN_ALPHA, 1.0), FADE_MIN_ALPHA, 1.0)
	if absf(a - _alpha) > 0.02 or (a == 1.0 and _alpha != 1.0):
		_alpha = a
		if visual:
			visual.set_ghost(a)
		if name_tag:
			# Very close: the tag would float at the horizon over the road, hide it.
			name_tag.visible = a > 0.35
			name_tag.modulate.a = clampf(a * 1.5, 0.0, 1.0)


static func _vec3(v: Variant) -> Variant:
	if typeof(v) == TYPE_VECTOR3:
		return v
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 3:
		var a: Array = v
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return null
