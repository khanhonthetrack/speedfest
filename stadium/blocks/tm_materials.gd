class_name TmMaterials
extends RefCounted
## Materials of the recreated blocks and the Stadium, by key. With HD graphics on (the default;
## TmUi setting "hd") most keys get our procedural surface shader (blocks/tm_surface.gdshader:
## world-space concrete, grass, dirt, grids, panels, seats, screens... in the Stadium's colours,
## the main ones measured from TMNF's textures locally: road and platform (165, 164, 161) and
## (166, 165, 162), grass (52, 75, 40), dirt (67, 61, 49), parking blue (50, 75, 157)); off, or for
## the keys without one, flat colours: [albedo, roughness, metallic(, emission energy)].
## Unknown keys get a magenta debug material.

static var _cache := {}
static var _noise_fine: NoiseTexture2D
static var _noise_coarse: NoiseTexture2D

const COLORS := {
	"asphalt": [Color8(165, 164, 161), 0.85, 0.0],
	"platform": [Color8(166, 165, 162), 0.8, 0.0],
	"rubber": [Color(0.78, 0.12, 0.10), 0.7, 0.0],
	"rubber_white": [Color(0.92, 0.92, 0.92), 0.7, 0.0],
	"curb_face": [Color(0.14, 0.14, 0.15), 0.75, 0.0],
	"curb_outer": [Color(0.14, 0.14, 0.15), 0.75, 0.0],
	"shoulder": [Color(0.24, 0.52, 0.27), 0.75, 0.0],
	"curb_top": [Color(0.80, 0.80, 0.79), 0.8, 0.0],
	"road_lip": [Color(0.80, 0.80, 0.79), 0.8, 0.0],
	"metal": [Color(0.62, 0.64, 0.68), 0.45, 0.7],
	"grid": [Color(0.42, 0.44, 0.48), 0.5, 0.6],
	"wall": [Color(0.88, 0.89, 0.91), 0.75, 0.0],
	"wall_dark": [Color(0.32, 0.34, 0.38), 0.8, 0.0],
	# the platform walls and the circuit walls in TMNF's colours (measured from its renders)
	"platform_wall": [Color8(50, 51, 53), 0.82, 0.0],
	"circuit_side": [Color8(48, 44, 40), 0.6, 0.2],       # the circuit's sides: dark panels, orange bands
	"circuit_cap": [Color8(40, 38, 36), 0.6, 0.2],        # the circuit walls' end caps
	"fabric_auvent": [Color8(222, 223, 220), 0.7, 0.0],   # the white fabric under raised circuits
	# the border atlas' bands (texgen/borders.py; one texture, the UVs pick the band): their own
	# colours when HD is off
	"border_panel": [Color8(179, 171, 168), 0.75, 0.0],
	"border_blue": [Color8(62, 133, 254), 0.5, 0.0],
	"border_ribs": [Color8(36, 35, 31), 0.9, 0.0],
	"border_black": [Color8(16, 15, 15), 0.85, 0.0],
	"border_orange": [Color8(190, 99, 8), 0.6, 0.0],
	"fabric_orange": [Color8(201, 108, 8), 0.6, 0.0],     # the grandstands' orange strips (TMNF's FabricBorderRubber)
	"border_green": [Color8(58, 128, 66), 0.65, 0.0],
	"road_under": [Color8(141, 136, 133), 0.6, 0.3],      # the road keel's underside (TMNF's light plates)
	"road_grid": [Color8(80, 79, 78), 0.5, 0.6],         # the road shoulder's grid (TMNF's RoadGrid)
	"road_metal": [Color8(42, 40, 37), 0.7, 0.3],        # the road's dark border metal (curb ends, deck sides)
	"platform_tray": [Color8(34, 34, 34), 0.8, 0.2],     # the dark tray under the decks (TMNF's Stands2)
	# the grandstands (Fabric) as TMNF's: the stands' grey concrete top, their dark quarter-pipe
	# front (TMNF's PlatformFloor) and dark backs (Stands2); measured from its textures
	"stands_top": [Color8(149, 148, 147), 0.8, 0.0],
	"stands_front": [Color8(43, 44, 43), 0.7, 0.1],
	"stands_dark": [Color8(35, 36, 37), 0.75, 0.2],
	"control_under": [Color8(179, 181, 181), 0.7, 0.1],  # the camera lights' undersides (TMNF's Auvent)
	"booth_rim": [Color8(138, 144, 150), 0.75, 0.0],     # the ground booths' plinth rim (TMNF's, measured)
	"plinth_pad": [Color8(226, 224, 222), 0.75, 0.0],    # the sculptures' plinth pads (TMNF's white fabric, light panel)
	"pillar": [Color8(182, 183, 179), 0.8, 0.0],         # the road's pillars (TMNF's light concrete)
	"circuit_panel": [Color8(222, 223, 221), 0.55, 0.0],
	"circuit_band": [Color8(10, 72, 170), 0.45, 0.0],
	"circuit_trim": [Color8(52, 96, 160), 0.5, 0.0],
	"circuit_floor": [Color8(26, 84, 170), 0.5, 0.25],
	"circuit_bumper": [Color8(20, 20, 22), 0.85, 0.0],
	"truss": [Color8(40, 40, 41), 0.55, 0.3],
	"screen_dark": [Color(0.015, 0.018, 0.022), 0.2, 0.0],     # the circuit walls' screens: off, as TMNF's
	"control_panel": [Color8(222, 223, 221), 0.55, 0.0],
	"pub_facade": [Color8(212, 212, 210), 0.6, 0.0],    # the camera pub's sides (texgen/booth.py pub_facade)
	"pub_end": [Color8(40, 41, 43), 0.6, 0.0],         # its ends
	"glass_dark": [Color(0.09, 0.11, 0.13, 0.72), 0.05, 0.3],     # the control booths' smoked windows
	"glass_booth": [Color(0.42, 0.44, 0.45, 0.55), 0.05, 0.3],    # the glass booths' grey glass (TMNF's)
	"logo": [Color(0.12, 0.30, 0.72), 0.6, 0.0],
	"screen": [Color(0.12, 0.22, 0.48), 0.3, 0.0, 0.7],     # lit displays, as in TMNF
	"stands": [Color(0.17, 0.29, 0.58), 0.8, 0.0],                  # seats (pattern 7: sectors, rows)
	"structure": [Color(0.30, 0.31, 0.34), 0.7, 0.3],
	"grass": [Color8(66, 98, 48), 0.95, 0.0],
	"dirt": [Color8(84, 74, 58), 0.95, 0.0],
	"dirt_road": [Color8(122, 109, 92), 0.9, 0.0],     # the dirt roads' packed track (HD: _dirt_road)
	"road_to_dirt": [Color8(147, 143, 134), 0.85, 0.0],  # the asphalt where a dirt road meets the road
	"water": [Color(0.06, 0.22, 0.32, 0.86), 0.04, 0.0],
	"glass": [Color(0.70, 0.85, 0.95, 0.35), 0.05, 0.0],
	"turbo": [Color(0.95, 0.65, 0.10), 0.5, 0.0],
	"freewheel": [Color8(176, 14, 12), 0.5, 0.0],
	"turbo_rim": [Color8(40, 38, 34), 0.7, 0.0],         # the turbo deck's rim (TMNF's TURBO sign)
	"turbo_rim_out": [Color8(40, 38, 34), 0.7, 0.0],
	"race_start": [Color8(37, 135, 60), 0.75, 0.0],      # TMNF's start / finish roads (its texture's paint)
	"race_finish": [Color8(152, 35, 35), 0.75, 0.0],
	"gate_line": [Color8(62, 133, 254), 0.5, 0.0],       # the line across the road at a gate
	"inflatable": [Color(0.95, 0.85, 0.25), 0.6, 0.0],
	# the inflatable decorations, in their TMNF textures' colours (measured, area-weighted)
	"airship": [Color8(237, 230, 170), 0.4, 0.0],        # the airship's envelope (its livery's mean)
	"airship_fin": [Color8(205, 12, 10), 0.35, 0.0],     # its tail fins (TMNF's red)
	"airship_white": [Color8(244, 242, 240), 0.35, 0.0],  # its gondola, pods, bottom fin (TMNF's)
	"airship_yellow": [Color8(250, 238, 76), 0.35, 0.0],  # the bottom fin's edges (TMNF's yellow)
	"airship_window": [Color(0.09, 0.1, 0.12), 0.12, 0.5],   # the gondola's windows
	"infl_leaf": [Color8(51, 131, 41), 0.35, 0.0],
	"infl_trunk": [Color8(188, 138, 58), 0.35, 0.0],
	"infl_trunk_low": [Color8(140, 82, 33), 0.35, 0.0],
	"infl_trunk_top": [Color8(158, 110, 49), 0.35, 0.0],
	"infl_trunk_ring": [Color8(105, 62, 26), 0.35, 0.0],
	"infl_sand": [Color8(215, 164, 37), 0.4, 0.0],
	"infl_base": [Color8(125, 123, 116), 0.4, 0.0],
	"dirt_bumper": [Color8(214, 216, 216), 0.4, 0.0],
	"infl_cactus": [Color8(86, 107, 60), 0.35, 0.0],
	"infl_tree": [Color8(25, 61, 51), 0.35, 0.0],
	"infl_snow": [Color8(228, 234, 238), 0.35, 0.0],
	"infl_rope": [Color8(22, 22, 22), 0.8, 0.0],
	"infl_label": [Color8(240, 245, 206), 0.35, 0.0],
	"infl_ink": [Color8(40, 44, 40), 0.35, 0.0],
	"infl_rope_red": [Color8(231, 8, 8), 0.5, 0.0],
	"fabric": [Color(0.93, 0.93, 0.94), 0.8, 0.0],
	"fabric_roof": [Color(0.94, 0.94, 0.95), 0.8, 0.0],
	"fabric_under": [Color(0.80, 0.82, 0.86), 0.85, 0.0],     # the Fabric roofs' underside, in their shade
	"pipe": [Color(0.82, 0.84, 0.88), 0.35, 0.55],
	"rubber_dark": [Color(0.10, 0.10, 0.11), 0.9, 0.0],
	"lamp": [Color(1.0, 0.96, 0.85), 0.3, 0.0, 2.0],
	"sculpt": [Color8(195, 196, 195), 0.7, 0.0],          # the sculptures (TMNF's light concrete panels)
	# gates (blocks/tm_gate_dress.gd): the painted arch, its lit inner face per kind, the banner
	"gate": [Color(0.86, 0.87, 0.90), 0.35, 0.55],
	"gate_glow_start": [Color(0.30, 1.00, 0.45), 0.4, 0.0, 2.6],
	"gate_glow_finish": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.6],
	"gate_glow_cp": [Color(0.25, 0.82, 1.00), 0.4, 0.0, 2.6],
	"gate_glow_lap": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.6],
	"gate_lamp_start": [Color(0.30, 1.00, 0.45), 0.4, 0.0, 2.2],
	"gate_lamp_finish": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.2],
	"gate_lamp_cp": [Color(0.25, 0.82, 1.00), 0.4, 0.0, 2.2],
	"gate_lamp_lap": [Color(1.00, 0.22, 0.18), 0.4, 0.0, 2.2],
	"banner": [Color(0.03, 0.04, 0.07), 0.4, 0.2],
	"gate_shell": [Color(0.13, 0.135, 0.15), 0.7, 0.1],
	"gate_start": [Color(0.88, 0.90, 0.88), 0.7, 0.0],
	"gate_cp": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"gate_finish": [Color8(196, 28, 22), 0.7, 0.0],
	"curb_start": [Color(0.88, 0.90, 0.88), 0.7, 0.0],
	"curb_cp": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"curb_finish": [Color8(196, 28, 22), 0.7, 0.0],
	"gate_lap": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	# the cut-out cards (CUTOUT: textured always; these, their visible pixels' mean, for the checks)
	"lattice_x": [Color(0.91, 0.92, 0.93), 0.45, 0.2],
	"railing": [Color(0.2, 0.21, 0.23), 0.6, 0.4],
	"girder_dark": [Color(0.23, 0.24, 0.25), 0.6, 0.4],
	"girder_plate": [Color(0.2, 0.21, 0.22), 0.6, 0.4],
	"grate": [Color(0.18, 0.18, 0.2), 0.7, 0.4],
	"booth_glass": [Color(0.3, 0.33, 0.36), 0.2, 0.3],
	"roof_glass": [Color(0.28, 0.33, 0.35), 0.2, 0.3],
	"booth_wall": [Color(0.26, 0.27, 0.29), 0.8, 0.0],
	"curb_lap": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"curb_start_out": [Color(0.88, 0.90, 0.88), 0.7, 0.0],
	"curb_cp_out": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"curb_finish_out": [Color8(196, 28, 22), 0.7, 0.0],
	"curb_lap_out": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"bumper_cp": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"bumper_cp_out": [Color(0.12, 0.12, 0.14), 0.7, 0.0],
	"gate_lamps": [Color(0.95, 0.93, 0.85), 0.5, 0.0, 3.0],
	"spots_nose": [Color(0.2, 0.2, 0.21), 0.5, 0.2, 2.0],
	"spots_bank": [Color(0.3, 0.3, 0.31), 0.5, 0.2, 2.0],
	"sign_arrow": [Color8(56, 52, 45), 0.5, 0.0, 2.0],
	# the Stadium around the map (env/tm_stadium_build.gd)
	"concrete": [Color(0.78, 0.78, 0.76), 0.9, 0.0],
	"facade": [Color(0.70, 0.71, 0.72), 0.7, 0.1],
	"roof": [Color(0.93, 0.93, 0.95), 0.6, 0.0],
	"roof_under": [Color(0.80, 0.81, 0.83), 0.7, 0.2],
	"mast": [Color(0.92, 0.92, 0.94), 0.4, 0.4],
	"cable": [Color(0.22, 0.22, 0.24), 0.5, 0.5],
	"led": [Color(0.10, 0.22, 0.50), 0.4, 0.0, 0.6],
	"screen_on": [Color(0.25, 0.45, 0.85), 0.3, 0.0, 1.0],
	"parvis": [Color8(150, 148, 150), 0.95, 0.0],
	"parking": [Color8(50, 75, 157), 0.9, 0.0],
	"road_dark": [Color8(86, 84, 87), 0.9, 0.0],
	"plain": [Color(0.42, 0.47, 0.38), 1.0, 0.0],
}

