class_name TrackDefs
extends RefCounted
## Static metadata for the three tracks. Layouts live in res://tracks/defs/<id>.gd.

const IDS: Array[String] = ["downtown", "arena", "coast"]

const DEFS := {
	"downtown": {
		"name": "Neon Downtown",
		"theme": "city",
		"circuit": false,
		"blurb": "Rooftop stunt run through a rainy neon city: a gap jump, a wall ride, a loop and a dive between towers.",
		"target_s": 35,
		"weather": "rain",
	},
	"arena": {
		"name": "Pulse Arena",
		"theme": "arena",
		"circuit": false,
		"blurb": "Classic night stadium: tower dive, turbo, loop, wall ride, gap jump, half-pipe and a big final jump.",
		"target_s": 32,
		"weather": "dry",
	},
	"coast": {
		"name": "Sunset Coast",
		"theme": "coast",
		"circuit": false,
		"blurb": "Cliffside run at dusk: fast sweepers, a cliff wall ride, the huge bay jump and a headland loop.",
		"target_s": 32,
		"weather": "dry",
	},
}

const DURATIONS_S: Array[int] = [180, 300, 420, 600]
const DEFAULT_DURATION_S := 300


static func get_def(track_id: String) -> Dictionary:
	return DEFS.get(track_id, DEFS["arena"])


static func display_name(track_id: String) -> String:
	return get_def(track_id)["name"]


static func theme(track_id: String) -> String:
	return get_def(track_id)["theme"]
