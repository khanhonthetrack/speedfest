"""Frigate V8: an American front-engined V8 sports car of the mid 2000s: a long low hood with fixed
teardrop headlights under clear covers, a wide mouth, vents behind the front wheels, a cab pushed
back under a big glass hatch, four round tail lamps and four pipes in the middle (our own; the
class of car NFS Most Wanted's Blacklist #5 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.435
SPEC = {
    "id": "frigate", "name": "Frigate V8",
    "length": L, "wheelbase": 2.686, "front_overhang": 1.00, "track": (1.578, 1.528),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.55, the glass hatch's at 4.0,
    # the lip on the measured tail (the drawing's front and rear views are wider than the side's
    # scale: their features are placed by proportion)
    "fit": {"cowl": 1.55, "deck": 4.0},
    "tyre": {"r": (0.3265, 0.3412), "w": (0.245, 0.285), "rim_r": (0.2286, 0.2413), "rim": "split", "spokes": 5, "dish": 0.035},
    "body": {
        "floor": 0.13,
        "curves": {
            "top": [(0.0, 0.56), (0.15, 0.61), (0.5, 0.69), (1.0, 0.78), (1.5, 0.85), (1.78, 0.89), (2.6, 0.93), (3.4, 0.95),
                    (3.95, 0.975), (4.25, 0.99), (L, 0.96)],
            "edge_x": [(0.0, 0.56), (0.3, 0.66), (1.0, 0.72), (1.75, 0.74), (2.2, 0.78), (3.3, 0.80), (3.9, 0.78), (L, 0.70)],
            "edge_y": [(0.0, 0.57), (0.15, 0.62), (0.5, 0.70), (1.0, 0.775), (1.5, 0.835), (1.78, 0.87), (2.6, 0.905), (3.4, 0.93),
                       (3.95, 0.96), (4.25, 0.975), (L, 0.945)],
            "sh_x": [(0.0, 0.68), (0.3, 0.83), (1.0, 0.905), (1.8, 0.875), (2.6, 0.87), (3.3, 0.905), (3.7, 0.915), (4.1, 0.88), (L, 0.80)],
            "sh_y": [(0.0, 0.54), (0.3, 0.62), (1.0, 0.72), (1.8, 0.80), (2.6, 0.84), (3.3, 0.88), (3.7, 0.91), (4.1, 0.925), (L, 0.90)],
            "side_x": [(0.0, 0.76), (0.3, 0.87), (1.0, 0.922), (1.8, 0.90), (2.6, 0.895), (3.3, 0.915), (3.69, 0.922), (4.1, 0.90),
                       (L, 0.84)],
            "side_y": [(0.0, 0.42), (1.0, 0.52), (2.6, 0.54), (3.7, 0.60), (L, 0.62)],
            "rk_x": [(0.0, 0.72), (0.4, 0.85), (1.0, 0.875), (2.6, 0.865), (3.6, 0.89), (L, 0.80)],
            "rk_y": [(0.0, 0.22), (1.0, 0.22), (3.5, 0.25), (L, 0.34)],
            "fl_x": [(0.0, 0.60), (0.5, 0.78), (1.0, 0.82), (3.6, 0.82), (L, 0.70)],
            "floor_y": [(0.0, 0.17), (0.5, 0.145), (0.95, 0.135), (3.75, 0.135), (4.05, 0.24), (L, 0.31)],
        },
        "radii": {"edge": 0.05, "sh": 0.05, "side": 0.13, "rk": 0.05, "fl": 0.02},
        "bows": {"edge_sh": 0.008, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 2.2},
        "front": {"yc": 0.40, "plan": (0.50, 2.9), "top": (0.18, 2.7), "bottom": (0.10, 2.9)},
        "rear": {"yc": 0.68, "plan": (0.26, 3.3), "top": (0.05, 3.5), "bottom": (0.18, 2.5)},
    },
    "cabin": {
        "d0": 1.47, "d1": 4.08,
        "curves": {
            "top": [(1.47, 0.84), (4.08, 0.95)],
            "rail_x": [(1.47, 0.66), (2.1, 0.63), (2.6, 0.60), (3.1, 0.61), (3.5, 0.66), (4.08, 0.72)],
            "base_x": [(1.47, 0.71), (1.9, 0.77), (2.4, 0.785), (3.3, 0.79), (3.8, 0.77), (4.08, 0.74)],
            "crown": 0.05,
        },
        "radii": {"rail": 0.07},
    },
    "arches": {"r": [0.353, 0.367], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.66, 1.60), (0.66, 1.60), (0.56, 2.30), (-0.56, 2.30)], "radii": [0.04, 0.04, 0.08, 0.08]},
        {"plane": "side", "outline": [(2.08, 0.84), (2.14, 0.92), (2.40, 1.135), (3.0, 1.165), (3.03, 0.92)],
         "radii": [0.02, 0.05, 0.12, 0.03, 0.02], "mirror": True},
        # the big glass hatch, wrapping down to the tail
        {"plane": "top", "outline": [(-0.60, 3.20), (0.60, 3.20), (0.70, 3.98), (-0.70, 3.98)], "radii": [0.08, 0.08, 0.06, 0.06]},
    ],
    "paint": [
        {"plane": "side", "outline": [(3.03, 0.92), (3.21, 0.94), (3.19, 1.17), (3.03, 1.17)], "radii": [0.01] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.95, 0.83), (2.08, 0.84), (2.13, 0.91)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(0.28, 0.49), (0.47, 0.50), (0.47, 0.53), (0.28, 0.52)], "radii": [0.012] * 4, "mat": "amber",
         "mirror": True},
        {"plane": "side", "outline": [(4.0, 0.72), (4.20, 0.735), (4.20, 0.77), (4.0, 0.76)], "radii": [0.012] * 4, "mat": "lens_red",
         "mirror": True},
    ],
    "insets": [
        # fixed headlights under clear covers on the fenders' fronts: two round lamps and a slatted one outboard
        {"plane": "front", "ray": (-0.2, -0.12, -1), "outline": [(0.53, 0.66), (0.72, 0.67), (0.88, 0.72), (0.89, 0.80), (0.82, 0.83),
                                                                   (0.64, 0.79), (0.54, 0.72)],
         "radii": [0.03, 0.05, 0.04, 0.04, 0.04, 0.05, 0.03], "depth": 0.06, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.63, 0.73), 0.04, 0.03, "chrome"), ("projector", (0.63, 0.73), 0.03, "proj"),
                      ("ring", (0.73, 0.745), 0.04, 0.03, "chrome"), ("projector", (0.73, 0.745), 0.03, "proj"),
                      ("strip", [(0.82, 0.75), (0.86, 0.79)], 0.04, "lamp")]},
        # square fog lamps at the bumper's corners
        {"plane": "front", "ray": (-0.3, 0, -1), "outline": rect(0.75, 0.31, 0.89, 0.42), "radii": [0.02] * 4, "depth": 0.04,
         "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True, "elements": [("projector", (0.80, 0.365), 0.025, "proj")]},
        # four round tail lamps
        {"plane": "rear", "ray": (-0.3, 0, 1), "outline": circle(0.70, 0.865, 0.085, 36), "depth": 0.035, "mats": ("lamp", "trim"),
         "cover": "lens_red", "mirror": True, "elements": [("ring", (0.70, 0.865), 0.08, 0.05, "light"), ("disc", (0.70, 0.865), 0.024, "light")]},
        {"plane": "rear", "outline": circle(0.47, 0.865, 0.08, 36), "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red",
         "mirror": True, "elements": [("ring", (0.47, 0.865), 0.075, 0.046, "light"), ("disc", (0.47, 0.865), 0.022, "lamp")]},
        {"plane": "rear", "outline": rect(-0.26, 0.52, 0.26, 0.71), "radii": [0.03] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.17, 0.54, 0.17, 0.69), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the wide mesh mouth, split in three
        {"plane": "front", "outline": [(-0.50, 0.27), (0.50, 0.27), (0.52, 0.42), (-0.52, 0.42)], "radii": [0.03] * 4, "depth": 0.10,
         "mats": ("grille", "trim"), "bars": {"y": [-0.31, 0.0, 0.31], "vertical": True, "mat": "trim", "t": 0.014}},
        # the hood's window over the engine
        {"plane": "top", "outline": [(-0.14, 0.40), (0.14, 0.40), (0.12, 0.52), (-0.12, 0.52)], "radii": [0.02] * 4, "depth": 0.03,
         "mats": ("grille", "trim")},
        # two vents behind each front wheel and a slot ahead of each rear one
        {"plane": "side", "outline": [(1.30, 0.50), (1.47, 0.49), (1.52, 0.62), (1.33, 0.62)], "radii": [0.015] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True},
        {"plane": "side", "outline": [(1.38, 0.28), (1.53, 0.27), (1.56, 0.41), (1.40, 0.42)], "radii": [0.015] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True},
        {"plane": "side", "outline": [(3.10, 0.36), (3.15, 0.37), (3.16, 0.58), (3.12, 0.58)], "radii": [0.01] * 4, "depth": 0.03,
         "mats": ("grille", "trim"), "mirror": True},
        # the rear diffuser and the vents either side of it
        {"plane": "rear", "outline": [(-0.40, 0.20), (0.40, 0.20), (0.42, 0.36), (-0.42, 0.36)], "radii": [0.04] * 4, "depth": 0.05,
         "mats": ("trim", "trim")},
        {"plane": "rear", "outline": [(0.45, 0.30), (0.68, 0.30), (0.70, 0.37), (0.47, 0.37)], "radii": [0.02] * 4, "depth": 0.04,
         "mats": ("grille", "trim"), "mirror": True, "bars": {"y": [0.335], "mat": "trim", "t": 0.008}},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.72, 0.84), (1.70, 0.6), (1.74, 0.22), (3.0, 0.24), (3.10, 0.6), (3.12, 0.92)]},
        {"plane": "top", "line": [(-0.72, 1.48), (-0.75, 0.8), (-0.58, 0.12), (0.58, 0.12), (0.75, 0.8), (0.72, 1.48)], "mirror": False},
    ],
    "solids": [
        # carbon side skirts
        {"outline": [(1.85, 0.12), (3.05, 0.12), (3.05, 0.17), (1.85, 0.17)], "axis": "x", "a0": 0.82, "a1": 0.89, "mat": "carbon",
         "radii": [0.01, 0.01, 0.02, 0.02], "mirror": True},
    ],
    "splitter": {"d1": 0.5, "reach": 0.05, "y": 0.13, "t": 0.018, "mat": "carbon"},
    "mirrors": [{"base": (0.80, 2.12, 0.86), "size": (0.15, 0.09, 0.12), "reach": 0.05}],
    "exhausts": [{"at": (0.10, 0.27, L - 0.06), "r": 0.042, "length": 0.14}, {"at": (0.21, 0.27, L - 0.06), "r": 0.042, "length": 0.14}],
    "wipers": {"d": 1.66, "x": [0.42, -0.08], "len": 0.5, "dir": -1},
}