## Textured keys (HD): our own generated maps in assets/tex (stadium/tools/texgen: <name>_albedo,
## _normal, _orm): [texture name, metres one texture covers (u along the sweep, v across it),
## world: planar world mapping (no stretching on curves, for surfaces without a direction),
## optional tint (times the albedo), optional macro variation (0..0.3, large surfaces)].
const TEXTURED := {
	"asphalt": ["road_concrete", Vector2(16.0, 16.0), true, Color.WHITE, 0.10],
	"road_to_dirt": ["road_to_dirt", Vector2(1.0, 1.0), false],     # one image over the piece (dirt.gd TO_ROAD)
	# the field, dirt roads, platforms, structures and walls (texgen/surfaces.py)
	"grass": ["stadium_grass", Vector2(32.0, 32.0), true, Color.WHITE, 0.16],
	"dirt": ["stadium_dirt", Vector2(8.0, 8.0), true, Color.WHITE, 0.14],
	# (the decks: one texture per 32 m block, its edge the blocks' seam; the tread is a DETAIL map)
	"platform": ["platform_plate", Vector2(32.0, 32.0), true, Color.WHITE, 0.05],
	"structure": ["steel_painted", Vector2(8.0, 8.0), true],
	"wall": ["wall_panels", Vector2(16.0, 16.0), true],
	"wall_dark": ["wall_panels", Vector2(16.0, 16.0), true, Color(0.36, 0.38, 0.42)],
	# the platforms' walls; the circuit walls' cladding and band (along the wall), the truss behind
	"platform_wall": ["platform_wall", Vector2(8.0, 8.0), true],
	# the circuit's sides (texgen/circuit_side.py; UV-mapped as TMNF's: TmGeo.remap_uv_sides) and
	# the white fabric under raised circuit pieces (the cladding's texture, laid flat)
	"circuit_side": ["circuit_side", Vector2(1.0, 1.0), false],
	"circuit_cap": ["circuit_side", Vector2(1.0, 1.0), false],    # its left part (circuit.gd _cap_uv)
	"fabric_auvent": ["circuit_panel", Vector2(16.0, 16.0), true],
	# the turbo pads (texgen/turbo.py; UV-mapped across the pad, as TMNF's: TmGeo.remap_uv)
	"turbo": ["turbo_pad", Vector2(1.0, 1.0), false],
	"freewheel": ["freewheel_pad", Vector2(1.0, 1.0), false],    # (texgen/turbo.py; laid out as the turbo)
	"turbo_rim": ["turbo_rim", Vector2(1.0, 1.0), false],        # (texgen/turbo.py; platform.gd PLATE_LIP)
	# the start / finish roads (texgen/gates.py race_road; road.gd _race_road maps them)
	"race_start": ["race_start", Vector2(1.0, 1.0), false],
	"race_finish": ["race_finish", Vector2(1.0, 1.0), false],
	"gate_line": ["border_atlas", Vector2(1.0, 1.0), false],     # its blue band (road.gd _gate_line)
	# TMNF's border atlas, as ours (UV-mapped: u along, 16 m a tile; v the band: TmGeo.border_uv)
	"border_panel": ["border_atlas", Vector2(1.0, 1.0), false],
	"border_blue": ["border_atlas", Vector2(1.0, 1.0), false],
	"border_ribs": ["border_atlas", Vector2(1.0, 1.0), false],
	"border_black": ["border_atlas", Vector2(1.0, 1.0), false],
	"border_orange": ["border_atlas", Vector2(1.0, 1.0), false],
	"border_green": ["border_atlas", Vector2(1.0, 1.0), false],
	# the road keel's underside (texgen/decks.py road_under; UV-mapped along and across)
	"road_under": ["road_under", Vector2(8.0, 4.0), false],
	"stands_top": ["stadium_concrete", Vector2(8.0, 8.0), true, Color(0.83, 0.82, 0.84)],
	"stands_front": ["platform_plate", Vector2(32.0, 32.0), true, Color(0.27, 0.27, 0.27)],
	"stands_dark": ["steel_truss", Vector2(8.0, 8.0), true],
	"road_grid": ["road_grid", Vector2(2.0, 1.965), false],       # (texgen/road.py grid)
	"pillar": ["stadium_concrete", Vector2(4.0, 4.0), true],
	"sculpt": ["stadium_concrete", Vector2(24.0, 24.0), true],    # the sculptures: TMNF's concrete panels, not our tiles
	"circuit_panel": ["circuit_panel", Vector2(16.0, 8.0), false],
	"circuit_band": ["circuit_band", Vector2(16.0, 3.5), false],
	"truss": ["steel_truss", Vector2(8.0, 8.0), true],
	"circuit_floor": ["circuit_kerb", Vector2(16.0, 16.0), true],     # the lane-level blue strip
	"circuit_bumper": ["circuit_bumper", Vector2(16.0, 2.0), false],  # the lane side's rubber, our name on it
	"control_panel": ["circuit_panel", Vector2(16.0, 8.0), false],     # the control booths' white sides
	"pub_facade": ["pub_facade", Vector2(2.0, 1.0), false],     # the camera pub's sides (rows: control.gd PUB)
	"pub_end": ["pub_end", Vector2(8.0, 8.0), true],    # its ends: a dark curtain wall (texgen/booth.py)
	"booth_wall": ["booth_wall", Vector2(0.5, 1.0), false],    # their room's wall (texgen/booth.py; 8 m, rows)
	"curb_face": ["road_curb_face", Vector2(8.0, 1.25), false],
	"curb_outer": ["road_curb_face", Vector2(8.0, 1.25), false],
	"shoulder": ["road_shoulder", Vector2(8.0, 2.0), false],
	"curb_top": ["road_curb_top", Vector2(8.0, 1.5), false],
	"road_lip": ["road_curb_top", Vector2(8.0, 1.5), false],
	# gates (road.gd _gate): the arch's faces, the gate block's curb faces, the light rigs
	"gate_start": ["gate_start", Vector2(8.0, 1.25), false],
	"gate_cp": ["gate_cp", Vector2(8.0, 1.25), false],
	"gate_finish": ["gate_finish", Vector2(8.0, 1.25), false],
	"gate_lap": ["gate_lap", Vector2(8.0, 1.25), false],
	# the gate block's curbs, both faces (texgen/gates.py: the word every 4 m; UV-mapped as the
	# border atlas, the face's rows spread over the texture: road.gd _entry)
	"curb_start": ["curb_start", Vector2(1.0, 1.0), false],
	"curb_cp": ["curb_cp", Vector2(1.0, 1.0), false],
	"curb_finish": ["curb_finish", Vector2(1.0, 1.0), false],
	"curb_lap": ["curb_lap", Vector2(1.0, 1.0), false],
	# the same on the curbs' outer faces, mirrored as TMNF's (its words read backwards from outside)
	"curb_start_out": ["curb_start", Vector2(-1.0, 1.0), false],
	"curb_cp_out": ["curb_cp", Vector2(-1.0, 1.0), false],
	"curb_finish_out": ["curb_finish", Vector2(-1.0, 1.0), false],
	"curb_lap_out": ["curb_lap", Vector2(-1.0, 1.0), false],
	"turbo_rim_out": ["turbo_rim", Vector2(-1.0, 1.0), false],
	# the dirt checkpoint's bumpers (dirt.gd GATE_BUMPER): the sign's word every 5 m, as TMNF's
	"bumper_cp": ["curb_cp", Vector2(1.25, 1.0), false],
	"bumper_cp_out": ["curb_cp", Vector2(-1.25, 1.0), false],
	"gate_lamps": ["gate_lamps", Vector2(2.0, 1.0), false],
	"spots_nose": ["spots_nose", Vector2(2.0, 1.0), false],     # the camera lights' top bar nose (rows; texgen/booth.py)
	"spots_bank": ["spots_bank", Vector2(1.0, 1.0), false],     # their floodlight banks' faces
	"sign_arrow": ["sign_arrow", Vector2(1.0, 1.0), false],     # the dirt roads' LED arrow signs (dirt.gd)
	# the grandstands' wave roofs (fabric.gd), the platforms' skirts
	"fabric": ["fabric_top", Vector2(8.0, 8.0), false],
	"fabric_roof": ["fabric_roof", Vector2(16.0, 10.4), false],     # the wave roofs' outside (TMNF's layout)
	"fabric_under": ["fabric_under", Vector2(16.0, 8.0), false],     # its ribs on the truss arches
	# the Stadium around the field (env/tm_stadium_build.gd): world-mapped
	"facade": ["stadium_facade", Vector2(16.0, 16.0), true],
	"concrete": ["stadium_concrete", Vector2(16.0, 16.0), true],
	"roof": ["fabric_top", Vector2(16.0, 16.0), true],
	# inflatable cushion walls (8 m pillows on the 8 m grid), the tube network's pillars and pipes
	"inflatable": ["inflatable_vinyl", Vector2(8.0, 8.0), true],
	# the decorations: one near-white vinyl (texgen/stadium.py inflatable_skin), tinted per part
	"airship": ["airship_skin", Vector2(1.0, 1.0), false],      # our livery in TMNF's layout (texgen/stadium.py)
	"infl_leaf": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(55, 142, 44)],
	"infl_trunk": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(203, 149, 63)],
	"infl_trunk_low": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(151, 89, 36)],
	"infl_trunk_top": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(171, 119, 53)],
	"infl_trunk_ring": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(114, 67, 28)],
	"infl_sand": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(232, 177, 40)],
	"infl_base": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(135, 133, 125)],
	"dirt_bumper": ["dirt_bumper", Vector2(1.0, 1.0), false],     # the dirt roads' logo bumpers (u: 8 m a tile)
	"infl_cactus": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(93, 116, 65)],
	"infl_tree": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(27, 66, 55)],
	"infl_snow": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(246, 253, 255)],
	"infl_label": ["inflatable_skin", Vector2(4.0, 4.0), true, Color8(255, 255, 223)],
	"pipe": ["pillar_steel", Vector2(8.0, 8.0), true],
}

