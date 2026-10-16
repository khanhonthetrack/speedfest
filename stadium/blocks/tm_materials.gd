class_name TmMaterials
extends RefCounted
## Visual materials of the recreated blocks, by key (our own look in the TMNF Stadium style; flat
## colours for now, procedural textures later): [albedo, roughness, metallic(, emission energy)].
## Unknown keys get a magenta debug material.

static var _cache := {}

const COLORS := {
	"asphalt": [Color(0.20, 0.21, 0.23), 0.85, 0.0],
	"platform": [Color(0.66, 0.69, 0.74), 0.8, 0.0],
	"rubber": [Color(0.78, 0.12, 0.10), 0.7, 0.0],
	"rubber_white": [Color(0.92, 0.92, 0.92), 0.7, 0.0],
	"metal": [Color(0.62, 0.64, 0.68), 0.45, 0.7],
	"grid": [Color(0.42, 0.44, 0.48), 0.5, 0.6],
	"wall": [Color(0.88, 0.89, 0.91), 0.75, 0.0],
	"wall_dark": [Color(0.32, 0.34, 0.38), 0.8, 0.0],
	"logo": [Color(0.12, 0.30, 0.72), 0.6, 0.0],
	"screen": [Color(0.05, 0.06, 0.08), 0.3, 0.0],
	"stands": [Color(0.36, 0.42, 0.55), 0.85, 0.0],
	"structure": [Color(0.30, 0.31, 0.34), 0.7, 0.3],
	"grass": [Color(0.30, 0.50, 0.20), 0.95, 0.0],
	"dirt": [Color(0.55, 0.38, 0.22), 0.95, 0.0],
	"water": [Color(0.15, 0.40, 0.65, 0.75), 0.1, 0.0],
	"glass": [Color(0.70, 0.85, 0.95, 0.35), 0.05, 0.0],
	"turbo": [Color(0.95, 0.65, 0.10), 0.5, 0.0],
	"inflatable": [Color(0.95, 0.85, 0.25), 0.6, 0.0],
	"fabric": [Color(0.85, 0.86, 0.90), 0.8, 0.0],
	"pipe": [Color(0.82, 0.84, 0.88), 0.35, 0.55],
	"rubber_dark": [Color(0.10, 0.10, 0.11), 0.9, 0.0],
	"lamp": [Color(1.0, 0.96, 0.85), 0.3, 0.0, 3.0],
	"sculpt": [Color(0.84, 0.86, 0.90), 0.55, 0.1],
}


static func get_material(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var spec: Array = COLORS.get(key, [Color(1, 0, 1), 0.5, 0.0])
	m.albedo_color = spec[0]
	m.roughness = spec[1]
	m.metallic = spec[2]
	if spec.size() > 3:
		m.emission_enabled = true
		m.emission = spec[0]
		m.emission_energy_multiplier = spec[3]
	if (spec[0] as Color).a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m
