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
  tracks use). Left: the corners' raised base.
- The platform checkpoint is TMNF's: the road gate resized on the deck, the set-back edge under
  its feet, the CHECKPOINT rim (the turbo deck's TURBO rim mirrored as TMNF's). Left: the high
  dirt checkpoint's side rails and posts, the turbo deck's advert band, the platform billboard's
  struts (TMNF's are lattice beams).
- Control: the glass booths (grey glass, a room, the roof), the pubs (2:1 boards, the base's kiosk,
  frame, plinth), the camera lights (dark centre, floodlight bars), the camera galleries' rail.
- The pub base and the camera pub are TMNF's (20 Oct): the kiosk's boards flush in a border frame,
  the plinths' railing and light rim; the camera pub's facade (`texgen/booth.py pub_facade`,
  windows, lamp strip), light roof edges, dark curtain-wall ends, framed boards between posts, the
  advert band, the walkway railing. Left: the other pub forms (corner, T, cross, dead end: TMNF's
  dark wall with a board and a logo panel on the outer sides), the small logo signs.
- Others: sculptures (concrete panels, smooth shading, atlas curbs), the grandstands' white truss
  lattice, the airship's livery (our names in TMNF's layout).
- The airship is TMNF's (20 Oct): its lofts had lost the gondola and the fins, built now from
  TMNF's measured outlines (`sculpt.gd _airship`): the fins and rudders (top and sides red, the
  bottom one white with yellow along its leading edge and foot), the gondola (hull, three windows
  between white pillars, the red stripe, the dark frame), the engine pods with fans and stub
  wings, the keel girders fore and aft, the four mooring arms and their cables, the tail rounded.
  Its livery is laid out as TMNF's in the world (`texgen/stadium.py airship_skin`, mapped through
  the envelope's rings): the yellow band round it at y 29.6-44.2 (which makes the nose and the
  tail yellow), white round the side fins' roots, four lights fore and aft, the gores by angle.
  Ours keeps its name readable on both sides (TMNF's reads mirrored on one) and leaves out TMNF's
  small names and spots. Left: the frame's hangers and logo panel, the windows' interior.
- The checker reads alpha-cut textures (trusses, railings) by their visible texels now.

- The camera light's steel and spotlights are TMNF's (20 Oct): W-truss panels over the floodlight
  bars, the trusses holding them out, the grating walkway with its railing, round spotlights
  (`texgen/booth.py camera_spots`, lenses alone glowing). The platform columns' outer and inner
  faces TMNF's slotted plates (`texgen/lattice.py plate`). The dump read cut-out materials as white
  (fixed in `tests/block_dump.gd`): their "colour differs" before then was the tool's.

- The ground grandstands' orange strips (quarter-pipe ends, the lip's top), dark ends, the pillar
  piece's white back with its framed screen (20 Oct). TMNF's FabricFloorNoOcc there is grass.

- The dirt pieces' furniture (20 Oct): advert boards, bands, kiosks and logo bumpers at TMNF's
  measured places (`dirt_furniture.py` -> `blocks/data/dirt_furniture.json`, built in `dirt.gd`).
  Left: the DirtHigh fences' other parts (Auvent2, borders, grids), the bumpers' tie-downs.

- The loops' backs (20 Oct): grates, the dark spine and rails, the clamps every 22.5 degrees.

