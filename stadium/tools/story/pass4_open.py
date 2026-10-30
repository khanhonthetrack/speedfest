"""(Kept in the repo.) The fourth pass on night 1's opening (docs/CINEMATICS.md, "fourth pass"): the
stills critic's notes on the third pass (5.5 and 5.0 against take five's 4.5) built into the scene.
Edits the committed scene in place, after pass3_open.py, and changes nothing on a second run.
    python3 tools/story/pass4_open.py stadium/story/scenes/c01_open.json"""
import copy, json, sys

path = sys.argv[1]
scene = json.load(open(path))
shots = {s["id"]: s for s in scene["shots"]}


def light(kind, pos, look, colour, energy, angle, rng, shadow=True, lid=None):
    out = {"kind": kind, "pos": pos, "look": look, "colour": colour, "energy": energy, "angle": angle, "range": rng}
    if not shadow:
        out["shadow"] = False
    if lid:
        out["id"] = lid
    return out


def person(shot, pid):
    return next(p for p in shot.get("people", []) if p["id"] == pid)


def blue_floods(top, back):
    """The yard's two blue floods (the stage's side, the crowd's), as every yard shot has them."""
    return [light("spot", [0.0, 11.0, -16.0], [0.0, 0.0, 6.0], "#7f9cff", top, 50.0, 40.0),
            light("spot", [0.0, 10.0, 22.0], [0.0, 0.0, 8.0], "#7f9cff", back, 45.0, 30.0)]


YARD = ["yard", "gus_points", "coat", "gus", "kit_mcu", "lot47_nose", "lot47_wheel", "lot47_orbit", "kit_eyes",
        "lot47_paint", "lot47_hero"]

# 1. the city: low over the quay's edge (the deck, a sodium lamp and the bollards slide past the lens:
# a foreground, parallax), pushing in; a haze that lays the far towers back, a glow band on the
# horizon behind them; the lamp's warm against the city's cool
city = shots["city"]
city["camera"] = {"ease": "inout", "handheld": 0.06, "keys": [
    {"u": 0, "pos": [53.0, 2.1, -130.0], "look": [520.0, 32.0, 100.0], "fov": 33, "roll": 2.0},
    {"u": 1, "pos": [49.5, 2.0, -126.0], "look": [520.0, 30.0, 100.0], "fov": 33, "roll": 0.0}]}
city["env"] = {"fog": 0.0009, "fog_colour": "#2a2140", "fog_sky": 0.25, "vol_fog": 0.0008, "reflect": 0.5,
               "city_lit": 0.3, "city_glow": 2.6}
city["sky"] = {"zenith": "#08070e", "horizon": "#3a2850"}
scene["props"] = [p for p in scene["props"] if not str(p.get("id", "")).startswith("quay_")]
scene["props"].append({"kind": "pole", "id": "quay_lamp", "pos": [60.5, 0, -129.0], "yaw": 0, "height": 5.0,
                       "energy": 5.0, "colour": "#ffa040"})
for i, z in enumerate([-127.0, -121.0, -115.0]):            # mooring bollards along the edge
    scene["props"].append({"kind": "barrel", "id": "quay_bollard%d" % i, "pos": [63.4, 0, z], "fire": False})

# 2. the canyon: in behind Kit (her head and shoulders on the left third, the lamp's pool ahead of
# her), a cool rim off her, the sodium down so the ground goes blue-black and the orange lives in the
# puddles; down the lane the auction's light coming back through the rain, two figures in it
canyon = shots["canyon"]
canyon["camera"] = {"ease": "linear", "handheld": 0.18, "keys": [
    {"u": 0, "pos": [-8.4, 1.3, -65.5], "look": [20.0, 1.6, -67.5], "fov": 32},
    {"u": 1, "pos": [-6.6, 1.25, -65.6], "look": [20.0, 1.6, -67.5], "fov": 32}]}
for l in canyon["lights"]:
    if l.get("id") == "kit_rim":
        l["energy"] = 2.5
    elif l.get("colour") == "#9fb4ff" and l["pos"][0] == 55.0:
        l["energy"] = 4.0
canyon["lights"] = [l for l in canyon["lights"] if l.get("id") not in ("kit_cool_rim", "lane_back")]
canyon["lights"] += [light("spot", [-2.0, 3.0, -68.5], [-5.0, 1.4, -66.5], "#9fb4ff", 4.0, 30.0, 8.0, False, "kit_cool_rim"),
                     light("spot", [24.0, 7.0, -66.5], [-6.0, 1.0, -66.5], "#7f9cff", 8.0, 14.0, 60.0, False, "lane_back")]
canyon["people"] = [p for p in canyon["people"] if p["id"] not in ("w1", "w2")]
canyon["people"] += [{"id": "w1", "who": "crowd4", "clip": "Stand", "pos": [9.0, 0, -67.3], "face": 90, "start": 0.4},
                     {"id": "w2", "who": "crowd1", "clip": "Stand_Talk", "pos": [10.4, 0, -65.9], "face": 100, "start": 1.1}]

# 3. the crowd watches the stage in every yard shot (no head thrown back at the sky: c4's idle threw
# it back, so it stands in another)
for sid in YARD:
    for p in shots[sid].get("people", []):
        if p["id"].startswith("c") and p["id"][1:].isdigit():
            p["gaze"] = "gus"
