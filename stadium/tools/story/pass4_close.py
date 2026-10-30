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
k["bend"] = [{"t": 0.0, "Neck": [8, 0, -6], "Head": [12, 4, -18]}, {"t": 1.6, "Neck": [8, 0, -6], "Head": [12, 4, -18]},
             {"t": 2.1, "Neck": [3, 0, -3], "Head": [5, 0, -6]}]     # (the fifth pass's 2.1 s)

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

# === the Mirror's fifth pass (its critic on round four's stills: 5.5 and 5.5) ======================
# One light per face, from a source the scene has, and no fill at the lens: the street's sodium
# through the window, the coupe's beams from behind (a rim that grows shot to shot), the mirror's
# slash across the eyes (a spot cut to a band), the dash's blue below; teal only ever the ghost's.
# The city's bounce through the glass down in the cabin (it lit every face flat). The coupe nearer
# every cut (it came and went: 30, 94, 25, 35, 48 m). Her car without its wing in the dream (from
# inside, its bar and struts read as a gate across the road). asleep from outside her window, in the
# car at once; the whiteout burning past white; an empty back seat before the hit; the hit lit on
# the ghost.
EYES5 = [0.372, 1.115, -0.12]                 # (story_lab --probe over the Mirror: she sits 2-3 cm further back)
HEAD5 = [0.372, 1.1, -0.15]
MIRROR_C = [0.0, 1.131, 0.512]
LINING = omni([0.15, 1.3, -0.1], "#2a3560", 0.12, 1.0, id="lining")     # the night off the headlining: blacks held off 0
CABIN = {"gi": 0.35}
MIRROR_SHOTS = ["asleep", "dream_road", "profile", "mirror_far", "coupe_low", "closer", "rear_window", "glare",
                "whiteout", "empty_road", "dark_road", "breath_out", "she_is_there", "eyes", "look_back", "hit"]
for sid in MIRROR_SHOTS:
    sh = shots[sid]
    k_ = car(sh, "kit")
    if k_ is not None:
        k_["tuning"] = "1.7.6.0"              # (spoiler "None")
    sh["env"] = dict(sh.get("env", {}), city_led=0.0)
    if sid not in ("dream_road", "coupe_low"):
        sh["env"].update(CABIN)
for sid, ahead in (("dream_road", -40.0), ("profile", -36.0), ("mirror_far", -32.0), ("coupe_low", -27.0), ("closer", -22.0),
                   ("rear_window", -16.0)):
    w_ = car(shots[sid], "white")
    w_["ahead"] = ahead
    w_["speed"] = 21.5                         # (1.5 m/s on her: the cuts carry the approach, not the shots)
car(shots["glare"], "white")["ahead"] = -11.0
for sid in ("profile", "mirror_far", "closer", "glare", "whiteout"):
    shots[sid]["glass"] = 0.2
for sid in ("breath_out", "she_is_there", "eyes", "look_back", "hit"):
    shots[sid]["glass"] = 0.1                  # (the rain has stopped; the glass is still wet)
shots["breath_out"]["rain"] = 0.0

# asleep: through her rain-beaded window from outside, the street's sodium raking her face
sh = shots["asleep"]
sh["dur"] = 2.1
sh["fade_in"] = 0.5
sh["glass"] = 0.1                 # (the film's rain on the lens: at 0.5 it smeared the whole frame brown)
car(sh, "kit")["rain_glass"] = 1.0    # (the beads on her window itself, between the lens and her)
sh["lights"] = [
    {"kind": "omni", "pos": [-6.0, 5.0, 4.0], "colour": "#ffb36b", "energy": 2.0, "range": 18.0},
    {"kind": "omni", "pos": [4.5, 3.2, 0.5], "colour": "#ffd2a1", "energy": 2.0, "range": 12.0},
    spot([1.6, 2.2, 1.2], HEAD5, "#ffb36b", 3.5, 25.0, 4.0, True, id="window_key"),
    omni([0.37, 0.85, 0.45], "#3fa0ff", 0.3, 0.8), LINING]
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [1.15, 1.08, 0.05]}, {"u": 1, "pos": [1.09, 1.08, 0.04]}, look=[0.37, 1.05, -0.06], fov=30)}

# the dream's road: longer travel, the coupe's lamps down so it has a shape, a cold edge on her roof
sh = shots["dream_road"]
sh["dur"] = 2.0
car(sh, "kit")["glow"] = 0.0
sh["lights"] = sh["lights"][:5] + [spot([-1.8, 2.2, -4.0], [0.0, 1.3, 0.0], "#9fc0ff", 2.5, 30.0, 7.0, id="roof_rim")] + white_lamps(2.5)
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.12, "keys": keys(
    {"u": 0, "pos": [2.6, 0.32, 6.4]}, {"u": 1, "pos": [2.0, 0.32, 4.4]}, look=[-0.3, 0.8, -6.0], fov=28, exposure=0.85)}

# profile: the mirror a soft edge in the corner where her eyes go; a streetlight crossing her face
# midway; the beams arriving on her hair
sh = shots["profile"]
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.25, 1.0), omni([1.0, 0.95, 0.2], "#ff5aa8", 0.15, 1.4), FILL, LINING,
                spot([-0.25, 1.5, -1.9], HEAD5, "#e8eeff", [[0, 0.0], [1.4, 2.5]], 10.0, 4.0, id="beams")] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.15, "keys": keys(
    {"u": 0, "pos": [-0.36, 1.02, 0.62]}, {"u": 1, "pos": [-0.34, 1.02, 0.60]},
    look=[0.33, 1.10, -0.08], fov=28, dof=[0.9, 0.6, 0.1], dof_near=[0.45, 0.2, 0.15], exposure=0.85)}     # (cabin_frame.py: the mirror 5 %, top right)
sh["passing"].update({"phase": -0.15, "energy": 2.0, "shadow": True})

# the mirror far: the glass fills the frame
sh = shots["mirror_far"]
sh["mirror"]["exposure"] = 3.0
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.0, "keys": keys(
    {"u": 0, "pos": [0.28, 1.18, -0.05]}, {"u": 1, "pos": [0.275, 1.178, -0.02]},
    look=MIRROR_SEE, fov=17, dof=[0.9, 0.5, 0.15])}

# the low reverse: her rear quarter a dark soft edge on the right, her tail light red on the road
sh = shots["coupe_low"]
sh["lights"] = [DASH, omni([-0.6, 0.85, -2.2], "#ff2a2a", 3.0, 5.0)] + white_lamps(4.0)
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.1, "keys": keys(
    {"u": 0, "pos": [-1.3, 0.5, -0.6]}, {"u": 1, "pos": [-1.28, 0.5, -0.7]},
    look=[-0.5, 0.95, -60.0], fov=28, dof_near=[1.6, 0.8, 0.15], exposure=0.85)}

# closer: the beams her key, a hard white rim growing round hair, ear and cheek; the front dark
sh = shots["closer"]
sh["dur"] = 1.3
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.2, 1.0), FILL, LINING,
                spot([-0.15, 1.45, -1.7], HEAD5, "#f2f4ff", [[0, 5.0], [1.3, 10.0]], 10.0, 4.0, id="beams")] + white_lamps()
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [-0.22, 1.08, 0.50]}, {"u": 1, "pos": [-0.21, 1.08, 0.47]}, look=[0.37, 1.1, -0.12], fov=30, exposure=0.85)}    # (clear of the mirror)
person(sh, "kit_driver")["looks"] = [[0.15, 0.55, "mirror"], [0.7, 1.3, "rear"]]

# the glimpse: no light on her from the front for its frames (a black head against the glare)
sh = shots["rear_window"]
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", [[0, 0.35], [1.08, 0.35], [1.1, 0.0], [1.26, 0.0], [1.28, 0.35]], 1.0),
                omni([0.0, 0.9, -3.6], "#b01818", 0.5, 9.0),
                omni([-0.3, 0.9, -0.4], "#2a3560", [[0, 0.25], [1.08, 0.25], [1.1, 0.0], [1.26, 0.0], [1.28, 0.25]], 1.6)] + white_lamps(7.0, 6.0)
for sid in ("rear_window", "empty_road"):
    for kk in shots[sid]["camera"]["keys"]:
        kk["pos"][1] = 1.2
        kk["look"] = [-0.03, 1.04, -16.0]

# the glare: over the mirror's back (a dark edge on the right), its slash a band across her eyes;
# she turns into it and screws them shut
sh = shots["glare"]
sh["lights"] = [DASH, FILL, LINING,
                spot(MIRROR_C, EYES5, "#eef2ff", [[0, 0.0], [0.4, 0.5], [1.2, 4.0]], 8.0, 1.2, band=0.25, id="slash")] + white_lamps(10.0)
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.2, "keys": keys(
    {"u": 0, "pos": [-0.25, 1.16, 0.575]}, {"u": 1, "pos": [-0.245, 1.16, 0.565]},
    look=[0.30, 1.11, -0.08], fov=22, dof_near=[0.4, 0.2, 0.2], exposure=1.0)}
k = person(sh, "kit_driver")
k["looks"] = [[0.5, 1.2, "mirror"]]
k["shapes"] = [{"t": 0}, {"t": 0.8}, {"t": 0.95, "eyeSquintLeft": 0.8, "eyeSquintRight": 0.8, "browDownLeft": 0.4,
                                        "browDownRight": 0.4}]
k["bend"] = [{"t": 0}, {"t": 0.5}, {"t": 0.8, "Neck": [0, -10, 0], "Head": [-4, -18, 0]}]    # (into the glass: the clip
# had her head turned the other way, eyes straining across)

# the whiteout: the coupe's nose in the glass, then the glass burning past white into the glow and
# the light spilling out of it over the housing and the visors
sh = shots["whiteout"]
car(sh, "white")["ahead"] = -5.0
sh["mirror"]["exposure"] = [[0, 1.6], [0.45, 1.6], [0.75, 8.0]]
sh["mirror"]["boost"] = [[0, 1.0], [0.45, 1.0], [0.75, 4.0]]
sh["env"].update({"glow": 1.0, "bloom": 0.3})
sh["lights"] = sh["lights"][:3] + [omni([0.0, 1.13, 0.45], "#e8eeff", [[0, 0.0], [0.4, 0.0], [0.72, 6.0]], 1.2, id="spill")] + sh["lights"][3:]
for kk in sh["camera"]["keys"]:
    kk["fov"] = 16

# the road empty: the tail light's red on the wet road, a little haze, the shelf not a void
sh = shots["empty_road"]
sh["env"]["fog"] = 0.008
sh["lights"] = [DASH, FILL, omni([0.0, 0.9, -3.6], "#ff2a2a", 1.2, 6.0), omni([0.0, 1.4, -1.6], "#ffb36b", 0.15, 1.5),
                omni([-0.5, 5.0, -18.0], "#ffb36b", 6.0, 14.0, True)]

# a dark road: the ghost's eye height, creeping towards her headrest; a cold edge on Kit's head;
# the mirror's housing just showing (a mirror with nothing in it)
sh = shots["dark_road"]
sh["lights"] = [omni([0.3, 0.95, 0.5], "#6fa8ff", 0.6, 1.0), FILL, omni([0.0, 0.9, -3.6], "#ff2a2a", 0.3, 9.0),
                spot([0.9, 1.35, 0.3], HEAD5, "#9fb8ff", 1.2, 25.0, 2.0, id="kit_rim"), omni([0.0, 1.2, 0.4], "#6fa8ff", 0.1, 0.5)]
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.08, "keys": keys(
    {"u": 0, "pos": [-0.05, 1.05, -0.80]}, {"u": 1, "pos": [-0.05, 1.05, -0.62]},
    look=[0.7, 1.0, 4.0], fov=34, dof_near=[0.6, 0.3, 0.12])}

