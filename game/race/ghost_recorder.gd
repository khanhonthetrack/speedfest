class_name GhostRecorder
extends RefCounted
## Records a run at 20 Hz: samples {t, p, q, st, fl} (t = run ms, p/q as arrays, st = steer, fl = flags).
## The race calls start() at GO, tick(run_ms, car) every physics tick and finish(ms, splits) at the
## finish, which returns the ghost Dictionary for Profile.save_ghost().
##
## Ghost format (JSON):
##   {"version": 1, "track": id, "car": CarConfig, "ms": total, "splits": [cp ms...],
##    "hz": 20, "samples": [{"t":, "p": [x,y,z], "q": [x,y,z,w], "st":, "fl":}, ...]}

const VERSION := 1
const HZ := 20
const INTERVAL_MS := 1000.0 / HZ
const MAX_SAMPLES := HZ * 60 * 10   # 10 minutes; longer runs stop recording (and aren't saved)

var samples: Array = []
var recording := false
var overflow := false
var _next_ms := 0.0


func start() -> void:
	samples.clear()
	recording = true
	overflow = false
	_next_ms = 0.0


func stop() -> void:
	recording = false


func tick(run_ms: int, node: Node3D, steer: float = 0.0, flags: int = 0) -> void:
	if not recording or float(run_ms) < _next_ms:
		return
	if samples.size() >= MAX_SAMPLES:
		overflow = true
		recording = false
		return
	samples.append(make_sample(run_ms, node.global_transform, steer, flags))
	_next_ms += INTERVAL_MS
	# Don't fall behind after a long hitch: resync to the current time.
	if _next_ms < float(run_ms):
		_next_ms = float(run_ms) + INTERVAL_MS


## Adds the final sample and returns the ghost (empty if the recording overflowed).
func finish(total_ms: int, node: Node3D, splits: Array, track_id: String, car_config: Dictionary, steer: float = 0.0, flags: int = 0) -> Dictionary:
	if overflow or samples.is_empty():
		recording = false
		return {}
	if int(samples[-1]["t"]) < total_ms:
		samples.append(make_sample(total_ms, node.global_transform, steer, flags))
	recording = false
	return {
		"version": VERSION,
		"track": track_id,
		"car": car_config,
		"ms": total_ms,
		"splits": splits.duplicate(),
		"hz": HZ,
		"samples": samples.duplicate(),
	}


static func make_sample(run_ms: int, xf: Transform3D, steer: float, flags: int) -> Dictionary:
	var q := xf.basis.get_rotation_quaternion()
	var p := xf.origin
	return {
		"t": run_ms,
		"p": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)],
		"q": [snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)],
		"st": snappedf(steer, 0.01),
		"fl": flags,
	}


## True if a loaded ghost Dictionary looks usable.
static func is_valid_ghost(g: Dictionary) -> bool:
	if g.is_empty() or typeof(g.get("samples")) != TYPE_ARRAY:
		return false
	var s: Array = g["samples"]
	if s.size() < 2:
		return false
	for i in [0, s.size() - 1]:
		var e: Variant = s[i]
		if typeof(e) != TYPE_DICTIONARY or not e.has("t") or typeof(e.get("p")) != TYPE_ARRAY or typeof(e.get("q")) != TYPE_ARRAY:
			return false
	return true
