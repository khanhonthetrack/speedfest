extends Node
## Visual demo: solo race on the test track plus three RemoteCars fed synthetic snapshots that
## drive alongside/ahead of the local car (name tags, fading, wheels, lights).
## tools/run_scene.sh res://tests/race/remote_cars_demo.tscn -- --frames=420 --shot=/abs/remote.png --autodrive

var race: Node
var remotes: Array[RemoteCar] = []
const OFFSETS := [Vector3(-4.0, 0, -9.0), Vector3(4.5, 0, -22.0), Vector3(0.5, 0, 3.5)]
const NAMES := ["NightRider", "Khanh", "TOFU_DRIFT"]
const CARS := ["brute", "veloce", "kaze"]


func _ready() -> void:
	Game.mode = "solo"
	Game.round_info = {}
	race = (load("res://race/race.tscn") as PackedScene).instantiate()
	race.set("track_override", load("res://tests/race/test_track.gd").create())
	add_child(race)
	for i in 3:
		var rc := RemoteCar.new()
		race.add_child(rc)
		var cfg := CarDefs.default_config(CARS[i])
		rc.setup(100 + i, NAMES[i], cfg)
		remotes.append(rc)


func _physics_process(_delta: float) -> void:
	var car: Car = race.get("car")
	if car == null:
		return
	var now := Time.get_ticks_msec()
	var xf := car.global_transform
	for i in remotes.size():
		var p: Vector3 = xf.origin + xf.basis * OFFSETS[i]
		p.y = car.global_position.y
		var q := xf.basis.get_rotation_quaternion()
		var v := car.linear_velocity
		remotes[i].push_state({"rx_ms": now, "ts": now, "t": 1000, "p": [p.x, p.y, p.z], "q": [q.x, q.y, q.z, q.w],
			"v": [v.x, v.y, v.z], "st": 0.1 * sin(now / 500.0 + i), "rpm": 0.7, "fl": 16 | (1 if i == 0 else 0) | (2 if i == 1 else 0)})