# the false calm: 0.3 s shorter; keyed from her side window (not the dome: a hard edge under the
# chin), the wheel's rim soft in front; teal arrives with her
sh = shots["breath_out"]
sh["dur"] = 2.3
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [0.11, 0.98, 0.80]}, {"u": 1, "pos": [0.12, 0.98, 0.70]},
    look=[0.2, 1.05, -0.12], fov=32, dof=[1.0, 0.4, 0.1], exposure=0.8)}
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.2, 1.0), LINING,
                spot([0.9, 1.3, 0.1], HEAD5, "#8fa6c8", 1.0, 30.0, 1.6, id="side_key"),
                omni([-0.25, 1.35, -0.9], GHOST_LIGHT, [[0, 0.0], [1.95, 0.0], [2.05, 0.4]], 0.7, id="ghost_light")]
k = person(sh, "kit_driver")
k["breathe"] = [1.4, 2.2]
k["bend"] = [{"t": 0}, {"t": 0.25, "Spine": [10, 0, 0], "Chest": [12, 0, 0]},
             {"t": 0.9, "Spine": [8, 0, 0], "Chest": [10, 0, 0], "Head": [-6, 0, 0]},
             {"t": 1.95, "Spine": [8, 0, 0], "Chest": [10, 0, 0], "Head": [-6, 0, 0]},
             {"t": 2.15, "Spine": [2, 0, 0], "Neck": [0, -6, 0], "Head": [-5, -12, 0]}]
k["shapes"] = [{"t": 0, "browInnerUp": 0.35}, {"t": 0.8, "eyeBlinkLeft": 1, "eyeBlinkRight": 1, "browInnerUp": 0.1},
               {"t": 1.95, "eyeBlinkLeft": 1, "eyeBlinkRight": 1}, {"t": 2.02, "eyeBlinkLeft": 0, "eyeBlinkRight": 0, "browInnerUp": 0.6}]
k["looks"] = [[2.0, 2.3, "mirror"]]
g = person(sh, "passenger")
g["from"] = 2.0
g["lift"] = [[2.0, -0.45], [2.25, 0.0]]
g["bend"] = [{"t": 2.0, "Neck": [15, 0, 0], "Head": [25, 0, 0]}, {"t": 2.3, "Neck": [-2, 0, 0], "Head": [12, 0, 10]}]
g["reach"] = [{"t": 2.1}, {"t": 2.25, "LeftHand": copy.deepcopy(g["reach"][-1]["LeftHand"])}]
sh["sounds"] = [{"at": 0.2, "cue": "breath", "db": -6}, {"at": 1.2, "cue": "drip", "db": -14}, {"at": 2.0, "cue": "creak", "db": -10}]

# she is there: her light low and in front of her (above her head it made a teal wig of her hair)
sh = shots["she_is_there"]
sh["grade"] = dict(INSERT, lift=0.03)
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.35, 1.0),
                omni([0.0, 0.95, -0.12], GHOST_LIGHT, [[0, 0.0], [0.52, 0.0], [0.55, 0.35]], 0.45, id="ghost_face")]
for kk in sh["camera"]["keys"]:
    kk["fov"] = 15
    kk["look"] = [0.0, 1.125, 0.512]

# her eyes: brow to nose, the mirror's band across them, the rest black; a dart into the glass
sh = shots["eyes"]
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.15, 1.0),
                spot(MIRROR_C, EYES5, "#cfe0ff", 2.5, 6.0, 1.2, band=0.25, id="slash"),
                spot([-0.2, 1.3, -0.7], HEAD5, GHOST_LIGHT, 0.2, 20.0, 1.5, id="ghost_edge")]
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": keys(
    {"u": 0, "pos": [0.30, 1.125, 0.43]}, {"u": 1, "pos": [0.30, 1.125, 0.42]},
    look="kit_driver", look_by=[0.0, -0.03, 0.0], fov=10, exposure=0.7)}
k = person(sh, "kit_driver")
k["looks"] = [[0.0, 0.1, "ahead"], [0.1, 0.6, "mirror"]]
k["shapes"] = [{"t": 0, "browInnerUp": 0.7}, {"t": 0.12, "browInnerUp": 1.0, "jawOpen": 0.1}]

# the look back: shorter (the turn into the lens), lit cold from the seat she looks at
sh = shots["look_back"]
sh["dur"] = 0.8
sh["lights"] = [omni([-0.02, 0.95, -0.35], GHOST_LIGHT, 0.6, 1.0, id="seat_cold"), LINING,
                spot([0.35, 0.92, 0.45], HEAD5, "#6fa8ff", 1.0, 35.0, 1.2, id="under")]
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.2, "keys": keys(
    {"u": 0, "pos": [-0.05, 1.08, -0.45]}, {"u": 1, "pos": [-0.045, 1.08, -0.43]}, look=[0.37, 1.1, -0.1], fov=30, exposure=0.7)}
k = person(sh, "kit_driver")
k["bend"] = [{"t": 0, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}, dict(TURN, t=0.3), dict(TURN, t=0.8)]
k["looks"] = [[0.1, 0.35, "rear"], [0.35, 0.8, "camera"]]
sh["sounds"] = [{"at": 0.5, "cue": "breath", "db": -10}]

# the empty seat: what she sees (nothing), from her head; then the hit
if "empty_seat" not in shots:
    shots["empty_seat"] = dict(copy.deepcopy(shots["look_back"]), id="empty_seat")
    _i = [x["id"] for x in scene["shots"]].index("look_back")
    scene["shots"].insert(_i + 1, shots["empty_seat"])
sh = shots["empty_seat"]
sh["dur"] = 0.6
sh["people"] = []
car(sh, "kit")["tuning"] = "1.7.6.0"
sh["env"] = dict(sh.get("env", {}), city_led=0.0, **CABIN)
sh["lights"] = [omni([0.0, 1.0, 0.2], "#6fa8ff", 0.3, 1.5), LINING,
                omni([0.0, 0.95, -0.7], "#8fa6c8", 0.45, 1.0, id="bench_cold")]     # (the bench in the dark: m8 saw black)
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.3, "keys": keys(
    {"u": 0, "pos": [0.30, 1.12, -0.05], "look": [-0.10, 0.85, -0.60]}, {"u": 1, "pos": [0.28, 1.12, -0.07], "look": [-0.05, 0.85, -0.62]},
    fov=30, exposure=1.0)}
sh["sounds"] = [{"at": 0.25, "cue": "breath", "db": -13, "pitch": 1.35}]

# the hit: the ghost beside Kit's head (not behind it), lit from below as the brightest face, in
# focus; Kit half lit and soft in front
sh = shots["hit"]
g = person(sh, "passenger")
g["pos"] = [0.14, 0.0, -0.42]
GHOST_EYES = [0.04, 1.18, -0.26]              # (story_lab --probe: her lean carries her face in over the console)
sh["lights"] = [omni([0.32, 0.93, 0.55], "#6fa8ff", 0.35, 1.0),
                spot([0.1, 0.85, -0.05], GHOST_EYES, GHOST_LIGHT, 2.0, 30.0, 1.2, id="ghost_under"),
                spot([0.5, 1.3, -0.9], GHOST_EYES, GHOST_LIGHT, 1.5, 20.0, 1.5, id="ghost_rim")]
# Kit flinches round towards her (she turned away to the door when the ghost was behind her head)
person(sh, "kit_driver")["bend"] = [{"t": 0}, {"t": 0.08, "Chest": [-4, -4, 0], "Neck": [0, -15, 0], "Head": [-3, -22, 0]}]
sh["camera"]["keys"][0]["dof"] = [1.35, 0.3, 0.1]
sh["camera"]["keys"][0]["dof_near"] = [0.9, 0.15, 0.08]
sh["camera"]["keys"][2]["exposure"] = 0.85

# --- the fifth pass, round two (m8's critic: 5.0, asleep unreadable): keys from the threat, not the lens;
# the whiteout climbing from the coupe's grille; the empty places lit; sizes stepping up ----------------
for sid in MIRROR_SHOTS + ["empty_seat"]:      # (each shot's lights its own: DASH, FILL, LINING are shared dicts)
    shots[sid]["lights"] = copy.deepcopy(shots[sid]["lights"])
sh = shots["asleep"]
sh["dur"] = 1.8
person(sh, "kit_driver")["bend"] = [{"t": 0.0, "Neck": [8, 0, -6], "Head": [12, 4, -18]}, {"t": 1.3, "Neck": [8, 0, -6], "Head": [12, 4, -18]},
                                    {"t": 1.8, "Neck": [3, 0, -3], "Head": [5, 0, -6]}]     # (the head's lift inside 1.8 s)
for l in sh["lights"]:
    if l.get("id") == "window_key":
        l.update({"pos": [1.25, 2.5, -0.5], "look": [0.37, 1.1, -0.06], "energy": 2.0})     # (from above and behind: 3:1)
    elif l.get("pos") == [4.5, 3.2, 0.5]:
        l["energy"] = 0.7                     # (it bloomed into the lens)
sh = shots["dream_road"]
sh["lights"] = sh["lights"][:6] + white_lamps(1.5)
for kk, p_ in zip(sh["camera"]["keys"], ([2.2, 0.45, 5.6], [1.7, 0.45, 4.0])):
    kk["pos"] = p_
sh = shots["profile"]
for l in sh["lights"]:
    if l.get("id") == "beams":
        l["energy"] = [[0, 1.2], [1.4, 2.5]]
    elif l.get("pos") == [0.32, 0.93, 0.55]:
        l["energy"] = 0.1
for kk, p_ in zip(sh["camera"]["keys"], ([-0.43, 1.0, 0.68], [-0.41, 1.0, 0.66])):
    kk["pos"] = p_
person(sh, "kit_driver")["bend"] = [{"t": 0.0}, {"t": 0.3}, {"t": 0.6, "Neck": [0, -6, 0], "Head": [0, -10, 0]}]
sh = shots["mirror_far"]
sh["mirror"]["exposure"] = 2.2
for kk in sh["camera"]["keys"]:
    kk["fov"] = 15
sh = shots["coupe_low"]
sh["lights"] = [DASH, omni([-0.6, 0.85, -2.2], "#ff2a2a", 3.0, 5.0)] + white_lamps(2.0)
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.1, "keys": keys(
    {"u": 0, "pos": [-1.6, 0.6, -0.4]}, {"u": 1, "pos": [-1.58, 0.6, -0.5]},
    look=[-0.2, 0.8, -12.0], fov=30, dof_near=[1.5, 0.8, 0.15], exposure=0.75)}   # (her rear quarter the right quarter)
sh = shots["closer"]
sh["lights"] = [dict(l, energy=0.08) if l.get("pos") in ([0.32, 0.93, 0.55], [-0.3, 0.9, -0.4]) else l for l in sh["lights"]]
for kk in sh["camera"]["keys"]:
    kk["fov"] = 24                            # (a step in from profile, not the same size again)
person(sh, "kit_driver")["bend"] = [{"t": 0.0}, {"t": 0.6}, {"t": 0.8, "Neck": [0, -12, 0], "Head": [0, -22, 0]}]
sh = shots["rear_window"]
sh["lights"].append(omni([-0.05, 1.0, -0.55], GHOST_LIGHT, [[0, 0.0], [1.09, 0.0], [1.1, 0.15], [1.26, 0.15], [1.27, 0.0]], 0.6,
                         id="glimpse_face"))
person(sh, "passenger")["pos"] = [-0.18, -0.06, -0.40]
for kk in sh["camera"]["keys"]:
    if kk.get("t") == 1.18:
        kk["exposure"] = 1.1
sh = shots["glare"]
for kk in sh["camera"]["keys"]:
    kk["fov"] = 18
for kk, p_ in zip(sh["camera"]["keys"], ([-0.28, 1.16, 0.61], [-0.275, 1.16, 0.60])):
    kk["pos"] = p_
for l in sh["lights"]:
    if l.get("id") == "slash":
        l["energy"] = [[0, 0.0], [0.4, 0.5], [1.2, 3.0]]
