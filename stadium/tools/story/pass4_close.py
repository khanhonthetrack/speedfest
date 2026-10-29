"""(Kept in the repo.) The fourth pass on night 1's Mirror (docs/CINEMATICS.md, "fourth pass"), from
the third pass's critic (5-6/10 a shot): every face lit by a light the scene has (a streetlight
through the window, the coupe's beams from behind, the instruments from below, the mirror's slash,
the dome from above) instead of a fill at the lens; cameras inside the cabin checked against its
parts (the rear-view mirror, the wheel and the visors block most places a lens would like to be);
the ghost lit only by her own cold light, never brighter than Kit; the inserts' street a stop under
the mirror; the false calm, the reveal and the look back tighter. Edits the committed scene in place
and gives the same file however often it runs (after pass3_close.py).
    python3 tools/story/pass4_close.py stadium/story/scenes/c01_close.json"""
import copy, json, sys

path = sys.argv[1]
scene = json.load(open(path))
shots = {s["id"]: s for s in scene["shots"]}


def car(shot, cid):
    return next((c for c in shot.get("cars", []) if c["id"] == cid), None)


def person(shot, pid):
    return next((p for p in shot.get("people", []) if p["id"] == pid), None)


def omni(pos, colour, energy, rng, shadow=False, **more):
    l = {"car": "kit", "kind": "omni", "pos": pos, "colour": colour, "energy": energy, "range": rng, "shadow": shadow}
    l.update(more)
    return l


def spot(pos, look, colour, energy, angle, rng, shadow=False, **more):
    l = {"car": "kit", "kind": "spot", "pos": pos, "look": look, "colour": colour, "energy": energy, "angle": angle,
         "range": rng, "shadow": shadow}
    l.update(more)
    return l


def white_lamps(e=8.0, rng=3.0):
    """The coupe's own lamps (in its frame), at e."""
    return [{"car": "white", "kind": "omni", "pos": [0.6, 0.7, 2.2], "colour": "#f2f4ff", "energy": e, "range": rng, "shadow": False},
            {"car": "white", "kind": "omni", "pos": [-0.6, 0.7, 2.2], "colour": "#f2f4ff", "energy": e, "range": rng, "shadow": False},
            {"car": "white", "kind": "omni", "pos": [0.0, 1.7, 1.2], "colour": "#c8d4ff", "energy": 2.5, "range": 4.0, "shadow": False}]


def keys(*ks, **common):
    return [dict(common, **k) for k in ks]


EYES = [0.376, 1.117, -0.096]                 # Kit's eyes as she sits (Lot 47's frame; story_lab --probe: a
HEAD = [0.376, 1.1, -0.12]                    # quarter of a metre behind the layout's "driver_head")
DASH = omni([0.32, 0.93, 0.55], "#6fa8ff", 0.35, 1.0)          # the instruments' glow
FILL = omni([-0.3, 0.9, -0.4], "#2a3560", 0.25, 1.6)           # the night through the far windows
DREAD_ENV = {"city_lit": 0.05, "city_led": 0.0}
ROAD_ENV = {"city_led": 0.25}                # (the shopfronts' neon lines at waist height read as a track's barrier lights)
INSERT = {"preset": "night", "vignette": 0.6}    # the mirror's inserts: the street round the glass a stop down
GHOST_LIGHT = "#9fd8c8"

# --- asleep: a streetlight through her window, her head fallen against the headrest --------------------
sh = shots["asleep"]
sh["dur"] = 2.4
sh["glass"] = 0.15
sh["lights"] = [
    {"kind": "omni", "pos": [-6.0, 5.0, 4.0], "colour": "#ffb36b", "energy": 2.0, "range": 18.0},
    {"kind": "omni", "pos": [4.5, 3.2, 0.5], "colour": "#ffd2a1", "energy": 2.0, "range": 12.0},
    spot([1.4, 1.35, 0.25], HEAD, "#ffb36b", 2.2, 25.0, 3.0, True, id="window_key"),
    omni([0.45, 1.38, -0.35], "#7fb0ff", 0.4, 0.9),
    FILL,
    omni([0.37, 0.85, 0.45], "#3fa0ff", 0.25, 0.8)]
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [-0.05, 1.0, 0.75]}, {"u": 1, "pos": [-0.03, 1.0, 0.69]},
    look=[0.35, 1.05, -0.05], fov=32, eye_light=0.04)}
k = person(sh, "kit_driver")
k["bend"] = [{"t": 0.0, "Neck": [8, 0, -6], "Head": [12, 4, -18]}, {"t": 1.9, "Neck": [8, 0, -6], "Head": [12, 4, -18]},
             {"t": 2.4, "Neck": [3, 0, -3], "Head": [5, 0, -6]}]