for shot in scene["shots"]:
    for p in shot.get("people", []):
        if p["id"] == "c4":
            p["clip"] = "Stand_B"

# 4. the yard: the crane starts in among the heads; Gus keyed from the truss and rimmed off the wall
# (the brightest face in the frame), the crowd edged from the stage side, the warm spot on Kit down
yard = shots["yard"]
yard["camera"] = {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [1.3, 2.2, 13.4], "look": [0.3, 2.0, -2.6], "fov": 30, "dof_near": [1.2, 0.6, 0.04], "dof": [15.0, 8.0, 0.04]},
    {"u": 1, "pos": [1.0, 1.6, 12.7], "look": [0.3, 2.0, -2.6], "fov": 30}]}
GUS_KEY = light("spot", [0.0, 4.2, -0.6], [0.0, 2.0, -2.6], "#ffcf99", 5.0, 25.0, 8.0, lid="gus_key")
GUS_BACK = light("spot", [0.0, 6.0, -7.5], [0.0, 2.0, -2.6], "#7f9cff", 6.0, 25.0, 10.0, False, "gus_back")
CROWD_RIM = light("spot", [0.0, 6.0, 4.5], [0.0, 1.6, 9.5], "#7f9cff", 4.0, 50.0, 10.0, False, "crowd_rim")
yard["lights"] = blue_floods(8.0, 8.0) + [light("spot", [1.8, 3.0, 13.8], [0.4, 1.7, 11.2], "#ffa040", 1.5, 15.0, 6.0),
                                          dict(GUS_KEY), dict(GUS_BACK), dict(CROWD_RIM)]

# Gus presents the lot on "Lot forty-six" (an open hand, palm up, out towards the cars: an
# auctioneer at work, not an A-pose)
PRESENT = {"at": [-0.34, 1.86, -2.12], "palm": [0.0, 1.0, 0.0], "fingers": [-0.25, 0.0, 0.97],
           "elbow": [-0.6, -1.0, 0.0], "fist": 0.1}
person(yard, "gus")["reach"] = [{"t": 0.35}, {"t": 1.05, "RightHand": PRESENT},
                                {"t": 2.6, "RightHand": dict(PRESENT, at=[-0.36, 1.84, -2.1])}, {"t": 3.3}]

# 5. Gus points the gentleman out, seen from 55 degrees off his point (the arm across the frame, not
# down the lens), keyed short-side, rimmed, the wall melted
gp = shots["gus_points"]
gp["camera"] = {"ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [3.2, 1.95, 0.45], "look": [-0.25, 2.1, -2.4], "fov": 20, "dof": [4.7, 1.5, 0.12], "eye_light": 0.15},
    {"u": 1, "pos": [3.0, 1.95, 0.2], "look": [-0.25, 2.1, -2.4], "fov": 20, "eye_light": 0.15}]}
gp["lights"] = blue_floods(6.0, 1.0) + [light("spot", [-2.4, 3.2, 0.4], [0.0, 2.2, -2.6], "#ffcf99", 6.0, 25.0, 8.0),
                                        light("spot", [1.8, 4.5, -6.0], [0.0, 2.1, -2.6], "#7f9cff", 5.0, 25.0, 9.0, False)]

# 6. the gentleman at the back, from Gus's side of the line (he looks screen right, back at Gus's
# screen-left point), tighter; a hard top-side key on his face, a rim off the dark behind him
coat = shots["coat"]
coat["camera"] = {"ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [0.4, 1.95, 5.6], "look": [-2.5, 1.62, 14.5], "fov": 18, "dof_near": [6.3, 2.0, 0.12], "dof": [9.3, 1.8, 0.12], "eye_light": 0.15},
    {"u": 1, "pos": [0.32, 1.9, 5.95], "look": [-2.5, 1.62, 14.5], "fov": 18, "eye_light": 0.15}]}
coat["lights"] = blue_floods(4.0, 3.0) + [light("spot", [-1.4, 4.2, 12.6], [-2.5, 1.7, 14.5], "#ffb070", 4.0, 25.0, 8.0),
                                          light("spot", [-3.4, 3.5, 17.5], [-2.5, 1.6, 14.5], "#7f9cff", 4.0, 30.0, 8.0, False)]

# 7. "Lot forty-seven": three-quarter, Gus left of centre with the room on his look (to Kit's side), a
# short-side key, a rim, the floods down (the truss's glints out), the wall melted
gus = shots["gus"]
gus["camera"] = {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [-1.0, 1.7, 0.7], "look": [0.25, 2.2, -2.6], "fov": 27, "dof": [3.6, 1.0, 0.14], "eye_light": 0.2},
    {"u": 1, "pos": [-0.9, 1.7, 0.5], "look": [0.25, 2.2, -2.6], "fov": 27, "eye_light": 0.2}]}
gus["lights"] = blue_floods(3.0, 1.0) + [light("spot", [1.7, 3.2, -1.8], [0.0, 2.2, -2.6], "#ffcf99", 6.0, 25.0, 8.0),
                                         light("spot", [-1.2, 4.0, -5.5], [0.0, 2.1, -2.6], "#7f9cff", 4.0, 25.0, 9.0, False)]