sh["lights"].append(omni([0.9, 1.3, -0.35], "#6fa8ff", 0.15, 0.9, id="hair_rim"))
sh = shots["whiteout"]
sh["mirror"]["exposure"] = [[0, 0.7], [0.45, 1.2], [0.75, 8.0]]      # (the grille and two lamps first, then the burn)
sh["mirror"]["boost"] = [[0, 1.0], [0.5, 1.5], [0.75, 4.0]]
for l in sh["lights"]:
    if l.get("car") == "white" and l.get("colour") == "#f2f4ff":
        l["energy"] = [[0, 3.0], [0.45, 8.0], [0.7, 30.0]]
sh = shots["empty_road"]
for l in sh["lights"]:
    if l.get("pos") == [-0.5, 5.0, -18.0]:
        l["energy"] = 10.0
    elif l.get("pos") == [0.0, 0.9, -3.6]:
        l["energy"] = 0.5
sh["lights"].append(omni([1.5, 5.0, -34.0], "#ffb36b", 8.0, 14.0, id="far_pool"))
for kk in sh["camera"]["keys"]:
    kk["exposure"] = 1.0
sh = shots["dark_road"]
for kk, p_ in zip(sh["camera"]["keys"], ([0.05, 1.08, -0.72], [0.05, 1.08, -0.56])):
    kk["pos"] = p_
    kk["look"] = [0.55, 1.0, 4.0]
for l in sh["lights"]:
    if l.get("id") == "kit_rim":
        l.update({"look": [0.37, 0.95, 0.35], "energy": 0.9})        # (onto the wheel's rim and her hand)
sh = shots["breath_out"]
for l in sh["lights"]:
    if l.get("id") == "side_key":
        l.update({"pos": [1.0, 1.35, -0.2], "energy": 2.0})
    elif l.get("pos") == [0.32, 0.93, 0.55]:
        l["energy"] = 0.1
sh = shots["she_is_there"]
for kk in sh["camera"]["keys"]:
    kk["fov"] = 11
for l in sh["lights"]:
    if l.get("id") == "ghost_face":
        l["pos"] = [0.0, 0.8, -0.2]           # (lower: the crown dark, the face and hand lit from under)
sh = shots["eyes"]
for kk in sh["camera"]["keys"]:
    kk["pos"][1] = 1.14
    kk["look_by"] = [0.0, 0.005, 0.0]
sh = shots["look_back"]
for l in sh["lights"]:
    if l.get("id") == "under":
        l.update({"pos": [0.6, 1.0, 0.1], "energy": 0.3})
for kk, p_ in zip(sh["camera"]["keys"], ([-0.11, 1.08, -0.43], [-0.105, 1.08, -0.41])):
    kk["pos"] = p_
sh = shots["empty_seat"]
car(sh, "kit")["wet_seat"] = True           # (where she sat: wet, as Dee finds it at dawn)
sh["lights"] = [l for l in sh["lights"] if l.get("id") not in ("slash_seat", "seat_teal")] + [
    spot([-0.9, 1.4, -0.8], [-0.1, 0.6, -0.6], "#9fb8ff", 2.0, 30.0, 2.0, id="slash_seat"),
    omni([-0.05, 0.75, -0.6], GHOST_LIGHT, 0.15, 0.5, id="seat_teal")]
for kk, p_ in zip(sh["camera"]["keys"], ([0.22, 1.12, -0.08], [0.21, 1.12, -0.10])):
    kk["pos"] = p_
    kk["look"] = [-0.1, 0.75, -0.65]
sh = shots["hit"]
person(sh, "passenger")["pos"] = [0.10, 0.0, -0.42]
person(sh, "kit_driver")["bend"] = [{"t": 0}, {"t": 0.04, "Chest": [-4, -4, 0], "Neck": [0, -15, 0], "Head": [-3, -22, 0]}]
sh["lights"].append(omni([0.15, 0.9, -0.1], GHOST_LIGHT, 0.3, 0.6, id="teal_on_kit"))

# --- round two, the second critic (5.0): the blacks held off zero inside; the glare from the mirror's own
# side, frontal, its band across the eyes, and closer previewing it; the glimpse a human outline rimmed
# by the beams; the look back keyed teal from the seat's side -------------------------------------------
for sid in ("profile", "closer", "glare", "dark_road", "breath_out", "eyes", "look_back", "empty_seat", "hit", "rear_window",
            "empty_road"):
    shots[sid].pop("grade", None)             # (re-placed at the end: the file the same however often it runs)
    shots[sid]["grade"] = {"preset": "night", "lift": 0.03}
for sid in ("mirror_far", "she_is_there"):
    shots[sid].pop("grade", None)
    shots[sid]["grade"] = dict(INSERT, lift=0.03)
sh = shots["dream_road"]
for l in sh["lights"]:
    if l.get("kind") == "spot" and l.get("pos") in ([0.6, 0.65, 2.3], [-0.6, 0.65, 2.3]):
        l["energy"] = 1.2                     # (her own lamps flared into the lens)
sh = shots["mirror_far"]
for kk in sh["camera"]["keys"]:
    kk["fov"] = 14
sh["lights"] = [l for l in sh["lights"] if l.get("id") != "housing_edge"] + [
    spot([0.15, 1.35, 0.80], [0.0, 1.17, 0.52], "#9fb8ff", 0.6, 25.0, 1.0, id="housing_edge")]
sh = shots["closer"]
sh["passing"]["phase"] = 0.05                 # (its peak across her face at 0.6 s)
sh["lights"] = [l for l in sh["lights"] if l.get("id") != "slash_early"] + [
    spot(MIRROR_C, EYES5, "#f2f4ff", [[0, 0.0], [0.4, 0.0], [1.0, 1.5]], 6.0, 1.2, band=0.25, id="slash_early")]
sh = shots["glare"]
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.2, "keys": keys(
    {"u": 0, "pos": [0.04, 1.12, 0.43]}, {"u": 1, "pos": [0.045, 1.12, 0.42]},
    look=[0.37, 1.11, -0.08], fov=26, exposure=1.0)}   # (from the mirror's side: her face into the band, frontal)
sh = shots["rear_window"]
person(sh, "passenger")["pos"] = [-0.20, -0.08, -0.43]
sh["lights"] = [l for l in sh["lights"] if l.get("id") != "glimpse_rim"] + [
    spot([0.3, 1.4, -1.8], [-0.2, 1.05, -0.43], "#f2f4ff", [[0, 0.0], [1.09, 0.0], [1.1, 3.0], [1.26, 3.0], [1.27, 0.0]], 20.0, 2.5,
         id="glimpse_rim")]
for l in sh["lights"]:
    if l.get("pos") == [0.0, 0.9, -3.6]:
        l["energy"] = 0.3
sh = shots["empty_road"]
sh["flash"] = [[0.0, 0.25]]
sh = shots["dark_road"]
sh["lights"] = [l for l in sh["lights"] if l.get("id") != "console"] + [omni([-0.2, 0.95, 0.6], "#9fb8ff", 0.3, 0.8, id="console")]
sh = shots["breath_out"]
for l in sh["lights"]:
    if l.get("id") == "ghost_light":
        l.update({"pos": [-0.2, 1.0, -0.7], "energy": [[0, 0.0], [1.95, 0.0], [2.05, 0.6]]})    # (a glint in her eye)
sh = shots["she_is_there"]
sh["mirror"]["exposure"] = 2.0
for l in sh["lights"]:
    if l.get("id") == "ghost_face":
        l.update({"pos": [0.0, 0.75, -0.2], "energy": [[0, 0.0], [0.52, 0.0], [0.55, 0.28]]})
sh = shots["eyes"]
for kk in sh["camera"]["keys"]:
    kk["pos"][1] = 1.125
    kk["look_by"] = [0.0, -0.009, 0.0]       # (the eyes a little above the middle: +0.01 framed the forehead)
    kk["fov"] = 11
for l in sh["lights"]:
    if l.get("pos") == [0.32, 0.93, 0.55]:
        l["energy"] = 0.05
sh = shots["look_back"]
sh["lights"] = [l for l in sh["lights"] if l.get("id") not in ("seat_cold", "seat_side")] + [
    spot([0.05, 1.35, -0.55], HEAD5, GHOST_LIGHT, 0.8, 30.0, 1.2, id="seat_side")]
for kk, p_ in zip(sh["camera"]["keys"], ([-0.08, 1.03, -0.45], [-0.075, 1.03, -0.43])):
    kk["pos"] = p_
    kk["fov"] = 34
    kk["look"] = [0.37, 1.12, -0.10]
sh = shots["empty_seat"]
for kk in sh["camera"]["keys"]:
    kk["exposure"] = 1.1
sh = shots["hit"]
person(sh, "passenger")["pos"] = [0.08, 0.0, -0.34]

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
               "back_seat", "knock_dee3", "knock_kit3", "mirror_dawn", "knock_dee4", "kit_react", "pins", "knock_kit4",
               "knock_end"]
if "kit_react" not in shots:                 # (a new shot: Kit hearing Dee's "They've been places.")
    shots["kit_react"] = dict(copy.deepcopy(shots["kit_two"]), id="kit_react")
    scene["shots"].append(shots["kit_react"])
_first = [x["id"] for x in scene["shots"]].index("arch")
scene["shots"] = scene["shots"][:_first] + [shots[x] for x in KNOCK_ORDER] + [
    x for x in scene["shots"][_first:] if x["id"] not in KNOCK_ORDER]

DAWN = {"zenith": "#2e3e60", "horizon": "#8c97ad", "cloud_cover": 0.3, "cloud_lo": "#4c5468", "cloud_hi": "#9ca4b6"}   # (the blue hour)
KNOCK_ENV = {"fog": 0.002, "fog_colour": "#6f7f9c", "fog_sky": 0.85, "exposure": 1.35, "sky": DAWN, "city_lit": 0.08,
             "city_led": 0.0}
KNOCK_GRADE = {"preset": "dawn", "shadows_amount": 0.08, "saturation": 0.8}     # (faces went violet in the blue shadows)
SUN = {"kind": "sun", "pos": [-30.0, 9.0, 12.0], "look": [0.0, 0.0, 0.0], "colour": "#a9bcdc", "energy": 0.75, "range": 40.0}
SKY = {"kind": "omni", "pos": [-6.0, 6.0, -4.0], "colour": "#8da2cc", "energy": 3.0, "range": 26.0}
STREET = {"kind": "spot", "pos": [5.5, 2.4, 3.5], "look": [0.5, 1.05, 0.1], "colour": "#8ea2c4", "energy": 0.6, "range": 14.0,
          "angle": 34.0}
ARCH_RIM = {"kind": "spot", "pos": [2.6, 2.7, -0.6], "look": [1.2, 1.05, 0.05], "colour": "#ffb36b", "energy": 2.5, "angle": 40.0,
            "range": 3.5}      # (onto her back and shoulders, falling into the door: aimed at her head it lit the visor cream)
NEXT_DOOR = {"kind": "omni", "pos": [5.2, 2.6, 9.5], "colour": "#ff9a50", "energy": 0.8, "range": 6.0}
WINDOW = omni([0.85, 1.30, 0.25], "#b8c8e4", 0.2, 1.3)           # the morning through Dee's window, on Kit
KIT_KEYS = [spot([0.2, 1.45, 0.75], [0.376, 1.117, -0.096], "#a9bcdc", 0.8, 30.0, 1.6, id="kit_key"),
            spot([-0.2, 1.25, -1.0], [0.376, 1.12, -0.12], "#ffd2a0", 0.4, 25.0, 1.6, id="kit_rim"),
            omni([0.4, 1.42, 0.1], "#6f7c98", 0.1, 0.8, id="headlining")]
DEE_KEY = spot([0.3, 1.55, 0.6], [1.09, 1.29, 0.09], "#b8c8e4", 0.5, 30.0, 2.0, id="dee_key")
OUTSIDE = [SUN, SKY, STREET, ARCH_RIM, NEXT_DOOR]
KNOCK_PROPS = [{"kind": "viaduct", "pos": [5.6, 0.0, 0.5], "yaw": -90.0, "arches": 7, "bulb": 2.2},
               {"kind": "quay", "pos": [0.0, 0.012, 0.0], "rect": [-40.0, -40.0, 5.6, 40.0], "walls": False, "wetness": 0.8},
               {"kind": "warehouse", "pos": [-2.0, 0.0, -24.0], "size": [30.0, 8.0, 12.0], "doors": 3, "lit": [1]}]
