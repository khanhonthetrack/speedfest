"""(Kept in the repo: regenerates take five's scene from take four's, `git show 131d50f:stadium/story/scenes/<file>`; the Mirror: take5_mirror.py, then take5_mirror2.py, then take5_knock.py.)
Take five's opening (docs/CINEMATICS.md, first pass items 3 and 6): the yard on a dark, wet quay
("bare": "set": the docks set's props, the city across the water), lit on purpose (the stage's truss,
sodium masts with black between, a cool backlight over the auction, a fire), and re-cut: the city,
a pass down a container canyon, the yard at eye level, Gus and Kit in medium close-up, Lot 47 in
four different moves under softboxes; the later shots keep their cutting, on the new set and light.
    python3 intro.py <take4 c01_open.json> <out.json>"""
import copy, json, math, sys

src = json.load(open(sys.argv[1]))
old = {s["id"]: s for s in src["shots"]}
ids = [s["id"] for s in src["shots"]]
later = src["shots"][ids.index("phone"):]

# --- the set -----------------------------------------------------------------------------------
props = [{"kind": "quay", "rect": [-420, -150, 64, 420], "edges": ["x1", "z0"], "water": 700,
          "paint": [[-11, -6, -11, 30, 0.15, "#d9a31e"], [11, -6, 11, 30, 0.15, "#d9a31e"],
                    [-11, -6, 11, -6, 0.15, "#d9a31e"], [-5.25, -0.6, -5.25, 4.8, 0.1, "#c8c8c0"],
                    [-1.75, -0.6, -1.75, 4.8, 0.1, "#c8c8c0"], [1.75, -0.6, 1.75, 4.8, 0.1, "#c8c8c0"],
                    [5.25, -0.6, 5.25, 4.8, 0.1, "#c8c8c0"], [-40, 60, 40, 60, 0.2, "#d9a31e"]]}]
for p in src["props"]:
    q = copy.deepcopy(p)
    if q["kind"] == "mast":
        q["colour"] = "#ff9d3c"
        q["energy"] = 14.0
    if q["kind"] == "pole":
        q["colour"] = "#cfd8ff"
        q["energy"] = 8.0
    props.append(q)
props += [
    {"kind": "sts_crane", "pos": [64, 0, -70], "height": 40, "outreach": 48},
    {"kind": "sts_crane", "pos": [64, 0, -15], "height": 40, "outreach": 48, "colour": "#c8c8c4"},
    {"kind": "sts_crane", "pos": [64, 0, 55], "height": 40, "outreach": 48},
    {"kind": "warehouse", "pos": [-25, 0, 88], "size": [60, 10, 26], "doors": 5, "lit": [1, 3]},
    {"kind": "warehouse", "pos": [-100, 0, 88], "size": [60, 10, 26], "doors": 5, "lit": [2], "colour": "#3f4a52"},
    {"kind": "portacabin", "pos": [-13, 0, -7], "yaw": 25, "sign": "PELL SALVAGE"},
    {"kind": "stage", "pos": [0, 0, -3.6], "size": [5, 2.4], "height": 0.5, "energy": 4.5},
    {"kind": "barrel", "pos": [5.6, 0, 12.6]},
    {"kind": "fence", "from": [-30, 60], "to": [30, 60], "height": 2.6},
]
RIG = [  # the yard's own light, besides the props' (masts, poles, the truss's lamps, the fire): a cold
    # backlight from behind the containers (rims heads and roofs, makes the rain read), another behind
    # the crowd for the reverses
    {"kind": "spot", "pos": [0.0, 11.0, -16.0], "look": [0.0, 0.0, 6.0], "colour": "#7f9cff", "energy": 14.0, "range": 40.0,
     "angle": 50.0},
    {"kind": "spot", "pos": [0.0, 10.0, 22.0], "look": [0.0, 0.0, 8.0], "colour": "#7f9cff", "energy": 8.0, "range": 30.0,
     "angle": 45.0},
]
CAR_SHINE = [  # softboxes over and beside Lot 47 (the car stands at z 2), seen only in its paint
    {"kind": "softbox", "pos": [0.0, 5.0, 2.0], "look": [0.0, 0.0, 2.0], "size": [0.5, 7.0], "energy": 0.9},
    {"kind": "softbox", "pos": [0.5, 0.6, 7.5], "look": [0.0, 0.4, 2.0], "size": [3.0, 0.5], "energy": 0.6},
    {"kind": "softbox", "pos": [4.5, 2.0, 2.0], "look": [0.0, 0.8, 2.0], "size": [7.0, 0.7], "energy": 1.5},
    {"kind": "softbox", "pos": [-4.5, 2.0, 2.0], "look": [0.0, 0.8, 2.0], "size": [7.0, 0.7], "energy": 1.5},
]
PROBE = {"pos": [0.0, 2.0, 2.0], "size": [18.0, 9.0, 18.0]}
ENV = {"height_fog": [3.0, 0.04]}