## Detail maps over a textured key (tm_textured.gdshader): [map name (assets/tex/<name>_detail),
## metres one detail tile covers, strength].
const DETAIL := {
	"platform": ["tread_plate", 1.0, 1.0],
}

## Cut-out cards: the steel TMNF draws as alpha cards (girders, railings, catwalks), our own RGBA
## drawings (texgen/lattice.py), alpha-scissored and drawn from both sides, HD or not (a flat colour
## would fill the holes): key -> [texture set, the colour its pixels average (no texture), and
## optionally the UVs' scale and true to blend (glass) rather than cut]. Their UVs are given in
## texture units (lattice cards: u along per its tile, v across 0..1).
const CUTOUT := {
	# the booths' windows (texgen/booth.py): a 2.2 m module, u 16 m a tile along the sweep (rows)
	"booth_glass": ["booth_window", Color(0.3, 0.33, 0.36), Vector2(16.0 / 2.2, 1.0), true],
	"roof_glass": ["roof_glass", Color(0.28, 0.33, 0.35), Vector2(0.25, 0.25), true],   # the stand roofs' glass band (auto UVs: 8 m)
	"lattice_x": ["lattice_xbrace", Color(0.91, 0.92, 0.93)],
	"railing": ["lattice_railing", Color(0.2, 0.21, 0.23)],
	"girder_dark": ["lattice_girder", Color(0.23, 0.24, 0.25)],
	"girder_plate": ["lattice_plate", Color(0.2, 0.21, 0.22)],
	"grate": ["lattice_grate", Color(0.18, 0.18, 0.2)],
}

