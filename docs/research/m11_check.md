# M11: the block-by-block look check against TMNF (session 13, 19 Oct)

Owner: "yes do the systematic check and fix everything". Tool: `stadium/tests/block_dump.tscn` +
`tools/research/tmnf/material_check.py` (tools/research/tmnf/README.md, "Look check"). TMNF's
meshes and textures stay local; only our numbers are here.

## How it measures
Points every 0.5 m over TMNF's visual meshes (548 shapes we build, of TMNF's 653), each with the
colour of TMNF's texture there (blurred to 32 x 32, so an atlas's bands survive but not its grain;
TMNF's v runs up), matched to our nearest surface facing the same way within 0.35 m; colours
compared in Lab (differs: dE > 25). TMNF's grass materials draw with a shader of their own and are
compared as the grass TMNF shows. Our colour per material key is its mean albedo (texture mean x
tint), so patterned keys (turbo stripes, seats) read as their mean. Caveats: TMNF's alpha-card
trusses and glows count as surface; faces of ours hidden inside solids (a ledge's bottom, a wall's
inner sides) count as extra.

## First run (all shapes)
TMNF area 1.9 km2: colour differs on 23%, missing 18%, extra 0.24 km2. Weighted by our 65 tracks'
block counts, the largest, per our material key (TMNF colours sRGB):

| our key (colour) | TMNF material it covers -> TMNF colour | where | fix |
|---|---|---|---|
| structure (73 77 82) | RoadDetails 141 135 132; FabricAuvent2 222; Sculpt/FabricStructure 212; RoadBorderMetal 40; Stands2 34 | road sides, circuit walls' undersides, bridges, platform road sides | split by face: road sides light, undersides white fabric, border metal dark, stands dark |
| wall_dark (80 85 96) | Circuit 65 55 45; FabricAuvent2 222 (circuit base underside) | circuit base and wall sides | warm dark; base underside white fabric |
| metal (158 163 173) | RoadBorderMetal 42 39 36; PlatformRoadBorder 41 42 49; RoadDetails 26; FabricInterior 141 147 152 | road and platform borders; circuit wall band | dark border metal except the circuit wall's light band |
| curb_top (199 199 195) | RoadBorderMetal 84 81 78 | road curbs' tops | darker |
| curb_outer (35 43 54) | RoadBorderRubber 35 40 54 (ok); RoadBorderMetal 162 155 152 | curbs' outer side | the metal part light |
| shoulder (67 72 82) | RoadGrid 80 79 78 (ok); RoadBorder 66 125 76 (green band) | road shoulders | the green band of TMNF's border atlas |
| grid (107 112 122) | RoadGrid 80 79 78 | grids | warmer, darker |
| platform_wall (43 47 47) | PlatformFloor 44 (ok); RoadBorder orange band (top, bottom, ends) | platform walls | the orange band on the edges |
| platform (166 164 161) | Platform 167 (ok); FabricPlatformFloor 44 | grandstands' floors | dark floor there |
| fabric (233) | Fabric 238 (ok); Airship 225 214 175 | airship | its own beige |

TMNF's StadiumRoadBorder atlas (1024 x 512), bands top to bottom: light grey panel, dark ribbed
rubber, black band with a logo and a white line, blue line, orange band with logos, blue line,
green band with a white line. Faces pick a band by v (platform wall edges: rows 298-391, the
orange band between its blue lines). Ours will be our own atlas with the same bands (our logo).

Missing geometry, largest: the grandstands' alpha-card trusses (StructureAlpha / StructureGeneric,
Fabric pieces), the arch rings' and bridges' pillars (Sculpt: possibly an offset; check),
platform pieces' undersides (PlatformAuventAlpha), inflatable castles and trees (our shapes
don't overlap TMNF's), dirt roads' fabric, grid and logos (Road/Dirt), control booths' interiors.
Not real: EditorHelpers, light glows (WarpSpotsGlow).

## Fixed so far (M11-2)
- Platform walls (the orange band on top, foot and ends) and turbo pads (road and platform):
  our border atlas and turbo texture, UV-mapped as TMNF's (PROGRESS, 19 Oct).
