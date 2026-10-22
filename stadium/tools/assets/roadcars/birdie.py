"""Birdie GT: a three-door hot hatch of the mid 2000s: tall glasshouse, thick C-pillar, a big
trapezoid grille mouth, twin round lamps under each headlight's glass (our own; the class of car
NFS Most Wanted's Blacklist #15 drove)."""

from roadcars._util import circle, ellipse, rect

L = 4.216
SPEC = {
    "id": "birdie", "name": "Birdie GT",
    "length": L, "wheelbase": 2.578, "front_overhang": 0.875, "track": (1.539, 1.528),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.07, the glasshouse down to the tail,
    # the roof's line measured up to the spoiler
    "fit": {"cowl": 1.07, "deck": 4.04},
    "profile": {"cabin.top": {"from": "side_top", "ranges": [[1.10, 3.45]], "add": 0.0, "smooth": 0.10, "every": 0.1}},
    "tyre": {"r": (0.3185, 0.3185), "w": (0.225, 0.225), "rim_r": 0.2286, "rim": "split", "spokes": 5, "dish": 0.03},
    "body": {
        "floor": 0.15,
        "curves": {
            "top": [(0.0, 0.76), (0.15, 0.80), (0.5, 0.875), (0.9, 0.935), (1.1, 0.965), (2.0, 1.0), (3.3, 1.02), (3.95, 1.03),
                    (4.1, 1.0), (L, 0.96)],
            "edge_x": [(0.0, 0.60), (0.3, 0.66), (0.9, 0.69), (1.1, 0.72), (1.5, 0.79), (3.3, 0.80), (3.8, 0.78), (4.0, 0.74), (L, 0.68)],
            "edge_y": [(0.0, 0.74), (0.15, 0.78), (0.5, 0.855), (0.9, 0.915), (1.1, 0.94), (1.5, 0.955), (2.5, 0.975), (3.3, 0.995),
                       (3.95, 1.005), (4.1, 0.985), (L, 0.945)],
            "sh_x": [(0.0, 0.72), (0.3, 0.82), (0.8, 0.86), (1.2, 0.865), (2.5, 0.868), (3.3, 0.872), (3.9, 0.862), (L, 0.80)],
            "sh_y": [(0.0, 0.70), (0.3, 0.76), (0.8, 0.83), (1.1, 0.87), (1.5, 0.90), (2.5, 0.925), (3.3, 0.95), (3.9, 0.965),
                     (L, 0.925)],
            "side_x": [(0.0, 0.80), (0.3, 0.862), (0.8, 0.882), (2.0, 0.878), (3.4, 0.882), (4.0, 0.868), (L, 0.80)],
            "side_y": [(0.0, 0.50), (1.0, 0.70), (2.0, 0.74), (3.5, 0.78), (L, 0.74)],
            "rk_x": [(0.0, 0.76), (0.4, 0.845), (1.0, 0.855), (3.4, 0.862), (L, 0.80)],
            "rk_y": [(0.0, 0.27), (1.0, 0.26), (3.4, 0.29), (L, 0.36)],
            "fl_x": [(0.0, 0.62), (0.5, 0.76), (1.0, 0.79), (3.4, 0.79), (L, 0.70)],
            "floor_y": [(0.0, 0.22), (0.5, 0.18), (0.9, 0.155), (3.6, 0.155), (4.0, 0.21), (L, 0.25)],
        },
        "radii": {"edge": 0.035, "sh": 0.045, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"edge_sh": 0.004, "sh_side": 0.024, "side_rk": 0.018},
        "front": {"yc": 0.48, "plan": (0.30, 3.3), "top": (0.12, 3.1), "bottom": (0.10, 2.9)},
        "rear": {"yc": 0.66, "plan": (0.25, 3.5), "top": (0.06, 3.1), "bottom": (0.12, 2.7)},
    },
    "cabin": {
        "d0": 1.0, "d1": 4.10,
        "curves": {
            "top": [(1.0, 0.92), (3.60, 1.37), (3.75, 1.23), (3.90, 1.06), (4.02, 0.98), (4.10, 0.94)],
            "rail_x": [(1.0, 0.64), (1.4, 0.635), (1.8, 0.625), (2.5, 0.635), (3.3, 0.63), (3.7, 0.65), (4.10, 0.67)],
            "base_x": [(1.0, 0.70), (1.3, 0.76), (1.6, 0.78), (3.5, 0.785), (3.85, 0.77), (4.10, 0.73)],
            "crown": 0.05,
        },
        "radii": {"rail": 0.07},
    },
    "arches": {"r": [0.345, 0.345], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.66, 1.12), (0.66, 1.12), (0.57, 1.86), (-0.57, 1.86)], "radii": [0.04, 0.04, 0.07, 0.07]},
        # the long door's glass, a thick B-pillar, the quarter glass swept down at its back
        {"plane": "side", "outline": [(1.47, 0.92), (1.62, 1.08), (2.0, 1.30), (2.68, 1.33), (2.66, 0.955)],
         "radii": [0.02, 0.06, 0.12, 0.02, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.80, 0.965), (2.82, 1.32), (3.25, 1.30), (3.40, 1.22), (3.43, 1.02)],
         "radii": [0.02, 0.03, 0.08, 0.06, 0.03], "mirror": True},
        {"plane": "rear", "outline": [(-0.62, 1.03), (0.62, 1.03), (0.56, 1.32), (-0.56, 1.32)], "radii": [0.05, 0.05, 0.08, 0.08]},
    ],
    "paint": [
        # the B-pillar blacked out, the mirror's sail
        {"plane": "side", "outline": [(2.65, 0.95), (2.80, 0.96), (2.82, 1.335), (2.69, 1.335)], "radii": [0.01] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.38, 0.89), (1.48, 0.915), (1.52, 1.0)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        # rear reflectors in the bumper's corners
        {"plane": "rear", "outline": [(0.62, 0.40), (0.80, 0.40), (0.80, 0.43), (0.62, 0.43)], "radii": [0.012] * 4,
         "mat": "lens_red", "mirror": True},
    ],
    "insets": [
        # headlights: a big and a small round lamp under one glass, rising to the outside
        {"plane": "front", "ray": (-0.3, -0.15, -1), "outline": [(0.42, 0.61), (0.79, 0.615), (0.80, 0.735), (0.70, 0.805), (0.55, 0.765),
                                                                  (0.42, 0.70)],
         "radii": [0.03, 0.04, 0.05, 0.05, 0.05, 0.03], "depth": 0.055, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.66, 0.716), 0.07, 0.056, "chrome"), ("projector", (0.66, 0.716), 0.05, "proj"),
                      ("ring", (0.518, 0.696), 0.048, 0.036, "chrome"), ("projector", (0.518, 0.696), 0.034, "proj"),
                      ("strip", [(0.47, 0.632), (0.76, 0.632)], 0.012, "amber")]},
        # tail lamps across the hatch's corners, two round lamps in each
        {"plane": "rear", "ray": (-0.4, 0, 1), "outline": [(0.44, 0.88), (0.47, 0.80), (0.62, 0.765), (0.83, 0.765), (0.835, 0.90),
                                                            (0.79, 0.99), (0.55, 0.97)],
         "radii": [0.03, 0.04, 0.04, 0.03, 0.04, 0.04, 0.04], "depth": 0.04, "mats": ("lamp", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("ring", (0.53, 0.88), 0.065, 0.045, "light"), ("ring", (0.70, 0.88), 0.065, 0.045, "light"),
                      ("disc", (0.53, 0.88), 0.022, "lamp"), ("disc", (0.70, 0.88), 0.022, "amber")]},
        # fog lamps low in the bumper's corners
        {"plane": "front", "outline": [(0.47, 0.25), (0.73, 0.26), (0.74, 0.39), (0.49, 0.39)], "radii": [0.03, 0.04, 0.04, 0.03],
         "depth": 0.04, "mats": ("grille", "trim"), "mirror": True,
         "elements": [("ring", (0.65, 0.325), 0.047, 0.036, "chrome"), ("projector", (0.65, 0.325), 0.034, "proj")]},
        # the rear plate in the bumper
        {"plane": "rear", "outline": rect(-0.29, 0.39, 0.29, 0.545), "radii": [0.02] * 4, "depth": 0.018,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.24, 0.41, 0.24, 0.525), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # one big honeycomb grille from the hood's edge to the bumper's foot, a red line across its top
        {"plane": "front", "ray": (0, -0.15, -1), "outline": [(-0.42, 0.705), (0.42, 0.705), (0.44, 0.62), (0.37, 0.27), (-0.37, 0.27),
                                                               (-0.44, 0.62)],
         "radii": [0.03, 0.03, 0.04, 0.05, 0.05, 0.04], "depth": 0.08, "mats": ("grille", "trim"),
         "bars": {"y": [0.672], "mat": "caliper", "t": 0.012}},
        # the slots under the headlights
        {"plane": "front", "outline": [(0.47, 0.51), (0.77, 0.51), (0.78, 0.575), (0.47, 0.575)], "radii": [0.03] * 4, "depth": 0.04,
         "mats": ("grille", "trim"), "mirror": True},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.33, 0.89), (1.30, 0.6), (1.33, 0.30), (2.82, 0.30), (2.84, 0.7), (2.80, 0.96)]},
        {"plane": "top", "line": [(-0.70, 1.05), (-0.73, 0.6), (-0.64, 0.10), (0.64, 0.10), (0.73, 0.6), (0.70, 1.05)], "mirror": False},
        {"plane": "rear", "line": [(-0.64, 1.0), (-0.62, 0.78), (-0.60, 0.62), (-0.52, 0.585), (0.52, 0.585), (0.60, 0.62),
                                   (0.62, 0.78), (0.64, 1.0)], "mirror": False},
        {"plane": "side", "line": circle(3.62, 0.80, 0.065, 24), "closed": True, "mirror": False},
    ],
    "solids": [
        # the roof spoiler over the hatch glass
        {"outline": [(3.40, 1.415), (3.72, 1.35), (3.74, 1.375), (3.45, 1.445)], "radii": [0.01, 0.01, 0.01, 0.03], "axis": "x",
         "a0": -0.60, "a1": 0.60, "mat": "paint"},
    ],
    "handles": [(2.55, 0.75)],
    "mirrors": [{"base": (0.79, 1.52, 0.98), "size": (0.17, 0.11, 0.13), "reach": 0.04}],
    "exhausts": [{"at": (0.42, 0.24, L - 0.08), "r": 0.042, "length": 0.15, "mirror": False},
                 {"at": (0.53, 0.24, L - 0.08), "r": 0.042, "length": 0.15, "mirror": False}],
    "wipers": {"d": 1.16, "x": [0.46, -0.06], "len": 0.52, "dir": -1},
}
