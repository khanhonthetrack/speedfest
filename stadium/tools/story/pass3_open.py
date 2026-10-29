"""(Kept in the repo.) The third pass on night 1's opening (docs/CINEMATICS.md, "third pass to 7/10"):
edits the committed scene in place, so it runs on take five's c01_open.json and again on its own
output without changing it twice.
    python3 tools/story/pass3_open.py stadium/story/scenes/c01_open.json"""
import copy, json, sys

path = sys.argv[1]
scene = json.load(open(path))
shots = {s["id"]: s for s in scene["shots"]}

# 1. the city across the water: clear air (a dark blue haze, the layers read by depth), no shot
# lights (the city lights itself), low over the water past the quay cranes (out of frame), the city
# in the harbour (a planar reflection), a quick fade up
city = shots["city"]
city["dur"] = 3.0
city["fade_in"] = 0.5
city["env"] = {"fog": 0.0003, "vol_fog": 0.0008, "reflect": 0.5}
city["lights"] = []
city["camera"] = {"ease": "inout", "keys": [
    {"u": 0, "pos": [58.0, 9.0, -135.0], "look": [520.0, 50.0, 100.0], "fov": 35, "roll": 3.0},
    {"u": 1, "pos": [52.0, 8.5, -128.0], "look": [520.0, 47.0, 100.0], "fov": 35, "roll": 0.0}], "handheld": 0.08}
city.pop("probe", None)


def light(kind, pos, look, colour, energy, angle, rng, shadow=True):
    out = {"kind": kind, "pos": pos, "look": look, "colour": colour, "energy": energy, "angle": angle, "range": rng}
    if not shadow:
        out["shadow"] = False
    return out


def line(shot, text, lid, hold=None):
    l = {"id": lid, "speaker": "Gus", "text": text}
    if hold is not None:
        l["hold"] = hold
    shot["lines"] = [l]


def person(shot, pid):
    return next(p for p in shot.get("people", []) if p["id"] == pid)


# Lot 47 on deep-dish rims (a widebody street build's; the turbines read as a toy's)
for shot in scene["shots"]:
    for c in shot.get("cars", []):
        if c.get("paint") == "lot47":
            c["tuning"] = "0.7.6.0"

# 2. the canyon: a sodium lamp on a pole ahead of Kit, in frame, rimming her (no more black cut-out)
scene["props"] = [p for p in scene["props"] if p.get("id") != "canyon_lamp"]
scene["props"].append({"kind": "pole", "id": "canyon_lamp", "pos": [12.0, 0, -69.3], "yaw": 0, "height": 4.5,
                       "energy": 7.0, "colour": "#ffa040"})
canyon = shots["canyon"]
canyon["lights"] = [l for l in canyon["lights"] if l.get("id") != "kit_rim"]
canyon["lights"].append({"id": "kit_rim", "kind": "spot", "pos": [-0.5, 3.2, -63.6], "look": [-5.0, 1.4, -66.5],
                         "colour": "#ffa040", "energy": 5.0, "angle": 30.0, "range": 10.0, "shadow": False})

# 3. the crowd: four more between the cars and the camera (the auction a crowd, not five backs), in
# every shot of the yard
EXTRAS = [{"id": "c6", "clip": "Stand_B", "pos": [-0.6, 0, 7.6], "face": 185, "start": 1.3, "who": "crowd2"},
          {"id": "c7", "clip": "Stand", "pos": [1.1, 0, 6.8], "face": 175, "start": 0.6, "who": "crowd5"},
          {"id": "c8", "clip": "Stand_Talk", "pos": [-2.3, 0, 6.9], "face": 165, "start": 2.0, "who": "crowd1"},
          {"id": "c9", "clip": "Stand", "pos": [3.4, 0, 7.7], "face": 200, "start": 1.7, "who": "crowd3"}]
for shot in scene["shots"]:
    ids = [p["id"] for p in shot.get("people", [])]
    if "c1" in ids:
        for e in EXTRAS:
            if e["id"] not in ids:
                shot["people"].append(copy.deepcopy(e))