def people(gus_on_stage=True):
    out = copy.deepcopy(old["yard"]["people"])
    for p in out:
        if p["id"] == "gus" and gus_on_stage:
            p["pos"] = [0.0, 0.5, -2.6]
        if p["id"] == "c4":
            p["pos"] = [2.7, 0, 12.2]
            p["face"] = 200
    return out


def base(sid, camera, **kw):
    s = {"id": sid, "track": "H01", "at": 0.03, "rain": 0.75, "ambience": "rain", "env": copy.deepcopy(ENV),
         "cars": copy.deepcopy(old["yard"]["cars"]), "people": people(), "lights": copy.deepcopy(RIG), "camera": camera}
    s.update(kw)
    return s


def line(lid, text, speaker="Gus", **kw):
    l = {"id": lid, "speaker": speaker, "text": text}
    l.update(kw)
    return l


def orbit(r, h, deg, centre=(0.0, 0.0)):
    a = math.radians(deg)
    return [round(centre[0] + r * math.sin(a), 3), h, round(centre[1] + r * math.cos(a), 3)]


shots = []
# 1. the city across the water, the title in the left third
city = copy.deepcopy(old["city"])
city["dur"] = 4.0
city["env"] = {"fog": 0.003, "fog_colour": "#5a3040", "fog_sky": 0.4, "height_fog": [35.0, 0.03]}
city["camera"] = {"ease": "inout", "keys": [
    {"u": 0, "pos": [60.0, 22.0, -95.0], "look": [520.0, 110.0, 140.0], "fov": 35, "roll": 3.0},
    {"u": 1, "pos": [52.0, 15.0, -88.0], "look": [520.0, 104.0, 140.0], "fov": 35, "roll": 0.0}], "handheld": 0.08}
city["lights"] = [{"kind": "omni", "pos": [480.0, 40.0, 160.0], "colour": "#ff8a40", "energy": 10.0, "range": 450.0, "shadow": False},
                  {"kind": "omni", "pos": [300.0, 60.0, 220.0], "colour": "#6f8cff", "energy": 4.0, "range": 300.0, "shadow": False}]
city["dur"] = 3.5
city["rain"] = 0.3
city["card"] = {"title": "Night 1", "subtitle": "The Yard", "align": "left"}
shots.append(city)
# 2. down a canyon of containers, low, the height fog lying in it
shots.append(base("canyon", {"ease": "linear", "handheld": 0.3, "keys": [
    {"u": 0, "pos": [-9.0, 1.7, -65.2], "look": [20.0, 1.5, -66.5], "fov": 35},
    {"u": 1, "pos": [-6.6, 1.65, -65.2], "look": [22.0, 1.5, -66.5], "fov": 35}]}, dur=2.5,
    people=[{"id": "kit", "who": "kit", "clip": "Walk", "pos": [-6.0, 0.0, -66.5], "path": [[-6.0, -66.5], [6.0, -66.5]],
             "walk_at": 0.0}],
    lights=[{"kind": "spot", "pos": [-28.0, 7.5, -63.5], "look": [-28.0, 0.0, -66.5], "colour": "#ffa040", "energy": 6.0,
             "angle": 60.0, "range": 12.0, "shadow": False},
            {"kind": "spot", "pos": [-2.0, 7.5, -69.5], "look": [-2.0, 0.0, -66.5], "colour": "#ffa040", "energy": 6.0,
             "angle": 60.0, "range": 12.0, "shadow": False},
            {"kind": "spot", "pos": [55.0, 12.0, -66.5], "look": [-30.0, 0.0, -66.5], "colour": "#9fb4ff", "energy": 7.0,
             "angle": 22.0, "range": 90.0}]))
# 3. the yard at eye level, behind the crowd, their backs soft in front
yard = base("yard", {"ease": "inout", "handheld": 0.2, "keys": [
    {"u": 0, "pos": [-1.9, 2.2, 14.2], "look": [0.4, 1.3, -1.0], "fov": 28, "dof_near": [1.6, 0.8, 0.1], "dof": [20.0, 8.0, 0.1]},
    {"u": 1, "pos": [-1.6, 2.15, 13.6], "look": [0.4, 1.3, -1.0], "fov": 28}]},
    lines=[line("c01_open_001", "Lot forty-six, no reserve, gone to the gentleman at the back...")], lead=0.3, tail=0.2)