# --- the dream's road: the pursuer given clean air, Kit's lamps down so its beams read first ---------------
sh = shots["dream_road"]
sh["dur"] = 2.4
sh["env"] = dict(ROAD_ENV)
car(sh, "white")["ahead"] = -30.0
car(sh, "kit")["glow"] = 0.5
sh["lights"] = [
    omni([0.32, 1.05, 0.35], "#6fa8ff", 1.0, 1.0),             # her head against the windscreen
    spot([0.6, 0.65, 2.3], [0.6, 0.0, 14.0], "#e8eeff", 3.0, 28.0, 25.0),
    spot([-0.6, 0.65, 2.3], [-0.6, 0.0, 14.0], "#e8eeff", 3.0, 28.0, 25.0),
    omni([-2.5, 2.4, -2.5], "#ff4fa0", 3.0, 7.0, True),
    omni([1.5, 1.6, -6.0], "#f2f4ff", 3.0, 6.0)] + white_lamps(4.0)   # (the coupe's beams on the roofline)
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.08, "keys": keys(
    {"u": 0, "pos": [2.4, 0.34, 5.6]}, {"u": 1, "pos": [2.1, 0.34, 4.8]}, look=[-0.3, 0.8, -6.0], fov=28)}

# --- profile: three-quarter front, the coupe's beams a hard rim from behind ---------------------------------
sh = shots["profile"]
sh["env"] = dict(ROAD_ENV)
sh["lights"] = [DASH, omni([1.0, 0.95, 0.2], "#ff5aa8", 0.5, 1.4, True), FILL,
                spot([-0.25, 1.5, -1.9], HEAD, "#e8eeff", 3.0, 8.0, 4.0, id="beams")] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.2, "keys": keys(
    {"u": 0, "pos": [-0.30, 1.02, 0.35]}, {"u": 1, "pos": [-0.28, 1.02, 0.32]},
    look=[0.37, 1.11, -0.08], fov=35, eye_light=0.04, dof=[0.9, 0.6, 0.1])}
sh["passing"]["energy"] = 1.2

# --- the mirror far: the glass framed by the header and the visors, the street round it down ------------------
MIRROR_SEE = [0.0, 1.131, 0.512]
sh = shots["mirror_far"]
sh["glass"] = 0.2
sh["env"] = dict(ROAD_ENV, ssr=False)
sh["grade"] = dict(INSERT)
sh["mirror"]["exposure"] = 2.6
sh["lights"] = [DASH, FILL, omni([0.2, 1.42, -0.1], "#ff5fa8", 0.15, 0.7)] + white_lamps(14.0, 6.0)
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.0, "keys": keys(
    {"u": 0, "pos": [0.28, 1.2, -0.05]}, {"u": 1, "pos": [0.275, 1.195, -0.02]},
    look=MIRROR_SEE, fov=22, dof=[0.9, 0.5, 0.15])}

# --- the low reverse: our flank soft at the edge, the coupe nearer, our tail light red on the wet road --------
sh = shots["coupe_low"]
sh["dur"] = 1.6
car(sh, "white")["ahead"] = -35.0
sh["lights"] = [DASH, omni([-0.6, 0.85, -2.2], "#ff2a2a", 2.0, 3.0)] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.1, "keys": keys(
    {"u": 0, "pos": [-1.15, 0.55, -1.6]}, {"u": 1, "pos": [-1.13, 0.56, -1.52]},
    look=[-0.2, 0.95, -60.0], fov=24, dof_near=[0.8, 0.4, 0.15])}

# --- closer: a close-up clear of the mirror, the beams' back key growing --------------------------------------
sh = shots["closer"]
sh["env"] = dict(ROAD_ENV)
sh["lights"] = [DASH, omni([0.85, 1.2, 0.2], "#ff6fb0", 0.5, 1.5, True), FILL,
                spot([-0.25, 1.5, -1.9], HEAD, "#f2f4ff", [[0, 4.0], [1.5, 7.0]], 8.0, 4.0, id="beams")] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [-0.2, 1.1, 0.5]}, {"u": 1, "pos": [-0.18, 1.1, 0.47]},
    look=[0.37, 1.1, -0.1], fov=26, eye_light=0.05)}
sh["passing"]["shadow"] = False

# --- THE GLIMPSE: a black head against the glare, the lamps blooming instead of clipping ----------------------
sh = shots["rear_window"]
sh["glass"] = 0.3
sh["env"] = dict(ROAD_ENV)
sh["lights"] = [DASH, omni([0.0, 0.9, -3.6], "#b01818", 0.5, 9.0), FILL] + white_lamps(5.0, 6.0)
for kk in sh["camera"]["keys"]:
    kk["exposure"] = 1.25 if kk.get("t") == 1.18 else 0.85
g = person(sh, "passenger")
g["pos"] = [-0.05, -0.06, -0.40]

# --- the glare: across the cabin over the mirror, a slash of the beams over her eyes ----------------------------
sh = shots["glare"]
sh["env"] = dict(ROAD_ENV)
sh["lights"] = [DASH, FILL, spot([0.0, 1.13, 0.5], EYES, "#eef2ff", [[0, 0.0], [1.2, 3.5]], 6.0, 1.2, id="slash")] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.3, "keys": [
    {"u": 0, "pos": [0.05, 1.18, 0.42], "look": [0.37, 1.11, -0.08], "fov": 28, "eye_light": 0.0, "exposure": 1.0},
    {"u": 1, "pos": [0.06, 1.18, 0.40], "look": [0.37, 1.11, -0.08], "fov": 28, "eye_light": 0.0, "exposure": 1.4}]}

