"""Gavial S: a mid-engined coupe of the mid 2000s: a low hood between front fenders that rise into
big oval headlights, three intakes in the nose, a long arching roof down a glass hatch to a duck
tail, a big scoop ahead of each wide rear haunch, twin pipes in the middle (our own; the class of
car NFS Most Wanted's Blacklist #10 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.341
SPEC = {
    "id": "gavial", "name": "Gavial S",
    "length": L, "wheelbase": 2.415, "front_overhang": 0.95, "track": (1.486, 1.528),
    # fitted to a drawing (blueprint_fit.py): the glasshouse between the windscreen's foot (1.50) and
    # the hatch glass's (3.75), the deck behind it; the front keeps its own lines (its fenders rise
    # far above the hood), "front" past the cowl leaves it out
    "fit": {"cowl": 1.50, "deck": 3.75, "front": 1.6, "hood_add": -0.012},
    "tyre": {"r": (0.323, 0.335), "w": (0.235, 0.265), "rim_r": 0.2413, "rim": "split", "spokes": 5, "dish": 0.035},
    "body": {
        "floor": 0.13,
        "curves": {
            "top": [(0.0, 0.56), (0.15, 0.60), (0.5, 0.665), (0.95, 0.735), (1.40, 0.81), (2.0, 0.86), (3.2, 0.92), (3.9, 0.975),
                    (4.15, 0.99), (L, 0.68)],
            "hood_x": [(0.0, 0.32), (0.3, 0.40), (0.9, 0.45), (1.3, 0.52), (1.6, 0.66), (3.2, 0.66), (3.8, 0.62), (L, 0.56)],
            "hood_y": [(0.0, 0.55), (0.15, 0.59), (0.5, 0.655), (0.95, 0.72), (1.40, 0.80), (1.6, 0.83), (3.2, 0.905), (3.9, 0.965),
                       (4.15, 0.98), (L, 0.67)],
            "edge_x": [(0.0, 0.58), (0.3, 0.68), (0.9, 0.73), (1.35, 0.72), (1.6, 0.74), (2.6, 0.76), (3.3, 0.80), (3.9, 0.78), (L, 0.70)],
            "edge_y": [(0.0, 0.60), (0.25, 0.70), (0.6, 0.76), (0.95, 0.775), (1.35, 0.81), (1.6, 0.84), (2.6, 0.87), (3.3, 0.91),
                       (3.9, 0.96), (4.15, 0.975), (L, 0.66)],
            "sh_x": [(0.0, 0.66), (0.3, 0.80), (0.9, 0.865), (1.4, 0.84), (2.3, 0.82), (3.0, 0.86), (3.4, 0.89), (3.9, 0.87), (L, 0.78)],
            "sh_y": [(0.0, 0.56), (0.3, 0.66), (0.9, 0.73), (1.4, 0.78), (2.3, 0.83), (3.0, 0.86), (3.4, 0.89), (3.9, 0.88), (4.15, 0.80), (L, 0.64)],
            "side_x": [(0.0, 0.74), (0.3, 0.84), (0.95, 0.89), (1.5, 0.86), (2.4, 0.85), (3.0, 0.885), (3.4, 0.905), (3.9, 0.885),
                       (L, 0.80)],
            "side_y": [(0.0, 0.42), (0.95, 0.52), (2.4, 0.54), (3.4, 0.60), (L, 0.56)],
            "rk_x": [(0.0, 0.70), (0.4, 0.82), (1.0, 0.84), (2.4, 0.83), (3.4, 0.86), (L, 0.78)],
            "rk_y": [(0.0, 0.22), (1.0, 0.23), (3.3, 0.25), (L, 0.34)],
            "fl_x": [(0.0, 0.58), (0.5, 0.75), (1.0, 0.78), (3.3, 0.78), (L, 0.68)],
            "floor_y": [(0.0, 0.17), (0.5, 0.145), (0.9, 0.135), (3.5, 0.135), (3.9, 0.24), (L, 0.31)],
        },
        "radii": {"hood": 0.06, "edge": 0.07, "sh": 0.05, "side": 0.13, "rk": 0.06, "fl": 0.02},
        "bows": {"hood_edge": -0.008, "edge_sh": 0.01, "sh_side": 0.024, "side_rk": 0.018},
        "front": {"yc": 0.40, "plan": (0.48, 2.7), "top": (0.20, 2.7), "bottom": (0.10, 2.9)},
        "rear": {"yc": 0.55, "plan": (0.30, 3.1), "top": (0.06, 3.5), "bottom": (0.18, 2.5)},
    },
    "cabin": {
        "d0": 1.42, "d1": 3.85,
        "curves": {
            "top": [(1.42, 0.84), (3.85, 0.90)],
            "rail_x": [(1.42, 0.59), (1.8, 0.585), (2.3, 0.56), (2.8, 0.56), (3.3, 0.58), (3.85, 0.62)],
            "base_x": [(1.42, 0.64), (1.65, 0.72), (2.0, 0.745), (3.0, 0.75), (3.5, 0.72), (3.85, 0.66)],
            "crown": 0.05,
        },
        "radii": {"rail": 0.07},
    },
    "arches": {"r": [0.349, 0.361], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.64, 1.53), (0.64, 1.53), (0.48, 2.22), (-0.48, 2.22)], "radii": [0.04, 0.04, 0.08, 0.08]},
        # the door glass and the small quarter glass behind its slanted frame
        {"plane": "side", "outline": [(1.73, 0.865), (1.80, 0.93), (2.25, 1.15), (2.70, 1.18), (2.80, 1.12), (2.72, 0.87)],
         "radii": [0.02, 0.05, 0.12, 0.06, 0.04, 0.02], "mirror": True},
        {"plane": "side", "outline": [(2.77, 0.875), (2.86, 1.11), (3.0, 1.06), (3.12, 0.95), (3.12, 0.885)],
         "radii": [0.02, 0.03, 0.06, 0.05, 0.02], "mirror": True},
        # the glass hatch
        {"plane": "top", "outline": [(-0.44, 3.0), (0.44, 3.0), (0.47, 3.72), (-0.47, 3.72)], "radii": [0.08, 0.08, 0.06, 0.06]},
    ],
    "paint": [
        {"plane": "side", "outline": [(2.71, 0.87), (2.78, 0.875), (2.87, 1.12), (2.80, 1.13)], "radii": [0.005] * 4,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": rect(0.59, 0.53, 0.71, 0.56), "radii": [0.012] * 4, "mat": "amber", "mirror": True},
    ],
    "insets": [
        # big oval headlights where the fenders meet the nose
        {"plane": "front", "ray": (-0.25, -0.35, -1), "outline": ellipse(0.585, 0.69, 0.135, 0.085, 40, rot=0.3),
         "depth": 0.06, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("projector", (0.56, 0.68), 0.045, "proj"), ("projector", (0.66, 0.71), 0.03, "proj"),
                      ("strip", [(0.47, 0.66), (0.52, 0.68)], 0.014, "amber")]},
        # the nose's side intakes with a round lamp in each
        {"plane": "front", "ray": (-0.3, 0, -1), "outline": [(0.30, 0.25), (0.70, 0.26), (0.71, 0.45), (0.33, 0.47)],
         "radii": [0.04, 0.05, 0.05, 0.04], "depth": 0.07, "mats": ("grille", "trim"), "mirror": True,
         "elements": [("ring", (0.54, 0.40), 0.045, 0.035, "chrome"), ("projector", (0.54, 0.40), 0.033, "proj")]},
        # tail lamps wrapping far round the haunches
        {"plane": "rear", "ray": (-0.6, 0, 1), "outline": [(0.50, 0.68), (0.78, 0.67), (1.05, 0.70), (1.05, 0.78), (0.79, 0.80),
                                                            (0.62, 0.82), (0.52, 0.76)],
         "radii": [0.02, 0.03, 0.02, 0.02, 0.03, 0.03, 0.02], "depth": 0.035, "mats": ("lamp", "trim"), "cover": "lens_red",
         "mirror": True, "elements": [("strip", [(0.55, 0.72), (0.80, 0.735)], 0.05, "light")]},
        {"plane": "rear", "outline": rect(-0.33, 0.39, 0.33, 0.59), "radii": [0.08] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.17, 0.42, 0.17, 0.56), [0.01] * 4, "plate", 0.004)]},
    ],
    "recesses": [
        # the nose's centre intake
        {"plane": "front", "outline": [(-0.25, 0.22), (0.25, 0.22), (0.27, 0.36), (-0.27, 0.36)], "radii": [0.04] * 4, "depth": 0.09,
         "mats": ("grille", "trim")},
        # the scoop ahead of each rear wheel, with slats
        {"plane": "side", "outline": [(2.67, 0.40), (2.84, 0.40), (2.99, 0.645), (2.85, 0.645)], "radii": [0.03] * 4, "depth": 0.06,
         "mats": ("grille", "trim"), "mirror": True, "bars": {"y": [0.46, 0.52, 0.58], "mat": "paint", "t": 0.014}},
        # the vents across the rear's foot either side of the pipes
        {"plane": "rear", "outline": [(-0.56, 0.23), (0.56, 0.23), (0.58, 0.35), (-0.58, 0.35)], "radii": [0.03] * 4, "depth": 0.05,
         "mats": ("grille", "trim")},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.56, 0.85), (1.54, 0.6), (1.58, 0.30), (2.50, 0.30), (2.62, 0.45), (2.74, 0.65), (2.76, 0.87)]},
        {"plane": "top", "line": [(-0.50, 1.42), (-0.46, 0.6), (-0.36, 0.15), (0.36, 0.15), (0.46, 0.6), (0.50, 1.42)], "mirror": False},
        {"plane": "top", "line": [(-0.50, 3.80), (-0.52, 4.22), (0.52, 4.22), (0.50, 3.80)], "mirror": False},
    ],
    "splitter": {"d1": 0.42, "reach": 0.03, "y": 0.13, "t": 0.016, "mat": "trim"},
    "handles": [(2.65, 0.695)],
    "mirrors": [{"base": (0.76, 1.80, 0.88), "size": (0.15, 0.09, 0.12), "reach": 0.05}],
    "exhausts": [{"at": (0.045, 0.285, L - 0.05), "r": (0.032, 0.036), "length": 0.14}],
    "wipers": {"d": 1.56, "x": [0.42, -0.08], "len": 0.48, "dir": -1},
}