DEE_LOOK = {"mouth": 0.35, "tint": {"cloth__male_worksuit01": "#3a4352"}}
TEASE = {"mouthSmileLeft": 0.1, "mouthSmileRight": 0.06}       # (more read as a sneer)
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


def kshot(sid, lights, camera, lines, dur=None, lead=0.2, tail=0.25, window=("driver",), outside=False):
    sh = shots[sid]
    sh["env"] = copy.deepcopy(KNOCK_ENV)
    if outside:
        sh["env"]["exposure"] = 1.55       # (the blue hour opens up outside: the wides read deep night)
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
        if sid != "arch":
            level_gaze(d)         # (the arch takes the insert's Dee whole)
    return sh


def level_gaze(d):
    """Dee's face towards Kit's, not into her lap: leaning on the door, 55 degrees forward from the hips
    up with her head bowed, she looked at Kit with her eyes rolled up under her lids (all whites).
    The neck and head lifted, the chest as it was (straighter, it raised her face over the window's
    top)."""
    for b in d.get("bend", []):
        hips = b.get("Hips", [0])[0]
        if hips < 26:
            continue
        for bone, cap in ((("Neck", -12), ("Head", -30)) if hips >= 30 else (("Neck", -9), ("Head", -18))):
            if bone in b:
                b[bone] = [min(b[bone][0], cap)] + list(b[bone])[1:]


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
    {"u": 1.0, "pos": [-4.6, 1.2, -5.4], "look": [2.6, 1.0, 0.4], "fov": 38}]}, [], dur=3.8, window=None, outside=True)
sh["fade_in"] = 0.6
sh["props"][0]["train"] = [-3.2, 24.0]
sh["lights"][3] = dict(ARCH_RIM, pos=[3.4, 2.9, -0.8], look=[2.6, 0.0, -0.1], energy=3.0, angle=60.0)
person(sh, "dee").update({"pos": [5.9, 0.0, 0.9], "path": [[1.6, 0.15]], "walk_at": -0.6, "rate": 1.1})
# (from her door, hurrying in the rain, mid-stride on the first frame: at the car as the cut lands)

# the knock from outside: her knuckles on the beaded glass in the right foreground, Kit asleep behind it
sh = kshot("knock_ins", OUTSIDE + [omni([0.3, 1.2, 0.4], "#8fa3c2", 0.3, 1.0)],
           cam([1.95, 1.2, 0.95], [1.93, 1.2, 0.9], [0.75, 1.1, 0.0], 34, 0.06, dof=[2.5, 1.0, 0.1]), [], dur=1.2,
           window={"driver": [9.0, 10.0]}, outside=True)       # (the glass its own wound piece, still up)
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
    if "LeftHand" in r and r["LeftHand"]["at"][1] > 1.2:          # (her left hand on the door's top, not the roof)
        r["LeftHand"] = {"at": [0.85, 0.874, 0.32], "palm": [-0.35, -0.94, 0], "fingers": [-0.94, 0.25, 0.25], "fist": 0.25,
                         "elbow": [0.5, -0.6, 0.6]}

# the two-shot, third: where everyone is (Dee at the window, Kit looking up at her), Kit's first line
sh = kshot("two_shot", OUTSIDE + [WINDOW], cam([2.55, 1.62, 1.05], [2.4, 1.58, 0.9], [0.45, 1.1, -0.1], 30, 0.1,
                                                dof_near=[1.0, 0.5, 0.12]),
           [say("What... what time is it?", "c01_close_002", "Kit", 2.2)],
           window={"driver": [GLASS_DOWN[0] - KNOCK_DUR, GLASS_DOWN[1] - KNOCK_DUR]}, outside=True)   # (the glass going on down over the cut)
kit(sh, "dee", KIT_SLEEPY, bend=TO_DEE)

# Dee's profile from ahead of her, outside: the arch's lamp an edge on her hair, the street behind
sh = kshot("knock_two", OUTSIDE, cam([0.98, 1.3, 1.35], [0.98, 1.3, 1.3], "dee", 28, look_by=[0.0, -0.03, 0.0],
                                     dof=[1.8, 1.0, 0.12]),
           [say("Gone six. You slept in it.", "c01_close_003", "Dee", 2.2)], outside=True)
person(sh, "dee")["shapes"] = [{"t": 0.0}, {"t": 0.9, **TEASE}]

# Kit three-quarter from the dash (her eyes off the lens): defensive, a look away down the road
sh = kshot("kit_two", [WINDOW] + OUTSIDE + KIT_KEYS, cam([0.52, 1.1, 0.6], [0.51, 1.1, 0.57], "kit_driver", 34, 0.06,
                                              look_by=[0.0, 0.0, 0.0], eye_light=0.03, dof=[1.2, 0.6, 0.1]),
           [say("I wasn't sleeping. I was driving.", "c01_close_004", "Kit", 2.4)])
kit(sh, "dee", KIT_DEFENSIVE, looks=[[0.55, 1.7, "road"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]}])

# Kit's profile from the passenger's side, Dee listening beyond the window (the cut stays inside)
sh = kshot("kit_wake", OUTSIDE + [WINDOW] + KIT_KEYS, cam([-0.15, 1.12, 0.15], [-0.13, 1.12, 0.13], "kit_driver", 30, 0.06,
                                                          look_by=[0.0, 0.02, 0.0], eye_light=0.02, dof=[1.6, 0.8, 0.1]),
           [say("There was a white car right behind me.", "c01_close_004b", "Kit", 2.6)])
kit(sh, "dee", dict(KIT_DEFENSIVE, browInnerUp=0.45), bend=TO_DEE)

# Dee from inside, low (the roof's rail over her head), the arch soft behind her
def cam_dee_in(fov, x=-0.1, z=0.46):
    return cam([x, 1.0, z], [x + 0.02, 1.0, z - 0.03], "dee", fov, look_by=[0.0, -0.08, 0.0], dof=[1.8, 0.8, 0.15])


sh = kshot("knock_dee2", OUTSIDE + [WINDOW, DEE_KEY], cam_dee_in(32), [say("You were drooling on the wheel.", "c01_close_005", "Dee", 2.2)])
person(sh, "dee")["shapes"] = [{"t": 0.0, **TEASE}]

# the scare line: Kit close, the camera easing in, her eyes going to the back seat; the window's light
# falls away off her face
sh = kshot("knock_kit2", [omni([0.85, 1.30, 0.25], "#b8c8e4", [[0, 0.2], [0.9, 0.08]], 1.3)] + OUTSIDE + KIT_KEYS,
           cam([0.12, 1.06, 0.52], [0.13, 1.07, 0.46], "kit_driver", 28, 0.06, look_by=[0.0, 0.0, 0.0], eye_light=0.02,
               dof=[1.0, 0.5, 0.1]),
           [say("There was someone in the back.", "c01_close_006", "Kit", 2.3)])
kit(sh, "dee", KIT_AFRAID, looks=[[0.4, 1.8, "rear"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]},
                                                             {"t": 0.45, "Neck": [0, -8, 0], "Head": [0, -14, 0]},
                                                             {"t": 1.7, "Neck": [0, -8, 0], "Head": [0, -14, 0]},
                                                             {"t": 2.1, "Neck": [2, 10, 0], "Head": [4, 16, 0]}])
person(sh, "kit_driver")["blink"] = False       # (her eyes open through the look: the turn read as shut eyes)

# the back seat while Dee explains it: the first light through the rear glass raking the cushion, and
# on it the wet patch she names
REAR_LIGHT = [omni([0.0, 1.38, -0.95], "#b4c4e0", 0.9, 1.3),
              spot([-0.07, 1.13, -0.89], [0.02, 0.32, -0.5], "#a9b8d0", 2.5, 30.0, 2.0, id="rear_glass")]   # (its glint off the patch into the lens)
sh = kshot("back_seat", OUTSIDE + REAR_LIGHT, cam([-0.08, 1.2, -0.08], [-0.07, 1.18, -0.13], [0.0, 0.35, -0.55], 36, 0.0,
                                                  dof=[1.4, 0.6, 0.1]),
           [say("There's a parcel shelf back there, and a wet patch.", "c01_close_007", "Dee", 3.0, voice=True)])
car(sh, "kit")["wet_seat"] = True

# Dee wider from inside: her hands on the door's top in the frame, explaining it away
sh = kshot("knock_dee3", OUTSIDE + [WINDOW, DEE_KEY], cam([0.15, 1.2, -0.3], [0.17, 1.2, -0.28], "dee", 30, look_by=[0.0, -0.05, 0.0],
                                                           dof_near=[0.5, 0.2, 0.12]),
           [say("You need a new door seal, that's all.", "c01_close_007b", "Dee", 2.5)])

# Kit from the passenger's seat, the mirror at the top of the frame: her eyes go up to it
sh = kshot("knock_kit3", [WINDOW] + OUTSIDE + KIT_KEYS, cam([-0.25, 1.12, 0.45], [-0.24, 1.12, 0.42], "kit_driver", 32, 0.06,
                                                 look_by=[0.0, 0.02, 0.0], eye_light=0.02, dof=[1.1, 0.5, 0.1]),
           [say("I saw her in the mirror.", "c01_close_008", "Kit", 2.0)])
kit(sh, "dee", KIT_HAUNTED, looks=[[0.6, 2.4, "mirror"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]},
                                                                {"t": 0.6, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}])

# the mirror at dawn: the back seat in it, the wet patch glinting under the rear glass's light
sh = kshot("mirror_dawn", OUTSIDE + REAR_LIGHT, cam([0.3, 1.17, -0.25], [0.295, 1.168, -0.21], [0.0, 1.115, 0.512], 13, 0.0,
                                                    dof=[0.9, 0.5, 0.15]),
           [say("She was soaking.", "c01_close_008b", "Kit", 1.8, voice=True)])
sh["mirror"] = {"glass": True, "follow": "kit", "exposure": 0.9}
sh["dur"], sh["lead"] = 1.8, 0.0                # (an insert: a close-up's 1.5 s and the line's)
car(sh, "kit")["wet_seat"] = True
kit(sh, "mirror", KIT_HAUNTED, bend=[{"t": 0.0, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}])

# "Old cars...": Dee closer, her eyes dropping to the dash at the end (the pins next)
sh = kshot("knock_dee4", OUTSIDE + [WINDOW, DEE_KEY], cam([-0.08, 1.0, 0.44], [-0.04, 1.0, 0.38], "dee", 22, look_by=[0.0, -0.06, 0.0],
                                                           dof=[1.8, 0.8, 0.15]),
           [say("Old cars give you bad dreams.", "c01_close_009", "Dee", 1.9)])
# Kit hears the rest: her eyes going down to the dash (the pins next); Dee as she is in kit_two (the
# shot was copied from it once: nothing else re-spells her here)
shots["kit_react"]["people"] = [p for p in shots["kit_react"]["people"] if p["id"] != "dee"] + [
    copy.deepcopy(person(shots["kit_two"], "dee"))]
sh = kshot("kit_react", [WINDOW] + OUTSIDE + KIT_KEYS, cam([0.5, 1.1, 0.58], [0.49, 1.1, 0.55], "kit_driver", 24, 0.04,
                                                         look_by=[0.0, 0.0, 0.0], eye_light=0.02, dof=[1.1, 0.5, 0.1]),
           [say("They've been places.", "c01_close_009b", "Dee", 1.5, voice=True)], dur=1.8)
sh["lead"] = 0.1
kit(sh, "dee", KIT_HAUNTED, looks=[[0.9, 1.8, "ahead"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]},
                                                               {"t": 1.0, "Neck": [8, 4, 0], "Head": [10, 6, 0]}])

