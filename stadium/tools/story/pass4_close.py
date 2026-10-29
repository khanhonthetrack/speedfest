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


EYES = [0.37, 1.09, 0.17]                     # Kit's eyes (Lot 47's frame)
HEAD = [0.37, 1.12, 0.12]
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
                spot([0.1, 1.25, -2.2], [0.37, 1.15, 0.1], "#e8eeff", 3.0, 12.0, 4.0, id="beams")] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.2, "keys": keys(
    {"u": 0, "pos": [-0.30, 1.02, 0.35]}, {"u": 1, "pos": [-0.28, 1.02, 0.32]},
    look=[0.37, 1.12, 0.05], fov=35, eye_light=0.04, dof=[0.9, 0.6, 0.1])}
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
                spot([0.2, 1.2, -2.0], HEAD, "#f2f4ff", [[0, 4.0], [1.5, 7.0]], 14.0, 4.0, id="beams")] + white_lamps()
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
sh["lights"] = [DASH, FILL, spot([0.0, 1.13, 0.5], EYES, "#eef2ff", [[0, 0.0], [1.2, 14.0]], 6.0, 1.2, id="slash")] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.3, "keys": [
    {"u": 0, "pos": [0.05, 1.18, 0.42], "look": [0.37, 1.12, 0.0], "fov": 28, "eye_light": 0.0, "exposure": 1.0},
    {"u": 1, "pos": [0.06, 1.18, 0.40], "look": [0.37, 1.12, 0.0], "fov": 28, "eye_light": 0.0, "exposure": 1.4}]}

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
    {"u": 0, "pos": [0.02, 1.14, -0.55]}, {"u": 1, "pos": [0.03, 1.14, -0.51]},
    look=[0.35, 1.0, 4.0], fov=34, dof_near=[0.55, 0.3, 0.12])}
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
                spot([0.3, 1.33, 0.12], [0.37, 1.0, 0.17], "#8fa6c8", 1.0, 40.0, 1.0, id="dome_key"),
                omni([0.0, 1.2, -0.6], GHOST_LIGHT, 0.15, 0.6, id="ghost_light")]
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
                omni([0.05, 1.2, -0.15], GHOST_LIGHT, [[0, 0.0], [0.52, 0.0], [0.55, 0.5]], 0.45, id="ghost_face")]
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
                spot([0.05, 1.18, 0.48], EYES, "#cfe0ff", 3.0, 10.0, 1.0, id="slash")]
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [0.30, 1.125, 0.43]}, {"u": 1, "pos": [0.30, 1.125, 0.42]},
    look="kit_driver", look_by=[0.0, 0.01, 0.0], fov=12, eye_light=0.0)}
person(sh, "kit_driver")["shapes"] = [{"t": 0, "browInnerUp": 0.6}, {"t": 0.12, "browInnerUp": 1.0, "jawOpen": 0.1}]

# --- the look back: the instruments light her from below, the street two stops under her face ------------------
sh = shots["look_back"]
sh["dur"] = 1.3
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.2, 1.0),
                spot([0.35, 0.92, 0.45], [0.37, 1.1, 0.12], "#6fa8ff", 1.0, 35.0, 1.2, id="under")]
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.2, "keys": keys(
    {"u": 0, "pos": [-0.05, 1.08, -0.45]}, {"u": 1, "pos": [-0.04, 1.08, -0.41]},
    look=[0.32, 1.1, 0.05], fov=30, eye_light=0.03, exposure=0.85)}
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
                omni([0.40, 0.88, 0.30], GHOST_LIGHT, 1.0, 0.42),             # Kit's under-light, in front of her
                spot([0.5, 1.3, -0.9], [0.24, 1.1, -0.05], GHOST_LIGHT, 1.5, 20.0, 1.5, id="ghost_rim")]
person(sh, "kit_driver")["looks"] = [[0.0, 0.4, "passenger"]]

# --- the black: cut just after the gasp ---------------------------------------------------------------------------
shots["black"]["dur"] = 1.1

json.dump(scene, open(path, "w"), indent="\t")
