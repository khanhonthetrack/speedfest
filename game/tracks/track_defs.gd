class_name TrackDefs
extends RefCounted
## Static metadata for the tracks. Layouts live in res://tracks/defs/<id>.gd.
## infield / dunes: ~10 s sprints that use grass, gravel and sand (owner, session 4).

const IDS: Array[String] = ["downtown", "arena", "coast", "infield", "dunes"]

const DEFS := {
	"downtown": {
		"name": "Neon Downtown",
		"short": "Downtown",
		"theme": "city",
		"circuit": false,
		"blurb": "Rooftop run through a rainy neon city: a rooftop gap jump, a checkpoint inside a tower, wall rides on facades and a needle jump between towers.",
		"target_s": 35,
		"weather": "rain",
	},
	"arena": {
		"name": "Pulse Arena",
		"short": "Arena",
		"theme": "arena",
		"circuit": false,
		"blurb": "Classic night stadium: tower dive, turbo, loop, wall ride, gap jump, half-pipe and a big final jump.",
		"target_s": 32,
		"weather": "dry",
	},
	"coast": {
		"name": "Sunset Coast",
		"short": "Coast",
		"theme": "coast",
		"circuit": false,
		"blurb": "Cliffside run at dusk: fast sweepers, a cliff wall ride, the huge bay jump and a headland loop.",
		"target_s": 32,
		"weather": "dry",
	},
	"infield": {
		"name": "Infield Rush",
		"short": "Infield",
		"theme": "arena",
		"circuit": false,
		"blurb": "10-second stadium sprint: a hairpin with a grass short cut, a gravel chicane and a jump over the sand trap.",
		"target_s": 11,
		"weather": "dry",
	},
	"dunes": {
		"name": "Dune Dash",
		"short": "Dunes",
		"theme": "coast",
		"circuit": false,
		"blurb": "10-second beach sprint: a sand short cut, a dune jump, a gravel hairpin and grass on the clifftop.",
		"target_s": 11,
		"weather": "dry",
	},
}

const DURATIONS_S: Array[int] = [180, 300, 420, 600]
const DEFAULT_DURATION_S := 300


static func get_def(track_id: String) -> Dictionary:
	return DEFS.get(track_id, DEFS["arena"])


static func display_name(track_id: String) -> String:
	return get_def(track_id)["name"]


## One-word name for tight spots (lobby track chips).
static func short_name(track_id: String) -> String:
	var d := get_def(track_id)
	return String(d.get("short", d["name"]))


static func theme(track_id: String) -> String:
	return get_def(track_id)["theme"]