# 8. Kit hears "Lot forty-seven": keyed warm from the stage's side (her short side, a catchlight),
# the violet under her chin gone, a blue rim; her eyes come up to Gus on the beat
KIT_KEY = light("spot", [1.6, 3.2, 8.0], [0.4, 1.6, 11.2], "#ffcf99", 3.0, 22.0, 8.0, lid="kit_key")
mcu = shots["kit_mcu"]
mcu["camera"] = {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [-0.6, 1.62, 9.75], "look": [0.65, 1.62, 11.2], "fov": 30, "dof": [1.85, 1.0, 0.12], "eye_light": 0.2},
    {"u": 1, "pos": [-0.55, 1.62, 9.9], "look": [0.65, 1.62, 11.2], "fov": 30, "eye_light": 0.2}]}
mcu["lights"] = blue_floods(14.0, 10.0) + [light("spot", [-1.4, 3.0, 13.6], [0.4, 1.7, 11.2], "#8aa6ff", 1.5, 20.0, 7.0),
                                           dict(KIT_KEY)]
k = person(mcu, "kit")
k["gaze"] = "gus"
k["looks"] = [[0.0, 0.35, "ahead"]]

# 9. Kit sees the car: her eyes' view of the coupe across the lots, past the heads between (where she
# stands, what she wants), a slow push (over her shoulder her backlit hair blurred to a pale blob)
eyes = shots["kit_eyes"]
eyes.pop("dur", None)
eyes["lead"], eyes["tail"] = 0.3, 0.3
eyes["lines"] = [{"id": "c01_open_003a", "speaker": "Gus", "text": "Engine's sweet."}]     # (his patter over what she sees)
eyes["camera"] = {"ease": "inout", "handheld": 0.08, "keys": [
    {"u": 0, "pos": [0.42, 1.6, 10.95], "look": [-0.05, 0.9, 2.0], "fov": 20, "dof": [9.0, 3.0, 0.12]},
    {"u": 1, "pos": [0.41, 1.6, 10.75], "look": [-0.05, 0.9, 2.0], "fov": 18}]}
eyes["lights"] = blue_floods(14.0, 6.0) + [dict(KIT_KEY)]
k = person(eyes, "kit")
k["gaze"] = ""
k.pop("looks", None)

# 10. the car shots: the softboxes that showed as studio orbs out; the stage's own light makes the
# reflections (a warm truss spot behind the car, blue rims either side); the underglow down a third
STAGE_WARM = light("spot", [0.0, 4.0, -1.0], [0.0, 0.6, 2.0], "#ffcf99", 5.0, 40.0, 10.0, lid="stage_warm")
RIMS = [light("spot", [3.2, 5.5, -6.0], [0.0, 1.2, 1.0], "#9fb4ff", 4.0, 25.0, 12.0, False),
        light("spot", [-3.2, 5.5, -6.0], [0.0, 1.2, 1.0], "#9fb4ff", 4.0, 25.0, 12.0, False)]


def kit_car(shot):
    return next(c for c in shot["cars"] if c["id"] == "kit")


nose = shots["lot47_nose"]
nose["camera"] = {"follow": "kit", "ease": "out", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [2.6, 0.35, 4.0], "look": [-0.4, 0.7, 1.0], "fov": 30, "dof": [4.2, 3.0, 0.08]},
    {"u": 1, "pos": [1.9, 0.38, 3.6], "look": [-0.4, 0.7, 1.0], "fov": 30}]}
nose["lights"] = blue_floods(14.0, 8.0) + [l for l in nose["lights"] if l.get("kind") == "softbox" and l["pos"][0] in (4.5, -4.5)]
nose["lights"] += [light("spot", [1.5, 0.2, 4.5], [0.0, 0.45, 2.2], "#ffcf99", 2.0, 35.0, 6.0, False), dict(STAGE_WARM)]
kit_car(nose)["glow"] = 0.6

wheel = shots["lot47_wheel"]
wheel["lead"], wheel["tail"] = 0.15, 0.15
for l in wheel["lights"]:
    if l.get("kind") == "softbox" and l["pos"] == [4.5, 2.0, 2.0]:
        l["energy"] = 0.6
kit_car(wheel)["glow"] = 0.6

orbit = shots["lot47_orbit"]
orbit["lead"], orbit["tail"] = 0.2, 0.3
orbit["lights"] = blue_floods(14.0, 8.0) + [l for l in orbit["lights"] if l.get("kind") == "softbox" and l["pos"][0] in (4.5, -4.5)]
orbit["lights"] += [light("spot", [-3.5, 3.5, 1.5], [0.0, 1.0, -1.0], "#ffcf99", 4.0, 35.0, 9.0),
                    light("spot", [-3.5, 1.5, -3.5], [0.0, 0.8, -1.5], "#9fb4ff", 3.0, 30.0, 7.0, False)]
kit_car(orbit)["glow"] = 0.35

# the bonnet's insert out ("Engine's sweet" is over Kit's view now): its reflections of the truss
# lamps read as studio discs and an exhaust insert stayed murky; the run one insert shorter
scene["shots"] = [x for x in scene["shots"] if x["id"] != "lot47_bonnet"]
shots.pop("lot47_bonnet", None)

# 11. "Somebody painted her by hand. Look at that.": a push in to the rear quarter's hand-painted
# shapes and pinstripe, the focus racking onto them; the warm spot raking the panel, off the tyre
paint = shots["lot47_paint"]
paint["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.1, "keys": [
    {"u": 0, "pos": [2.3, 1.0, -0.5], "look": [0.95, 0.85, -1.6], "fov": 26, "dof": [2.0, 1.2, 0.12]},
    {"u": 1, "pos": [1.7, 0.95, -1.15], "look": [0.95, 0.85, -1.6], "fov": 26, "dof": [1.2, 0.8, 0.12]}]}