# the pins: one lens, a slow move off the screen (no zoom), the number clear of the bars
sh = kshot("pins", [omni([0.0, 0.7, 0.62], "#8f7cff", 0.3, 0.25), omni([0.1, 1.0, 0.4], "#b9a8ff", 0.4, 1.0)],
           cam([0.14, 0.97, 0.3], [0.07, 0.86, 0.47], [0.0, 0.70, 0.65], 26, 0.0),
           [say("Huh. Nine pins.", "c01_close_010", "Dee", voice=True, at=0.6)], dur=2.6)
car(sh, "kit")["pins"] = 0

# the plea from Dee's eyes: Kit looks up into them (the lens)
sh = kshot("knock_kit4", OUTSIDE + [WINDOW], cam([1.45, 1.36, 0.15], [1.43, 1.35, 0.15], [0.38, 1.12, -0.1], 30, 0.05,
                                                  dof=[1.6, 0.6, 0.1]),
           [say("Wipe it. Please.", "c01_close_011", "Kit", 1.8)], outside=True)
sh["people"] = [p for p in sh["people"] if p["id"] != "dee"]     # (her own eyes: the camera)
kit(sh, "camera", KIT_PLEA, bend=TO_DEE)

# the end: a slow pull back that keeps the car, Dee and her lit arch, the number coming into the top
sh = kshot("knock_end", OUTSIDE + [WINDOW], {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-3.0, 1.3, 3.6], "look": [1.4, 1.2, 0.2], "fov": 40},
    {"u": 1.0, "pos": [-5.6, 2.3, 6.4], "look": [2.4, 4.0, 0.4], "fov": 36}]},
    [say("Not yet. Let's see where they go first.", "c01_close_012", "Dee", set=["seen_nine_pins"])], lead=0.6, tail=1.0,
    outside=True)
sh["dur"] = 5.0
# she stays at the window, leaning on it, and looks off up the street on "let's see where they go"
# (she stood up and faced the lens: the owner's "standing weirdly")
d = person(sh, "dee")
lean = [b for b in d["bend"] if "Hips" in b and b["Hips"][0] >= 30]
base = copy.deepcopy(lean[0]) if lean else {"Hips": [30, 0, 0]}
base.pop("t", None)
d["bend"] = [dict(copy.deepcopy(base), t=0.0), dict(copy.deepcopy(base), t=2.2),
             dict(copy.deepcopy(base), t=2.9, Neck=[base.get("Neck", [-12])[0], 14, 0], Head=[base.get("Head", [-30])[0], 32, 0])]
level_gaze(d)
d["looks"] = [[2.9, 5.0, "ahead"]]            # (her eyes go with her head up the street, not back to Kit)
d["lift"] = -0.008
d["reach"] = [r for r in d["reach"] if r.get("t", 0) <= 0.9] or d["reach"][:1]

# === the knock's fifth pass (its critic on round four's stills: 5.0 and 5.0) =======================
# One dawn and one geography: a cold sun from the street's end on every exterior, the arch's lamp the
# warm key on Dee, the cabin's linings off zero. Kit's singles keyed from her window and shot from
# Dee's side of the lens (frontal, on the camera's axis, they were flat mannequins looking at us);
# the scare line from where the passenger sat, Kit turning back into the lens. Dee's coverage wide,
# two-shot, then over Kit's shoulder (the same camera on a longer lens read as a zoom between cuts),
# her hands on the door in frame, a warm edge from the lamp. The knock with the fist in view; the arch
# ending on Dee already at the window (a match into the insert); the back seat from between the front
# headrests, raked by the rear glass's light so the wet patch reads; the end on Dee's face, then up
# over the car (it drifted onto an empty wall). Cameras checked on the cabin's ray-cast map.
K_EYES = [0.376, 1.117, -0.096]
D_EYES = [1.07, 1.29, 0.09]
LINING_K = omni([0.4, 1.38, 0.2], "#8fa3c2", 0.15, 0.9, id="lining")
WIN_KEY = spot([1.0, 1.4, 0.15], K_EYES, "#ffd2a0", 0.8, 28.0, 1.8, id="win_key")     # Kit from her window
DEE_RIM = spot([2.3, 1.8, -0.4], D_EYES, "#ffb36b", 0.6, 25.0, 3.0, id="dee_rim")      # the arch's lamp on Dee's cheek
KNOCK_SHOTS = KNOCK_ORDER
for sid in KNOCK_SHOTS:
    sh = shots[sid]
    for l in sh.get("lights", []):
        if l.get("kind") == "sun":
            l.update({"colour": "#b8c8e0", "energy": 1.0})
        elif l.get("pos") == [0.85, 1.3, 0.25] and l.get("kind") == "omni":
            l.update({"colour": "#c9d3e6", "energy": 0.1 if not isinstance(l.get("energy"), list) else l["energy"]})   # (it lit Kit lilac)
        elif l.get("id") == "kit_key":
            l["energy"] = 0.3                  # (the frontal key on the camera's axis: down to a fill)
        elif l.get("id") == "headlining":
            l["energy"] = 0.15


def add_lights(sh, *ls):
    have = {l.get("id") for l in sh["lights"] if l.get("id")}
    sh["lights"] += [copy.deepcopy(l) for l in ls if l.get("id") not in have]


def set_cam(sh, pos0, pos1, look, fov, handheld=0.06, **key):
    sh["camera"] = cam(pos0, pos1, look, fov, handheld, **key)


# arch: a shorter stall on the wall, ending with Dee already bent to the driver's glass, her fist up
# (a match into the insert); a warm key from the lamp's side on her, a cold edge on the car's roof
sh = shots["arch"]
sh["camera"]["keys"] = [{"u": 0.0, "pos": [-9.0, 5.2, -7.5], "look": [4.1, 5.6, 0.5], "fov": 40},
                        {"u": 0.45, "pos": [-7.0, 3.0, -6.6], "look": [3.8, 2.4, 0.5], "fov": 38},
                        {"u": 1.0, "pos": [-4.4, 1.35, -5.0], "look": [3.9, 1.25, 0.6], "fov": 34}]
sh["fade_in"] = 0.4
_ins = person(shots["knock_ins"], "dee")
_d = person(sh, "dee")
for k_ in ("path", "walk_at", "rate"):
    _d.pop(k_, None)
_d.update({k_: copy.deepcopy(_ins[k_]) for k_ in ("pos", "clip", "face", "gaze", "reach_car", "lift", "bend", "breathe") if k_ in _ins})
_d["reach"] = [dict(copy.deepcopy(_ins["reach"][0]), t=0.0)]
add_lights(sh, spot([3.6, 2.2, 0.0], [1.42, 1.3, 0.1], "#ffb36b", 1.2, 20.0, 5.0, id="dee_face"),
           spot([-2.0, 2.6, -3.0], [0.0, 1.2, 0.0], "#9fb4d8", 1.2, 30.0, 6.0, id="roof_rim"))
for l in sh["lights"]:
    l.pop("car", None) if l.get("id") in ("dee_face", "roof_rim") else None

# the knock from Dee's left: her right fist on the glass between the lens and Kit asleep
sh = shots["knock_ins"]
set_cam(sh, [1.95, 1.25, -0.70], [1.93, 1.25, -0.66], [0.80, 1.12, 0.10], 32, 0.06, dof=[1.6, 0.6, 0.1])

# the knock: higher and wider, the window's foot on the lower third, her hands at the glass; the
# lining lifted; the lamp's warm edge on her
sh = shots["knock"]
set_cam(sh, [-0.30, 1.05, 0.30], [-0.29, 1.05, 0.27], [0.95, 1.15, 0.08], 38, 0.08, dof_near=[0.45, 0.2, 0.1])
add_lights(sh, LINING_K, dict(DEE_RIM, pos=[2.4, 1.9, -0.5], energy=0.9))

# the two-shot: down to Dee's shoulder and in, Kit keyed from her window side
sh = shots["two_shot"]
set_cam(sh, [2.30, 1.40, 0.75], [2.22, 1.39, 0.68], [0.45, 1.18, -0.05], 32, 0.08, dof_near=[1.0, 0.5, 0.12])
add_lights(sh, spot([1.1, 1.65, 0.45], K_EYES, "#ffc890", 0.9, 18.0, 2.0, id="kit_two_key"))

# Dee's profile: Kit out of the frame (it cut through her eye), a soft key from the cabin on Dee's
# face, the dawn behind her a stop down
sh = shots["knock_two"]
set_cam(sh, [0.85, 1.30, 1.45], [0.85, 1.30, 1.40], "dee", 28, 0.06, look_by=[0.12, -0.03, 0.0], dof=[1.8, 1.0, 0.12])
sh["env"]["exposure"] = 1.2
add_lights(sh, spot([0.9, 1.2, 0.6], D_EYES, "#ffd2a0", 0.6, 25.0, 1.5, id="dee_soft"))

# Kit's singles from Dee's side, keyed from the window, the looks away short
sh = shots["kit_two"]
set_cam(sh, [0.75, 1.12, 0.55], [0.74, 1.12, 0.52], "kit_driver", 34, 0.06, look_by=[0.0, -0.05, 0.0], dof=[1.2, 0.6, 0.1])
add_lights(sh, WIN_KEY, LINING_K)
person(sh, "kit_driver")["looks"] = [[0.8, 1.4, "road"]]
sh["lines"][0]["hold"] = 2.0

sh = shots["kit_wake"]
set_cam(sh, [-0.05, 1.08, 0.25], [-0.04, 1.08, 0.23], "kit_driver", 32, 0.06, look_by=[0.06, -0.04, 0.0], dof=[1.6, 0.8, 0.1])
add_lights(sh, LINING_K)

# Dee: wide from inside with both hands on the door in frame; the lamp's edge on her
sh = shots["knock_dee2"]
set_cam(sh, [-0.18, 1.00, 0.50], [-0.16, 1.00, 0.47], "dee", 36, 0.06, look_by=[0.0, -0.12, 0.0], dof=[1.8, 0.8, 0.15])
for l in sh["lights"]:
    if l.get("id") == "dee_key":
        l["energy"] = 0.3
add_lights(sh, DEE_RIM)

# "There was someone in the back": from where the passenger sat; she turns round into the lens
sh = shots["knock_kit2"]
set_cam(sh, [0.05, 1.1, -0.75], [0.06, 1.1, -0.72], "kit_driver", 30, 0.04, dof=[1.4, 0.6, 0.1])
add_lights(sh, WIN_KEY, LINING_K)
kit(sh, "dee", KIT_AFRAID, looks=[[0.4, 1.8, "camera"]], bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]},
                                                               dict(TURN, t=0.45), dict(TURN, t=1.7),
                                                               {"t": 2.1, "Neck": [2, 10, 0], "Head": [4, 16, 0]}])
# (round over her shoulder to the middle of the back seat: the Mirror's look back, chest and all)
person(sh, "kit_driver")["blink"] = False

# the back seat from between the front headrests, the rear glass's light raking the cushion low
sh = shots["back_seat"]
set_cam(sh, [0.0, 1.20, 0.05], [0.0, 1.19, 0.0], [0.0, 0.55, -0.75], 42, 0.0, dof=[1.6, 0.8, 0.1])
sh["lights"] = [l for l in sh["lights"] if l.get("id") != "rear_glass" and l.get("pos") != [0.0, 1.38, -0.95]] + [
    omni([0.0, 1.38, -0.95], "#b4c4e0", 0.3, 1.3),
    spot([0.0, 1.25, -1.25], [0.0, 0.5, -0.6], "#a9b8d0", 0.5, 50.0, 1.6, id="rear_screen"),
    spot([0.70, 0.70, -0.80], [-0.3, 0.5, -0.6], "#9fb4d8", 0.4, 40.0, 1.6, id="rake")]
sh.pop("lead", None), sh.pop("tail", None), sh.pop("min", None)
sh["dur"] = 2.6
sh["lines"][0]["hold"] = 2.4
sh["lines"][0]["at"] = 0.1

# Dee's second: the wide two-shot from the passenger's seat, Kit's profile soft left, Dee right
sh = shots["knock_dee3"]
set_cam(sh, [-0.45, 1.15, -0.05], [-0.43, 1.15, -0.04], [1.20, 1.15, 0.10], 34, 0.05, dof_near=[0.6, 0.3, 0.12])
add_lights(sh, DEE_RIM, LINING_K)

