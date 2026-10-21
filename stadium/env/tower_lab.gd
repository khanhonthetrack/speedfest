extends Node3D
## Looks at TmTower's skyscrapers (no map): the Stadium's sky and sun, a plaza, a row of towers in
## their styles. --view=street (from the pavement, looking up), mid (from 300 m), far (2 km),
## top (from a roof). --frames=N --shot=/abs.png for a screenshot.

const SPECS := [
	{"height": 300.0, "w": 46.0, "d": 40.0, "shape": "chamfer", "glass": "blue", "crown": "spire", "seed": 3,
		"tiers": [[0.55, 1.0], [0.85, 0.82], [1.0, 0.64]]},
	{"height": 380.0, "w": 52.0, "d": 52.0, "shape": "rounded", "glass": "silver", "crown": "slant", "seed": 11,
		"tiers": [[0.7, 1.0], [1.0, 0.86]]},
	{"height": 220.0, "w": 40.0, "d": 34.0, "shape": "rect", "glass": "bronze", "crown": "flat", "seed": 23, "fins": 2},
	{"height": 260.0, "w": 44.0, "d": 44.0, "shape": "octagon", "glass": "green", "crown": "ring", "seed": 31, "fins": 4,
		"tiers": [[0.6, 1.0], [1.0, 0.9]]},
	{"height": 340.0, "w": 38.0, "d": 38.0, "shape": "circle", "glass": "dark", "crown": "spire", "seed": 47,
		"tiers": [[0.8, 1.0], [1.0, 0.75]]},
]


func _ready() -> void:
	TmStadiumEnv.add(self)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 8000)
	ground.mesh = pm
	ground.material_override = TmMaterials.get_material("concrete")
	add_child(ground)
	var x := 0.0
	for spec: Dictionary in SPECS:
		var t := TmTower.build(spec)
		t.position = Vector3(x, 0.0, 0.0)
		add_child(t)
		x += 110.0
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 12000.0
	add_child(cam)
	cam.current = true
	match String(TestHooks.arg("view", "mid")):
		"street":
			cam.position = Vector3(80.0, 1.8, 70.0)
			cam.look_at(Vector3(40.0, 160.0, 0.0))
		"far":
			cam.position = Vector3(1400.0, 60.0, 1900.0)
			cam.look_at(Vector3(220.0, 150.0, 0.0))
		"top":
			cam.position = Vector3(-60.0, 230.0, 120.0)
			cam.look_at(Vector3(160.0, 200.0, 0.0))
		_:
			cam.position = Vector3(380.0, 90.0, 360.0)
			cam.look_at(Vector3(220.0, 150.0, 0.0))