for l in paint["lights"]:
    if l.get("colour") == "#ffe2b8":
        l["pos"], l["look"], l["energy"] = [3.2, 1.6, -0.3], [0.95, 0.95, -1.5], 2.0
kit_car(paint)["glow"] = 0.35

# 12. the hero: the back spot split into two rims (no star over Gus), Gus keyed from the truss and
# clear of the roof, the floods and the underglow down, no shoulder slab at the edge
hero = shots["lot47_hero"]
hero["camera"] = {"follow": "kit", "ease": "out", "keys": [
    {"u": 0, "pos": [0.6, 0.35, 7.4], "look": [0.0, 0.72, 0.5], "fov": 30, "dof": [9.0, 6.0, 0.06]},
    {"u": 1, "pos": [0.6, 0.45, 6.2], "look": [0.0, 0.78, 0.5], "fov": 30}]}
hero["lights"] = blue_floods(8.0, 8.0) + [l for l in hero["lights"] if l.get("kind") == "softbox" and l["pos"][0] in (4.5, -4.5)]
hero["lights"] += copy.deepcopy(RIMS) + [
    light("spot", [0.0, 4.2, -0.8], [0.0, 2.2, -2.6], "#ffcf99", 5.0, 25.0, 8.0, lid="gus_key"),
    {"kind": "spot", "pos": [-6.5, 2.4, 4.5], "look": [-2.2, 0.6, 2.0], "look_to": [2.2, 0.6, 2.0], "colour": "#e8eeff",
     "energy": 4.0, "range": 16.0, "angle": 16.0}]
kit_car(hero)["glow"] = 0.75
hero["people"] = [p for p in hero["people"] if p["id"] != "c7"]

# 13. the car run quickens into the hero (each insert its line and a breath, not 3.5 s): the lines
# held a touch quicker than the reading speed's default (they are short and Gus's patter)
for sid, hold in [("lot47_nose", 1.9), ("lot47_wheel", 2.2), ("lot47_orbit", 2.4), ("lot47_paint", 2.6)]:
    shots[sid]["lines"][0]["hold"] = hold

# 14. Lot 47's plate lettered (a car that had an owner)
for sid in YARD:
    for c in shots[sid].get("cars", []):
        if c["id"] == "kit":
            c["plate"] = "KX47 VRN"


# === ROUND TWO (the critic on round four's stills, 5.5 and 5.5) =====================================
# The beat: Kit sees the car she will end up with, and a stranger watches her. Her reaction after the
# car run (her point of view out: it was the one face missing for the last 17 s), a hairline flicker of
# the stage's floods on it; the coat man glanced back at before the button. The rhythm off the
# metronome (a slow open, quicker through Gus and the coat, a quick car run, a long button); the halos
# off the cast (back rims down); short-side keys on faces; the floods down in the car run (the tyres
# went grey under them); the paint's insert on the door, raked; the tangents off Gus's legs.
def rim_down(lights, energy):
    for l in lights:
        if l.get("colour") == "#7f9cff" and l.get("shadow") is False and l["pos"][2] < 0 and l["pos"][1] < 7.0:
            l["energy"] = energy


# the city: lower over the quay (its edge a diagonal), the searchlights' sources behind the towers,
# the far towers laid back in haze
city["camera"] = {"ease": "inout", "handheld": 0.06, "keys": [
    {"u": 0, "pos": [51.0, 1.0, -128.5], "look": [535.0, 22.0, 70.0], "fov": 33, "roll": 2.0},
    {"u": 1, "pos": [48.0, 1.05, -125.0], "look": [535.0, 20.0, 70.0], "fov": 33, "roll": 0.0}]}
city["env"]["fog"] = 0.0018
city["dur"] = 3.5
# the canyon: no push into a figure standing still; held behind her, cut sooner
canyon["camera"] = {"ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [-8.6, 1.35, -65.3], "look": [20.0, 1.6, -67.5], "fov": 32},
    {"u": 1, "pos": [-8.45, 1.35, -65.32], "look": [20.0, 1.6, -67.5], "fov": 32}]}
for l in canyon["lights"]:
    if l.get("id") == "lane_back":
        l["energy"] = 4.0
canyon["dur"] = 2.3
# the yard: craning down from over the crowd (Gus's legs off the coupe's roof), his back rim down
yard["camera"] = {"ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [1.3, 3.4, 13.4], "look": [0.3, 2.0, -2.6], "fov": 30, "dof": [15.0, 8.0, 0.04]},
    {"u": 1, "pos": [1.0, 1.9, 12.7], "look": [0.3, 2.25, -2.6], "fov": 30}]}
for l in yard["lights"]:
    if l.get("id") == "gus_back":
        l["energy"], l["pos"] = 2.5, [1.2, 5.0, -6.5]
    elif l.get("id") == "crowd_rim":
        l["energy"] = 2.0
    elif l.get("colour") == "#ffa040":
        l["energy"] = 0.4                  # (the head nearest the lens a dark wipe, not a brown blob)