- The circuit base variants (M11-4, 20 Oct; there was no model): the bump's dome, the hole's shaft,
  the pillar pads with their pillars (`circuit.gd`). Collision 100% TMNF's on all 20 shapes; colour
  differs 4.2% (our adverts on the pillars' bands; TMNF's column hidden in the collar). The border
  atlas' rows on them read TMNF's v upward (material_check's convention): row = (1 - v) x 512.

- The glass booth's room (20 Oct): the sloping ceiling, the ground pavilion's partitions, the back
  wall dark (BaseGround missing 280 -> 1 m2). Sample TMNF's colours inside triangles, not at
  vertices: its ceiling's vertices sit on dark texels, its face is light (182).

- The glass booth's corner (21 Oct): TMNF's is no quarter circle. Its outer side runs straight to
  x 4.1, swings 35 degrees about a pivot 0.75 m in from the centre line (the glass's radius 12.6 m,
  the wall's 11.1 m: their distance out less 0.75), kinks 10 degrees onto a 45-degree chamfer and
  back; the inner side is a chamfer of the square corner (the centre line's from x 6.43), opaque
  white (ControlInterior, no glass, no room). Fidelity: CornerAir 89.2 -> 98.3%, CornerGround
  88.2 -> 99.7%.
- The air glass booths (21 Oct): TMNF's ledge is a grating walkway (AuventAlpha) at 1 m with a
  1 m railing, a landing at 0 and a stair at each open end (1 + 3 m on a straight, 3 + 2.2 m on
  the corner, along the edge), ad boards 0-1 m under its edge (straight and T side: 4-16 and
  22-28; dead end arms 4-10 from the end; round: 10-80 and 100-170 degrees each half; the
  corner's 9.6 and 18.3 m), the inner corners' grating on the ground (no railing); the glass is
  the window modules as the ground's (posts radial round the pavilions: TmGeo.UPRIGHT_ROWS), the
  wall under the walkway dark, the underside white 4 m in from each side. Ours had a solid
  ledge, plain glass, a white wall. Fidelity: 98.6-100% on all six.
- The dark steel (21 Oct): every TMNF Stands2 material (Control, Platform, Fabric, Turbo, Warp)
  draws StadiumWarpStands2D: dark (mean 35, 30-41) ribbed panels, posts, a heavy girder across the
  middle, faint braces (K toward the middle double post, opening from a post on the right), mapped
  8-14 m a tile (rotated on the booths' end caps). Our steel_truss drew bold light X's on a grid:
  redrawn in its layout (texgen decks.py), mean 34.
- The tube light system (21 Oct; 144 campaign uses): TMNF's is three lamp bars (0.6 m square,
  WarpSpots: lamps on the outer face, top and bottom, 3 m a tile) either side of the pipe along each
  arm, 12 m beside an arm with nothing on that side, 6 m on a side facing another arm, 30 m along a
  straight; a frame across each arm (two octagonal collars, plates out to the bars); a 4 m column
  at the junction with strips up its closed faces; the base no pipe, four bars up two faces of the
  column. Ours: a box, a dark sleeve, cubes in rings. Fidelity: Straight 83.5 -> 97.6%, Cross 82.7
  -> 95.8%, T 84.1 -> 96.3%, Corner 87.8 -> 97.4%, Deadend 93.0 -> 98.4%, Base 92.7 -> 99.0%.
- The inflatable ground pillar walls (21 Oct; 36 on our tracks): TMNF's pillow is no sine across:
  a steep groove at each seam (out 0.27 m at 0.2 m, 1 m at 0.8 m from it), flat low down (y 3:
  1.04-1.07 m out from 1.9 m on), a crown up top (2.15 m); now sampled on a grid (PILLOW_DEPTH).
  Its plinth face is upright to 1.5 m, then a bevel. Its banner shows from both sides (ours now
  printed on the skin behind too, reading the right way). Fidelity: TShapedPillarGround 94.8 ->
  97.6%, CornerPillarGround 98.5%. Found on the way: the air walls' trim strips threw a script
  error (never built); fixed.
- The dirt-to-road piece (21 Oct; 26 on our tracks): TMNF's curb keeps the road's section all
  along, only moved: its shoulder dips toward the sunken asphalt (its lip 0.38 m down by z 17,
  bending from x 3.9), then the curb alone sinks (0.11 m at z 17 to 0.64 m at the end) and slides
  0.97 m in between z 20 and 26. Ours dropped at z 17 into a squeezed, scaled curb. Now tables
  (dirt.gd TO_ROAD_DIP, TO_ROAD_SINK). Fidelity 92.5 -> 98.8%.
- The booths' plinth rims (bluish grey), the camera booth's walkway (white), the galleries' ends
  (dark): camera booth 127 -> 73 m2, its straight 392 -> 64, glass straight 650 -> 320 (20 Oct).
- The grandstands' wave roofs: fabric_roof in TMNF's layout (ribs every two facets, pillows).
- The dirt-to-road transition's asphalt (road_to_dirt), the LED signs (13 dirt pieces), the dirt
  pieces' border tubes (41) and the bumpers' rubber ends (StadiumRaceSignsRubber, 21 pieces).
- The platform ramp's curb underside (orange band), the turbo pads' grating, the road turbo's
  railings and fans.
- The sculptures' plinth pads (white), the snow trees' snow (on each tier's slope), the turbines'
  fans (nine dark blades) and exhaust caps (bolt rings).
- Survey of our tracks' 75 shapes after these (20 Oct, evening): colour differs 11.5%, missing
  5.5% (11.6% / 5.6% before them: the big rest is the deliberate (our adverts, the airship's
  livery, the gates' sign panels left out) and what the tool can't judge (flat lattice cards
  against our tubes, coplanar or hidden surfaces, texture pattern within a matching mean).
- Checked and left: the road pub base and the grandstand pillar piece ("differ" from coplanar or
  hidden surfaces the tool can't tell apart: a light strip 2 mm over rubber, a screen in its
  measured frame); the platform wall's orange band (its rows TMNF's; the rest is TMNF's printed
  logos, ours our emblem); the road undersides (their mean colour TMNF's; the rest is texture
  pattern).

- The platform plates' inner corners (20 Oct, late): TMNF notches its T, cross and corner plates
  at each corner between two open sides (the lip turned round an open corner square) and leaves
  the bottom plate open there; its slab sides and bottom are the dark truss (Stands2). Cross
  missing 191 -> 10 m2, T 96 -> 12, corner 56 -> 12.
- The platform checkpoint's floodlight banks (20 Oct, late): 18 banks (spots missing 54 -> 0 m2);
  TMNF's additive glow cards (WarpSpotsGlow, ~170 m2) stay "missing": our lamps are emissive.
- The gate arches' words (20 Oct, late): TMNF repeats the word every 3.08 m along the arch (u per
  metre of its RaceSigns faces); ours was 8 m. Now 3.08 (ring 2.19).
- The inflatable billboard walls (21 Oct): TMNF's ground pillars are banner cushions on a plinth
  (white banner on each red pillow, feet, posts), ours were thick red walls; rebuilt (our emblem
  on the banner). TMNF's own logo reads mirrored from the bulge side in our reference renders;
  ours reads from there (the track side).
- The camera pub (21 Oct): its ends TMNF's turned steel panels (a 12 x 6 m tile from x 4) with a
  white strip up each corner, its roof strips grey concrete (ours were white: dE 31 on 250 m2).
- The road pub (21 Oct): the boards' inner faces dark (TMNF's Stands2), the ad outward only. Its
  floor's grey middle strip already sits 2 mm over the rubber (the checker's "rubber" there is
  the coplanar case).
- The platform lip's rows (21 Oct): ours were a segment behind TMNF's (ribs on the bevel where
  TMNF has the black band); fixed on the decks and slopes, the ramp-up piece's bevel orange.
- Atlas rows (21 Oct): `rowcheck.py` (scratch: TMNF's border-atlas triangles' centroids, ours at the
  same spot, the row there) found the platform lip, slopes, dead end, the ramp's orange band, the
  sculptures' curb tops, the checkpoint notch; and TMNF's atlas on the gate arches' top and
  underside where ours had a flat shell (fixed). Worth keeping: a row shift hides from the colour
  check when both rows are dark.
- The circuit walls' bumpers (21 Oct): TMNF's atlas rows on the foot and ledge bumpers, the ledge
  bumper on TMNF's outline (atlas_rows: 0 rows off; "(none)" left where our outline still
  differs: the cap's trim and truss).
- The road keel's plates (21 Oct; TMNF's details rows 0-288 across each half) and the border
  atlas' rail rows 141-215 (TMNF's: rails, grating, slotted teeth; ours were uniform ribs), the
  panel band's frame. Compare atlases region by region (same rows): a uniform band in ours where
  TMNF's has structure won't show in mean colours.
- Survey by use (20 Oct, late): list every shape our tracks build (`TmTracks` challenges through
  `TmBlockCatalogue.shape_name`, with counts), dump those and weight each shape's missing and
  differing area by its count. The catalogue's "uses" are per block (its base form), so forms a
  neighbour chooses (junctions, T and cross plates, border corners) were missing from the
  earlier lists. Top of that list now: the grandstand straights' lattice (flat cards in TMNF),
  the airship's livery (ours), the grandstand pillar piece and the snow / palm trees (organic),
  the circuit border's blue shade, the platform turbo deck, the platform checkpoint's glow and
  spots, the road straight's underside details, the camera light and camera pub straights.

- **Inflatable castles (M11-3)**: not on our tracks, 13 uses in TMNF's campaign (A02, A09, A11,
  B11, C05, C11). TMNF's: material StadiumInflatableCastle (one 512 atlas: slate cone rows 0-37,
  trim 37-49, printed band 49-100, battlement band 105-136, stone 136-425, green cushion 425-512
  with a board in the middle), StadiumInflatable2Occ (the quilted grey roofs, the cushions' skirt),
  StadiumRoadDetails (the ropes' pegs). Measured with scratch tools (each tower's rings: axis,
  foot, shaft top, crown, tip; each wall sheet's foot line and top; the cushion rings' seams;
  battlements' boxes; the bridge's front face, lip and tunnel). Built as a kit (`castle.gd`);
  the keeps' walls round over in the slate rows, the hall's, bridge's and step walls' in the
  band's edge (rows 47-57). TMNF's u reads mirrored in our view: our u runs the other way
  (`castle.gd _right`) so our name reads left to right.

## Our tracks' blocks now (20 Oct)
The 76 shapes our tracks use (`--shapes` from our tracks), TMNF area 276,492 m2: colour differs
10.5% (13.5% at the round's start), missing 7.5% (11.8%). Left, by area times our tracks' use: the
grandstands' (Fabric) lattice TMNF draws as flat cards (missing 1,500-1,900 m2 on each straight;
ours are tubes there), the platform road's underside details (road_under against TMNF's detail
atlas, 214 m2), the airship's livery (its name and logos are ours), the snow and palm trees (organic), the circuit border's blue shade, the turbo deck, the
road gates' sign boards (left out: the owner's option B), the loops.
