"""Taipan V10: an American V10 brute: a hood as long as the cabin is short, with a power dome and
two louvred vents, a wide oval mouth, narrow teardrop headlights, gills behind the front wheels,
huge rear haunches and a short duck-tailed rump (our own; the class of car NFS Most Wanted's
Blacklist #4 drove)."""
from roadcars._util import circle, ellipse, rect, slots

L = 4.46
SPEC = {
    "id": "taipan", "name": "Taipan V10",
    "length": L, "wheelbase": 2.51, "front_overhang": 1.03, "track": (1.574, 1.548),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.75, the backlight's at 4.10,
    # the duck tail on the measured deck
    "fit": {"cowl": 1.75, "deck": 4.10},
    "tyre": {"r": (0.325, 0.345), "w": (0.275, 0.335), "rim_r": (0.2286, 0.2413), "rim": "five", "spokes": 5, "dish": 0.045},
    "body": {
        "floor": 0.13,
        "curves": {
            "top": [(0.0, 0.58), (0.15, 0.63), (0.5, 0.71), (1.0, 0.79), (1.5, 0.86), (1.95, 0.875), (2.6, 0.89), (3.4, 0.91),
                    (3.85, 0.93), (4.25, 1.0), (L, 0.97)],
            "hood_x": [(0.0, 0.30), (0.3, 0.38), (1.0, 0.40), (1.6, 0.42), (2.0, 0.55), (3.4, 0.62), (L, 0.58)],
            "hood_y": [(0.0, 0.57), (0.15, 0.62), (0.5, 0.69), (1.0, 0.765), (1.5, 0.835), (1.95, 0.865), (2.6, 0.88), (3.4, 0.90),
                       (3.85, 0.92), (4.25, 0.985), (L, 0.955)],
            "edge_x": [(0.0, 0.56), (0.3, 0.66), (1.0, 0.74), (1.6, 0.74), (2.1, 0.78), (3.4, 0.82), (4.0, 0.80), (L, 0.72)],
            "edge_y": [(0.0, 0.58), (0.2, 0.65), (0.6, 0.73), (1.03, 0.77), (1.6, 0.83), (2.1, 0.86), (3.4, 0.89), (3.85, 0.92),
                       (4.25, 0.975), (L, 0.945)],
            "sh_x": [(0.0, 0.68), (0.3, 0.82), (1.0, 0.905), (1.7, 0.88), (2.5, 0.88), (3.2, 0.92), (3.55, 0.935), (4.1, 0.90), (L, 0.80)],
            "sh_y": [(0.0, 0.56), (0.3, 0.64), (1.0, 0.73), (1.7, 0.80), (2.5, 0.85), (3.2, 0.88), (3.55, 0.90), (4.1, 0.92), (L, 0.90)],
            "side_x": [(0.0, 0.76), (0.3, 0.87), (1.03, 0.94), (1.7, 0.91), (2.4, 0.905), (3.1, 0.935), (3.54, 0.955), (4.1, 0.925),
                       (L, 0.84)],
            "side_y": [(0.0, 0.42), (1.0, 0.52), (2.4, 0.54), (3.5, 0.60), (L, 0.62)],
            "rk_x": [(0.0, 0.72), (0.4, 0.85), (1.0, 0.88), (2.4, 0.87), (3.5, 0.91), (L, 0.80)],
            "rk_y": [(0.0, 0.22), (1.0, 0.22), (3.4, 0.25), (L, 0.34)],
            "fl_x": [(0.0, 0.60), (0.5, 0.78), (1.0, 0.82), (3.5, 0.82), (L, 0.70)],
            "floor_y": [(0.0, 0.17), (0.5, 0.145), (0.95, 0.135), (3.6, 0.135), (4.0, 0.24), (L, 0.31)],
        },
        "radii": {"hood": 0.1, "edge": 0.06, "sh": 0.05, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"hood_edge": -0.004, "edge_sh": 0.01, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 1.6},
        "front": {"yc": 0.40, "plan": (0.52, 2.7), "top": (0.20, 2.7), "bottom": (0.10, 2.9)},
        "rear": {"yc": 0.66, "plan": (0.28, 3.1), "top": (0.06, 3.5), "bottom": (0.18, 2.5)},
    },
    "cabin": {
        "d0": 1.68, "d1": 4.18,
        "curves": {
            "top": [(1.68, 0.84), (4.18, 0.93)],
            "rail_x": [(1.68, 0.66), (2.1, 0.63), (2.6, 0.585), (3.1, 0.59), (3.6, 0.61), (4.18, 0.66)],
            "base_x": [(1.68, 0.71), (2.0, 0.76), (2.5, 0.78), (3.3, 0.77), (3.8, 0.74), (4.18, 0.68)],
            "crown": 0.05,
            "crown_q": 3.0,
        },
        "radii": {"rail": 0.07},
    },
    "arches": {"r": [0.351, 0.371], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.68, 1.80), (0.68, 1.80), (0.58, 2.36), (-0.58, 2.36)], "radii": [0.04, 0.04, 0.08, 0.08]},
        # a small door glass behind the mirror's sail
        {"plane": "side", "outline": [(2.45, 0.855), (2.50, 1.05), (2.62, 1.105), (2.92, 1.105), (3.04, 1.04), (3.07, 0.86)],
         "radii": [0.02, 0.06, 0.06, 0.08, 0.05, 0.02], "mirror": True},
        # the double-bubble backlight
        {"plane": "top", "outline": [(-0.50, 3.30), (0.50, 3.30), (0.56, 3.95), (-0.56, 3.95)], "radii": [0.06, 0.06, 0.05, 0.05]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.14, 0.85), (2.45, 0.855), (2.48, 1.0)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
    ],
    "insets": [
        # teardrop headlights: two round lamps and a small one at the inner tip
        {"plane": "front", "ray": (-0.3, -0.1, -1), "outline": [(0.45, 0.545), (0.82, 0.555), (0.86, 0.60), (0.84, 0.70), (0.76, 0.715),
                                                                   (0.60, 0.67)],
         "radii": [0.02, 0.04, 0.04, 0.04, 0.04, 0.04], "depth": 0.05, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.72, 0.62), 0.045, 0.035, "chrome"), ("projector", (0.72, 0.62), 0.033, "proj"),
                      ("ring", (0.63, 0.62), 0.045, 0.035, "chrome"), ("projector", (0.63, 0.62), 0.033, "proj"),
                      ("disc", (0.53, 0.605), 0.025, "amber")]},
        # big round fog lamps beside the mouth
        {"plane": "front", "outline": circle(0.72, 0.37, 0.075, 32), "depth": 0.045, "mats": ("trim", "trim"), "mirror": True,
         "elements": [("ring", (0.72, 0.37), 0.072, 0.058, "chrome"), ("projector", (0.72, 0.37), 0.055, "proj")]},
        # tail lamps: three segments over a bar each side
        {"plane": "rear", "ray": (-0.45, 0, 1), "outline": [(0.51, 0.70), (0.78, 0.70), (0.81, 0.73), (0.80, 0.78), (0.72, 0.80),
                                                             (0.53, 0.80)],
         "radii": [0.02, 0.03, 0.02, 0.03, 0.03, 0.02], "depth": 0.03, "mats": ("lamp", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("strip", [(0.58, 0.715), (0.58, 0.785)], 0.06, "light"), ("strip", [(0.66, 0.715), (0.66, 0.785)], 0.06, "light"),
                      ("strip", [(0.74, 0.715), (0.74, 0.78)], 0.05, "light")]},
        {"plane": "rear", "ray": (-0.45, 0, 1), "outline": rect(0.50, 0.62, 0.81, 0.66), "radii": [0.02] * 4, "depth": 0.025,
         "mats": ("lamp", "trim"), "cover": "lens_red", "mirror": True, "elements": [("strip", [(0.53, 0.64), (0.78, 0.64)], 0.02, "light")]},
        {"plane": "rear", "outline": rect(-0.31, 0.63, 0.31, 0.79), "radii": [0.04] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.15, 0.645, 0.15, 0.775), [0.01] * 4, "plate", 0.004)]},
        # the side pipes, out of the sills ahead of the rear wheels
        {"plane": "side", "outline": circle(2.95, 0.20, 0.055, 24), "depth": 0.06, "mats": ("trim", "trim"), "mirror": True,
         "elements": [("ring", (2.95, 0.20), 0.055, 0.042, "chrome")]},
    ],
    "recesses": [
        # the wide mouth, split down the middle, with a bar across
        {"plane": "front", "outline": [(-0.58, 0.27), (0.58, 0.27), (0.62, 0.36), (0.60, 0.47), (-0.60, 0.47), (-0.62, 0.36)],
         "radii": [0.04, 0.04, 0.06, 0.03, 0.03, 0.06], "depth": 0.10, "mats": ("grille", "trim"),
         "bars": [{"y": [0.0], "vertical": True, "mat": "paint", "t": 0.035}, {"y": [0.39], "mat": "trim", "t": 0.012}]},
        # the hood's nostril and its louvred vents by the windscreen
        {"plane": "top", "outline": [(-0.15, 0.25), (0.15, 0.25), (0.14, 0.42), (-0.14, 0.42)], "radii": [0.03] * 4, "depth": 0.035,
         "mats": ("grille", "trim")},
        {"plane": "top", "outline": [(0.36, 1.05), (0.56, 0.95), (0.62, 1.45), (0.42, 1.50)], "radii": [0.03] * 4, "depth": 0.035,
         "mats": ("grille", "trim"), "mirror": True, "bars": {"y": [1.10, 1.20, 1.30, 1.40], "mat": "paint", "t": 0.02}},
        # the rear diffuser
        {"plane": "rear", "outline": [(-0.62, 0.23), (0.62, 0.23), (0.64, 0.44), (-0.64, 0.44)], "radii": [0.04] * 4, "depth": 0.05,
         "mats": ("trim", "trim")},
    ],
    "cutters": [
        # gills behind the front wheels
        {"outline": o, "axis": "x", "a0": 0.84, "a1": 1.2, "mats": ("inlet", "inlet"), "radii": [0.01] * 4, "mirror": True}
        for o in [[(1.50 + 0.07 * i, 0.40), (1.53 + 0.07 * i, 0.40), (1.60 + 0.07 * i, 0.62), (1.57 + 0.07 * i, 0.62)] for i in range(3)]
    ],
    "gaps": [
        {"plane": "side", "line": [(2.08, 0.85), (2.07, 0.62), (1.92, 0.30), (3.02, 0.30), (3.08, 0.6), (3.07, 0.86)]},
        {"plane": "top", "line": [(-0.74, 1.70), (-0.76, 0.8), (-0.58, 0.12), (0.58, 0.12), (0.76, 0.8), (0.74, 1.70)], "mirror": False},
        {"plane": "top", "line": [(-0.60, 4.15), (-0.64, 4.38), (0.64, 4.38), (0.60, 4.15)], "mirror": False},
    ],
    "splitter": {"d1": 0.5, "reach": 0.05, "y": 0.13, "t": 0.018, "mat": "carbon"},
    "handles": [],
    "mirrors": [{"base": (0.79, 2.32, 0.87), "size": (0.15, 0.09, 0.12), "reach": 0.05}],
    "exhausts": [],
    "wipers": {"d": 1.85, "x": [0.42, -0.08], "len": 0.5, "dir": -1},
}