# Gus's point: keyed short-side, the halo off him (the back spot rims his head and shoulder only)
gp["lights"] = blue_floods(6.0, 1.0) + [light("spot", [-1.2, 3.6, 1.4], [0.0, 2.2, -2.6], "#ffcf99", 6.0, 25.0, 8.0),
                                        light("spot", [2.4, 4.0, -4.5], [0.0, 2.2, -2.6], "#7f9cff", 1.8, 20.0, 8.0, False)]
for k_ in gp["camera"]["keys"]:
    k_["eye_light"] = 0.08
gp["lines"][0]["hold"] = 2.1
gp["lead"], gp["tail"] = 0.1, 0.1
# the coat man: a long lens, a hard warm rim off a lamp behind him, a cool front fill; a beat shorter
coat["camera"] = {"ease": "inout", "handheld": 0.08, "keys": [
    {"u": 0, "pos": [1.4, 1.95, 5.8], "look": [-2.5, 1.7, 14.5], "fov": 12, "dof_near": [6.3, 2.0, 0.1], "dof": [10.3, 1.8, 0.1], "eye_light": 0.05},
    {"u": 1, "pos": [1.34, 1.94, 5.95], "look": [-2.5, 1.7, 14.5], "fov": 12, "eye_light": 0.05}]}
coat["lights"] = blue_floods(3.0, 2.0) + [light("spot", [-4.0, 3.8, 16.5], [-2.5, 1.7, 14.5], "#ffb070", 5.0, 22.0, 8.0, lid="coat_rim"),
                                          light("spot", [0.5, 3.0, 9.0], [-2.5, 1.7, 14.5], "#9fb4ff", 1.2, 25.0, 9.0, False),
                                          light("omni", [-4.6, 3.6, 17.5], None, "#ffb070", 2.0, 0.0, 4.0, False)]
coat["lights"][-1].pop("look"); coat["lights"][-1].pop("angle")
coat["lead"], coat["tail"] = 0.1, 0.2
coat["lines"][0]["hold"] = 1.5
# "Lot forty-seven": the back rim down (the outline round him)
for l in gus["lights"]:
    if l.get("colour") == "#7f9cff" and l.get("shadow") is False:
        l["energy"] = 2.0
# Kit hearing it: the floods down, the warm key a little up (3:1 on her face)
mcu["lights"] = blue_floods(6.0, 4.0) + [light("spot", [-1.4, 3.0, 13.6], [0.4, 1.7, 11.2], "#8aa6ff", 1.2, 20.0, 7.0),
                                         dict(KIT_KEY, energy=4.0)]
# the car run: the floods down (they greyed the tyres), the underglow under the paint
for sid, glow in [("lot47_nose", 0.4), ("lot47_wheel", 0.35), ("lot47_orbit", 0.3), ("lot47_paint", 0.3), ("lot47_hero", 0.5)]:
    sh = shots[sid]
    for l in sh["lights"]:
        if l.get("colour") == "#7f9cff" and l.get("angle") in (50.0, 45.0):
            l["energy"] = 7.0 if l["pos"][2] < 0 else 4.0
    kit_car(sh)["glow"] = glow
nose["lines"][0]["hold"] = 1.7
nose["lead"], nose["tail"] = 0.15, 0.15
wheel["lines"][0]["hold"] = 1.7
orbit["lines"][0]["hold"] = 2.0
orbit["lead"], orbit["tail"] = 0.15, 0.25
# Kit sees it: her face, close and still, cold from the coupe's underglow below, the stage's floods
# stuttering for a breath (something wrong with the car, already); Gus's patter over her
eyes["camera"] = {"ease": "inout", "handheld": 0.06, "keys": [
    {"u": 0, "pos": [-0.3, 1.61, 10.28], "look": [0.4, 1.59, 11.2], "fov": 24, "dof": [1.5, 0.8, 0.12], "eye_light": 0.05},
    {"u": 1, "pos": [-0.28, 1.61, 10.33], "look": [0.4, 1.59, 11.2], "fov": 24, "eye_light": 0.05}]}
eyes["lights"] = blue_floods(6.0, 4.0) + [light("spot", [0.2, 0.9, 8.5], [0.4, 1.6, 11.2], "#bfd4ff", 1.5, 25.0, 6.0, False, "car_glow_key"),
                                          dict(KIT_KEY, energy=1.5)]
eyes["lines"] = [{"id": "c01_open_003a", "speaker": "Gus", "text": "Engine's sweet.", "hold": 1.1, "voice": True}]
eyes["lead"], eyes["tail"] = 0.15, 0.15
eyes["flicker"] = {"rate": 14.0, "depth": 0.7, "from": 0.75, "to": 0.95}
k = person(eyes, "kit")
k["gaze"] = "gus"
k["shapes"] = {"browInnerUp": 0.25, "eyeSquintLeft": 0.15, "eyeSquintRight": 0.15}
# "painted her by hand": on the door, the brushed shapes and the pinstripe raked by a light along the flank
paint["camera"] = {"follow": "kit", "ease": "inout", "handheld": 0.08, "keys": [
    {"u": 0, "pos": [2.1, 0.9, 1.4], "look": [0.95, 0.85, 0.4], "fov": 30, "dof": [1.8, 1.0, 0.12]},
    {"u": 1, "pos": [2.0, 0.9, 0.6], "look": [0.95, 0.85, -0.4], "fov": 30}]}