# --- the whiteout: two lamps growing until they eat the mirror, the cabin flooded on the hit --------------------
sh = shots["whiteout"]
car(sh, "white").update({"ahead": -4.0, "left": 0.4})
sh["mirror"]["exposure"] = 2.6
sh["lights"] = [DASH, FILL,
                omni([0.0, 1.2, -1.5], "#f2f4ff", [[0, 0.0], [0.45, 0.0], [0.72, 10.0]], 3.0)] + [
    dict(l, energy=[[0, 8.0], [0.3, 8.0], [0.7, 30.0]], range=10.0) if l["colour"] == "#f2f4ff" else l for l in white_lamps()]
sh["camera"] = {"follow": "kit", "ease": "in", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [0.3, 1.15, -0.10], "look": MIRROR_SEE, "fov": 13, "exposure": 1.0},
    {"t": 0.45, "pos": [0.3, 1.15, -0.06], "look": MIRROR_SEE, "fov": 13, "exposure": 1.0},
    {"t": 0.7, "pos": [0.3, 1.15, -0.02], "look": MIRROR_SEE, "fov": 13, "exposure": 1.6}]}

# --- the road empty: dark, one streetlight's pool where the coupe was ------------------------------------------
sh = shots["empty_road"]
sh["glass"] = 0.3
sh["env"] = dict(ROAD_ENV)
sh["lights"] = [DASH, FILL, omni([0.0, 0.9, -3.6], "#ff2a2a", 0.25, 9.0),
                omni([-0.5, 5.0, -18.0], "#ffb36b", 6.0, 14.0, True)]
for kk in sh["camera"]["keys"]:
    kk["exposure"] = 0.85

# --- a dark road: the ghost's own place, Kit's head a soft dark shape on the left -------------------------------
sh = shots["dark_road"]
sh["dur"] = 1.5
sh["lights"] = [omni([0.3, 0.95, 0.5], "#6fa8ff", 0.6, 1.0), FILL, omni([0.0, 0.9, -3.6], "#ff2a2a", 0.3, 9.0)]
sh["camera"] = {"follow": "kit", "handheld": 0.05, "keys": keys(
    {"u": 0, "pos": [0.0, 1.15, -0.8]}, {"u": 1, "pos": [0.01, 1.15, -0.76]},
    look=[0.7, 1.0, 4.0], fov=34, dof_near=[0.6, 0.3, 0.12])}
sh["rain"] = [[0, 0.6], [0.5, 0.0]]
sh["passing"]["until"] = 0.75
for a in sh.get("ambience", []):
    if isinstance(a, dict) and a.get("cue") == "rain":
        a["to"] = 0.5
    if isinstance(a, dict) and a.get("cue") == "wipers":
        a["to"] = 0.75

# --- the false calm: shorter, lit from the dome above; she rises out of the dark in her own cold light ---------
sh = shots["breath_out"]
sh["dur"] = 2.6
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [0.06, 0.97, 0.80]}, {"u": 1, "pos": [0.07, 0.98, 0.70]},
    look=[0.2, 1.05, -0.12], fov=32, dof=[1.0, 0.4, 0.1], eye_light=0.04)}
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.2, 1.0),
                spot([0.32, 1.33, -0.05], [0.376, 1.0, -0.1], "#8fa6c8", 1.0, 40.0, 1.0, id="dome_key"),
                omni([-0.25, 1.35, -0.9], GHOST_LIGHT, 0.2, 0.7, id="ghost_light")]      # (a cold edge from behind her: at her face it lit her white)
k = person(sh, "kit_driver")
k["breathe"] = [1.7, 2.5]
k["bend"] = [{"t": 0}, {"t": 0.25, "Spine": [10, 0, 0], "Chest": [12, 0, 0]},
             {"t": 0.9, "Spine": [8, 0, 0], "Chest": [10, 0, 0], "Head": [-6, 0, 0]},
             {"t": 2.25, "Spine": [8, 0, 0], "Chest": [10, 0, 0], "Head": [-6, 0, 0]},
             {"t": 2.45, "Spine": [2, 0, 0], "Neck": [0, -6, 0], "Head": [-5, -12, 0]}]
k["shapes"] = [{"t": 0, "browInnerUp": 0.35}, {"t": 0.8, "eyeBlinkLeft": 1, "eyeBlinkRight": 1, "browInnerUp": 0.1},
               {"t": 2.25, "eyeBlinkLeft": 1, "eyeBlinkRight": 1}, {"t": 2.32, "eyeBlinkLeft": 0, "eyeBlinkRight": 0, "browInnerUp": 0.6}]
