class_name TrackDefs
extends RefCounted
## Static metadata for the tracks. Layouts live in res://tracks/defs/<id>.gd.
## infield / dunes: ~10 s sprints that use grass, gravel and sand (owner, session 4).
## rails: short stadium map with a start-ledge jump onto a grind rail (owner, session 5).
## rooftop / cliff / twister / pipes: 10-30 s maps, one clever idea each (owner, session 6).

const IDS: Array[String] = ["downtown", "arena", "coast", "rooftop", "cliff", "twister", "pipes", "infield", "dunes", "rails", "frost", "dust", "blackout", "glide", "techlab", "fullsend", "cruise", "plastic", "sausage", "mixer", "platform", "snake"]

const DEFS := {
	"downtown": {
		"name": "Neon Downtown",
		"short": "Downtown",
		"theme": "city",
		"circuit": false,
		"blurb": "Rainy rooftop run: a checkpoint inside a tower, wall rides on facades, a needle jump between towers.",
		"target_s": 35,
		"weather": "rain",
	},
	"arena": {
		"name": "Pulse Arena",
		"short": "Arena",
		"theme": "arena",
		"circuit": false,
		"blurb": "Night stadium: tower dive, loop, wall ride, gap jump, half-pipe and a big final jump.",
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
	"rooftop": {
		"name": "Rooftop Rush",
		"short": "Rooftops",
		"theme": "city",
		"circuit": false,
		"blurb": "Never touch the street: roof jump, through a tower, a facade wall ride, then grind the cable to the finish roof.",
		"target_s": 14,
		"weather": "rain",
	},
	"cliff": {
		"name": "Cliff Hanger",
		"short": "Cliff",
		"theme": "coast",
		"circuit": false,
		"blurb": "Downhill sweepers with sand on the inside, a cliff wall ride, then the super boost bay jump.",
		"target_s": 15,
		"weather": "dry",
	},
	"twister": {
		"name": "Twister",
		"short": "Twister",
		"theme": "arena",
		"circuit": false,
		"blurb": "Two loops that twist opposite ways, a side turbo between them, out onto the finish jump.",
		"target_s": 14,
		"weather": "dry",
	},
	"pipes": {
		"name": "Pipe Dream",
		"short": "Pipes",
		"theme": "arena",
		"circuit": false,
		"blurb": "Three banked half-pipes: low and gravelly or high and fast. The side turbos reward the high line.",
		"target_s": 18,
		"weather": "dry",
	},
	"rails": {
		"name": "Rail Rush",
		"short": "Rails",
		"theme": "arena",
		"circuit": false,
		"blurb": "Fly off the start ledge, land on the rail and grind it round the bend to the finish.",
		"target_s": 7,
		"weather": "dry",
	},
	"frost": {
		"name": "Frostbite",
		"short": "Frost",
		"theme": "arena",
		"circuit": false,
		"blurb": "Ice map: brake on the asphalt strips, let the banking carry you round the ice, then the ice bowl.",
		"target_s": 20,
		"weather": "dry",
	},
	"dust": {
		"name": "Dust Devil",
		"short": "Dust",
		"theme": "coast",
		"circuit": false,
		"blurb": "Dirt road: drift the hairpins, hop the dunes straight, keep off the gravel edges.",
		"target_s": 22,
		"weather": "dry",
	},
	"blackout": {
		"name": "Blackout",
		"short": "Blackout",
		"theme": "city",
		"circuit": false,
		"blurb": "Engine off after the boost: dive through the towers on momentum and make the finish jump.",
		"target_s": 20,
		"weather": "rain",
	},
	"glide": {
		"name": "Glider",
		"short": "Glider",
		"theme": "arena",
		"circuit": false,
		"blurb": "Hit the reactor pad on the kicker and fly the long gap, steering in the air to the landing.",
		"target_s": 18,
		"weather": "dry",
	},
	"techlab": {
		"name": "Tech Lab",
		"short": "Tech",
		"theme": "arena",
		"circuit": false,
		"blurb": "Narrow deck, tight hairpins and chicanes: brake late, turn in early, drift the hairpin.",
		"target_s": 22,
		"weather": "dry",
	},
	"fullsend": {
		"name": "Full Send",
		"short": "Send",
		"theme": "coast",
		"circuit": false,
		"blurb": "Never brake: wide banked sweepers, long drops and boosts at 300+ km/h.",
		"target_s": 24,
		"weather": "dry",
	},
	"cruise": {
		"name": "Autopilot",
		"short": "Cruise",
		"theme": "city",
		"circuit": false,
		"blurb": "Cruise control locks your speed through a wall ride and a loop: you only steer.",
		"target_s": 20,
		"weather": "rain",
	},
	"plastic": {
		"name": "Plastic Fantastic",
		"short": "Plastic",
		"theme": "arena",
		"circuit": false,
		"blurb": "Plastic drags you down: ride the turbo lines up the climb, the slalom and the half-pipe.",
		"target_s": 18,
		"weather": "dry",
	},
	"sausage": {
		"name": "Sausage Run",
		"short": "Sausage",
		"theme": "coast",
		"circuit": false,
		"blurb": "Rolling humps: crest them flat and stay planted, or float into the next dip.",
		"target_s": 16,
		"weather": "dry",
	},
	"mixer": {
		"name": "Surface Mixer",
		"short": "Mixer",
		"theme": "arena",
		"circuit": false,
		"blurb": "Asphalt, dirt hairpin, ice bend, grass slalom, plastic climb: a new surface every section.",
		"target_s": 24,
		"weather": "dry",
	},
	"platform": {
		"name": "Stepping Stones",
		"short": "Stones",
		"theme": "arena",
		"circuit": false,
		"blurb": "Narrow platforms and gaps: hop, land straight, line up the next lip.",
		"target_s": 15,
		"weather": "dry",
	},
	"snake": {
		"name": "Snake Alley",
		"short": "Snake",
		"theme": "city",
		"circuit": false,
		"blurb": "S-bends between tower walls, rising and falling: rhythm and clean exits.",
		"target_s": 22,
		"weather": "rain",
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
