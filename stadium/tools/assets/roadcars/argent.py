"""Argent 500: a V8 grand-touring coupe of the mid 2000s: twin oval headlights under one glass a
side, a grille of chrome louvres, a pillarless glasshouse arching to the trunk, rounded-triangle
tail lamps (our own; the class of car NFS Most Wanted's Blacklist #7 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.638
SPEC = {
    "id": "argent", "name": "Argent 500",
    "length": L, "wheelbase": 2.715, "front_overhang": 0.89, "track": (1.52, 1.50),
    # fitted to a drawing's side view (blueprint_fit.py): the windscreen's foot at 1.38, the
    # backlight's at 3.95 (no front or rear view: those features are the spec's own)
    "fit": {"cowl": 1.38, "deck": 3.95},
    "tyre": {"r": (0.3185, 0.322), "w": (0.225, 0.255), "rim_r": 0.2286, "rim": "multi", "spokes": 10, "dish": 0.025},
    "body": {
        "floor": 0.15,
        "curves": {
            "top": [(0.0, 0.70), (0.15, 0.745), (0.5, 0.82), (0.9, 0.875), (1.30, 0.925), (2.0, 0.96), (3.2, 0.99), (3.78, 1.03),
                    (4.2, 1.045), (4.5, 1.035), (L, 1.0)],
            "edge_x": [(0.0, 0.56), (0.3, 0.63), (0.9, 0.66), (1.3, 0.70), (1.65, 0.76), (3.3, 0.77), (3.8, 0.745), (4.3, 0.70), (L, 0.64)],
            "edge_y": [(0.0, 0.68), (0.15, 0.725), (0.5, 0.80), (0.9, 0.855), (1.3, 0.905), (1.65, 0.93), (3.0, 0.97), (3.78, 1.01),
                       (4.2, 1.025), (4.5, 1.015), (L, 0.98)],
            "sh_x": [(0.0, 0.66), (0.3, 0.79), (0.85, 0.845), (1.3, 0.845), (2.5, 0.84), (3.4, 0.85), (4.0, 0.835), (4.4, 0.80), (L, 0.75)],
            "sh_y": [(0.0, 0.64), (0.3, 0.72), (0.85, 0.81), (1.3, 0.86), (2.0, 0.885), (3.0, 0.915), (3.7, 0.95), (4.3, 0.965), (L, 0.95)],
            "side_x": [(0.0, 0.75), (0.3, 0.83), (0.85, 0.86), (2.0, 0.855), (3.4, 0.86), (4.1, 0.845), (L, 0.78)],
            "side_y": [(0.0, 0.48), (1.0, 0.62), (2.2, 0.63), (3.5, 0.67), (L, 0.70)],
            "rk_x": [(0.0, 0.72), (0.4, 0.82), (1.0, 0.832), (3.4, 0.84), (L, 0.76)],
            "rk_y": [(0.0, 0.27), (1.0, 0.27), (3.4, 0.29), (L, 0.38)],
            "fl_x": [(0.0, 0.60), (0.5, 0.74), (1.0, 0.77), (3.5, 0.77), (L, 0.68)],
            "floor_y": [(0.0, 0.22), (0.45, 0.18), (0.85, 0.155), (3.8, 0.155), (4.2, 0.22), (L, 0.27)],
        },
        "radii": {"edge": 0.05, "sh": 0.05, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"edge_sh": 0.006, "sh_side": 0.024, "side_rk": 0.018},
        "front": {"yc": 0.48, "plan": (0.42, 2.9), "top": (0.16, 2.9), "bottom": (0.12, 2.9)},
        "rear": {"yc": 0.74, "plan": (0.30, 3.1), "top": (0.06, 3.5), "bottom": (0.16, 2.5)},
    },
    "cabin": {
        "d0": 1.30, "d1": 4.03,
        "curves": {
            "top": [(1.30, 0.92), (4.03, 1.01)],
            "rail_x": [(1.30, 0.63), (1.7, 0.61), (2.2, 0.585), (2.8, 0.59), (3.3, 0.62), (4.03, 0.69)],
            "base_x": [(1.30, 0.68), (1.55, 0.745), (1.9, 0.765), (3.3, 0.765), (3.75, 0.74), (4.03, 0.71)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.06},
    },
    "arches": {"r": [0.345, 0.348], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.64, 1.42), (0.64, 1.42), (0.54, 2.06), (-0.54, 2.06)], "radii": [0.04, 0.04, 0.08, 0.08],
         "trim_mat": "chrome"},
        # pillarless: the door glass and the quarter glass meet at a thin seal
        {"plane": "side", "outline": [(1.50, 0.94), (1.58, 1.02), (2.1, 1.30), (2.62, 1.33), (2.66, 0.965)],
         "radii": [0.02, 0.05, 0.12, 0.03, 0.02], "mirror": True, "trim_mat": "chrome"},
        {"plane": "side", "outline": [(2.72, 0.97), (2.74, 1.325), (3.1, 1.29), (3.35, 1.13), (3.45, 0.99)],
         "radii": [0.02, 0.03, 0.12, 0.08, 0.03], "mirror": True, "trim_mat": "chrome"},
        {"plane": "top", "outline": [(-0.55, 3.35), (0.55, 3.35), (0.65, 3.90), (-0.65, 3.90)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "insets": [
        # twin oval lamps under one glass a side
        {"plane": "front", "ray": (-0.3, -0.1, -1), "outline": [(0.36, 0.64), (0.76, 0.655), (0.86, 0.70), (0.84, 0.76), (0.62, 0.765),
                                                                  (0.38, 0.73)],
         "radii": [0.04, 0.06, 0.04, 0.05, 0.05, 0.04], "depth": 0.06, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.50, 0.70), 0.062, 0.054, "chrome", 0.006), ("projector", (0.50, 0.70), 0.045, "proj"),
                      ("ring", (0.70, 0.71), 0.052, 0.045, "chrome", 0.006), ("projector", (0.70, 0.71), 0.036, "proj"),
                      ("strip", [(0.78, 0.68), (0.845, 0.71)], 0.012, "amber")]},
        # rounded-triangle tail lamps
        {"plane": "rear", "ray": (-0.6, 0, 1), "outline": [(0.48, 0.84), (0.84, 0.80), (1.12, 0.82), (0.86, 0.95), (0.80, 0.985),
                                                            (0.55, 0.96)],
         "radii": [0.03, 0.05, 0.03, 0.05, 0.05, 0.04], "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("strip", [(0.56, 0.90), (0.80, 0.915)], 0.04, "light"), ("strip", [(0.60, 0.865), (0.82, 0.875)], 0.014, "amber")]},
        {"plane": "rear", "outline": rect(-0.27, 0.80, 0.27, 0.94), "radii": [0.01] * 4, "depth": 0.018,
         "mats": ("trim", "trim"), "elements": [("patch", rect(-0.255, 0.81, 0.255, 0.93), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the louvred grille and the lower mouth
        {"plane": "front", "outline": [(-0.30, 0.62), (0.30, 0.62), (0.34, 0.75), (-0.34, 0.75)], "radii": [0.03] * 4, "depth": 0.06,
         "mats": ("grille", "chrome"), "bars": {"y": [0.65, 0.685, 0.72], "mat": "chrome", "t": 0.014}},
        {"plane": "front", "outline": [(-0.52, 0.24), (0.52, 0.24), (0.48, 0.44), (-0.48, 0.44)], "radii": [0.05] * 4, "depth": 0.09,
         "mats": ("grille", "trim")},
        {"plane": "front", "outline": [(0.58, 0.25), (0.76, 0.26), (0.76, 0.38), (0.60, 0.38)], "radii": [0.03] * 4, "depth": 0.06,
         "mats": ("grille", "trim"), "mirror": True},
        # the rear bumper's dark lower band
        {"plane": "rear", "outline": rect(-0.62, 0.28, 0.62, 0.34), "radii": [0.02] * 4, "depth": 0.03, "mats": ("trim", "trim")},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.40, 0.93), (1.37, 0.6), (1.42, 0.29), (2.98, 0.30), (3.02, 0.7), (3.0, 0.97)]},
        {"plane": "top", "line": [(-0.69, 1.20), (-0.70, 0.6), (-0.60, 0.15), (0.60, 0.15), (0.70, 0.6), (0.69, 1.20)], "mirror": False},
        {"plane": "top", "line": [(-0.68, 3.98), (-0.72, 4.50), (0.72, 4.50), (0.68, 3.98)], "mirror": False},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.645, 0.965), (2.72, 0.97), (2.745, 1.33), (2.66, 1.335)], "radii": [0.004] * 4,
         "mat": "trim", "mirror": True, "cabin": True},
        # reflectors in the rear bumper
        {"plane": "rear", "outline": rect(0.55, 0.44, 0.78, 0.47), "radii": [0.012] * 4, "mat": "lens_red", "mirror": True},
        # a chrome strip along the flanks
        {"plane": "side", "outline": rect(1.30, 0.505, 3.10, 0.522), "radii": [0.008] * 4, "mat": "chrome", "mirror": True},
    ],
    "handles": [(2.65, 0.84)],
    "mirrors": [{"base": (0.77, 1.68, 0.93), "size": (0.16, 0.105, 0.13), "reach": 0.04}],
    "exhausts": [{"at": (0.56, 0.27, L - 0.08), "r": (0.06, 0.035), "length": 0.14}],
    "wipers": {"d": 1.44, "x": [0.44, -0.08], "len": 0.52, "dir": -1},
}