# Kit's eyes up to the mirror, looked up at; the voids lifted; lids open
sh = shots["knock_kit3"]
set_cam(sh, [-0.20, 1.06, 0.48], [-0.19, 1.06, 0.45], "kit_driver", 30, 0.06, look_by=[0.0, 0.0, 0.0], dof=[1.1, 0.5, 0.1])
add_lights(sh, WIN_KEY, omni([0.0, 1.35, 0.30], "#6f7c98", 0.15, 0.9, id="bounce"))
kit(sh, "dee", dict(KIT_HAUNTED, browInnerUp=0.8, eyeBlinkLeft=0.0, eyeBlinkRight=0.0), looks=[[0.3, 2.4, "mirror"]],
    bend=[{"t": 0.0, "Neck": [2, 10, 0], "Head": [4, 16, 0]}, {"t": 0.3, "Neck": [0, -6, 0], "Head": [-5, -12, 0]}])

# the mirror at dawn: the bench lit for the glass, the cushion in its middle
sh = shots["mirror_dawn"]
sh["mirror"]["exposure"] = 1.15
for kk in sh["camera"]["keys"]:
    kk["look"] = [0.0, 1.085, 0.512]
add_lights(sh, omni([0.0, 0.90, -0.85], "#9fb4d8", 0.4, 1.0, id="bench"))

# "Old cars...": over Kit's shoulder, Dee's hands on the door in frame
sh = shots["knock_dee4"]
set_cam(sh, [-0.24, 1.06, 0.30], [-0.22, 1.06, 0.27], "dee", 28, 0.05, look_by=[0.0, -0.05, 0.0], dof=[1.8, 0.8, 0.15])
add_lights(sh, DEE_RIM)

# "They've been places.": Kit's profile from the passenger's side, Dee soft beyond
sh = shots["kit_react"]
set_cam(sh, [-0.35, 1.12, 0.05], [-0.34, 1.12, 0.03], "kit_driver", 30, 0.04, look_by=[0.0, -0.03, 0.0], dof=[1.1, 0.5, 0.1])
add_lights(sh, WIN_KEY, LINING_K)
sh["dur"] = 1.6                               # (its line: 0.1 s in, 1.5 s long)

# the pins: all nine and the car's arrow over the subtitle; the slab top left down
sh = shots["pins"]
sh["camera"]["keys"][1]["pos"] = [0.07, 0.84, 0.47]
for kk in sh["camera"]["keys"]:
    kk["look"] = [0.0, 0.66, 0.65]
for l in sh["lights"]:
    if l.get("pos") == [0.1, 1.0, 0.4]:
        l["energy"] = 0.2

# the plea from Dee's eyes: closer (the pillar's edges out), the lamp's light through the window on her
sh = shots["knock_kit4"]
set_cam(sh, [1.30, 1.30, 0.10], [1.28, 1.29, 0.10], [0.38, 1.12, -0.1], 26, 0.05, dof=[1.6, 0.6, 0.1])
add_lights(sh, spot([2.2, 1.8, 0.4], K_EYES, "#ffb36b", 0.6, 25.0, 3.0, id="lamp_on_kit"))

# the end: on Dee's face for her line, then up over the car and her in the wet street
sh = shots["knock_end"]
sh["camera"] = {"follow": "kit", "path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [3.2, 1.0, 2.8], "look": [1.5, 1.25, 0.1], "fov": 32},
    {"u": 0.55, "pos": [3.3, 1.6, 3.6], "look": [1.3, 1.15, 0.0], "fov": 34},
    {"u": 1.0, "pos": [3.6, 3.2, 5.6], "look": [1.0, 0.8, 0.0], "fov": 40}]}
sh["dur"] = 4.6
sh["tail"] = 0.6
add_lights(sh, dict(spot([-2.0, 2.8, 4.0], [0.0, 1.2, 0.0], "#9fb4d8", 1.2, 30.0, 7.0, id="roof_rim")))


# --- the knock's sixth pass (k8's two critics: 5.0 and 5.0) ---------------------------------------------------
# every face keyed from a light the street has, none from the lens: Dee rimmed warm from the arch's lamp
# behind her and keyed cool from the dawn on her open side; Kit short-lit through the open window from
# behind her eyeline, a cold edge from the far window (the cabin's fills had lit the visors cream and
# flattened the faces to 1.5:1). Kit's two lines that showed the back of her head on her face; Dee's
# coverage five setups, not one over-the-shoulder four times; the whole scene on the front side of the
# line from the arch's end (Kit left, Dee right); the glass up and fogged for the knock, so the fist is on
# something; the wing off (a pale plank, a rail through every window; the Mirror's car has none); the
# warehouse's lit door off (a blank cream card behind the end); no zoom in the arch or the end.
K6_DEE_RIM = spot([2.4, 2.1, -0.6], D_EYES, "#ffb36b", 1.3, 22.0, 3.2, id="dee_rim")
K6_DEE_KEY = spot([1.1, 1.7, 1.3], D_EYES, "#a9bcdc", 0.6, 25.0, 2.2, id="dee_key")
K6_KIT_KEY = spot([1.25, 1.5, -0.35], K_EYES, "#ffd2a0", 0.95, 26.0, 1.9, id="win_key")
K6_KIT_EDGE = spot([-0.8, 1.5, 0.2], [0.376, 1.12, -0.12], "#9fb4d8", 0.3, 25.0, 1.6, id="kit_edge")
K6_ROOF = omni([0.1, 1.12, -0.35], "#6f7c98", 0.06, 1.1, id="roof_lift")     # (kept off the lining: near it, it glared)


def k6_lights(sh, *ls):
    """The street's lights kept, the car's all replaced."""
    sh["lights"] = [l for l in sh["lights"] if l.get("car") != "kit"] + [copy.deepcopy(l) for l in ls]


def k6_hold(sh, hold):
    sh["lines"][0]["hold"] = hold


for sid in KNOCK_ORDER:
    sh = shots[sid]
    car(sh, "kit")["tuning"] = "1.7.6.0"
    for p_ in sh.get("props", []):
        if p_.get("kind") == "warehouse":
            p_["lit"] = []

# the arch: a held look at the painted number, then down and across to the front of the car, Dee bent
# into the driver's window beside it (her lean read whole; Kit asleep inside), one focal length
sh = shots["arch"]
sh["camera"] = {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-9.0, 5.2, -7.5], "look": [4.1, 5.6, 0.5], "fov": 36},
    {"u": 0.3, "pos": [-8.7, 5.0, -7.0], "look": [4.1, 5.4, 0.5], "fov": 36},
    {"u": 0.65, "pos": [-3.0, 3.4, 3.5], "look": [2.2, 2.2, 0.3], "fov": 36},
    {"u": 1.0, "pos": [3.4, 1.6, 4.2], "look": [1.35, 1.2, 0.1], "fov": 36}]}
for l in sh["lights"]:
    if l.get("pos") == [3.4, 2.9, -0.8]:
        l["energy"] = 1.8                      # (the ochre panel was the subject)
    elif l.get("id") == "dee_face":
        l["energy"] = 2.0
if person(sh, "kit_driver") is None:
    sh["people"].insert(0, copy.deepcopy(person(shots["knock_ins"], "kit_driver")))

# the knock: from the front, low, her fist on the fogged glass, her other arm on the door, Kit asleep
# soft behind the glass
sh = shots["knock_ins"]
set_cam(sh, [1.27, 1.05, 0.78], [1.25, 1.05, 0.75], [0.84, 1.13, 0.0], 26, 0.05, dof=[1.4, 0.5, 0.1])
k6_lights(sh, dict(K6_KIT_KEY, energy=0.7), K6_ROOF)
car(sh, "kit").pop("fog_glass", None)
car(sh, "kit")["fog_glass"] = 0.4         # (popped first: a key already there keeps its place)

# "Kit. Kit! Open up.": the glass still up, fogged, until Kit winds it down
sh = shots["knock"]
set_cam(sh, [-0.30, 1.0, 0.30], [-0.29, 1.0, 0.27], [0.95, 1.18, 0.06], 36, 0.08, dof_near=[0.45, 0.2, 0.1])
k6_lights(sh, K6_DEE_RIM, K6_DEE_KEY, K6_KIT_EDGE, K6_ROOF)
car(sh, "kit").pop("fog_glass", None)
car(sh, "kit")["fog_glass"] = 0.4         # (popped first: a key already there keeps its place)

# "What... what time is it?": swung to the front so the heads part, Kit short-lit, a cold edge on Dee's hair
sh = shots["two_shot"]
set_cam(sh, [2.35, 1.45, 0.95], [2.30, 1.44, 0.90], [0.45, 1.15, -0.05], 30, 0.08, dof_near=[1.0, 0.5, 0.08])
k6_lights(sh, K6_KIT_KEY, spot([0.2, 2.4, 1.6], D_EYES, "#8ea2c4", 0.6, 25.0, 3.0, id="dee_edge"))
car(sh, "kit").pop("fog_glass", None)
car(sh, "kit")["fog_glass"] = 0.4         # (the pane still going down for 0.6 s: fogged, as in the knock)
for l in sh["lights"]:
    if l.get("kind") == "sun":
        l["energy"] = 0.6                      # (the street a stop under Kit)

# "Gone six.": her profile, her head down to Kit (level, she looked into the pillar), the light behind her bun
sh = shots["knock_two"]
set_cam(sh, [0.90, 1.25, 1.50], [0.90, 1.25, 1.46], "dee", 30, 0.06, look_by=[0.12, -0.03, 0.0], dof=[1.8, 1.0, 0.12])
for b in person(sh, "dee")["bend"]:
    if "Head" in b:
        b["Head"] = [-20] + list(b["Head"])[1:]
k6_hold(sh, 1.8)

# "I wasn't sleeping.": her face from the open window's front corner, her eyes off to Dee, short-lit
sh = shots["kit_two"]
set_cam(sh, [0.86, 1.14, 0.45], [0.85, 1.14, 0.42], "kit_driver", 34, 0.06, look_by=[0.0, -0.04, 0.0], dof=[1.2, 0.6, 0.1])
k6_lights(sh, K6_KIT_KEY, K6_KIT_EDGE, K6_ROOF)
k6_hold(sh, 1.8)

# "There was a white car right behind me.": on her face from outside, ahead of the door, Dee's head soft
# in front of her (nearer the lens: the near blur)
sh = shots["kit_wake"]
set_cam(sh, [1.50, 1.25, 1.20], [1.47, 1.25, 1.16], "kit_driver", 30, 0.06, look_by=[0.0, -0.03, 0.0], dof=[2.0, 0.8, 0.1],
        dof_near=[1.45, 0.2, 0.1])
k6_lights(sh, K6_KIT_KEY, K6_KIT_EDGE, K6_ROOF)
k6_hold(sh, 2.3)

# "You were drooling on the wheel.": tighter and lower than the knock, Kit's cheek a sliver at the left
sh = shots["knock_dee2"]
set_cam(sh, [-0.15, 0.98, 0.45], [-0.14, 0.98, 0.42], "dee", 32, 0.06, look_by=[0.0, -0.06, 0.0], dof=[1.8, 0.8, 0.15])
k6_lights(sh, K6_DEE_RIM, K6_DEE_KEY, K6_ROOF)
k6_hold(sh, 2.0)

# "There was someone in the back.": from where she sat, Kit turning into the lens; Dee out of it
sh = shots["knock_kit2"]
set_cam(sh, [0.05, 1.10, -0.75], [0.06, 1.10, -0.72], "kit_driver", 30, 0.04, look_by=[0.05, 0.0, 0.0], dof=[1.4, 0.6, 0.1])
k6_lights(sh, spot([1.4, 1.9, 0.9], K_EYES, "#ffb36b", 0.8, 25.0, 3.0, id="lamp_through"), K6_KIT_EDGE, K6_ROOF)
k6_hold(sh, 2.0)