k["looks"] = [[2.3, 2.6, "mirror"]]
g = person(sh, "passenger")
g["from"] = 2.3                                  # (the ghost's whole time on screen in the scene: 1.5 s at most)
g["lift"] = [[2.3, -0.45], [2.55, 0.0]]
g["bend"] = [{"t": 2.3, "Neck": [15, 0, 0], "Head": [25, 0, 0]}, {"t": 2.6, "Neck": [-2, 0, 0], "Head": [12, 0, 10]}]
g["reach"] = [{"t": 2.4}, {"t": 2.55, "LeftHand": copy.deepcopy(g["reach"][-1]["LeftHand"])}]
sh["sounds"] = [{"at": 0.2, "cue": "breath", "db": -6}, {"at": 1.2, "cue": "drip", "db": -14}, {"at": 2.3, "cue": "creak", "db": -10}]

# --- she is there: her face in the gap beside Kit's head, lit by her own light, eyes on Kit's ------------------
sh = shots["she_is_there"]
sh["dur"] = 1.2
sh["grade"] = dict(INSERT)
sh["mirror"]["exposure"] = 2.4
car(sh, "kit")["dome"] = [[0, 0.0], [0.52, 0.0], [0.55, 0.3]]
sh["flicker"] = {"rate": 16.0, "depth": 1.0, "from": 0.52, "to": 0.66}
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.35, 1.0),
                omni([-0.02, 1.22, -0.18], GHOST_LIGHT, [[0, 0.0], [0.52, 0.0], [0.55, 0.5]], 0.45, id="ghost_face")]
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [0.3, 1.17, -0.15]}, {"u": 1, "pos": [0.295, 1.168, -0.11]}, look=MIRROR_SEE, fov=13, dof=[0.9, 0.5, 0.15])}
person(sh, "kit_driver")["looks"] = [[0.0, 1.2, "mirror"]]
g = person(sh, "passenger")
g["pos"] = [0.02, -0.02, -0.32]
g["from"] = 0.55
g["bend"] = [{"t": 0, "Spine": [18, -6, 0], "Chest": [6, 0, 0], "Neck": [-4, -4, 0], "Head": [2, -6, 8]}]

# --- her eyes: the mirror's slash the only key, brow to nose, wide ------------------------------------------------
sh = shots["eyes"]
car(sh, "kit")["dome"] = 0.06
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.15, 1.0),
                spot([0.05, 1.18, 0.48], EYES, "#cfe0ff", 1.2, 10.0, 1.0, id="slash")]
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [0.30, 1.125, 0.43]}, {"u": 1, "pos": [0.30, 1.125, 0.42]},
    look="kit_driver", look_by=[0.0, 0.01, 0.0], fov=12, eye_light=0.0)}
person(sh, "kit_driver")["shapes"] = [{"t": 0, "browInnerUp": 0.6}, {"t": 0.12, "browInnerUp": 1.0, "jawOpen": 0.1}]

# --- the look back: the instruments light her from below, the street two stops under her face ------------------
sh = shots["look_back"]
sh["dur"] = 1.3
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.2, 1.0),
                spot([0.35, 0.92, 0.45], HEAD, "#6fa8ff", 1.0, 35.0, 1.2, id="under")]
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.2, "keys": keys(
    {"u": 0, "pos": [-0.05, 1.08, -0.45]}, {"u": 1, "pos": [-0.04, 1.08, -0.41]},
    look=[0.37, 1.1, -0.1], fov=30, eye_light=0.03, exposure=0.85)}
k = person(sh, "kit_driver")
TURN = {"Spine": [0, -20, 0], "Chest": [0, -22, 0], "UpperChest": [0, -18, 0], "Neck": [2, -24, 0], "Head": [4, -30, 5]}
k["bend"] = [{"t": 0, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}, dict(TURN, t=0.4), dict(TURN, t=0.9), {"t": 1.2}]
k["looks"] = [[0.15, 0.5, "rear"], [0.5, 0.9, "camera"], [0.9, 1.3, "ahead"]]
k["shapes"] = {"browInnerUp": 1.0, "jawOpen": 0.25, "mouthFrownLeft": 0.35, "mouthFrownRight": 0.35}
sh["sounds"] = [{"at": 0.95, "cue": "breath", "db": -10}, {"at": 1.15, "cue": "breath", "db": -13, "pitch": 1.35}]

# --- the hit: Kit's eyes already sliding to her, the ghost a dark shape with a cold edge -------------------------
sh = shots["hit"]
sh["env"] = dict(DREAD_ENV)
sh["flash"] = [[0.0, 0.05]]
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.8, 1.0),
                omni([0.40, 0.9, 0.05], GHOST_LIGHT, 0.45, 0.4),              # Kit's under-light, in front of her
                spot([0.5, 1.3, -0.9], [0.27, 1.17, -0.29], GHOST_LIGHT, 1.5, 20.0, 1.5, id="ghost_rim")]
person(sh, "kit_driver")["looks"] = [[0.0, 0.4, "passenger"]]

# --- the black: cut just after the gasp ---------------------------------------------------------------------------
shots["black"]["dur"] = 1.1