paint["lights"] = [l for l in paint["lights"] if l.get("id") != "rake"] + [
    light("spot", [1.9, 1.15, -3.2], [1.0, 0.85, 0.3], "#ffe2b8", 4.0, 18.0, 6.0, False, "rake")]
paint["lines"][0]["hold"] = 2.2
paint["lead"], paint["tail"] = 0.1, 0.2
# the coat man again, just before the button: his eyes on Kit (planted for later nights)
if "coat_glance" not in shots:
    cg = copy.deepcopy(coat)
    cg["id"] = "coat_glance"
    scene["shots"].insert([x["id"] for x in scene["shots"]].index("lot47_hero"), cg)
    shots["coat_glance"] = cg
cg = shots["coat_glance"]
cg.update({"camera": copy.deepcopy(coat["camera"]), "lights": copy.deepcopy(coat["lights"]), "lines": [], "dur": 0.8})
for k_ in ("lead", "tail", "min"):
    cg.pop(k_, None)
cg["people"] = copy.deepcopy(coat["people"])
person(cg, "coat")["gaze"] = "kit"
# the hero: off the axis a little (Gus off the roof), a long button
hero["camera"] = {"follow": "kit", "ease": "out", "keys": [
    {"u": 0, "pos": [1.2, 0.35, 7.4], "look": [0.2, 0.75, 0.5], "fov": 30, "dof": [9.0, 6.0, 0.06]},
    {"u": 1, "pos": [1.2, 0.45, 6.2], "look": [0.2, 0.8, 0.5], "fov": 30}]}
for l in hero["lights"]:
    if l.get("id") == "gus_key":
        l["energy"] = 5.0
rim_down(hero["lights"], 2.5)
hero["tail"] = 1.6

# the rhythm: a shot's floor under its line's own time (StoryScene's default is 2.5 s: every shot sat on it)
for sid, floor in [("gus_points", 2.2), ("coat", 1.8), ("lot47_nose", 1.8), ("lot47_wheel", 1.8), ("lot47_orbit", 2.2),
                   ("kit_eyes", 1.4), ("lot47_paint", 2.2)]:
    shots[sid]["min"] = floor

# === ROUND THREE (the critic on round two's stills, o10: 5.5 and 5.0) ===============================
# One side of the line for the whole crowd conversation (the camera crossed it between Gus's point and
# his "Lot forty-seven": he looked left, then right): Gus's singles from the crowd's right, Kit's and the
# coat man's too. The yard wide from behind the coat man (his hat soft in front, Kit and the crowd in the
# middle, Gus on the stage: the four in one frame, so "the gentleman at the back" is somebody); Gus's
# point over his shoulder onto him; the coat man keyed short-side with a rim (he was a hole in the dark)
# and nodding on his price; his glance at Kit a two-shot with her in it. Kit keyed short-side, her
# under-fill gone. The paint's insert tight on the stripe under a raking lamp. The city from the quay's
# edge (the road and its kerb out of the frame). The car run quicker, the orbit longer. The button: Lot
# 47's lamps blink twice and come on by themselves after "Who'll start me?".
def spotw(pos, look, colour, energy, angle, rng, shadow=False, lid=None):
    return light("spot", pos, look, colour, energy, angle, rng, shadow, lid)


def omniw(pos, colour, energy, rng, lid=None):
    l = light("omni", pos, None, colour, energy, 0.0, rng, False, lid)
    l.pop("look", None)
    l.pop("angle", None)
    return l


def cam2(pos0, pos1, look, fov, handheld=0.08, follow=None, **key):
    k0 = dict({"u": 0, "pos": pos0, "look": look, "fov": fov}, **key)
    k1 = {"u": 1, "pos": pos1, "look": look, "fov": fov}
    for k_ in ("eye_light", "look_by"):
        if k_ in key:
            k1[k_] = key[k_]
    c = {"ease": "inout", "handheld": handheld, "keys": [k0, k1]}
    if follow:
        c["follow"] = follow
    return c


def drop(sh, *ids):
    sh["lights"] = [l for l in sh["lights"] if l.get("id") not in ids]


COAT = [-2.5, 1.72, 14.5]
KIT_FACE = [0.4, 1.58, 11.2]
COAT_KEY = spotw([-4.2, 2.4, 12.6], COAT, "#ffb070", 4.0, 20.0, 6.0, lid="coat_key")       # short side, warm
COAT_RIM = spotw([-1.0, 3.2, 16.8], COAT, "#9fb4ff", 4.0, 20.0, 6.0, lid="coat_rim2")      # cuts him off the wall
# the city: from the quay's edge, the water on the lower third, the towers above it
city["camera"] = {"ease": "inout", "handheld": 0.06, "keys": [
    {"u": 0, "pos": [48.0, 4.5, -126.0], "look": [535.0, 30.0, 70.0], "fov": 28, "roll": 1.5},
    {"u": 1, "pos": [46.0, 4.2, -122.5], "look": [535.0, 30.0, 70.0], "fov": 28, "roll": 0.0}]}
# the canyon: a slow follow, a cool edge on Kit, the lookouts turning to her
canyon["camera"]["keys"][1]["pos"] = [-7.4, 1.35, -65.6]
for kk in canyon["camera"]["keys"]:
    kk["look"] = [20.0, 1.6, -69.0]
drop(canyon, "kit_rim")
canyon["lights"].append(spotw([-3.5, 3.4, -68.2], [-6.0, 1.5, -66.5], "#9fb4ff", 3.0, 25.0, 6.0, lid="kit_rim"))
for pid in ("w1", "w2"):
    person(canyon, pid)["looks"] = [[0.6, 2.3, "kit"]]