# the back seat: the parcel shelf and the rear glass over the bench, the patch in the middle, lit grazing
sh = shots["back_seat"]
set_cam(sh, [0.12, 1.22, -0.05], [0.12, 1.21, -0.12], [-0.08, 0.55, -0.85], 36, 0.0, dof=[1.6, 0.8, 0.1])
k6_lights(sh, spot([0.0, 1.25, -1.35], [0.0, 0.58, -0.7], "#a9b8d0", 1.5, 45.0, 1.8, id="rear_screen"),
          omni([0.0, 1.0, -0.4], "#6f7c98", 0.15, 1.2, id="bench_fill"))

# "You need a new door seal": the frame in a frame, lower, her eyes under the roof's edge
sh = shots["knock_dee3"]
set_cam(sh, [-0.45, 0.98, -0.05], [-0.43, 0.98, -0.04], [1.2, 1.32, 0.1], 34, 0.05, dof_near=[0.6, 0.3, 0.12])
k6_lights(sh, K6_DEE_RIM, K6_DEE_KEY, spot([-0.3, 1.6, -0.6], [0.376, 1.15, -0.12], "#8fa3c2", 0.35, 25.0, 1.4, id="kit_crown"))
k6_hold(sh, 2.2)

# "I saw her in the mirror.": Kit on the left third, Dee's side of the frame clear
sh = shots["knock_kit3"]
set_cam(sh, [-0.24, 1.08, 0.50], [-0.23, 1.08, 0.47], "kit_driver", 32, 0.06, look_by=[0.1, 0.0, 0.0], dof=[1.1, 0.5, 0.1])
k6_lights(sh, K6_KIT_KEY, K6_KIT_EDGE, K6_ROOF)
k6_hold(sh, 1.8)

# "She was soaking.": the mirror filling the frame, the empty bench in it lit where the patch is
sh = shots["mirror_dawn"]
set_cam(sh, [0.28, 1.13, -0.20], [0.28, 1.13, -0.08], [0.0, 1.085, 0.512], 11, 0.0, dof=[0.9, 0.5, 0.15])
sh["mirror"]["exposure"] = 1.35
for l in sh["lights"]:
    if l.get("id") == "rear_glass":
        l["look"] = [0.0, 0.55, -0.6]

# "Old cars give you bad dreams.": from the dash, a three-quarter on her leaning in; her look away inside it
sh = shots["knock_dee4"]
set_cam(sh, [0.32, 1.0, 0.45], [0.31, 1.0, 0.42], "dee", 30, 0.05, look_by=[0.0, -0.04, 0.0], dof=[1.8, 0.8, 0.15])
k6_lights(sh, K6_DEE_RIM, K6_DEE_KEY, K6_ROOF)
person(sh, "dee")["looks"] = [[1.2, 2.4, "ahead"]]

# "They've been places.": Kit hearing it, from the dash (Dee off the frame's edge, heard)
sh = shots["kit_react"]
set_cam(sh, [0.55, 1.10, 0.45], [0.54, 1.10, 0.43], "kit_driver", 32, 0.04, look_by=[0.0, -0.03, 0.0], dof=[1.0, 0.5, 0.1])
k6_lights(sh, K6_KIT_KEY, K6_KIT_EDGE, K6_ROOF)

# the pins: a strip of bezel and dash round the map, the hot spot off it
sh = shots["pins"]
set_cam(sh, [0.20, 1.0, 0.25], [0.10, 0.88, 0.42], [0.0, 0.66, 0.65], 30, 0.0)
for l in sh["lights"]:
    if l.get("pos") == [0.1, 1.0, 0.4]:
        l["energy"] = 0.08

# "Wipe it. Please.": Dee's eyes, a little looser, the lamp raking from behind Kit's eyeline
sh = shots["knock_kit4"]
set_cam(sh, [1.40, 1.30, 0.12], [1.36, 1.29, 0.12], [0.38, 1.10, -0.1], 30, 0.05, dof=[1.6, 0.6, 0.1])
k6_lights(sh, spot([2.0, 1.9, -0.5], K_EYES, "#ffb36b", 0.8, 25.0, 3.0, id="lamp_on_kit"),
          spot([-0.8, 1.5, 0.2], [0.376, 1.12, -0.12], "#9fb4d8", 0.35, 25.0, 1.6, id="kit_edge"))
k6_hold(sh, 1.6)

# the end: held on the two of them, then up past them to the arch's mouth, one focal length
sh = shots["knock_end"]
sh["camera"] = {"follow": "kit", "path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [3.2, 1.0, 2.8], "look": [1.5, 1.25, 0.1], "fov": 34},
    {"u": 0.3, "pos": [3.22, 1.05, 2.86], "look": [1.48, 1.24, 0.1], "fov": 34},
    {"u": 1.0, "pos": [3.4, 2.4, 4.8], "look": [1.2, 0.9, 0.0], "fov": 34}]}
k6_lights(sh, dict(spot([-2.0, 2.8, 4.0], [0.0, 1.2, 0.0], "#9fb4d8", 1.2, 30.0, 7.0, id="roof_rim")))


# --- the Mirror's sixth pass (m9's two critics: 5.0 and 5.0) ---------------------------------------------------
# asleep from inside (from outside, the driver's window is the body's painted glass, not glass: the
# camo on it was the smear two rounds running; the wound glass now stands in it); the empty seat and
# the hit lit and framed on what they are about; the faces' mirror light narrower and capped (a 2 cm
# band of flags blurred out in a small shadow and flooded the face: a small hard pool on the eyes
# instead), keyed from behind and the side; the coupe closing shot by shot (-30, -26, -22, -16, -13,
# -11, -8, -5 m), the run up to it quicker (dream road 1.6 s, profile 1.2, mirror far 1.2, coupe low
# 1.1, glare 0.9); the mirror inserts showing the housing;
# the whiteout's lamps seen growing before the white; the ghost lit on her face, not the seat or the hand.
def m6_lights(sh, keep, *add):
    """Of the car's lights, those `keep` passes (but none `add` brings again by id); then `add`."""
    ids = {l.get("id") for l in add if l.get("id")}
    sh["lights"] = [l for l in sh["lights"] if l.get("car") != "kit" or (keep(l) and l.get("id") not in ids)] + \
        [copy.deepcopy(l) for l in add]


def ahead(sh, m):
    car(sh, "white")["ahead"] = m


def keys2(sh, pos0, pos1, look, fov, **key):
    """Two keys, the camera's other settings kept."""
    cam_ = sh["camera"]
    k0 = dict(cam_["keys"][0])
    k0.update({"u": 0, "pos": pos0, "look": look, "fov": fov}, **key)
    k0.pop("t", None)
    k1 = {k_: v for k_, v in k0.items() if k_ not in ("dof", "dof_near")}
    k1.update({"u": 1, "pos": pos1})
    cam_["keys"] = [k0, k1]


# asleep: from the passenger's seat, her face in three-quarter, the beaded window and the arch's brick
# soft behind her; the sodium through the window on her face, the window key on her hair
sh = shots["asleep"]
c = car(sh, "kit")
c.pop("windows_down", None)
c["windows_down"] = {"driver": [9.0, 10.0]}       # (the wound glass, up all shot: glass, not the body's paint)
sh["glass"] = 0.0
sh["camera"] = {"follow": "kit", "ease": "inout", "keys": [
    {"u": 0, "pos": [-0.30, 1.10, 0.20], "look": [0.37, 1.06, -0.06], "fov": 32, "dof": [0.95, 0.6, 0.1]},
    {"u": 1, "pos": [-0.27, 1.10, 0.17], "look": [0.37, 1.06, -0.06], "fov": 32}]}
m6_lights(sh, lambda l: l.get("id") == "lining",
          spot([1.25, 2.5, -1.6], [0.37, 1.12, -0.1], "#ffb36b", 1.4, 25.0, 4.0, id="window_key"),
          spot([0.85, 1.6, 0.3], [0.37, 1.1, -0.06], "#ffb36b", 1.0, 25.0, 2.0, id="sodium_face"),
          omni([0.37, 0.85, 0.45], "#3fa0ff", 0.15, 0.8))

# the dream's road: lower, the front wheel sliding past the lens; the coupe two lamps at 30 m; her flank edged
sh = shots["dream_road"]
sh["dur"] = 1.6
keys2(sh, [2.2, 0.32, 5.6], [1.4, 0.32, 4.0], [-0.3, 0.8, -6.0], 28, exposure=0.85)
ahead(sh, -30.0)
m6_lights(sh, lambda l: True, spot([1.6, 1.4, -3.0], [0.9, 0.9, 1.0], "#c8d4ff", 3.0, 30.0, 6.0, id="flank_edge"))

# the low road shots without screen-space reflections: skimming the wet deck from 30-45 cm, its rays
# missed in a regular grid of dark ovals (a polka-dot road); the lamps' own highlights stay on the water
for sid in ("dream_road", "coupe_low"):
    shots[sid]["env"] = dict(shots[sid].get("env", {}), ssr=False)

# profile: her on the left third looking up to the right at the mirror; the coupe's beams a rim that grows
sh = shots["profile"]
sh["dur"] = 1.2
for kk in sh["camera"]["keys"]:
    kk["look"] = [0.44, 1.06, 0.03]
ahead(sh, -26.0)
m6_lights(sh, lambda l: l.get("pos") not in ([1.0, 0.95, 0.2], [-0.3, 0.9, -0.4]) and l.get("id") != "beams",
          spot([-0.25, 1.5, -1.9], [0.33, 1.15, -0.08], "#e8eeff", [[0, 4.0], [1.2, 9.0]], 20.0, 4.0, id="beams"),
          omni([-0.3, 0.9, 0.2], "#2a3560", 0.25, 1.6, id="fill_fwd"))
person(sh, "kit_driver")["looks"] = [[0.3, 1.0, "mirror"]]

# the mirror far: the housing in frame (the reflection alone read as a camera in the back seat)
sh = shots["mirror_far"]
sh["dur"] = 1.2
keys2(sh, [0.31, 1.18, -0.12], [0.305, 1.178, -0.09], [0.0, 1.131, 0.512], 17, dof=[0.9, 0.5, 0.15])
ahead(sh, -22.0)
m6_lights(sh, lambda l: l.get("pos") != [0.2, 1.42, -0.1], omni([0.0, 1.05, -0.7], "#2a3560", 0.3, 1.2, id="rear_fill"))

# the low reverse: on the dream road's side, our tail light and quarter soft at the left, the coupe nearer
sh = shots["coupe_low"]
sh["dur"] = 1.1
keys2(sh, [1.5, 0.45, -0.6], [1.48, 0.45, -0.7], [0.3, 0.8, -12.0], 30, dof_near=[1.5, 0.8, 0.15], exposure=0.75)
ahead(sh, -16.0)

# closer: the mirror's light a small pool on her eyes, capped; the beams' rim from behind
sh = shots["closer"]
for kk in sh["camera"]["keys"]:
    kk["exposure"] = 0.75
ahead(sh, -13.0)
for l in sh["lights"]:
    if l.get("id") == "slash_early":
        l.update({"angle": 5.0, "energy": [[0, 0.0], [0.4, 0.0], [1.0, 1.2]]})

# the glimpse's window: tilted down so the road takes the frame, the lamps lower so they keep a shape
sh = shots["rear_window"]
for kk in sh["camera"]["keys"]:
    kk["pos"] = [kk["pos"][0], 1.16, kk["pos"][2]]
    kk["look"] = [-0.03, 0.98, -16.0]
    kk["fov"] = 22
ahead(sh, -11.0)
for l in sh["lights"]:
    if l.get("car") == "white" and l.get("pos") in ([0.6, 0.7, 2.2], [-0.6, 0.7, 2.2]):
        l["energy"] = 5.0

# the glare: shorter, her eyes on the upper third, the light a pool on the eyes (it blew the face to an egg)
sh = shots["glare"]
sh["dur"] = 0.9
for kk in sh["camera"]["keys"]:
    kk["look"] = [0.42, 1.04, -0.08]
    kk["exposure"] = 0.8