## Fabric (the grandstands' and the stadium's roofs): how much sunlight shows through underneath
## (shader "translucent"; the glow is on with SDFGI, TmRtx: tm_membrane).
const TRANSLUCENT := {"fabric": 1.0, "fabric_roof": 1.0, "fabric_under": 1.0, "roof": 1.0, "roof_under": 0.6}

## The surface shader per key: [pattern, second colour, pattern size (m), variation, bump].
## Patterns: see blocks/tm_surface.gdshader.
const SURFACES := {
	"asphalt": [1, Color(0.3, 0.3, 0.3), 0.0, 0.10, 0.015],
	"road_to_dirt": [1, Color(0.3, 0.3, 0.3), 0.0, 0.10, 0.015],
	"platform": [1, Color(0.3, 0.3, 0.3), 8.0, 0.08, 0.015],
	"sculpt": [1, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.012],
	"concrete": [1, Color(0.3, 0.3, 0.3), 6.0, 0.08, 0.015],
	"grass": [2, Color8(98, 112, 58), 8.0, 0.14, 0.02],
	"plain": [2, Color8(98, 112, 58), 24.0, 0.10, 0.0],
	"dirt": [3, Color8(150, 138, 118), 1.0, 0.12, 0.03],
	"grid": [4, Color(0.05, 0.05, 0.06), 0.12, 0.05, 0.01],
	"metal": [5, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.01],
	"structure": [5, Color(0.3, 0.3, 0.3), 2.0, 0.06, 0.01],
	"gate": [5, Color(0.3, 0.3, 0.3), 3.0, 0.04, 0.005],
	"pipe": [5, Color(0.3, 0.3, 0.3), 3.0, 0.05, 0.0],
	"mast": [5, Color(0.3, 0.3, 0.3), 6.0, 0.04, 0.0],
	"turbo": [6, Color(0.08, 0.08, 0.09), 1.2, 0.05, 0.0],
	"stands": [7, Color(0.24, 0.40, 0.74), 20.0, 0.06, 0.02],
	"screen": [8, Color(0.03, 0.06, 0.16), 1.0, 0.0, 0.0],
	"led": [8, Color(0.02, 0.05, 0.14), 1.0, 0.0, 0.0],
	"screen_on": [8, Color(0.05, 0.10, 0.30), 1.0, 0.0, 0.0],
	"fabric": [9, Color(0.3, 0.3, 0.3), 8.0, 0.05, 0.01],
	"fabric_roof": [9, Color(0.3, 0.3, 0.3), 8.0, 0.05, 0.01],
	"fabric_under": [9, Color(0.3, 0.3, 0.3), 8.0, 0.05, 0.01],
	"roof": [9, Color(0.3, 0.3, 0.3), 15.0, 0.05, 0.01],
	"roof_under": [10, Color(0.30, 0.32, 0.36), 0.6, 0.0, 0.01],
	"wall": [11, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.01],
	"wall_dark": [11, Color(0.3, 0.3, 0.3), 4.0, 0.06, 0.01],
	"logo": [11, Color(0.3, 0.3, 0.3), 8.0, 0.05, 0.01],
	"parvis": [12, Color(0.3, 0.3, 0.3), 2.0, 0.08, 0.012],
	"parking": [12, Color(0.3, 0.3, 0.3), 5.0, 0.06, 0.0],
	"road_dark": [1, Color(0.3, 0.3, 0.3), 0.0, 0.10, 0.01],
	"rubber": [0, Color(0.3, 0.3, 0.3), 0.0, 0.05, 0.005],
	"rubber_white": [0, Color(0.3, 0.3, 0.3), 0.0, 0.05, 0.005],
	"rubber_dark": [0, Color(0.3, 0.3, 0.3), 0.0, 0.05, 0.005],
	"circuit_trim": [0, Color(0.3, 0.3, 0.3), 0.0, 0.04, 0.005],
	"circuit_floor": [5, Color(0.3, 0.3, 0.3), 4.0, 0.05, 0.01],
	"inflatable": [14, Color(0.95, 0.95, 0.95), 2.4, 0.04, 0.03],
	"lamp": [13, Color(0.10, 0.10, 0.12), 4.0, 0.0, 0.0],
}


