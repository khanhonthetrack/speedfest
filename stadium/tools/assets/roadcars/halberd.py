"""Halberd VIII: a turbocharged four-wheel-drive rally-bred sedan: a huge trapezoid mouth under a
slim grille, slanted headlights, a vented hood, boxy flared fenders, four doors and a tall wing on
two struts (our own; the class of car NFS Most Wanted's Blacklist #9 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.49
SPEC = {
    "id": "halberd", "name": "Halberd VIII",
    "length": L, "wheelbase": 2.625, "front_overhang": 0.86, "track": (1.515, 1.515),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.18, the backlight's at 3.84,
    # the wing over 3.98-4.45 (the trunk's keys behind it are the spec's)
    "fit": {"cowl": 1.18, "deck": 3.84, "wing": [3.98, 4.45]},
    "tyre": {"r": (0.3225, 0.3225), "w": (0.235, 0.235), "rim_r": 0.2286, "rim": "five", "spokes": 6, "dish": 0.04},
    "body": {
        "floor": 0.16,
        "curves": {
            "top": [(0.0, 0.72), (0.15, 0.77), (0.5, 0.83), (0.9, 0.88), (1.22, 0.93), (2.0, 0.97), (3.2, 0.99), (3.55, 1.03),
                    (4.0, 1.07), (4.35, 1.03), (L, 0.97)],
            "edge_x": [(0.0, 0.56), (0.3, 0.64), (0.9, 0.67), (1.22, 0.70), (1.55, 0.77), (3.2, 0.78), (3.7, 0.755), (4.2, 0.72), (L, 0.66)],
            "edge_y": [(0.0, 0.70), (0.15, 0.75), (0.5, 0.815), (0.9, 0.865), (1.22, 0.91), (1.55, 0.94), (3.0, 0.97), (3.55, 1.01),
                       (4.0, 1.05), (4.35, 1.01), (L, 0.95)],
            "sh_x": [(0.0, 0.70), (0.3, 0.82), (0.85, 0.87), (1.3, 0.855), (2.4, 0.85), (3.2, 0.86), (3.5, 0.87), (3.9, 0.855),
                     (4.3, 0.82), (L, 0.77)],
            "sh_y": [(0.0, 0.67), (0.3, 0.74), (0.85, 0.82), (1.3, 0.87), (2.0, 0.90), (3.0, 0.93), (3.6, 0.96), (4.2, 0.98), (L, 0.965)],
            "side_x": [(0.0, 0.78), (0.3, 0.86), (0.85, 0.89), (1.3, 0.87), (2.2, 0.86), (3.0, 0.87), (3.48, 0.885), (4.0, 0.865),
                       (L, 0.80)],
            "side_y": [(0.0, 0.50), (0.85, 0.62), (2.2, 0.64), (3.5, 0.68), (L, 0.70)],
            "rk_x": [(0.0, 0.74), (0.4, 0.85), (0.9, 0.86), (3.4, 0.86), (L, 0.78)],
            "rk_y": [(0.0, 0.28), (1.0, 0.28), (3.4, 0.30), (L, 0.38)],
            "fl_x": [(0.0, 0.60), (0.5, 0.76), (1.0, 0.78), (3.5, 0.78), (L, 0.68)],
            "floor_y": [(0.0, 0.23), (0.45, 0.19), (0.85, 0.165), (3.7, 0.165), (4.1, 0.27), (L, 0.35)],
        },
        "radii": {"edge": 0.03, "sh": 0.035, "side": 0.13, "rk": 0.04, "fl": 0.02},
        "bows": {"edge_sh": 0.004, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 2.4},
        "front": {"yc": 0.46, "plan": (0.32, 3.3), "top": (0.14, 2.9), "bottom": (0.10, 3.1)},
        "rear": {"yc": 0.74, "plan": (0.24, 3.5), "top": (0.06, 3.5), "bottom": (0.16, 2.5)},
    },
    "cabin": {
        "d0": 1.10, "d1": 3.92,
        "curves": {
            "top": [(1.10, 0.95), (3.92, 1.07)],
            "rail_x": [(1.10, 0.64), (1.6, 0.61), (2.1, 0.60), (2.9, 0.605), (3.4, 0.63), (3.92, 0.69)],
            "base_x": [(1.10, 0.69), (1.40, 0.75), (1.75, 0.765), (3.1, 0.765), (3.6, 0.74), (3.92, 0.71)],
            "crown": 0.05,
        },
        "radii": {"rail": 0.05},
    },
    "arches": {"r": [0.349, 0.349], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.68, 1.22), (0.68, 1.22), (0.55, 1.95), (-0.55, 1.95)], "radii": [0.04, 0.04, 0.07, 0.07]},
        {"plane": "side", "outline": [(1.42, 0.925), (1.50, 1.0), (2.0, 1.32), (2.40, 1.375), (2.43, 0.935)],
         "radii": [0.02, 0.05, 0.12, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.56, 0.945), (2.58, 1.375), (3.05, 1.37), (3.22, 1.30), (3.30, 0.98)],
         "radii": [0.02, 0.02, 0.08, 0.06, 0.03], "mirror": True},
        {"plane": "top", "outline": [(-0.55, 3.38), (0.55, 3.38), (0.66, 3.80), (-0.66, 3.80)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.42, 0.93), (2.57, 0.94), (2.59, 1.385), (2.42, 1.385)], "radii": [0.01] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.30, 0.915), (1.42, 0.925), (1.45, 0.975)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": rect(1.27, 0.67, 1.35, 0.70), "radii": [0.01] * 4, "mat": "amber", "mirror": True},
    ],
    "insets": [
        # slanted headlights: three round lamps in each
        {"plane": "front", "ray": (-0.3, -0.15, -1), "outline": [(0.42, 0.57), (0.78, 0.57), (0.82, 0.60), (0.81, 0.71), (0.55, 0.715),
                                                                   (0.45, 0.70)],
         "radii": [0.02, 0.03, 0.03, 0.04, 0.04, 0.02], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.47, 0.645), 0.042, 0.032, "chrome"), ("projector", (0.47, 0.645), 0.03, "proj"),
                      ("ring", (0.57, 0.65), 0.05, 0.04, "chrome"), ("projector", (0.57, 0.65), 0.038, "proj"),
                      ("ring", (0.68, 0.65), 0.045, 0.035, "chrome"), ("projector", (0.68, 0.65), 0.033, "proj"),
                      ("strip", [(0.74, 0.59), (0.80, 0.61)], 0.014, "amber")]},
        # tail lamps under the lid's slanted edges, three round lamps each
        {"plane": "rear", "ray": (-0.4, 0, 1), "outline": [(0.40, 0.685), (0.82, 0.69), (0.84, 0.74), (0.83, 0.86), (0.74, 0.875),
                                                            (0.58, 0.875)],
         "radii": [0.02, 0.03, 0.03, 0.03, 0.03, 0.02], "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("ring", (0.50, 0.735), 0.042, 0.03, "light"), ("ring", (0.605, 0.80), 0.05, 0.036, "light"),
                      ("ring", (0.71, 0.80), 0.05, 0.036, "light")]},
        {"plane": "rear", "outline": rect(-0.29, 0.37, 0.29, 0.54), "radii": [0.03] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.17, 0.385, 0.17, 0.525), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the upper grille dipping to a point, two slots under it and the huge mouth with the intercooler's fins
        {"plane": "front", "ray": (0, -0.15, -1), "outline": [(-0.38, 0.69), (0.38, 0.69), (0.36, 0.60), (0.0, 0.565), (-0.36, 0.60)],
         "radii": [0.02, 0.02, 0.04, 0.1, 0.04], "depth": 0.06, "mats": ("grille", "trim")},
        {"plane": "front", "outline": rect(0.02, 0.477, 0.30, 0.523), "radii": [0.015] * 4, "depth": 0.04, "mats": ("grille", "trim"),
         "mirror": True},
        {"plane": "front", "outline": [(-0.70, 0.32), (0.70, 0.32), (0.72, 0.40), (0.62, 0.455), (-0.62, 0.455), (-0.72, 0.40)],
         "radii": [0.04, 0.04, 0.04, 0.05, 0.05, 0.04], "depth": 0.12, "mats": ("grille", "trim"),
         "bars": {"y": [0.35, 0.38, 0.41, 0.44], "mat": "trim", "t": 0.008}},
        # the hood's scoop and outlets
        {"plane": "top", "outline": [(-0.20, 0.55), (0.20, 0.55), (0.18, 0.80), (-0.18, 0.80)], "radii": [0.03] * 4, "depth": 0.04,
         "mats": ("grille", "trim")},
        {"plane": "top", "outline": [(0.30, 0.45), (0.52, 0.48), (0.52, 0.70), (0.30, 0.68)], "radii": [0.02] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.38, 0.92), (1.35, 0.6), (1.38, 0.33), (2.45, 0.33), (2.47, 0.7), (2.45, 0.935)]},
        {"plane": "side", "line": [(2.48, 0.33), (3.12, 0.33), (3.18, 0.5), (3.24, 0.7), (3.30, 0.98)]},
        {"plane": "top", "line": [(-0.69, 1.12), (-0.70, 0.6), (-0.60, 0.15), (0.60, 0.15), (0.70, 0.6), (0.69, 1.12)], "mirror": False},
        {"plane": "top", "line": [(-0.62, 3.88), (-0.62, 4.42)], "mirror": False},
        {"plane": "top", "line": [(0.62, 3.88), (0.62, 4.42)], "mirror": False},
        {"plane": "rear", "line": [(-0.61, 0.97), (-0.40, 0.685), (0.40, 0.685), (0.61, 0.97)], "mirror": False},
        {"plane": "side", "line": rect(3.71, 0.81, 3.89, 0.94), "closed": True, "mirror": False},
    ],
    "splitter": {"d1": 0.45, "reach": 0.04, "y": 0.20, "t": 0.016},
    # the tall wing: swept fins up from the trunk's corners
    "wings": [{"span": 0.60, "chord": 0.22, "d": 4.22, "y": 1.24, "pitch": 0.06, "mat": "carbon",
               "uprights": [{"x": 0.56, "t": 0.02, "outline": [(4.03, 1.04), (4.28, 1.04), (4.44, 1.29), (4.34, 1.30)],
                             "radii": [0.02, 0.06, 0.03, 0.06], "mat": "paint"}]}],
    "handles": [(2.30, 0.845), (3.30, 0.89)],
    "mirrors": [{"base": (0.77, 1.52, 0.94), "size": (0.16, 0.105, 0.12), "reach": 0.04}],
    "exhausts": [{"at": (-0.50, 0.31, L - 0.07), "r": 0.057, "length": 0.15, "mirror": False}],
    "wipers": {"d": 1.28, "x": [0.44, -0.08], "len": 0.5, "dir": -1},
}