# the yard: from behind the coat man, the four in one frame; the sides' containers lit; Gus keyed from the side
yard["camera"] = {"ease": "inout", "handheld": 0.1, "keys": [
    {"u": 0, "pos": [-3.4, 1.85, 16.4], "look": [0.0, 2.0, -2.6], "fov": 30, "dof": [22.0, 8.0, 0.04], "dof_near": [1.2, 0.6, 0.1]},
    {"u": 1, "pos": [-3.1, 1.8, 15.8], "look": [0.0, 2.0, -2.6], "fov": 30}]}
drop(yard, "side_l", "side_r", "gus_warm_back")
yard["lights"] += [omniw([-8.0, 3.0, 2.0], "#ffa040", 1.5, 8.0, "side_l"), omniw([8.0, 3.0, 2.0], "#7f9cff", 1.5, 8.0, "side_r"),
                   spotw([0.0, 4.6, -3.8], [0.0, 2.0, -2.6], "#ffd9a8", 2.0, 30.0, 6.0, lid="gus_warm_back")]
for l in yard["lights"]:
    if l.get("id") == "gus_key":
        l.update({"pos": [2.0, 4.0, -0.2], "energy": 3.0})
# Gus's point: over his shoulder onto the coat man (the point lands on him), the halo off
gp["camera"] = cam2([1.0, 2.6, -4.3], [0.85, 2.6, -4.1], COAT, 22, 0.08, dof=[24.0, 6.0, 0.06], dof_near=[6.0, 3.0, 0.12])
for l in gp["lights"]:
    if l.get("colour") == "#7f9cff" and l.get("pos") == [2.4, 4.0, -4.5]:
        l["energy"] = 0.8
drop(gp, "coat_key", "coat_rim2")
gp["lights"] += [COAT_KEY, COAT_RIM]
# the coat man: closer, keyed short-side with a rim, the wall under his face; a nod on his price
coat["camera"] = cam2([0.6, 1.8, 8.4], [0.55, 1.8, 8.55], COAT, 14, 0.08, dof_near=[4.5, 2.0, 0.12], dof=[9.0, 2.0, 0.1], eye_light=0.03)
drop(coat, "coat_key", "coat_rim2")
coat["lights"] += [COAT_KEY, COAT_RIM]
for l in coat["lights"]:
    if l.get("pos") == [-4.6, 3.6, 17.5]:
        l["energy"] = 1.0
    elif l.get("id") == "coat_rim":
        l["energy"] = 2.0
person(coat, "coat")["bend"] = [{"t": 0.0}, {"t": 0.8}, {"t": 1.0, "Neck": [6, 0, 0], "Head": [8, 0, 0]}, {"t": 1.3}]
# "Lot forty-seven": from the crowd's right (he looks left, as in his point), keyed on the far side, shorter
gus["camera"] = cam2([1.0, 1.7, 0.7], [0.9, 1.7, 0.5], [-0.25, 2.2, -2.6], 27, 0.12, dof=[3.6, 1.0, 0.14], eye_light=0.03)
drop(gus, "gus_far")
gus["lights"].append(spotw([-1.6, 3.2, -0.8], [0.0, 2.2, -2.6], "#ffcf99", 6.0, 25.0, 6.0, lid="gus_far"))
for l in gus["lights"]:
    if l.get("colour") == "#7f9cff" and l.get("shadow") is False:
        l["energy"] = 1.0
gus["lines"][0]["hold"] = 1.4
gus["lead"], gus["tail"] = 0.05, 0.05
gus.pop("dur", None)
gus["min"] = 1.5
# Kit hearing it: from the crowd's right (she looks right, to Gus), keyed short-side, rimmed
mcu["camera"] = cam2([1.5, 1.6, 9.9], [1.45, 1.6, 10.05], [0.3, 1.5, 11.2], 26, 0.12, dof=[1.85, 1.0, 0.12], eye_light=0.03)
drop(mcu, "kit_short", "kit_rim2")
mcu["lights"] += [spotw([-0.8, 2.5, 9.6], KIT_FACE, "#ffcf99", 3.5, 25.0, 5.0, lid="kit_short"),
                  spotw([1.4, 3.0, 13.4], KIT_FACE, "#8aa6ff", 2.0, 25.0, 5.0, lid="kit_rim2")]
for l in mcu["lights"]:
    if l.get("id") == "kit_key":
        l["energy"] = 1.0
person(mcu, "kit").pop("looks", None)
# Kit sees it: the same side, closer, short-side key and a hair rim, her under-fill gone, a bokeh behind
eyes["camera"] = cam2([1.1, 1.6, 10.35], [1.08, 1.6, 10.4], [0.35, 1.45, 11.2], 21, 0.06, dof=[1.5, 0.8, 0.12], eye_light=0.02)
drop(eyes, "car_glow_key", "kit_short", "kit_rim2", "far_bokeh")
eyes["lights"] += [spotw([-0.7, 2.3, 9.9], KIT_FACE, "#ffcf99", 3.0, 25.0, 5.0, lid="kit_short"),
                   spotw([1.2, 2.8, 12.6], KIT_FACE, "#8aa6ff", 2.0, 25.0, 5.0, lid="kit_rim2"),
                   omniw([-3.0, 3.2, 20.0], "#ffa040", 1.5, 6.0, "far_bokeh")]