## HD graphics: the surface shader (TmUi setting "hd"; --hd=0 turns it off for a run).
static func hd() -> bool:
	# not under the RTX fork's path tracing, which draws custom shaders wrongly (the car vanished;
	# tested on an RTX 2060): there the standard materials, which it traces fully
	return bool(TmUi.setting("hd")) and String(TestHooks.arg("hd", "1")) != "0" and not TmRtx.path_tracing_active()


## Forgets the made materials (after the HD setting changes; the next scene makes them anew).
static func clear_cache() -> void:
	_cache.clear()


## A material made elsewhere, under a key (the stadium's ground with its own class map).
static func register(key: String, m: Material) -> void:
	_cache[key] = m


## The shared noise textures (fine, coarse) the procedural shaders read.
static func noise_textures() -> Array:
	if _noise_fine == null:
		_noise_fine = _noise(0.02, 3, 5)
		_noise_coarse = _noise(0.008, 9, 4)
	return [_noise_fine, _noise_coarse]


static func _noise(freq: float, seed_value: int, octaves: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.seed = seed_value
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	return t


## Textured keys whose emission map alone glows (its lenses), times this energy; the others with a
## map glow all over (colour + map).
const LENS_GLOW := {"spots_nose": 2.5, "spots_bank": 2.5, "sign_arrow": 2.5}


static func get_material(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var spec: Array = COLORS.get(key, [Color(1, 0, 1), 0.5, 0.0])
	var m: Material
	if CUTOUT.has(key):
		m = _cutout(CUTOUT[key])
	elif hd() and TEXTURED.has(key):
		m = _textured(TEXTURED[key], DETAIL.get(key, []))
		if m != null and LENS_GLOW.has(key):
			(m as ShaderMaterial).set_shader_parameter("emission_colour", Color.BLACK)
			(m as ShaderMaterial).set_shader_parameter("emission_energy", float(LENS_GLOW[key]))
	elif hd() and SURFACES.has(key):
		m = _surface(key, spec)
	elif hd() and key == "water":
		m = _water(spec)
	elif hd() and key == "dirt_road" and _tex("dirt_road", "albedo") != null:
		m = _dirt_road()
	else:
		m = _flat(spec)
	if m is ShaderMaterial and TRANSLUCENT.has(key):
		(m as ShaderMaterial).set_shader_parameter("translucent", float(TRANSLUCENT[key]))
	_cache[key] = m
	return m


static func _flat(spec: Array) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = spec[0]
	m.roughness = spec[1]
	m.metallic = spec[2]
	if spec.size() > 3:
		m.emission_enabled = true
		m.emission = spec[0]
		m.emission_energy_multiplier = spec[3]
	if (spec[0] as Color).a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A cut-out card's material (CUTOUT): its albedo's alpha cut at half, both sides drawn.
static func _cutout(spec: Array) -> Material:
	var m := ORMMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if spec.size() > 2:
		m.uv1_scale = Vector3((spec[2] as Vector2).x, (spec[2] as Vector2).y, 1.0)
	if spec.size() > 3 and bool(spec[3]):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var albedo := _tex(String(spec[0]), "albedo")
	if albedo == null:
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color = spec[1]
		return m
	m.albedo_texture = albedo
	var nrm := _tex(String(spec[0]), "normal")
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
	var orm := _tex(String(spec[0]), "orm")
	if orm != null:
		m.orm_texture = orm
	return m


## A textured material (HD): albedo, normal and ORM maps from assets/tex (blocks/tm_textured.gdshader:
## what ORMMaterial3D did, with the map's sky occlusion).
static func _textured(spec: Array, detail: Array = []) -> ShaderMaterial:
	var metres: Vector2 = spec[1]
	var m := textured(String(spec[0]), Vector2(1.0 / metres.x, 1.0 / metres.y), bool(spec[2]), 1.0 / metres.x)
	if m != null and spec.size() > 3:
		m.set_shader_parameter("tint", spec[3])
	if m != null and spec.size() > 4 and float(spec[4]) > 0.0:
		m.set_shader_parameter("macro_tex", noise_textures()[1])
		m.set_shader_parameter("macro", float(spec[4]))
	var dt := _tex(String(detail[0]), "detail") if m != null and not detail.is_empty() else null
	if dt != null:
		m.set_shader_parameter("detail_tex", dt)
		m.set_shader_parameter("has_detail", true)
		m.set_shader_parameter("detail_ratio", metres.x / float(detail[1]))
		m.set_shader_parameter("detail_strength", float(detail[2]))
	return m


## A tm_textured material for texture set `name`: on the mesh UVs times `uv_scale`, or (world) on
## three world planes, `world_scale` textures per metre. Null when the set has no albedo map.
static func textured(name: String, uv_scale := Vector2.ONE, world := false, world_scale := 1.0) -> ShaderMaterial:
	var albedo := _tex(name, "albedo")
	if albedo == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = preload("res://blocks/tm_textured.gdshader")
	m.set_shader_parameter("albedo_tex", albedo)
	m.set_shader_parameter("normal_tex", _tex(name, "normal"))
	m.set_shader_parameter("orm_tex", _tex(name, "orm"))
	var em := _tex(name, "emission")
	m.set_shader_parameter("has_emission", em != null)
	if em != null:
		m.set_shader_parameter("emission_tex", em)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("world", world)
	m.set_shader_parameter("world_scale", world_scale)
	return m


static func _tex(name: String, map: String) -> Texture2D:
	for ext in [".jpg", ".png"]:
		var path := "res://assets/tex/%s_%s%s" % [name, map, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## The dirt roads (HD, blocks/tm_dirt.gdshader): the packed track where the ground is level, the
## loose dirt ("dirt") on the berms and slopes.
static func _dirt_road() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://blocks/tm_dirt.gdshader")
	for part in ["albedo", "normal", "orm"]:
		m.set_shader_parameter("road_" + part, _tex("dirt_road", part))
		m.set_shader_parameter("loose_" + part, _tex("stadium_dirt", part))
	m.set_shader_parameter("macro_tex", noise_textures()[1])
	return m


## Water (HD): glossy, deep teal, ripples from a noise normal map projected in world space.
static func _water(spec: Array) -> StandardMaterial3D:
	var m := _flat(spec)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.03
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 4.0
	t.noise = n
	m.normal_enabled = true
	m.normal_texture = t
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


static func _surface(key: String, spec: Array) -> ShaderMaterial:
	noise_textures()
	var s: Array = SURFACES[key]
	var c: Color = spec[0]
	var m := ShaderMaterial.new()
	m.shader = preload("res://blocks/tm_surface.gdshader")
	m.set_shader_parameter("pattern", int(s[0]))
	m.set_shader_parameter("albedo", Color(c.r, c.g, c.b))   # source_color: sRGB, made linear
	m.set_shader_parameter("albedo2", s[1])
	m.set_shader_parameter("roughness", float(spec[1]))
	m.set_shader_parameter("metallic", float(spec[2]))
	var energy := float(spec[3]) if spec.size() > 3 else 0.0
	if int(s[0]) == 6:
		energy = maxf(energy, 1.0)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("scale", float(s[2]))
	m.set_shader_parameter("variation", float(s[3]))
	m.set_shader_parameter("bump", float(s[4]))
	m.set_shader_parameter("noise_fine", _noise_fine)
	m.set_shader_parameter("noise_coarse", _noise_coarse)
	if int(s[0]) == 8:
		var ads: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Adverts")
		if ads:
			m.set_shader_parameter("advert_tex", ads.call("texture"))
			m.set_shader_parameter("advert_fill", ads.call("fill_texture"))
			m.set_shader_parameter("has_advert", true)
			m.set_shader_parameter("billboard", key in TmGeo.BILLBOARDS)
	return m