# === the knock's fourth pass (its critic on round three's stills: 4.5 and 4.5) ===================
# Dee's face in the window for her first line (from a camera at eye height the roof's rail cut her at
# the chin); the knock seen from outside on beaded glass; the geography (the two-shot) third; the
# shot-reverse broken up: Dee's profile outside, Kit three-quarter (her eyes off the lens), an
# over-the-shoulder from behind Dee, Kit from the passenger's seat, Dee's point of view for the plea;
# first light: a cold low sun over the street, the arch's lamp a warm rim behind Dee, the arch's bulb
# down so the background sits under the faces; Dee's mouth narrower, her overalls a worn navy; Kit's
# mouth shut but on the scare lines; the wet patch on screen when Dee names it; the end on the people
# with the number lit. The ids stay (pass3_close.py finds its shots by them): kit_wake is now the
# over-the-shoulder, knock_two Dee's profile outside.
KNOCK_ORDER = ["arch", "knock_ins", "knock", "two_shot", "knock_two", "kit_two", "kit_wake", "knock_dee2", "knock_kit2",
               "back_seat", "knock_dee3", "knock_kit3", "mirror_dawn", "knock_dee4", "pins", "knock_kit4", "knock_end"]
_first = [x["id"] for x in scene["shots"]].index("arch")
scene["shots"] = scene["shots"][:_first] + [shots[x] for x in KNOCK_ORDER] + [
    x for x in scene["shots"][_first:] if x["id"] not in KNOCK_ORDER]

DAWN = {"zenith": "#2a3756", "horizon": "#a8a2a6", "cloud_cover": 0.3, "cloud_lo": "#4c5062", "cloud_hi": "#a8a0a6"}
KNOCK_ENV = {"fog": 0.002, "fog_colour": "#6f7f9c", "fog_sky": 0.85, "exposure": 1.35, "sky": DAWN, "city_lit": 0.08,
             "city_led": 0.0}
KNOCK_GRADE = {"preset": "dawn", "shadows_amount": 0.08, "saturation": 0.8}     # (faces went violet in the blue shadows)
SUN = {"kind": "sun", "pos": [-30.0, 9.0, 12.0], "look": [0.0, 0.0, 0.0], "colour": "#a9bcdc", "energy": 0.75, "range": 40.0}
SKY = {"kind": "omni", "pos": [-6.0, 6.0, -4.0], "colour": "#8da2cc", "energy": 1.6, "range": 26.0}
STREET = {"kind": "spot", "pos": [5.5, 2.4, 3.5], "look": [0.5, 1.05, 0.1], "colour": "#8ea2c4", "energy": 0.6, "range": 14.0,
          "angle": 34.0}
ARCH_RIM = {"kind": "spot", "pos": [2.6, 2.7, -0.6], "look": [1.2, 1.05, 0.05], "colour": "#ffb36b", "energy": 2.5, "angle": 40.0,
            "range": 3.5}      # (onto her back and shoulders, falling into the door: aimed at her head it lit the visor cream)
NEXT_DOOR = {"kind": "omni", "pos": [5.2, 2.6, 9.5], "colour": "#ff9a50", "energy": 0.8, "range": 6.0}
WINDOW = omni([0.85, 1.30, 0.25], "#b8c8e4", 0.35, 1.3)          # the morning through Dee's window, on Kit
OUTSIDE = [SUN, SKY, STREET, ARCH_RIM, NEXT_DOOR]
KNOCK_PROPS = [{"kind": "viaduct", "pos": [5.6, 0.0, 0.5], "yaw": -90.0, "arches": 7, "bulb": 2.2},
               {"kind": "quay", "pos": [0.0, 0.012, 0.0], "rect": [-40.0, -40.0, 5.6, 40.0], "walls": False, "wetness": 0.8},
               {"kind": "warehouse", "pos": [-2.0, 0.0, -24.0], "size": [30.0, 8.0, 12.0], "doors": 3, "lit": [1]}]
DEE_LOOK = {"mouth": 0.35, "tint": {"cloth__male_worksuit01": "#3a4352"}}
TEASE = {"mouthSmileLeft": 0.22, "mouthSmileRight": 0.14}
KIT_SLEEPY = {"eyeSquintLeft": 0.45, "eyeSquintRight": 0.45, "browDownLeft": 0.1, "browDownRight": 0.1}
KIT_DEFENSIVE = {"browDownLeft": 0.3, "browDownRight": 0.3, "browInnerUp": 0.15, "mouthFrownLeft": 0.2, "mouthFrownRight": 0.2}
KIT_AFRAID = {"browInnerUp": 0.9, "jawOpen": 0.08, "mouthFrownLeft": 0.25, "mouthFrownRight": 0.25}
KIT_HAUNTED = {"browInnerUp": 0.6, "eyeBlinkLeft": 0.25, "eyeBlinkRight": 0.25, "mouthFrownLeft": 0.2, "mouthFrownRight": 0.2}
KIT_PLEA = {"browInnerUp": 1.0, "eyeSquintLeft": 0.15, "eyeSquintRight": 0.15, "mouthFrownLeft": 0.3, "mouthFrownRight": 0.3}
TO_DEE = [{"t": 0.0, "Neck": [6, 22, 0], "Head": [8, 30, 0]}]       # Kit's head round to the window
KNOCK_DUR = 2.6
GLASS_DOWN = [1.9, 3.2]                       # the glass winding down from Dee's line (s into the knock)