yard["lights"][0]["energy"] = 8.0
yard["lights"].append({"kind": "spot", "pos": [1.8, 3.0, 13.8], "look": [0.4, 1.7, 11.2], "colour": "#ffa040", "energy": 5.0,
                       "angle": 15.0, "range": 6.0})
for p in yard["people"]:
    if p["id"] == "c4":
        p["face"] = 180
shots.append(yard)
# the gentleman at the back: the coat man, alone at the crowd's edge
shots.append(base("coat", {"ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [-3.6, 1.7, 11.8], "look": [-2.5, 1.65, 14.5], "fov": 32, "dof": [4.5, 3.0, 0.12]},
    {"u": 1, "pos": [-3.62, 1.7, 11.9], "look": [-2.5, 1.65, 14.5], "fov": 32}]},
    lines=[line("c01_open_001c", "...for twelve hundred.")], lead=0.1, tail=0.3))
# 4. Gus on the stage, from a little below
gus_shot = base("gus", {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [-0.75, 1.75, 0.5], "look": [0.0, 2.15, -2.6], "fov": 26, "dof": [5.0, 4.0, 0.1]},
    {"u": 1, "pos": [-0.62, 1.75, 0.3], "look": [0.0, 2.15, -2.6], "fov": 26}]},
    lines=[line("c01_open_001b", "Lot forty-seven.")], lead=0.4, tail=0.6)
gus_shot["lights"][0]["energy"] = 5.0
gus_shot["lights"].append({"kind": "spot", "pos": [1.2, 3.6, -1.0], "look": [0.0, 2.1, -2.6], "colour": "#ffcf99", "energy": 4.0,
                           "angle": 25.0, "range": 8.0})
for p in gus_shot["people"]:
    if p["id"] == "gus":
        p["bend"] = [{"t": 0.0, "Head": [4, 0, 0]}]
shots.append(gus_shot)
# 5. Kit in the crowd: the eyes on the car
KIT_LIGHT = [{"kind": "spot", "pos": [1.8, 4.2, 7.6], "look": [0.4, 1.6, 11.2], "colour": "#ffcf99", "energy": 5.0, "angle": 18.0,
              "range": 9.0},
             {"kind": "spot", "pos": [-1.4, 3.0, 13.6], "look": [0.4, 1.7, 11.2], "colour": "#8aa6ff", "energy": 4.0, "angle": 20.0,
              "range": 7.0}]
kit_shot = base("kit_mcu", {"ease": "inout", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [-0.45, 1.6, 9.6], "look": [0.76, 1.62, 11.2], "fov": 30, "dof": [1.85, 1.0, 0.12]},
    {"u": 1, "pos": [-0.42, 1.6, 9.75], "look": [0.76, 1.62, 11.2], "fov": 30}]}, dur=1.6)
kit_shot["lights"] += copy.deepcopy(KIT_LIGHT)
for p in kit_shot["people"]:
    if p["id"] == "kit":
        p["bend"] = [{"t": 0.0, "Head": [-3, 0, 0]}]
shots.append(kit_shot)


def car_shot(sid, camera, lines, sweep=None, **kw):
    opts = {"lead": 0.3, "tail": 0.4}
    opts.update(kw)
    s = base(sid, camera, lines=lines, probe=copy.deepcopy(PROBE), **opts)
    s["lights"] += copy.deepcopy(CAR_SHINE)
    if sweep:
        s["lights"].append(sweep)
    return s


L = {l["id"]: l for s in src["shots"] for l in s.get("lines", [])}
# 6-10. Lot 47: four different moves
shots.append(car_shot("lot47_nose", {"follow": "kit", "ease": "out", "handheld": 0.15, "keys": [
    {"u": 0, "pos": [2.2, 0.4, 5.2], "look": [0.3, 0.72, 1.4], "fov": 30, "dof": [6.0, 4.0, 0.08]},
    {"u": 1, "pos": [1.5, 0.42, 4.6], "look": [0.2, 0.74, 1.3], "fov": 30}]}, [copy.deepcopy(L["c01_open_002"])]))
wheel = car_shot("lot47_wheel", {"follow": "kit", "ease": "inout", "keys": [
    {"u": 0, "pos": [1.9, 0.35, 2.6], "look": [0.85, 0.35, 1.3], "fov": 28, "dof": [1.8, 1.0, 0.12]},
    {"u": 1, "pos": [1.95, 0.42, 3.5], "look": [0.85, 0.45, 0.0], "fov": 28, "dof": [3.6, 2.0, 0.1]}]},
    [copy.deepcopy(L["c01_open_002b"])], lead=0.2, tail=0.3)
