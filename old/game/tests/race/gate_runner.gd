extends Node
## Test driver for the race module: while the race is RUNNING it moves the local car along the
## track path at a fixed speed by teleporting it every physics tick, so the real Area3D gates fire.
## Works on any track (test track or real). Enabled by race.gd with --gate_runner=<m/s>.

var race: Node
var speed := 40.0
var _d := 0.0
var _running := false


func _physics_process(delta: float) -> void:
	if race == null:
		return
	var car: Car = race.get("car")
	var track: Track = race.get("track")
	if car == null or track == null:
		return
	var running: bool = int(race.get("state")) == 2 # State.RUNNING
	if running and not _running:
		_d = track.path.closest_distance(car.global_position)
		print("GATE_RUNNER start d=%.1f length=%.1f zones=%s" % [_d, track.path.length, str(track.path.zones)])
	_running = running
	if not running:
		return
	_d += speed * delta
	if not track.path.is_circuit and _d > track.path.length - 1.0:
		_d = track.path.length - 1.0
	var dd := fposmod(_d, track.path.length) if track.path.is_circuit else _d
	var xf := track.path.sample_transform(dd)
	xf.origin += xf.basis.y * 0.6
	car.teleport(xf, -xf.basis.z * speed)
