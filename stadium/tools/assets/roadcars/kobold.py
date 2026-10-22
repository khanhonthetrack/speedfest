"""Kobold SS: a supercharged compact coupe of the mid 2000s: a chrome-barred grille over a wide
mesh mouth, big swept headlights, a smooth arcing roof into a short trunk and a tall wing on
stanchions (our own; the class of car NFS Most Wanted's garage opened with)."""
from roadcars._util import circle, ellipse, rect

L = 4.585
SPEC = {
    "id": "kobold", "name": "Kobold SS",
    "length": L, "wheelbase": 2.624, "front_overhang": 0.93, "track": (1.493, 1.483),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.20, the backlight's at 4.0,
    # the wing over 4.12-4.50
    "fit": {"cowl": 1.20, "deck": 4.0, "wing": [4.12, 4.50]},
    "tyre": {"r": (0.32, 0.32), "w": (0.225, 0.225), "rim_r": 0.2286, "rim": "five", "spokes": 5, "dish": 0.028},
    "body": {
        "floor": 0.155,
        "curves": {
            "top": [(0.0, 0.70), (0.15, 0.745), (0.5, 0.815), (0.9, 0.87), (1.25, 0.915), (2.0, 0.95), (3.0, 0.98), (3.70, 1.015),
                    (4.1, 1.03), (4.45, 1.02), (L, 0.99)],
            "edge_x": [(0.0, 0.56), (0.3, 0.63), (0.9, 0.66), (1.25, 0.70), (1.6, 0.765), (3.3, 0.775), (3.8, 0.745), (4.3, 0.70),
                       (L, 0.64)],
            "edge_y": [(0.0, 0.68), (0.15, 0.725), (0.5, 0.795), (0.9, 0.85), (1.25, 0.895), (1.6, 0.92), (3.0, 0.96), (3.7, 0.995),
                       (4.1, 1.01), (4.45, 1.0), (L, 0.97)],
            "sh_x": [(0.0, 0.68), (0.3, 0.80), (0.8, 0.845), (1.3, 0.85), (2.5, 0.85), (3.4, 0.855), (4.0, 0.84), (4.4, 0.81), (L, 0.75)],
            "sh_y": [(0.0, 0.64), (0.3, 0.73), (0.8, 0.81), (1.3, 0.85), (2.0, 0.875), (3.0, 0.905), (3.6, 0.935), (4.2, 0.955),
                     (L, 0.94)],
            "side_x": [(0.0, 0.76), (0.3, 0.835), (0.8, 0.862), (2.0, 0.858), (3.4, 0.862), (4.1, 0.85), (L, 0.78)],
            "side_y": [(0.0, 0.47), (1.0, 0.62), (2.2, 0.62), (3.5, 0.66), (L, 0.68)],
            "rk_x": [(0.0, 0.72), (0.4, 0.82), (1.0, 0.832), (3.4, 0.842), (L, 0.76)],
            "rk_y": [(0.0, 0.27), (1.0, 0.27), (3.4, 0.29), (L, 0.38)],
            "fl_x": [(0.0, 0.60), (0.5, 0.74), (1.0, 0.77), (3.5, 0.77), (L, 0.68)],
            "floor_y": [(0.0, 0.22), (0.5, 0.18), (0.9, 0.16), (3.8, 0.16), (4.2, 0.22), (L, 0.27)],
        },
        "radii": {"edge": 0.04, "sh": 0.05, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"edge_sh": 0.005, "sh_side": 0.024, "side_rk": 0.018},
        "front": {"yc": 0.46, "plan": (0.36, 3.4), "top": (0.16, 2.9), "bottom": (0.12, 2.9)},
        "rear": {"yc": 0.72, "plan": (0.16, 4.0), "top": (0.05, 3.0), "bottom": (0.12, 3.0)},
    },
    "cabin": {
        "d0": 1.12, "d1": 4.06,
        "curves": {
            "top": [(1.12, 0.95), (4.06, 1.10)],
            "rail_x": [(1.12, 0.64), (1.5, 0.62), (2.1, 0.575), (2.6, 0.58), (3.1, 0.60), (3.6, 0.65), (4.06, 0.70)],
            "base_x": [(1.12, 0.69), (1.45, 0.745), (1.8, 0.765), (3.3, 0.765), (3.7, 0.74), (4.06, 0.71)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.06},
    },
    "arches": {"r": [0.346, 0.346], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.62, 1.30), (0.62, 1.30), (0.53, 2.12), (-0.53, 2.12)], "radii": [0.04, 0.04, 0.07, 0.07]},
        # the door glass (the mirror's sail ahead of it) and the quarter glass behind the slanted B-pillar
        {"plane": "side", "outline": [(1.62, 0.955), (1.95, 1.245), (2.25, 1.315), (2.75, 1.31), (2.66, 0.995)],
         "radii": [0.02, 0.12, 0.08, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.85, 1.005), (2.89, 1.30), (3.20, 1.25), (3.50, 1.155), (3.62, 1.085)],
         "radii": [0.02, 0.03, 0.12, 0.06, 0.03], "mirror": True},
        {"plane": "top", "outline": [(-0.53, 3.22), (0.53, 3.22), (0.64, 3.86), (-0.64, 3.86)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.65, 0.99), (2.86, 1.0), (2.90, 1.32), (2.75, 1.32)], "radii": [0.01] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.48, 0.93), (1.63, 0.955), (1.68, 1.04)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        # the side markers behind the rear wheels
        {"plane": "side", "outline": [(4.10, 0.705), (4.26, 0.71), (4.26, 0.745), (4.10, 0.74)], "radii": [0.012] * 4, "mat": "lens_red",
         "mirror": True},
    ],
    "insets": [
        # big swept headlights: a projector inboard, a larger one outboard, the indicator along the bottom
        {"plane": "front", "ray": (-0.3, -0.3, -1), "outline": [(0.50, 0.64), (0.62, 0.625), (0.78, 0.635), (0.86, 0.67), (0.885, 0.745),
                                                               (0.83, 0.81), (0.64, 0.79), (0.52, 0.74)],
         "radii": [0.02, 0.05, 0.05, 0.03, 0.04, 0.05, 0.05, 0.03], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens",
         "mirror": True,
         "elements": [("projector", (0.64, 0.71), 0.042, "proj"), ("projector", (0.79, 0.735), 0.052, "proj"),
                      ("strip", [(0.56, 0.655), (0.74, 0.648)], 0.012, "amber")]},
        # fog lamps in slatted pods at the bumper's corners
        {"plane": "front", "outline": [(0.50, 0.285), (0.85, 0.285), (0.86, 0.39), (0.51, 0.39)], "radii": [0.03, 0.04, 0.04, 0.03],
         "depth": 0.045, "mats": ("grille", "trim"), "mirror": True,
         "elements": [("projector", (0.785, 0.337), 0.045, "proj"), ("strip", [(0.53, 0.315), (0.72, 0.315)], 0.012, "trim"),
                      ("strip", [(0.53, 0.36), (0.72, 0.36)], 0.012, "trim")]},
        # round tail lamps: one in each quarter, one in the lid
        {"plane": "rear", "ray": (-0.4, 0, 1), "outline": circle(0.79, 0.845, 0.088, 28), "depth": 0.035, "mats": ("lamp", "trim"),
         "cover": "lens_red", "mirror": True,
         "elements": [("ring", (0.79, 0.845), 0.075, 0.05, "light"), ("disc", (0.79, 0.845), 0.028, "lamp")]},
        {"plane": "rear", "outline": circle(0.52, 0.845, 0.082, 28), "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red",
         "mirror": True, "elements": [("ring", (0.52, 0.845), 0.07, 0.046, "light"), ("disc", (0.52, 0.845), 0.026, "lamp")]},
        {"plane": "rear", "outline": rect(-0.26, 0.29, 0.26, 0.53), "radii": [0.03] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.18, 0.32, 0.18, 0.48), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the upper grille between the lamps, split by a body-coloured bar; the wide lower mouth
        {"plane": "front", "ray": (0, -0.3, -1), "outline": [(-0.43, 0.585), (0.43, 0.585), (0.46, 0.68), (0.42, 0.755), (-0.42, 0.755), (-0.46, 0.68)],
         "radii": [0.03, 0.03, 0.03, 0.03, 0.03, 0.03], "depth": 0.06, "mats": ("grille", "trim"),
         "bars": {"y": [0.70], "mat": "paint", "t": 0.034}},
        {"plane": "front", "outline": [(-0.39, 0.24), (0.39, 0.24), (0.41, 0.385), (-0.41, 0.385)], "radii": [0.04, 0.04, 0.03, 0.03],
         "depth": 0.08, "mats": ("grille", "trim"), "bars": {"y": [0.29, 0.335], "mat": "trim", "t": 0.01}},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.43, 0.93), (1.38, 0.6), (1.42, 0.31), (2.80, 0.31), (2.84, 0.7), (2.80, 0.995)]},
        {"plane": "top", "line": [(-0.69, 1.20), (-0.72, 0.6), (-0.60, 0.13), (0.60, 0.13), (0.72, 0.6), (0.69, 1.20)], "mirror": False},
        {"plane": "top", "line": [(-0.66, 3.98), (-0.70, 4.50), (0.70, 4.50), (0.66, 3.98)], "mirror": False},
        {"plane": "side", "line": circle(3.85, 0.85, 0.055, 24), "closed": True, "mirror": False},
    ],
    # the tall wing on two stanchions
    "wings": [{"span": 0.74, "chord": 0.30, "d": 4.16, "y": 1.16, "pitch": 0.08,
               "uprights": [{"x": 0.50, "outline": [(4.20, 1.06), (4.34, 1.06), (4.32, 1.18), (4.24, 1.18)], "radii": [0, 0, 0.03, 0.03]}]}],
    "handles": [(2.60, 0.81)],
    "mirrors": [{"base": (0.77, 1.56, 0.96), "size": (0.16, 0.10, 0.12), "reach": 0.04}],
    "exhausts": [{"at": (0.60, 0.215, L - 0.08), "r": 0.048, "length": 0.14, "mirror": False}],
    "wipers": {"d": 1.28, "x": [0.44, -0.08], "len": 0.5, "dir": -1},
}
