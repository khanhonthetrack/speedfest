class_name Weather
extends RefCounted
## Round weather: "dry", "rain" or "storm". Pure rules and data, no nodes.
##
## Weather is a ROUND setting (the host picks it in the lobby; solo picks it on the track card),
## so the same track plays differently:
## - rain: all asphalt is a little slicker, and the stage's puddles fill up. A puddle cuts tire
##   grip sharply (aquaplaning) and drags a little speed. Puddles are placed by the stage design
##   (res://tracks/defs/<id>.gd, {"puddle": ...} markers) as line choices: the dry line is longer or
##   tighter, the wet line is faster if you keep the car straight.
## - storm: heavier rain, bigger puddles, extra storm-only puddles, lightning and thunder.
## - dry: no puddles at all; the asphalt is dry even downtown.
## PBs and PB ghosts are kept per (track, weather).

const MODES: Array[String] = ["dry", "rain", "storm"]
const NAMES := {"dry": "Dry", "rain": "Rain", "storm": "Storm"}
const BLURBS := {
	"dry": "Dry asphalt, full grip.",
	"rain": "Wet roads and puddles: puddles cut grip, keep it straight through them.",
	"storm": "Downpour: bigger puddles, extra ones, lightning. Hold on.",
}

## Grip of wet asphalt everywhere (multiplies tire grip), by mode.
const ROAD_GRIP := {"dry": 1.0, "rain": 0.94, "storm": 0.9}
## Grip in the middle of a puddle (multiplies the road grip).
const PUDDLE_GRIP := {"dry": 1.0, "rain": 0.5, "storm": 0.42}
## Water drag per wheel fully in a puddle (m/s^2 of the car's corner mass).
const PUDDLE_DRAG := {"dry": 0.0, "rain": 4.0, "storm": 5.0}
## Puddle size relative to its storm size (meshes are built at storm size).
const PUDDLE_EXTENT := {"dry": 0.0, "rain": 0.76, "storm": 1.0}
## Road shader wetness and rain particle density.
const ROAD_WETNESS := {"dry": 0.08, "rain": 0.85, "storm": 1.0}
const RAIN_DENSITY := {"dry": 0.0, "rain": 1.0, "storm": 1.6}


static func sanitize(mode: Variant) -> String:
	var m := String(mode).strip_edges().to_lower() if typeof(mode) == TYPE_STRING else ""
	return m if m in MODES else "dry"


## The stage's signature weather (TrackDefs "weather"): downtown rains, the others are dry.
static func default_for(track_id: String) -> String:
	return sanitize(TrackDefs.get_def(track_id).get("weather", "dry"))


static func display_name(mode: String) -> String:
	return NAMES.get(sanitize(mode), "Dry")


static func is_wet(mode: String) -> bool:
	return sanitize(mode) != "dry"


static func road_grip(mode: String) -> float:
	return ROAD_GRIP[sanitize(mode)]


static func puddle_grip(mode: String) -> float:
	return PUDDLE_GRIP[sanitize(mode)]


static func puddle_drag(mode: String) -> float:
	return PUDDLE_DRAG[sanitize(mode)]


static func puddle_extent(mode: String) -> float:
	return PUDDLE_EXTENT[sanitize(mode)]


static func road_wetness(mode: String) -> float:
	return ROAD_WETNESS[sanitize(mode)]


static func rain_density(mode: String) -> float:
	return RAIN_DENSITY[sanitize(mode)]


## Key for personal bests and PB ghosts: times in the rain don't compete with dry times.
static func pb_key(track_id: String, mode: String) -> String:
	return "%s@%s" % [track_id, sanitize(mode)]


static func next_mode(mode: String, step := 1) -> String:
	var i := MODES.find(sanitize(mode))
	return MODES[posmod(i + step, MODES.size())]
