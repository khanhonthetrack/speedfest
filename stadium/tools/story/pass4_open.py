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

json.dump(scene, open(path, "w"), indent="\t")