def say(text, lid, speaker, hold=None, **more):
    l = {"id": lid, "speaker": speaker, "text": text}
    if hold is not None:
        l["hold"] = hold
    l.update(more)
    return l


def kshot(sid, lights, camera, lines, dur=None, lead=0.2, tail=0.25, window=("driver",)):
    sh = shots[sid]
    sh["env"] = copy.deepcopy(KNOCK_ENV)
    sh["grade"] = dict(KNOCK_GRADE)
    sh["props"] = copy.deepcopy(KNOCK_PROPS)
    sh["lights"] = copy.deepcopy(lights)
    sh["camera"] = camera
    sh["rain"] = 0.5
    sh["lines"] = lines
    for k_ in ("dur", "lead", "tail", "min", "fade_in"):
        sh.pop(k_, None)
    if dur is not None:
        sh["dur"] = dur
    else:
        sh["lead"], sh["tail"], sh["min"] = lead, tail, 1.6
    c = car(sh, "kit")
    c["paint"] = "lot47_dew"               # dew on the paint at first light (its gloss mirrored the sky: a silver car)
    c["glow"] = 0.0                        # (parked all night: no underglow)
    c.pop("finish", None)
    for k_ in ("wet_seat", "rain_glass"):
        c.pop(k_, None)
    if window is None:
        c.pop("windows_down", None)
    else:
        c["windows_down"] = list(window) if isinstance(window, tuple) else window
    d = person(sh, "dee")
    if d:
        d.update(copy.deepcopy(DEE_LOOK))
        d.pop("shapes", None)
        if sid not in ("arch", "knock_ins", "knock"):
            lean_out(d)
    return sh


def lean_out(d):
    """Dee's lean on the door's top a little shallower (her head was a kiss away from Kit's), the same in
    every shot from the two-shot on; her thighs turned back as far, so her feet stay put."""
    for b in d.get("bend", []):
        if b.get("Hips", [0])[0] >= 36:
            b["Hips"] = [30] + list(b["Hips"])[1:]
            for leg in ("LeftUpperLeg", "RightUpperLeg"):
                if leg in b:
                    b[leg] = [b[leg][0] + 8] + list(b[leg])[1:]
            if "Head" in b:
                b["Head"] = [max(b["Head"][0], -16)] + list(b["Head"])[1:]


def kit(sh, gaze, face, looks=None, bend=None):
    k = person(sh, "kit_driver")
    k["gaze"], k["shapes"] = gaze, face
    if bend is not None:
        k["bend"] = copy.deepcopy(bend)
    if looks:
        k["looks"] = looks
    else:
        k.pop("looks", None)
    return k


def cam(pos0, pos1, look, fov, handheld=0.08, **key):
    k0 = dict({"u": 0, "pos": pos0, "look": look, "fov": fov}, **key)
    k1 = {"u": 1, "pos": pos1, "look": look, "fov": fov}
    for k_ in ("look_by", "eye_light"):
        if k_ in key:
            k1[k_] = key[k_]
    return {"follow": "kit", "ease": "inout", "handheld": handheld, "keys": [k0, k1]}


# the arch: from the painted number and a strip of dawn over the viaduct down to the whole car, Dee
# crossing to it from her door's pool of light
sh = kshot("arch", OUTSIDE, {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-9.0, 6.5, -7.5], "look": [4.5, 7.0, 0.5], "fov": 42},
    {"u": 0.45, "pos": [-7.0, 3.6, -6.6], "look": [3.8, 3.2, 0.5], "fov": 40},
    {"u": 1.0, "pos": [-4.6, 1.2, -5.4], "look": [2.6, 1.0, 0.4], "fov": 38}]}, [], dur=3.8, window=None)
sh["fade_in"] = 0.6
sh["props"][0]["train"] = [-3.2, 24.0]
sh["lights"][3] = dict(ARCH_RIM, pos=[3.4, 2.9, -0.8], look=[2.6, 0.0, -0.1], energy=3.0, angle=60.0)
person(sh, "dee").update({"pos": [5.9, 0.0, 0.9], "path": [[1.6, 0.15]], "walk_at": -0.6, "rate": 1.1})
# (from her door, hurrying in the rain, mid-stride on the first frame: at the car as the cut lands)

# the knock from outside: her knuckles on the beaded glass in the right foreground, Kit asleep behind it
sh = kshot("knock_ins", OUTSIDE + [omni([0.3, 1.2, 0.4], "#8fa3c2", 0.3, 1.0)],
           cam([1.95, 1.2, 0.95], [1.93, 1.2, 0.9], [0.75, 1.1, 0.0], 34, 0.06, dof=[2.5, 1.0, 0.1]), [], dur=1.2,
           window={"driver": [9.0, 10.0]})       # (the glass its own wound piece, still up)
car(sh, "kit")["rain_glass"] = 1.0
for r in person(sh, "dee")["reach"]:
    if "RightHand" in r and r["RightHand"].get("fist", 0) >= 0.85:
        r["RightHand"]["fist"] = 1.0       # a closed fist (at 0.85 it read as a limp paw)