# the car run: quicker inserts, a longer orbit
# (the softbox written whole: the round above keeps only the softboxes at x 4.5 and -4.5)
nose["lights"] = [l for l in nose["lights"] if not (l.get("kind") == "softbox" and l.get("pos") in ([4.5, 2.0, 2.0], [3.2, 3.4, 0.0]))] + [
    {"kind": "softbox", "pos": [3.2, 3.4, 0.0], "look": [0.0, 0.8, 2.0], "size": [7.0, 0.7], "energy": 1.5}]   # (a long strip down the hood's line)
for l in nose["lights"]:
    if l.get("kind") == "spot" and l.get("pos") == [1.5, 0.2, 4.5]:
        l.update({"pos": [2.4, 0.15, 3.2], "energy": 3.0, "angle": 25.0})
nose["lines"][0]["hold"] = 1.4
nose["min"] = 1.5
for l in wheel["lights"]:
    if l.get("kind") == "softbox" and l.get("pos") == [0.0, 5.0, 2.0]:
        l["energy"] = 0.4
drop(wheel, "tyre_rim")
wheel["lights"].append(spotw([1.4, 0.6, -0.6], [0.9, 0.35, 1.3], "#9fb4ff", 2.5, 25.0, 4.0, lid="tyre_rim"))
kit_car(wheel)["glow"] = 0.2
wheel["lines"][0]["hold"] = 1.4
wheel["min"] = 1.5
orbit["camera"]["keys"] = [{"u": 0.0, "pos": [2.0, 0.7, -4.95], "look": [0.0, 0.6, -0.3], "fov": 32},
                           {"u": 0.5, "pos": [2.8, 0.7, -4.6], "look": [0.0, 0.6, -0.3], "fov": 32},
                           {"u": 1.0, "pos": [3.4, 0.7, -4.0], "look": [0.0, 0.6, -0.3], "fov": 32}]
drop(orbit, "boot_warm")
orbit["lights"].append(spotw([-2.5, 2.4, -3.0], [0.0, 0.8, -1.9], "#ffcf99", 2.5, 30.0, 6.0, lid="boot_warm"))
orbit["min"] = 2.8
# the paint: tight on the stripe, raked along the flank, the softboxes off its glint
paint["camera"] = cam2([1.4, 0.85, 1.0], [1.4, 0.85, 0.4], [0.95, 0.82, 0.0], 22, 0.06, follow="kit", dof=[0.9, 0.4, 0.12])
paint["camera"]["keys"][0]["look"] = [0.95, 0.82, 0.3]
paint["camera"]["keys"][1]["look"] = [0.95, 0.82, -0.3]
for l in paint["lights"]:
    if l.get("kind") == "softbox" and l.get("pos") == [0.0, 5.0, 2.0]:
        l["energy"] = 0.3
    elif l.get("id") == "rake":
        l.update({"pos": [2.4, 1.0, -1.5], "look": [0.95, 0.85, 0.0], "colour": "#ffcf99", "energy": 4.0, "angle": 18.0})
paint["lines"][0]["hold"] = 1.7
paint["min"] = 1.8
paint["tail"] = 0.05
# his glance at Kit: a two-shot over her shoulder, his eyes going from Gus to her
cg["camera"] = cam2([1.0, 1.6, 9.8], [0.98, 1.6, 9.85], [-2.5, 1.65, 14.5], 18, 0.06, dof_near=[1.5, 0.8, 0.12], eye_light=0.03)
cg["lights"] = copy.deepcopy(coat["lights"])
cg["dur"] = 1.2
person(cg, "coat")["looks"] = [[0.0, 0.25, "gus"], [0.25, 1.2, "kit"]]
person(cg, "coat").pop("bend", None)
# the hero: off Gus's roofline tangent, the red car's glare down; the button: her lamps blink twice and
# come on by themselves (keyed lights in her housings, riding the car)
for kk in hero["camera"]["keys"]:
    kk["pos"][0] = 1.8
for l in hero["lights"]:
    if l.get("pos") == [-3.2, 5.5, -6.0]:
        l["energy"] = 2.0
BLINK = [[0, 0.0], [2.45, 0.0], [2.47, 4.0], [2.55, 4.0], [2.57, 0.0], [2.72, 0.0], [2.74, 4.0], [2.82, 4.0], [2.84, 0.0],
         [3.05, 0.0], [3.12, 4.0]]
drop(hero, "lamp_l", "lamp_r", "lamp_l_glow", "lamp_r_glow")
for side, lid in ((0.62, "lamp_l"), (-0.62, "lamp_r")):
    b = spotw([side, 0.68, 2.15], [side, 0.2, 9.0], "#e8f0ff", 0.0, 28.0, 10.0, lid=lid)
    b["energy"], b["car"] = BLINK, "kit"
    g = omniw([side, 0.68, 2.25], "#e8f0ff", 0.0, 0.35, lid + "_glow")
    g["energy"], g["car"] = [[t, v * 0.6] for t, v in BLINK], "kit"
    hero["lights"] += [b, g]
hero["sounds"] = [x for x in hero.get("sounds", []) if x.get("cue") != "thump"] + [{"at": 2.47, "cue": "thump", "db": -14}]

json.dump(scene, open(path, "w"), indent="\t")
