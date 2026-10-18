class_name TmInputScript
extends RefCounted
## A run's inputs as text, in the style of TMInterface's input scripts (the community tool TMNF
## players use to write, record and replay inputs), so a TMNF run can be driven through our car
## (race.tscn --inputs=<file>) and its checkpoint and finish times compared with the game's, and so
## a run here can be written out (--record_inputs=<file>). Lines (times in seconds from the start,
## 10 ms steps; "a-b" holds from a to b; # starts a comment):
##   1.20 press up | down | left | right        (rel / release: let go; up = gas, down = brake)
##   2.00-2.35 press left
##   3.10 steer -32768                          (-65536 full left .. 65536 full right)
##   4.00 gas 65536 / 4.00 brake 0              (analog gas and brake, 0..65536; our addition)
## Fractional values are accepted (our recordings write them, so a replay is exact).

const FULL := 65536.0

var _events: Array = []             ## [time_ms, kind, value], sorted by time
var _i := 0
var _keys := {"up": false, "down": false, "left": false, "right": false}
var _steer := 0.0                   ## analog steer (TMInterface sign: + = right), -1..1
var _gas := -1.0                    ## analog gas / brake, -1 = not set (the keys decide)
var _brake := -1.0
var error := ""


static func parse(text: String) -> TmInputScript:
	var s := TmInputScript.new()
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.split("#")[0].strip_edges()
		if line.is_empty():
			continue
		var p := line.split(" ", false)
		if p.size() < 2:
			s.error = "line %d: %s" % [n, raw]
			continue
		var t := p[0].split("-")
		var t0 := roundi(float(t[0]) * 1000.0)
		var t1 := roundi(float(t[1]) * 1000.0) if t.size() > 1 else -1
		var what := p[1].to_lower()
		if what in ["press", "rel", "release"] and p.size() > 2:
			var key := p[2].to_lower()
			s._events.append([t0, "key", [key, what == "press"]])
			if t1 >= 0:
				s._events.append([t1, "key", [key, what != "press"]])
		elif what in ["steer", "gas", "brake"] and p.size() > 2:
			s._events.append([t0, what, float(p[2]) / FULL])
		else:
			s.error = "line %d: %s" % [n, raw]
	s._events.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return s


static func load_file(path: String) -> TmInputScript:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		var none := TmInputScript.new()
		none.error = "can't read %s" % path
		return none
	return parse(f.get_as_text())


## The inputs at race time `ms` (call with rising times): [gas 0..1, brake 0..1, steer -1..1 with
## our sign (+ = left)].
func at(ms: int) -> Array:
	while _i < _events.size() and int(_events[_i][0]) <= ms:
		var e: Array = _events[_i]
		match String(e[1]):
			"key": _keys[String(e[2][0])] = bool(e[2][1])
			"steer": _steer = clampf(float(e[2]), -1.0, 1.0)
			"gas": _gas = clampf(float(e[2]), 0.0, 1.0)
			"brake": _brake = clampf(float(e[2]), 0.0, 1.0)
		_i += 1
	var gas := _gas if _gas >= 0.0 else (1.0 if _keys["up"] else 0.0)
	var brake := _brake if _brake >= 0.0 else (1.0 if _keys["down"] else 0.0)
	var steer := _steer
	if _keys["left"] or _keys["right"]:
		steer = (1.0 if _keys["right"] else 0.0) - (1.0 if _keys["left"] else 0.0)
	return [gas, brake, -steer]


## A recorded run (one [time_ms, gas, brake, steer (+ = left)] per tick) as a script: a line only
## where a value changes.
static func write(ticks: Array) -> String:
	var out := PackedStringArray(["# SpeedFest Stadium run, TMInterface-style (see race/tm_input_script.gd)"])
	var last := [-1.0, -1.0, 9.0]
	for t: Array in ticks:
		var secs := "%.2f" % (int(t[0]) / 1000.0)
		for k in 3:
			var v := float(t[k + 1])
			if absf(v - float(last[k])) > 1e-12:
				var name: String = ["gas", "brake", "steer"][k]
				var val := -v * FULL if k == 2 else v * FULL     # steer: TMInterface's sign
				out.append("%s %s %s" % [secs, name, String.num(val, 6)])
				last[k] = v
	return "\n".join(out) + "\n"