# the knock: low, looking up, her face in the glass over Kit asleep; the glass goes down on her line
sh = kshot("knock", OUTSIDE + [WINDOW], cam([-0.32, 0.94, 0.36], [-0.31, 0.94, 0.33], [0.88, 1.25, 0.08], 34,
                                             dof_near=[0.45, 0.2, 0.1]),        # (clear of the mirror and the visor)
           [say("Kit. Kit! Open up.", "c01_close_001", "Dee", 1.6)], dur=KNOCK_DUR, window={"driver": GLASS_DOWN})
sh["lead"], sh["tail"] = 0.9, 0.3
car(sh, "kit")["rain_glass"] = 1.0
for r in person(sh, "dee")["reach"]:
    if "RightHand" in r and r["RightHand"].get("fist", 0) >= 0.85:
        r["RightHand"]["fist"] = 1.0

# the two-shot, third: where everyone is (Dee at the window, Kit looking up at her), Kit's first line
sh = kshot("two_shot", OUTSIDE + [WINDOW], cam([2.55, 1.62, 1.05], [2.4, 1.58, 0.9], [0.45, 1.1, -0.1], 30, 0.1,
                                                dof_near=[1.0, 0.5, 0.12]),
           [say("What... what time is it?", "c01_close_002", "Kit", 2.2)],
           window={"driver": [GLASS_DOWN[0] - KNOCK_DUR, GLASS_DOWN[1] - KNOCK_DUR]})   # (the glass going on down over the cut)
kit(sh, "dee", KIT_SLEEPY, bend=TO_DEE)

# Dee's profile from ahead of her, outside: the arch's lamp an edge on her hair, the street behind
sh = kshot("knock_two", OUTSIDE, cam([0.98, 1.3, 1.35], [0.98, 1.3, 1.3], "dee", 28, look_by=[0.0, -0.03, 0.0],
                                     dof=[1.8, 1.0, 0.12]),
           [say("Gone six. You slept in it.", "c01_close_003", "Dee", 2.2)])
person(sh, "dee")["shapes"] = [{"t": 0.0}, {"t": 0.9, **TEASE}]

# Kit three-quarter from the dash (her eyes off the lens): defensive, a look away down the road
sh = kshot("kit_two", [WINDOW] + OUTSIDE, cam([0.52, 1.1, 0.6], [0.51, 1.1, 0.57], "kit_driver", 34, 0.06,
                                              look_by=[0.0, 0.0, 0.0], eye_light=0.03, dof=[1.2, 0.6, 0.1]),
           [say("I wasn't sleeping. I was driving.", "c01_close_004", "Kit", 2.4)])
kit(sh, "dee", KIT_DEFENSIVE, looks=[[0.55, 1.7, "road"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]}])

# over Dee's shoulder from outside: Kit through the open window, Dee's hair soft at the edge
sh = kshot("kit_wake", OUTSIDE + [WINDOW], cam([1.8, 1.42, 0.75], [1.76, 1.41, 0.72], [0.38, 1.12, -0.1], 30,
                                                dof_near=[0.7, 0.3, 0.14]),
           [say("There was a white car right behind me.", "c01_close_004b", "Kit", 2.6)])
kit(sh, "dee", dict(KIT_DEFENSIVE, browInnerUp=0.45), bend=TO_DEE)

# Dee from inside, low (the roof's rail over her head), the arch soft behind her
def cam_dee_in(fov, x=-0.1, z=0.46):
    return cam([x, 1.0, z], [x + 0.02, 1.0, z - 0.03], "dee", fov, look_by=[0.0, -0.03, 0.0], dof=[1.8, 0.8, 0.15])


sh = kshot("knock_dee2", OUTSIDE + [WINDOW], cam_dee_in(32), [say("You were drooling on the wheel.", "c01_close_005", "Dee", 2.2)])
person(sh, "dee")["shapes"] = [{"t": 0.0, **TEASE}]

# the scare line: Kit close, the camera easing in, her eyes going to the back seat; the window's light
# falls away off her face
sh = kshot("knock_kit2", [omni([0.85, 1.30, 0.25], "#b8c8e4", [[0, 0.35], [0.9, 0.12]], 1.3)] + OUTSIDE,
           cam([0.52, 1.1, 0.62], [0.49, 1.1, 0.54], "kit_driver", 26, 0.06, look_by=[0.0, 0.0, 0.0], eye_light=0.02,
               dof=[1.0, 0.5, 0.1]),
           [say("There was someone in the back.", "c01_close_006", "Kit", 2.3)])
kit(sh, "dee", KIT_AFRAID, looks=[[0.4, 1.8, "rear"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]},
                                                             {"t": 0.45, "Neck": [2, -14, 0], "Head": [2, -24, 0]},
                                                             {"t": 1.7, "Neck": [2, -14, 0], "Head": [2, -24, 0]},
                                                             {"t": 2.1, "Neck": [2, 10, 0], "Head": [4, 16, 0]}])