# 4. the yard: over Kit's shoulder, craning down behind the heads onto Gus (the depth in the
# parallax), the line cut at the dash: the rest goes with Gus pointing
yard = shots["yard"]
line(yard, "Lot forty-six, no reserve...", "c01_open_001")
yard["camera"] = {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [1.05, 2.9, 12.9], "look": [0.4, 1.75, -2.6], "fov": 28, "dof_near": [1.2, 0.6, 0.04], "dof": [15.0, 8.0, 0.04]},
    {"u": 1, "pos": [0.95, 1.72, 12.55], "look": [0.4, 1.95, -2.6], "fov": 28}]}

# 5. Gus points the gentleman out: his head comes round, his arm goes out to the back of the crowd
if "gus_points" not in shots:
    gp = copy.deepcopy(shots["gus"])
    gp["id"] = "gus_points"
    scene["shots"].insert([x["id"] for x in scene["shots"]].index("coat"), gp)
    shots["gus_points"] = gp
gp = shots["gus_points"]
line(gp, "...gone to the gentleman at the back...", "c01_open_001a", hold=2.4)
gp["lead"], gp["tail"] = 0.3, 0.2
gp["camera"] = {"ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [2.4, 1.9, 4.0], "look": [-0.1, 2.15, -2.6], "fov": 16, "dof": [7.0, 4.0, 0.1]},
    {"u": 1, "pos": [2.2, 1.9, 3.5], "look": [-0.15, 2.15, -2.6], "fov": 16}]}
gp["lights"] = [light("spot", [0.0, 11.0, -16.0], [0.0, 0.0, 6.0], "#7f9cff", 6.0, 50.0, 40.0),
                light("spot", [0.0, 10.0, 22.0], [0.0, 0.0, 8.0], "#7f9cff", 2.5, 45.0, 30.0),
                light("spot", [-1.6, 3.5, -0.6], [0.0, 2.2, -2.6], "#ffcf99", 6.0, 25.0, 8.0)]
g = person(gp, "gus")
g["gaze"] = "coat"
g["bend"] = [{"t": 0.0, "Head": [0, 16, 0], "Neck": [0, 6, 0], "Chest": [0, 4, 0]},
             {"t": 0.7, "Head": [-2, -5, 0], "Neck": [0, -3, 0], "Chest": [0, -5, 0]}]
POINT = {"at": [-0.27, 2.125, -2.06], "palm": [0.0, -1.0, 0.0], "fingers": [-0.134, 0.1, 0.986],
         "elbow": [-0.5, -1.0, 0.0], "fist": 0.85, "point": True}
g["reach"] = [{"t": 0.25}, {"t": 0.95, "RightHand": POINT}, {"t": 5.0, "RightHand": POINT}]

# 6. the coat man, reversed from the stage over the crowd's heads: he nods; a sodium lamp keys him
coat = shots["coat"]
coat["camera"] = {"ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [-1.6, 2.05, 5.2], "look": [-2.5, 1.62, 14.5], "fov": 22, "dof_near": [6.5, 2.5, 0.12], "dof": [9.4, 3.0, 0.12]},
    {"u": 1, "pos": [-1.68, 2.0, 5.55], "look": [-2.5, 1.62, 14.5], "fov": 22}]}
coat["lights"] = [light("spot", [0.0, 11.0, -16.0], [0.0, 0.0, 6.0], "#7f9cff", 4.0, 50.0, 40.0),
                  light("spot", [0.0, 10.0, 22.0], [0.0, 0.0, 8.0], "#7f9cff", 8.0, 45.0, 30.0),
                  light("spot", [-4.6, 3.6, 12.4], [-2.5, 1.6, 14.5], "#ff9a40", 5.0, 30.0, 8.0)]
cm = person(coat, "coat")
cm["gaze"] = "gus"
cm["bend"] = [{"t": 0.0}, {"t": 0.45}, {"t": 0.75, "Head": [9, 0, 0]}, {"t": 1.2, "Head": [1, 0, 0]}]

