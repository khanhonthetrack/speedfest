class_name TmGhost
extends RefCounted
## A run as a ghost: the car's pose, steering and speed every INTERVAL_MS of race time, played back
## smoothly against the race clock (TMNF races your best run's ghost). Saved as a small binary file
## (magic, version, interval, finish time, sample count, then STRIDE floats per sample).

const INTERVAL_MS := 20
const STRIDE := 9                 ## position (3), rotation quaternion (4), steer, speed (m/s)
const MAGIC := 0x48474D54         ## "TMGH"
const VERSION := 1

var samples := PackedFloat32Array()
var finish_ms := -1               ## the run's time; -1 while recording or unfinished


## Adds the pose at race time t_ms (every INTERVAL_MS; earlier times are ignored).
func record(t_ms: int, xf: Transform3D, steer: float, speed: float) -> void:
	if t_ms < count() * INTERVAL_MS:
		return
	var q := xf.basis.orthonormalized().get_rotation_quaternion()
	samples.append_array(PackedFloat32Array([xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w, steer, speed]))


func count() -> int:
	return samples.size() / STRIDE


## The run's length in ms (its finish, else its last sample).
func length_ms() -> int:
	return finish_ms if finish_ms >= 0 else maxi(0, (count() - 1) * INTERVAL_MS)


## The pose at race time t_ms, between the samples around it: {xform, steer, speed}; {} if empty.
func sample(t_ms: float) -> Dictionary:
	var n := count()
	if n == 0:
		return {}
	var f := clampf(t_ms / INTERVAL_MS, 0.0, float(n - 1))
	var i := mini(int(f), n - 1)
	var j := mini(i + 1, n - 1)
	var u := f - i
	var a := _at(i)
	var b := _at(j)
	var q: Quaternion = (a[1] as Quaternion).slerp(b[1], u)
	var pos: Vector3 = (a[0] as Vector3).lerp(b[0], u)
	return {"xform": Transform3D(Basis(q), pos), "steer": lerpf(a[2], b[2], u), "speed": lerpf(a[3], b[3], u)}


func _at(i: int) -> Array:
	var k := i * STRIDE
	var s := samples
	return [Vector3(s[k], s[k + 1], s[k + 2]), Quaternion(s[k + 3], s[k + 4], s[k + 5], s[k + 6]).normalized(), s[k + 7], s[k + 8]]


func save(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_32(MAGIC)
	f.store_32(VERSION)
	f.store_32(INTERVAL_MS)
	f.store_32(finish_ms)
	f.store_32(count())
	f.store_buffer(samples.to_byte_array())
	return true


static func load_file(path: String) -> TmGhost:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 20 or f.get_32() != MAGIC:
		return null
	if f.get_32() != VERSION or f.get_32() != INTERVAL_MS:
		return null
	var g := TmGhost.new()
	var fin := f.get_32()
	g.finish_ms = fin if fin < 0x80000000 else -1
	var n := f.get_32()
	g.samples = f.get_buffer(n * STRIDE * 4).to_float32_array()
	if g.samples.size() != n * STRIDE:
		return null
	return g