# the back seat while Dee explains it: the first light through the rear glass raking the cushion, and
# on it the wet patch she names
REAR_LIGHT = [omni([0.0, 1.38, -0.95], "#b4c4e0", 1.2, 1.3),
              spot([-0.12, 1.2, -1.05], [0.02, 0.32, -0.5], "#a9b8d0", 2.5, 35.0, 2.0, id="rear_glass")]   # (its glint off the patch into the lens)
sh = kshot("back_seat", OUTSIDE + REAR_LIGHT, cam([-0.12, 1.22, 0.0], [-0.11, 1.2, -0.06], [0.2, 0.5, -0.95], 40, 0.0,
                                                  dof=[1.6, 0.6, 0.1]),
           [say("There's a parcel shelf back there, and a wet patch.", "c01_close_007", "Dee", 3.0, voice=True)])
car(sh, "kit")["wet_seat"] = True

# Dee wider from inside: her hands on the door's top in the frame, explaining it away
sh = kshot("knock_dee3", OUTSIDE + [WINDOW], cam([-0.3, 0.99, 0.28], [-0.28, 0.99, 0.25], "dee", 36, look_by=[0.0, -0.05, 0.0],
                                                  dof=[1.8, 0.8, 0.15]),
           [say("You need a new door seal, that's all.", "c01_close_007b", "Dee", 2.5)])

# Kit from the passenger's seat, the mirror at the top of the frame: her eyes go up to it
sh = kshot("knock_kit3", [WINDOW] + OUTSIDE, cam([-0.25, 1.12, 0.45], [-0.24, 1.12, 0.42], "kit_driver", 32, 0.06,
                                                 look_by=[0.0, 0.02, 0.0], eye_light=0.02, dof=[1.1, 0.5, 0.1]),
           [say("I saw her in the mirror.", "c01_close_008", "Kit", 2.0)])
kit(sh, "dee", KIT_HAUNTED, looks=[[0.6, 2.4, "mirror"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]},
                                                                {"t": 0.6, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}])

# the mirror at dawn: the back seat in it, the wet patch glinting under the rear glass's light
sh = kshot("mirror_dawn", OUTSIDE + REAR_LIGHT, cam([0.3, 1.17, -0.25], [0.295, 1.168, -0.21], [0.0, 1.115, 0.512], 13, 0.0,
                                                    dof=[0.9, 0.5, 0.15]),
           [say("She was soaking.", "c01_close_008b", "Kit", 1.8, voice=True)])
sh["mirror"] = {"glass": True, "follow": "kit", "exposure": 1.1}
sh["dur"], sh["lead"] = 1.8, 0.0                # (an insert: a close-up's 1.5 s and the line's)
car(sh, "kit")["wet_seat"] = True
kit(sh, "mirror", KIT_HAUNTED, bend=[{"t": 0.0, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}])

# "Old cars...": Dee closer, her eyes dropping to the dash at the end (the pins next)
sh = kshot("knock_dee4", OUTSIDE + [WINDOW], cam_dee_in(28, -0.08, 0.44),
           [say("Old cars give you bad dreams. They've been places.", "c01_close_009", "Dee", 3.0)])
d = person(sh, "dee")
d["looks"] = [[2.5, 4.0, "ahead"]]

# the pins: one lens, a slow move off the screen (no zoom), the number clear of the bars
sh = kshot("pins", [omni([0.0, 0.7, 0.62], "#8f7cff", 0.3, 0.25), omni([0.1, 1.0, 0.4], "#b9a8ff", 0.4, 1.0)],
           cam([0.04, 0.8, 0.53], [0.14, 0.95, 0.33], [0.0, 0.70, 0.65], 22, 0.0),
           [say("Huh. Nine pins.", "c01_close_010", "Dee", voice=True, at=0.6)], dur=2.6)
car(sh, "kit")["pins"] = 0

# the plea from Dee's eyes: Kit looks up into them (the lens)
sh = kshot("knock_kit4", OUTSIDE + [WINDOW], cam([1.45, 1.36, 0.15], [1.43, 1.35, 0.15], [0.38, 1.12, -0.1], 30, 0.05,
                                                  dof=[1.6, 0.6, 0.1]),
           [say("Wipe it. Please.", "c01_close_011", "Kit", 1.8)])
sh["people"] = [p for p in sh["people"] if p["id"] != "dee"]     # (her own eyes: the camera)
kit(sh, "camera", KIT_PLEA, bend=TO_DEE)

# the end: a slow pull back that keeps the car, Dee and her lit arch, the number coming into the top
sh = kshot("knock_end", OUTSIDE + [WINDOW], {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-3.0, 1.3, 3.6], "look": [1.4, 1.2, 0.2], "fov": 40},
    {"u": 1.0, "pos": [-5.6, 2.3, 6.4], "look": [2.4, 4.0, 0.4], "fov": 36}]},
    [say("Not yet. Let's see where they go first.", "c01_close_012", "Dee", set=["seen_nine_pins"])], lead=0.6, tail=1.0)
sh["dur"] = 5.0

json.dump(scene, open(path, "w"), indent="\t")