# 7. Gus on "Lot forty-seven": keyed from the far side at 3:1, the front fill down, quicker
gus = shots["gus"]
line(gus, "Lot forty-seven.", "c01_open_001b", hold=1.5)
gus["lead"], gus["tail"], gus["dur"] = 0.15, 0.2, 1.9
gus["lights"] = [light("spot", [0.0, 11.0, -16.0], [0.0, 0.0, 6.0], "#7f9cff", 5.0, 50.0, 40.0),
                 light("spot", [0.0, 10.0, 22.0], [0.0, 0.0, 8.0], "#7f9cff", 3.0, 45.0, 30.0),
                 light("spot", [1.2, 3.6, -1.0], [0.0, 2.1, -2.6], "#ffcf99", 6.0, 25.0, 8.0)]

# 8. Kit's medium close-up: the light of her close-up (the underglow under her, a cool back rim), no
# blink on the cut, shorter
mcu = shots["kit_mcu"]
mcu["dur"] = 1.3
mcu["lights"] = copy.deepcopy(shots["kit_eyes"]["lights"])
person(mcu, "kit")["blink"] = False

# 9. the wheel: no hot spot on the wing at the end
for l in shots["lot47_wheel"]["lights"]:
    if l.get("kind") == "spot" and l.get("colour") == "#9fb4ff":
        l["energy"] = 1.2

# 10. the orbit on the cameras' side of the car (no crossing the line), ending before Lot 48 slides in
shots["lot47_orbit"]["camera"]["keys"] = [
    {"u": 0.0, "pos": [1.5, 0.9, -4.95], "look": [0.0, 0.6, -0.3], "fov": 32},
    {"u": 0.5, "pos": [2.3, 0.95, -4.7], "look": [0.0, 0.6, -0.3], "fov": 32},
    {"u": 1.0, "pos": [3.0, 1.0, -4.2], "look": [0.0, 0.6, -0.3], "fov": 32}]

# 11. "Engine's sweet" over a bonnet insert, the paint line on its own (3.5 s, not 5.3)
if "lot47_bonnet" not in shots:
    bn = copy.deepcopy(shots["lot47_paint"])
    bn["id"] = "lot47_bonnet"
    scene["shots"].insert([x["id"] for x in scene["shots"]].index("lot47_paint"), bn)
    shots["lot47_bonnet"] = bn
bn = shots["lot47_bonnet"]
line(bn, "Engine's sweet.", "c01_open_003a")
bn["lead"], bn["tail"] = 0.2, 0.2
bn["lights"] = [l for l in bn["lights"] if l.get("kind") != "spot" or l.get("colour") != "#ffe2b8"]
bn["camera"] = {"follow": "kit", "ease": "out", "handheld": 0.08, "keys": [
    {"u": 0, "pos": [0.65, 1.08, 5.0], "look": [0.0, 0.84, 2.8], "fov": 28, "dof": [2.3, 1.2, 0.12]},
    {"u": 1, "pos": [0.55, 1.03, 4.7], "look": [0.0, 0.84, 2.8], "fov": 28}]}
paint = shots["lot47_paint"]
line(paint, "Somebody painted her by hand. Look at that.", "c01_open_003", hold=3.0)

# 12. the hero: the stage's floodlight behind Lot 47's roof, not a blob over it
shots["lot47_hero"]["camera"]["keys"] = [
    {"u": 0, "pos": [0.35, 0.28, 7.4], "look": [0.0, 0.6, 0.5], "fov": 30, "dof": [9.0, 6.0, 0.06]},
    {"u": 1, "pos": [0.35, 0.3, 6.2], "look": [0.0, 0.62, 0.5], "fov": 30}]

# 13. an eye light on the faces (a catchlight, a touch on the skin: the cast's own layer)
for sid, e in [("gus_points", 0.15), ("coat", 0.15), ("gus", 0.2), ("kit_mcu", 0.2), ("kit_eyes", 0.2)]:
    for k in shots[sid]["camera"]["keys"]:
        k["eye_light"] = e

json.dump(scene, open(path, "w"), indent="\t")
