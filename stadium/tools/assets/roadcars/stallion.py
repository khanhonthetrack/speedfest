"""Stallion GT: a retro American muscle fastback of the mid 2000s: a long hood with a power bulge, a
shark nose leaning forward over a wide mesh grille with round lamps in it, a short roof falling to
a long backlight, a scoop ahead of each rear wheel, three upright tail-lamp bars a side (our own;
the class of car NFS Most Wanted's Blacklist #8 and #1 drove)."""
from roadcars._util import circle, ellipse, rect

L = 4.765
SPEC = {
    "id": "stallion", "name": "Stallion GT",
    "length": L, "wheelbase": 2.72, "front_overhang": 0.93, "track": (1.58, 1.59),
    # fitted to a drawing (blueprint_fit.py): the windscreen's foot at 1.62, the backlight's at 4.07
    "fit": {"cowl": 1.62, "deck": 4.07},
    "tyre": {"r": (0.34, 0.34), "w": (0.245, 0.275), "rim_r": 0.2413, "rim": "five", "spokes": 5, "dish": 0.035},
    "body": {
        "floor": 0.155,
        "curves": {
            "top": [(0.0, 0.80), (0.12, 0.83), (0.5, 0.88), (1.0, 0.935), (1.5, 0.97), (1.80, 0.99), (2.5, 1.02), (3.5, 1.04),
                    (3.85, 1.065), (4.4, 1.075), (L, 1.04)],
            "edge_x": [(0.0, 0.58), (0.3, 0.66), (1.0, 0.70), (1.75, 0.74), (2.1, 0.80), (3.5, 0.81), (4.0, 0.79), (4.5, 0.76), (L, 0.70)],
            "edge_y": [(0.0, 0.78), (0.12, 0.805), (0.5, 0.855), (1.0, 0.905), (1.5, 0.94), (1.8, 0.96), (2.5, 0.99), (3.5, 1.02),
                       (3.85, 1.045), (4.4, 1.055), (L, 1.02)],
            "sh_x": [(0.0, 0.74), (0.3, 0.86), (1.0, 0.90), (1.8, 0.895), (2.6, 0.89), (3.4, 0.90), (4.0, 0.89), (4.5, 0.86), (L, 0.80)],
            "sh_y": [(0.0, 0.74), (0.3, 0.79), (1.0, 0.86), (1.8, 0.92), (2.6, 0.95), (3.4, 0.98), (4.0, 1.0), (4.5, 1.0), (L, 0.98)],
            "side_x": [(0.0, 0.82), (0.3, 0.91), (1.0, 0.935), (1.8, 0.925), (2.6, 0.92), (3.3, 0.935), (3.7, 0.94), (4.3, 0.925),
                       (L, 0.86)],
            "side_y": [(0.0, 0.58), (1.0, 0.70), (2.6, 0.70), (3.6, 0.74), (L, 0.76)],
            "rk_x": [(0.0, 0.76), (0.4, 0.88), (1.0, 0.895), (3.6, 0.905), (L, 0.83)],
            "rk_y": [(0.0, 0.27), (1.0, 0.27), (3.6, 0.29), (L, 0.38)],
            "fl_x": [(0.0, 0.62), (0.5, 0.80), (1.0, 0.82), (3.6, 0.82), (L, 0.72)],
            "floor_y": [(0.0, 0.21), (0.5, 0.18), (0.95, 0.16), (3.9, 0.16), (4.3, 0.27), (L, 0.34)],
        },
        "radii": {"edge": 0.04, "sh": 0.04, "side": 0.13, "rk": 0.05, "fl": 0.02},
        "bows": {"edge_sh": 0.004, "sh_side": 0.024, "side_rk": 0.018, "crown_q": 1.7},
        "front": {"yc": 0.70, "plan": (0.34, 3.5), "top": (0.08, 2.9), "bottom": (0.30, 2.5)},
        "rear": {"yc": 0.80, "plan": (0.22, 3.6), "top": (0.05, 3.5), "bottom": (0.20, 2.5)},
    },
    "cabin": {
        "d0": 1.55, "d1": 4.12,
        "curves": {
            "top": [(1.55, 0.985), (4.12, 1.05)],
            "rail_x": [(1.55, 0.68), (2.1, 0.65), (2.5, 0.62), (3.0, 0.625), (3.5, 0.67), (4.12, 0.74)],
            "base_x": [(1.55, 0.75), (1.9, 0.80), (2.4, 0.815), (3.4, 0.81), (3.9, 0.80), (4.12, 0.77)],
            "crown": 0.045,
        },
        "radii": {"rail": 0.05},
    },
    "arches": {"r": [0.366, 0.366], "lift": 0.007},
    "glass": [
        {"plane": "top", "outline": [(-0.70, 1.68), (0.70, 1.68), (0.58, 2.36), (-0.58, 2.36)], "radii": [0.04, 0.04, 0.06, 0.06]},
        # the door glass, and the small quarter window in the fastback's pillar
        {"plane": "side", "outline": [(1.80, 1.012), (1.85, 1.06), (2.45, 1.355), (2.92, 1.37), (3.0, 1.33), (3.01, 1.045)],
         "radii": [0.02, 0.05, 0.12, 0.05, 0.05, 0.02], "mirror": True},
        {"plane": "side", "outline": [(3.22, 1.07), (3.26, 1.25), (3.42, 1.255), (3.69, 1.08)], "radii": [0.02, 0.03, 0.06, 0.03],
         "mirror": True},
        {"plane": "top", "outline": [(-0.56, 3.12), (0.56, 3.12), (0.72, 3.98), (-0.72, 3.98)], "radii": [0.05, 0.05, 0.04, 0.04]},
    ],
    "paint": [
        {"plane": "side", "outline": [(1.70, 1.0), (1.81, 1.012), (1.86, 1.07)], "radii": [0.01] * 3,
         "mat": "gloss_black", "mirror": True, "cabin": True},
        {"plane": "side", "outline": [(1.44, 0.645), (1.545, 0.645), (1.545, 0.69), (1.44, 0.69)], "radii": [0.01] * 4, "mat": "amber",
         "mirror": True},
        {"plane": "side", "outline": [(4.19, 0.51), (4.38, 0.51), (4.38, 0.54), (4.19, 0.54)], "radii": [0.01] * 4, "mat": "lens_red",
         "mirror": True},
        {"plane": "rear", "outline": rect(0.35, 0.555, 0.47, 0.60), "radii": [0.01] * 4, "mat": "lens_red", "mirror": True},
    ],
    "insets": [
        # headlights at the nose's corners: one big round lamp each
        {"plane": "front", "ray": (-0.3, 0, -1), "outline": [(0.64, 0.595), (0.86, 0.595), (0.90, 0.64), (0.89, 0.775), (0.65, 0.78)],
         "radii": [0.03, 0.04, 0.04, 0.03, 0.03], "depth": 0.06, "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True,
         "elements": [("ring", (0.77, 0.685), 0.08, 0.064, "chrome"), ("projector", (0.77, 0.685), 0.055, "proj")]},
        # tail lamps: three upright bars a side
        {"plane": "rear", "ray": (-0.25, 0, 1), "outline": [(0.47, 0.73), (0.86, 0.73), (0.89, 0.76), (0.89, 0.93), (0.86, 0.96),
                                                             (0.49, 0.96)],
         "radii": [0.02, 0.03, 0.03, 0.03, 0.03, 0.02], "depth": 0.035, "mats": ("trim", "trim"), "cover": "lens_red", "mirror": True,
         "elements": [("strip", [(0.55, 0.755), (0.55, 0.935)], 0.12, "light"), ("strip", [(0.69, 0.755), (0.69, 0.935)], 0.11, "light"),
                      ("strip", [(0.82, 0.755), (0.82, 0.935)], 0.10, "light")]},
        {"plane": "rear", "outline": rect(-0.23, 0.40, 0.23, 0.61), "radii": [0.03] * 4, "depth": 0.02,
         "mats": ("paint", "paint"), "elements": [("patch", rect(-0.18, 0.43, 0.18, 0.58), [0.01] * 4, "plate", 0.004)]},
        # the wide grille under the leaning nose, a round lamp in it at each end
        {"plane": "front", "outline": [(-0.55, 0.59), (0.55, 0.59), (0.55, 0.80), (-0.55, 0.80)], "radii": [0.04] * 4, "depth": 0.07,
         "mats": ("grille", "trim"),
         "elements": [("ring", (0.40, 0.69), 0.09, 0.07, "chrome", 0.02), ("projector", (0.40, 0.69), 0.066, "proj"),
                      ("ring", (-0.40, 0.69), 0.09, 0.07, "chrome", 0.02), ("projector", (-0.40, 0.69), 0.066, "proj")]},
        # the indicators under the headlights
        {"plane": "front", "ray": (-0.3, 0, -1), "outline": rect(0.65, 0.44, 0.89, 0.50), "radii": [0.02] * 4, "depth": 0.03,
         "mats": ("lamp", "lamp"), "cover": "lens", "mirror": True, "elements": [("strip", [(0.68, 0.47), (0.86, 0.47)], 0.03, "amber")]},
    ],
    "recesses": [
        # the lower mouth
        {"plane": "front", "outline": [(-0.60, 0.30), (0.60, 0.30), (0.58, 0.41), (-0.58, 0.41)], "radii": [0.04] * 4, "depth": 0.10,
         "mats": ("grille", "trim")},
        # the side scoops ahead of the rear wheels, with slats
        {"plane": "side", "outline": [(3.03, 0.56), (3.22, 0.57), (3.29, 0.65), (3.27, 0.80), (3.05, 0.82)],
         "radii": [0.02, 0.03, 0.04, 0.03, 0.02], "depth": 0.04, "mats": ("inlet", "trim"), "mirror": True,
         "bars": {"y": [0.62, 0.68, 0.74], "mat": "paint", "t": 0.02, "at": 0.4}},
    ],
    "solids": [
        # the ducktail on the trunk's edge
        {"outline": [(4.36, 1.05), (4.53, 1.07), (4.54, 1.11), (4.42, 1.10)], "radii": [0.01, 0.01, 0.01, 0.02], "axis": "x",
         "a0": -0.80, "a1": 0.80, "mat": "paint"},
    ],
    "gaps": [
        {"plane": "side", "line": [(1.67, 1.0), (1.64, 0.6), (1.70, 0.30), (2.88, 0.29), (2.98, 0.6), (3.0, 1.04)]},
        {"plane": "top", "line": [(-0.74, 1.58), (-0.78, 0.8), (-0.64, 0.12), (0.64, 0.12), (0.78, 0.8), (0.74, 1.58)], "mirror": False},
        {"plane": "top", "line": [(-0.72, 4.10), (-0.76, 4.62), (0.76, 4.62), (0.72, 4.10)], "mirror": False},
        {"plane": "rear", "line": [(-0.46, 0.98), (-0.46, 0.66), (0.46, 0.66), (0.46, 0.98)], "mirror": False},
        {"plane": "side", "line": circle(4.21, 0.885, 0.095, 28), "closed": True, "mirror": False},
    ],
    "splitter": {"d1": 0.5, "reach": 0.03, "y": 0.20, "t": 0.016, "mat": "trim"},
    "handles": [(2.82, 0.895)],
    "mirrors": [{"base": (0.82, 1.98, 1.03), "size": (0.17, 0.11, 0.13), "reach": 0.04}],
    "exhausts": [{"at": (0.67, 0.30, L - 0.08), "r": 0.05, "length": 0.15}],
    "wipers": {"d": 1.72, "x": [0.46, -0.08], "len": 0.54, "dir": -1},
}