ahead(sh, -8.0)
for l in sh["lights"]:
    if l.get("id") == "slash":
        l.update({"angle": 5.0, "energy": [[0, 0.0], [0.3, 0.4], [0.9, 1.6]]})
    elif l.get("car") == "white" and l.get("pos") == [0.0, 1.7, 1.2]:
        l["energy"] = 1.2
k = person(sh, "kit_driver")
k["looks"] = [[0.35, 0.9, "mirror"]]
k["shapes"] = [{"t": 0}, {"t": 0.55}, {"t": 0.7, "eyeSquintLeft": 0.8, "eyeSquintRight": 0.8, "browDownLeft": 0.4, "browDownRight": 0.4}]

# the whiteout: the two lamps seen in the glass first, swelling, the white only after 0.55 s
sh = shots["whiteout"]
sh["mirror"]["exposure"] = [[0, 0.7], [0.35, 1.4], [0.55, 3.5], [0.75, 8.0]]
sh["mirror"]["boost"] = [[0, 1.0], [0.45, 1.3], [0.75, 4.0]]
for l in sh["lights"]:
    if l.get("car") == "white" and l.get("pos") in ([0.6, 0.7, 2.2], [-0.6, 0.7, 2.2]):
        l["energy"] = [[0, 3.0], [0.45, 8.0], [0.6, 30.0]]

for sid in ("rear_window", "empty_road"):
    for kk in shots[sid]["camera"]["keys"]:
        kk["dof_near"] = [1.1, 0.5, 0.12]       # (on every key: a key without it turns it off)

# the empty road: the same tilt as the glimpse's window (a match)
sh = shots["empty_road"]
for kk in sh["camera"]["keys"]:
    kk["pos"] = [kk["pos"][0], 1.16, kk["pos"][2]]
    kk["look"] = [-0.03, 0.98, -16.0]
    kk["fov"] = 22

# the dark road: the creep felt (24 cm), her hair rimmed from the side glass, the mirror showing the seat
sh = shots["dark_road"]
sh["dur"] = 1.2
keys2(sh, [0.05, 1.08, -0.72], [0.05, 1.08, -0.48], [0.55, 1.0, 4.0], 34, dof_near=[0.6, 0.3, 0.12])
for l in sh["lights"]:
    if l.get("id") == "kit_rim":
        l.update({"look": [0.37, 1.18, -0.05], "energy": 2.2})
sh.pop("mirror", None)                       # (popped first: a key already there keeps its place)
sh["mirror"] = {"glass": True, "follow": "kit", "exposure": 1.0}

# the false calm: her key harder, the dash's under-light down; the ghost's light on her face, not the seat
sh = shots["breath_out"]
m6_lights(sh, lambda l: l.get("id") not in ("side_key", "ghost_light") and l.get("pos") != [0.32, 0.93, 0.55],
          omni([0.32, 0.93, 0.55], "#6fa8ff", 0.03, 1.0),
          spot([1.0, 1.35, -0.2], [0.372, 1.1, -0.15], "#8fa6c8", 2.6, 30.0, 1.6, id="side_key"),
          spot([0.12, 0.92, -0.35], [0.0, 1.08, -0.66], GHOST_LIGHT, [[0, 0.0], [1.95, 0.0], [2.05, 0.6]], 25.0, 1.0, id="ghost_light"))

# she is there: the housing in frame like the mirror far; her face lit from below, the hand left dim
sh = shots["she_is_there"]
keys2(sh, [0.32, 1.17, -0.15], [0.315, 1.168, -0.12], [0.0, 1.125, 0.512], 17, dof=[0.9, 0.5, 0.15])
sh["mirror"]["exposure"] = 1.5
for l in sh["lights"]:
    if l.get("id") == "ghost_face":
        l["pos"] = [0.0, 0.85, -0.45]

# her eyes: on the upper third, the mirror's light a pool on them, the rest of the face fallen away
sh = shots["eyes"]
for kk in sh["camera"]["keys"]:
    kk["look_by"] = [0.0, -0.018, 0.0]
for l in sh["lights"]:
    if l.get("id") == "slash":
        l.update({"angle": 5.0, "energy": 1.4})
    elif l.get("pos") == [0.32, 0.93, 0.55]:
        l["energy"] = 0.02

# the look back: a longer lens from further back, keyed from the ghost's side; the dark on the right lifted
sh = shots["look_back"]
keys2(sh, [-0.14, 1.04, -0.58], [-0.135, 1.04, -0.56], [0.37, 1.12, -0.1], 26, exposure=0.7)
m6_lights(sh, lambda l: l.get("id") not in ("seat_side", "under"),
          spot([-0.2, 1.4, -0.5], [0.372, 1.1, -0.15], GHOST_LIGHT, 1.6, 30.0, 1.2, id="seat_side"),
          spot([0.6, 1.0, 0.1], [0.372, 1.1, -0.15], "#6fa8ff", 0.1, 35.0, 1.2, id="under"),
          omni([0.6, 1.0, 0.6], "#2a3560", 0.15, 1.0, id="right_lift"))

# the empty seat: between the front seats onto the cushion, a pool of light on it where she sat
sh = shots["empty_seat"]
sh["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.18, "keys": [
    {"u": 0, "pos": [0.25, 1.16, 0.0], "look": [-0.15, 0.55, -0.75], "fov": 36, "exposure": 1.0},
    {"u": 1, "pos": [0.24, 1.16, -0.02], "look": [-0.15, 0.55, -0.75], "fov": 36, "exposure": 1.0}]}
m6_lights(sh, lambda l: l.get("id") not in ("slash_seat", "seat_teal"),
          spot([-0.1, 1.32, -0.3], [-0.15, 0.5, -0.75], "#8fa6c8", 1.6, 35.0, 1.6, id="cushion_pool"))

# the hit: on her face (her shoulder filled it), lit from under; Kit soft at the right
sh = shots["hit"]
sh["camera"]["keys"] = [          # (the depth of field on every key: a key without it turns it off)
    {"u": 0, "pos": [0.22, 1.08, 0.56], "look": [0.04, 1.10, -0.25], "fov": 30, "dof": [1.35, 0.3, 0.1], "exposure": 1.0,
     "dof_near": [0.75, 0.05, 0.08]},
    {"t": 0.03, "pos": [0.22, 1.08, 0.55], "look": [0.04, 1.10, -0.25], "fov": 30, "dof": [1.35, 0.3, 0.1], "exposure": 1.45,
     "dof_near": [0.75, 0.05, 0.08]},
    {"t": 0.12, "pos": [0.21, 1.08, 0.44], "look": [0.04, 1.10, -0.25], "fov": 30, "dof": [1.25, 0.3, 0.1], "exposure": 0.85,
     "dof_near": [0.64, 0.05, 0.08]}]
m6_lights(sh, lambda l: l.get("id") not in ("ghost_rim", "teal_on_kit"))


# --- the seventh pass (k9's critics: 5.0 and 4.5): what the pictures still got wrong ----------------------------
# Kit's mouth moving less as she speaks (at full width a still caught her mid-word: teeth like a grille, a
# red mouth); first light in the sky over the arch (the scene says "gone six" and showed 2 a.m.); the
# arch's crane never parked on the wall (its middle key stared at the pier), the floor's hot spot a wall
# lamp on Dee's back; the knock lower, air over Dee's hair; the scare from the back seat with Dee out of
# it; the back seat looking down past the front seats onto the cushion, the patch raked by the rear glass's
# light so its beads glint; the mirror at dawn with its housing, the dawn behind the rear glass in it.
DAWN7 = {"zenith": "#34466a", "horizon": "#c4a593", "cloud_cover": 0.35, "cloud_lo": "#5a5f74", "cloud_hi": "#d2b8a8"}
for s_ in scene["shots"]:
    k_ = person(s_, "kit_driver")
    if k_ is not None:
        k_.pop("mouth", None)
        k_["mouth"] = 0.4                 # (popped first: a key already there keeps its place)
for sid in KNOCK_ORDER:
    shots[sid]["env"]["sky"] = dict(DAWN7)

sh = shots["arch"]
sh["camera"] = {"path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": [-9.0, 5.2, -7.5], "look": [2.0, 2.6, 0.3], "fov": 36},
    {"u": 0.55, "pos": [-1.0, 2.6, 6.0], "look": [1.6, 1.4, 0.2], "fov": 36},
    {"u": 1.0, "pos": [3.4, 1.6, 4.2], "look": [1.35, 1.2, 0.1], "fov": 36}]}
for l in sh["lights"]:
    if l.get("id") == "dee_face":
        l.update({"pos": [3.6, 3.2, -1.2], "look": [1.4, 1.3, 0.1], "energy": 1.2, "angle": 50.0})
    elif l.get("pos") == [3.4, 2.9, -0.8]:
        l["energy"] = 1.0

sh = shots["knock"]
set_cam(sh, [-0.30, 0.92, 0.30], [-0.29, 0.92, 0.27], [0.95, 1.24, 0.10], 32, 0.08, dof_near=[0.45, 0.2, 0.1])

sh = shots["knock_kit2"]
set_cam(sh, [0.05, 1.10, -0.75], [0.06, 1.10, -0.72], "kit_driver", 30, 0.04, look_by=[-0.1, 0.0, 0.0], dof=[1.4, 0.6, 0.1])

sh = shots["back_seat"]
set_cam(sh, [0.10, 1.15, -0.10], [0.10, 1.14, -0.16], [0.02, 0.34, -0.5], 34, 0.0, dof=[1.6, 0.8, 0.1])
k6_lights(sh, spot([0.0, 1.25, -1.35], [0.02, 0.33, -0.5], "#b4c4e0", 1.8, 40.0, 1.9, id="rear_screen"),
          omni([0.0, 1.0, -0.4], "#6f7c98", 0.12, 1.2, id="bench_fill"))

sh = shots["mirror_dawn"]
set_cam(sh, [0.30, 1.16, -0.18], [0.30, 1.16, -0.10], [0.0, 1.085, 0.512], 19, 0.0, dof=[0.9, 0.5, 0.15])
sh["mirror"]["exposure"] = 1.6
sh["lights"] = [l for l in sh["lights"] if l.get("id") != "dawn_back"] + [
    omni([0.0, 1.4, -2.2], "#9fb4d8", 2.0, 3.0, id="dawn_back")]

# the Mirror's seventh pass: the hit from in front of her on the left (from the right, her wet hair
# hung between her face and the lens: the camera saw its curtain and her shoulder), Kit beyond her;
# the empty seat's pool bright enough to read on black leather; the whiteout's lamps held longer
# before the white (at 0.48 s the mirror was already a white card)
sh = shots["hit"]
sh["camera"]["keys"] = [          # (the depth of field on every key: a key without it turns it off)
    {"u": 0, "pos": [-0.25, 1.10, 0.45], "look": [-0.02, 1.12, -0.18], "fov": 30, "dof": [1.3, 0.3, 0.1], "exposure": 1.0},
    {"t": 0.03, "pos": [-0.25, 1.10, 0.44], "look": [-0.02, 1.12, -0.18], "fov": 30, "dof": [1.3, 0.3, 0.1], "exposure": 1.45},
    {"t": 0.12, "pos": [-0.22, 1.10, 0.36], "look": [-0.02, 1.12, -0.18], "fov": 30, "dof": [1.2, 0.3, 0.1], "exposure": 0.85}]
for l in sh["lights"]:
    if l.get("id") == "ghost_under":
        l.update({"pos": [-0.15, 0.85, 0.05], "look": [-0.02, 1.16, -0.18]})
sh = shots["empty_seat"]
for l in sh["lights"]:
    if l.get("id") == "cushion_pool":
        l.update({"energy": 5.0, "angle": 28.0})
sh = shots["whiteout"]
sh["mirror"]["exposure"] = [[0, 0.5], [0.45, 1.0], [0.62, 3.0], [0.75, 8.0]]

json.dump(scene, open(path, "w"), indent="\t")
