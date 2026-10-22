"""Albion GT: a British V12 grand tourer: a long hood over a wide barred grille, swept headlights, a
strake behind each front wheel, a low teardrop glasshouse in chrome, strong rear haunches and a
duck tail over slim lamps (our own; the class of car NFS Most Wanted's Blacklist #3 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.71
SPEC = {
    "id": "albion", "name": "Albion GT",
    "length": L, "wheelbase": 2.74, "front_overhang": 0.95, "track": (1.57, 1.56),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.50, the long backlight's at
    # 4.20, the duck tail on the measured deck
    "fit": {"cowl": 1.50, "deck": 4.20},
    "tyre": {"r": (0.3295, 0.3378), "w": (0.235, 0.275), "rim_r": 0.2413, "rim": "multi", "spokes": 10, "dish": 0.03},
    "body": {
        "floor": 0.135,
        "curves": {
            "top": [(0.0, 0.64), (0.15, 0.68), (0.6, 0.76), (1.2, 0.85), (1.72, 0.92), (2.4, 0.95), (3.5, 0.97), (3.95, 0.985),
                    (4.45, 1.0), (L, 0.97)],
            "edge_x": [(0.0, 0.56), (0.3, 0.64), (1.0, 0.68), (1.7, 0.72), (2.1, 0.78), (3.5, 0.79), (4.0, 0.78), (4.5, 0.74), (L, 0.68)],
            "edge_y": [(0.0, 0.63), (0.15, 0.67), (0.6, 0.75), (1.2, 0.835), (1.72, 0.90), (2.1, 0.92), (3.5, 0.95), (3.95, 0.97),
                       (4.45, 0.985), (L, 0.955)],
            "sh_x": [(0.0, 0.70), (0.3, 0.84), (0.95, 0.90), (1.7, 0.87), (2.6, 0.865), (3.4, 0.89), (3.8, 0.905), (4.3, 0.87), (L, 0.80)],
            "sh_y": [(0.0, 0.60), (0.3, 0.67), (0.95, 0.77), (1.7, 0.86), (2.6, 0.89), (3.4, 0.92), (3.8, 0.94), (4.3, 0.955), (L, 0.94)],
            "side_x": [(0.0, 0.78), (0.3, 0.88), (0.95, 0.932), (1.7, 0.905), (2.6, 0.895), (3.3, 0.915), (3.7, 0.935), (4.3, 0.91),
                       (L, 0.84)],
            "side_y": [(0.0, 0.46), (0.95, 0.56), (2.6, 0.58), (3.7, 0.62), (L, 0.64)],
            "rk_x": [(0.0, 0.74), (0.4, 0.86), (1.0, 0.88), (2.6, 0.87), (3.7, 0.89), (L, 0.80)],
            "rk_y": [(0.0, 0.23), (1.0, 0.24), (3.6, 0.26), (L, 0.36)],
            "fl_x": [(0.0, 0.60), (0.5, 0.78), (1.0, 0.81), (3.7, 0.81), (L, 0.70)],
            "floor_y": [(0.0, 0.19), (0.5, 0.155), (0.95, 0.14), (3.9, 0.14), (4.3, 0.25), (L, 0.32)],
        },
        "radii": {"edge": 0.05, "sh": 0.05, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"edge_sh": 0.008, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 2.2},
        "front": {"yc": 0.44, "plan": (0.48, 2.7), "top": (0.18, 2.9), "bottom": (0.12, 2.9)},
        "rear": {"yc": 0.70, "plan": (0.30, 3.1), "top": (0.06, 3.5), "bottom": (0.20, 2.5)},
    },
    "cabin": {
        "d0": 1.42, "d1": 4.28,
        "curves": {
            "top": [(1.42, 0.87), (4.28, 0.96)],
            "rail_x": [(1.42, 0.65), (2.0, 0.62), (2.5, 0.59), (3.0, 0.595), (3.6, 0.60), (4.28, 0.62)],
            "base_x": [(1.42, 0.69), (1.8, 0.76), (2.3, 0.78), (3.4, 0.78), (3.9, 0.74), (4.28, 0.66)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.07},
    },
    "arches": {"r": [0.356, 0.364], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.66, 1.58), (0.66, 1.58), (0.52, 2.17), (-0.52, 2.17)], "radii": [0.04, 0.04, 0.08, 0.08]},
        # the door glass and the quarter glass tapering to a point, in chrome
        {"plane": "side", "outline": [(1.98, 0.865), (2.05, 0.93), (2.35, 1.13), (2.95, 1.155), (2.98, 0.92)],
         "radii": [0.02, 0.05, 0.12, 0.03, 0.02], "mirror": True, "trim_mat": "chrome"},
        {"plane": "side", "outline": [(3.04, 0.93), (3.03, 1.14), (3.30, 1.10), (3.45, 1.03), (3.40, 0.98)],
         "radii": [0.02, 0.03, 0.08, 0.04, 0.03], "mirror": True, "trim_mat": "chrome"},
        # the long backlight, narrower at its foot
        {"plane": "top", "outline": [(-0.48, 3.35), (0.48, 3.35), (0.40, 4.12), (-0.40, 4.12)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.97, 0.92), (3.05, 0.93), (3.04, 1.15), (2.96, 1.16)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.78, 0.865), (1.98, 0.865), (2.05, 0.93)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        # the strake's chrome blade running on behind it
        {"plane": "side", "outline": rect(1.60, 0.674, 1.74, 0.688), "radii": [0.006] * 4, "mat": "chrome", "mirror": True},
    ],
    "insets": [
        # teardrop headlights: two round lamps each, the inner one bigger
        {"plane": "front", "ray": (-0.35, -0.25, -1), "outline": [(0.445, 0.585), (0.60, 0.585), (0.76, 0.62), (0.80, 0.68), (0.77, 0.74),
                                                                    (0.66, 0.75), (0.55, 0.70)],
         "radii": [0.02, 0.04, 0.04, 0.04, 0.04, 0.05, 0.04], "depth": 0.06, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.60, 0.645), 0.047, 0.037, "chrome"), ("projector", (0.60, 0.645), 0.035, "proj"),
                      ("ring", (0.705, 0.655), 0.038, 0.03, "chrome"), ("projector", (0.705, 0.655), 0.028, "proj")]},
        # slim tail lamps with a light bar inside
        {"plane": "rear", "ray": (-0.45, 0, 1), "outline": [(0.385, 0.70), (0.42, 0.685), (0.74, 0.685), (0.79, 0.715), (0.78, 0.765),
                                                             (0.70, 0.785), (0.40, 0.795)],
         "radii": [0.02, 0.02, 0.03, 0.03, 0.03, 0.03, 0.02], "depth": 0.03, "mats": ("lamp", "trim"), "cover": "lens_red",
         "mirror": True, "elements": [("strip", [(0.42, 0.745), (0.74, 0.74)], 0.03, "light")]},
        # the plate in a recess wider at its top
        {"plane": "rear", "outline": [(-0.31, 0.61), (0.31, 0.61), (0.385, 0.815), (-0.385, 0.815)], "radii": [0.05, 0.05, 0.02, 0.02],
         "depth": 0.025, "mats": ("paint", "paint"), "elements": [("patch", rect(-0.20, 0.64, 0.20, 0.78), [0.01] * 4, "plate", 0.004)]},
        # the diffuser with a pipe each side and two small lamps
        {"plane": "rear", "outline": [(-0.64, 0.33), (0.64, 0.33), (0.62, 0.42), (0.55, 0.435), (-0.55, 0.435), (-0.62, 0.42)],
         "radii": [0.03, 0.03, 0.03, 0.03, 0.03, 0.03], "depth": 0.04, "mats": ("trim", "trim"),
         "elements": [("disc", (0.225, 0.385), 0.02, "lens_red"), ("disc", (-0.225, 0.385), 0.02, "lens_red")]},
    ],
    "recesses": [
        # the wide barred grille, arching at its top; a flat mouth under it, slots either side
        {"plane": "front", "outline": [(-0.40, 0.42), (0.40, 0.42), (0.485, 0.48), (0.45, 0.555), (0.25, 0.60), (0.0, 0.612),
                                       (-0.25, 0.60), (-0.45, 0.555), (-0.485, 0.48)],
         "radii": [0.04, 0.04, 0.04, 0.06, 0.1, 0.1, 0.1, 0.06, 0.04], "depth": 0.08, "mats": ("grille", "chrome"),
         "bars": [{"y": [0.45, 0.48, 0.51, 0.54, 0.57], "mat": "chrome", "t": 0.006},
                  {"y": [-0.36, -0.24, -0.12, 0.0, 0.12, 0.24, 0.36], "vertical": True, "mat": "chrome", "t": 0.008}]},
        {"plane": "front", "outline": [(-0.40, 0.225), (0.40, 0.225), (0.38, 0.33), (-0.38, 0.33)], "radii": [0.05] * 4, "depth": 0.07,
         "mats": ("grille", "trim")},
        {"plane": "front", "ray": (-0.3, 0, -1), "outline": [(0.47, 0.31), (0.66, 0.31), (0.66, 0.34), (0.47, 0.335)], "radii": [0.012] * 4,
         "depth": 0.04, "mats": ("grille", "trim"), "mirror": True},
        # the nostril vents in the hood
        {"plane": "top", "outline": [(0.30, 0.95), (0.44, 0.92), (0.46, 1.02), (0.32, 1.05)], "radii": [0.02] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True},
        # the strake behind each front wheel
        {"plane": "side", "outline": [(1.22, 0.66), (1.62, 0.665), (1.62, 0.705), (1.22, 0.70)], "radii": [0.015] * 4, "depth": 0.025,
         "mats": ("inlet", "trim"), "mirror": True, "bars": {"y": [0.683], "mat": "chrome", "t": 0.012, "at": 0.3}},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.68, 0.87), (1.66, 0.6), (1.70, 0.29), (2.60, 0.31), (2.84, 0.48), (2.94, 0.92)]},
        {"plane": "top", "line": [(-0.72, 1.45), (-0.74, 0.7), (-0.60, 0.14), (0.60, 0.14), (0.74, 0.7), (0.72, 1.45)], "mirror": False},
        {"plane": "top", "line": [(-0.62, 4.24), (-0.66, 4.60), (0.66, 4.60), (0.62, 4.24)], "mirror": False},
    ],
    "splitter": {"d1": 0.45, "reach": 0.025, "y": 0.14, "t": 0.014, "mat": "trim"},
    "handles": [(2.73, 0.80)],
    "mirrors": [{"base": (0.80, 1.96, 0.92), "size": (0.15, 0.09, 0.12), "reach": 0.05}],
    "exhausts": [{"at": (0.45, 0.385, L - 0.06), "r": 0.045, "length": 0.14}],
    "wipers": {"d": 1.64, "x": [0.44, -0.08], "len": 0.52, "dir": -1},
}