- Circuit, 63 shapes (`--shape=Circuit`): colour differs 20.1% -> 9.1%, missing 2.8% -> 0.8%,
  extra 67,478 -> 3,332 m². Our circuit side texture on every upright face (TMNF's StadiumCircuit
  rows; mean dE 12), the walls' end caps on its left quarter, TMNF's white fabric under raised
  pieces and its dark stands' floor under the strip; slope bases as TMNF's (an 8 m plate along
  the road, a pillar under it). Left in the circuit list: the blue strip's shade (ours (24, 81,
  161) against TMNF's texture mean (51, 95, 155), mean dE 18, chosen from TMNF's renders in M9),
  the thin rubber strip under the wall's foot (TMNF's light blue-grey, ours dark; under the wall)
  and the band edges on the wall's road face (a few m² per shape).
- Roads (`--shape=Road/`, 208 shapes): colour differs 10.5%, missing 10.5% (most of the missing
  is the dirt roads' fabric, structure, grid and logos, and EditorHelpers, not real). The section's
  bands are TMNF's atlas rows; the keel's plates, the grid, pillars, noses, ground slopes (raised
  section and pillar) as TMNF's. Left: the junctions' underside (TMNF's keel bands round the
  corners; ours a flat plate), the brackets under the shoulders (RoadDetails, every 16 m), the
  turbo gantry (TurboStands2 / TurboAlpha), the dirt roads (next). Done since: FreeWheeling's red
  chevron pads, the start / finish roads (RoadRace's layout) and the gate line (the blue band).
- Inflatable decorations (M11-3): palm trees, snow trees and cacti rebuilt from TMNF's layout
  (`blob_slices.py`); collision fidelity cactus 94.6%, palm 82.4%, snow tree 84.7% (organic
  shapes against a 0.15 m test). Left: the castles (14-22%), the cushion structures' details.
- Platforms: the decks' underside (plate, hub, column beams by open sides), the slopes' frame
  (post, struts, trusses), the turbo deck's engine room (floor, four turbines, the TURBO rim), the
  checkpoint arch and ring (panel faces, the CHECKPOINT band, the billboard's fall), the open ends
  dark, the ramp onto the road with green shoulders. BaseAir: missing 766 -> 123 m2; 2StraightAir
  differ 1211 -> 197 m2; Turbo missing 2820 -> 814 m2.
- Roads: FreeWheeling pads, the start / finish roads (RoadRace's layout) and the gate line (the
  blue band; `TmGeo.split_mat`), the gates' word bands (FINISH white on red), the turbo gantry
  (turbines, railing, TURBO curbs), the tubes and pipe pillars (StadiumPillar), the dirt roads'
  curbs at the road and the dirt checkpoint's bumpers; the gates' feet (clamps with straps,
  eight-sided struts, lattice, light rigs; the dirt gates the road gate resized as TMNF's) and
  every gate block's curb signs (both faces, the word every 4 m on panels, mirrored outside;
  MULTILAP on the multilap). Left out with the sign boards (option B): the checkpoint's clamp at
  z 5.8 and its brace up to the boards.
- The grandstands' steel (TMNF's alpha-card lattices): cut-out cards (`TmMaterials.CUTOUT`,
  `texgen/lattice.py`); the raised straight's open base, the roofs' spine, catwalks, floodlights
  and railings, the raised pillar's tower (Fabric missing 9,727 -> 4,874 m2 on the four pieces our
  tracks use). Left: the corners' raised base, the ground pillar's orange end strips.
- The platform checkpoint is TMNF's: the road gate resized on the deck, the set-back edge under
  its feet, the CHECKPOINT rim (the turbo deck's TURBO rim mirrored as TMNF's). Left: the high
  dirt checkpoint's side rails and posts, the turbo deck's advert band, the platform billboard's
  struts (TMNF's are lattice beams).
- Control: the glass booths (grey glass, a room, the roof), the pubs (2:1 boards, the base's kiosk,
  frame, plinth), the camera lights (dark centre, floodlight bars), the camera galleries' rail.
- Others: sculptures (concrete panels, smooth shading, atlas curbs), the grandstands' white truss
  lattice, the airship's livery (our names in TMNF's layout).
- The checker reads alpha-cut textures (trusses, railings) by their visible texels now.

## Our tracks' blocks now (20 Oct)
The 76 shapes our tracks use (`--shapes` from our tracks), TMNF area 276,472 m2: colour differs
13.5%, missing 11.8%. Left, by area times our tracks' use: the grandstands' (Fabric) lattice and
girders (StructureAlpha / StructureGeneric / AuventAlpha alpha cards: their catwalks, the main
spine, the raised deck's lattice legs; missing 1,100-4,600 m2 a piece), the airship's gondola
frame, the snow and palm trees (organic), the circuit border's blue shade, the camera lights'
truss supports, the road gates' sign boards (left out: the owner's option B), the loops.