for l in wheel["lights"]:
    if l.get("kind") == "softbox" and l["pos"][0] < -4.0:
        l["pos"] = [-2.0, 2.0, 2.0]        # between the cars, on the side we see
wheel["lights"].append({"kind": "spot", "pos": [3.6, 1.0, 2.0], "look": [0.85, 0.4, 3.3], "colour": "#9fb4ff", "energy": 2.0,
                        "angle": 25.0, "range": 8.0})
shots.append(wheel)
shots.append(car_shot("lot47_orbit", {"follow": "kit", "path": "spline", "ease": "inout", "keys": [
    {"u": 0.0, "pos": orbit(5.2, 0.9, 200), "look": [0.0, 0.6, -0.3], "fov": 32},
    {"u": 0.5, "pos": orbit(5.2, 0.95, 212), "look": [0.0, 0.6, -0.3], "fov": 32},
    {"u": 1.0, "pos": orbit(5.2, 1.0, 225), "look": [0.0, 0.6, -0.3], "fov": 32}]}, [copy.deepcopy(L["c01_open_002c"])]))
# Kit's eyes on the car: the beat that tells the story (she wants it)
eyes = base("kit_eyes", {"ease": "inout", "handheld": 0.1, "keys": [
    {"u": 0, "pos": [-0.6, 1.35, 10.0], "look": [0.4, 1.6, 11.2], "fov": 24, "dof": [1.6, 0.8, 0.14]},
    {"u": 1, "pos": [-0.58, 1.36, 10.08], "look": [0.4, 1.6, 11.2], "fov": 24}]}, dur=1.2)
eyes["lights"] += copy.deepcopy(KIT_LIGHT[1:]) + [{"kind": "omni", "pos": [0.4, 0.6, 10.4], "colour": "#9a5bff", "energy": 1.5,
                                                    "range": 2.0, "shadow": False}]
shots.append(eyes)
paint = car_shot("lot47_paint", {"follow": "kit", "ease": "inout", "handheld": 0.12, "keys": [
    {"u": 0, "pos": [1.9, 1.0, 0.2], "look": [0.95, 0.8, -1.4], "fov": 32, "dof": [3.0, 2.0, 0.12]},
    {"u": 1, "pos": [1.9, 0.95, -0.4], "look": [0.95, 0.8, -1.4], "fov": 32}]}, [copy.deepcopy(L["c01_open_003"])],
    lead=0.2, tail=0.3)
paint["lights"].append({"kind": "spot", "pos": [3.2, 1.3, 0.5], "look": [0.95, 0.75, 1.3], "colour": "#ffe2b8", "energy": 4.0,
                        "angle": 14.0, "range": 6.0})
shots.append(paint)
hero = car_shot("lot47_hero", {"follow": "kit", "ease": "out", "keys": [
    {"u": 0, "pos": [0.0, 0.35, 7.4], "look": [0.0, 0.62, 0.5], "fov": 30, "dof": [9.0, 6.0, 0.06]},
    {"u": 1, "pos": [0.0, 0.4, 6.2], "look": [0.0, 0.64, 0.5], "fov": 30}]}, [copy.deepcopy(L["c01_open_003b"])],
    sweep={"kind": "spot", "pos": [-6.5, 2.4, 4.5], "look": [-2.2, 0.6, 2.0], "look_to": [2.2, 0.6, 2.0],
           "colour": "#e8eeff", "energy": 4.0, "range": 16.0, "angle": 16.0}, tail=0.9)
hero["lights"].append({"kind": "spot", "pos": [0.0, 6.5, -7.0], "look": [0.0, 2.0, -2.6], "colour": "#9fb4ff", "energy": 8.0,
                       "angle": 18.0, "range": 10.0})        # Gus a silhouette, a cone in the haze behind him
shots.append(hero)

# the later shots: the same set and light
for s in later:
    s = copy.deepcopy(s)
    s["lights"] = copy.deepcopy(RIG) + [l for l in s.get("lights", []) if l.get("car")]
    s["env"] = copy.deepcopy(ENV)
    for p in s.get("people", []):
        if p.get("id") == "gus":
            p["pos"] = [p["pos"][0], 0.5, p["pos"][2]] if abs(p["pos"][2] + 2.6) < 0.5 else p["pos"]
    shots.append(s)

out = copy.deepcopy(src)
out["bare"] = "set"
out["grade"] = "night"
out["props"] = props
out["shots"] = shots
json.dump(out, open(sys.argv[2], "w"), indent="\t")
print("opening: %d shots" % len(shots))
