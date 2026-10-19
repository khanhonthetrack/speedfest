# M9-0: TMNF's look, in numbers and words

What the remake measured of TrackMania Nations Forever's Stadium look, to build our own art to
match (M9-2). Numbers and descriptions only: TMNF's files were read locally from the free
installer (`tools/research/tmnf/setup_measurements.sh`, `ref_visuals.py`), nothing of them is in
the repo. Our counterparts are named in brackets.

## How TMNF's materials are made
- Each material names up to five maps: D diffuse, N normal, S specular, O occlusion, L light
  (lightmap). The textures are plain .dds files in `GameData/Stadium`.
- **Normal maps keep x in the alpha channel** (red is empty, y in green; "DXT5nm" style). Read as
  RGB they lean every surface along -x and change its brightness by a third; the reference
  viewer (`blocks/tm_ref_visuals.gd`) moves alpha into red. Before that fix TMNF's decks looked
  40% brighter than ours in the same light; after it, 127 against our 115.
- v runs up in TMNF's texture coordinates; meshes carry two UV sets (the second for the lightmap).
- Lighting is baked ("Compute Shadows" into the L maps) over a sun and a flat ambient (see Light).

## Decks (platform and circuit tops) [key "platform"]
- Diffuse (166-170, 165-169, 162-166): light grey steel, a fine herringbone/diamond tread at a few
  centimetres, horizontal smears and scratches, dark skid marks; no tile grid. One texture spans
  the deck; the visible seams are the 32 m block edges.
- [ours: `platform_plate` per 32 m block, world-mapped, and the `tread_plate` detail map, 1 m]

## Platform walls [key "platform_wall"]
- `Platform/Wall/BorderAir` (the wall on a platform's edge): both 32 x 8 m faces StadiumPlatformFloor,
  dark charcoal concrete (44, 44, 44) with vertical streaks, a lighter concrete cap. Rendered in
  the Day light about (50, 62, 72): the sky's blue in the shade. Joints every 8 m and halfway up.
- The grid walls (`Platform/Wall/1Air` ...): the same dark face between x 8 and 24, steel grid
  either side, pipe rails at 4 m.

## Circuit walls (Circuit/Border) [keys circuit_*]
The wall's 16 m face is on the outside (toward the grass); the lane is at the 8 m ledge on the
other side. From the material placement on the straight border's section (block z 22.4-32):
- **Outside, bottom to top**: black rubber bumper 0.1-1.28 m (RGB ~25), a light grey band
  1.28-2.41, white 2.41-3.4, the blue band 3.4-7.0 (blue (7-24, 78-85, 172-180) with a dot matrix
  and a white logo), white cladding 7.0-14.86 (222, 223, 221; smooth, faint vertical streaks),
  the top lip 14.86-16 dark blue-grey (66-87, 113-126, 160-177).
- **Lane side, bottom to top**: the ledge strip at 8 m, z 27-32, dark blue (32, 70, 117) (it is
  4.91 m wide on every border: on corners, GT curves and diagonals it follows the wall that far,
  radially, and the rest of the ledge is the lane's deck, StadiumPlatform; blue / deck m² on the
  ledge top, e.g. Corner In 227.5 / 220.8, GTCurve 3 In 721.0 / 1975.9, 3 Out 512.2 / 2192.4,
  Diag In 144.2 / 512.0, Corner and Diag Out all blue); black
  rubber 8.3-9.4 with small logos; the screen 9.6-12.7 (black: a display surface); dark steel
  truss 12.7-15.1 (35-40 grey); the blue lip on top.
- The cap is white with blue edges; the inside faces under the ledge are the dark truss.
- [ours: `circuit_band` (our name instead of the logo), `circuit_panel`, `circuit_trim`,
  `circuit_floor`, `rubber_dark`, `truss`. Our screens show the adverts.]

## Dirt roads (Road/Dirt) [key "dirt_road", blocks/tm_dirt.gdshader]
- The track (StadiumDirtRoad, mean (108, 96, 80)): packed earth combed by tyres into fine streaks
  along the road, lighter and smoother than the berms; mapped along the road.
- Berms and hills (StadiumDirt1, mean (67, 61, 49)): darker loose earth.
- Along the edges, on the grass: **grass tufts**, four shell layers (StadiumGrassFence, 0-0.5 m above
  the ground, alpha-tested blades). They look like a fence in a renderer that ignores the alpha;
  there are no fences on the plain pieces (`FenceRoadDirtStraight` adds rubber barriers with
  signs).

## Control blocks (camera galleries, glass rows, light rigs) [control.gd]
- Roof: the dark truss texture (StadiumControlStands2, ~35 grey) with a grey rim.
- Sides: white panels (ControlAuvent2, 223) and grey (ControlStands, 153); windows smoked glass
  (ControlGlass, ~90, alpha 0.6); a semi-transparent dark lattice awning (AuventAlpha, 47, alpha
  0.71); the pub rows carry advert screens.

## Grandstands (Fabric) [fabric.gd]
- Skin: white fabric panels. Underside: the same fabric with painted X bracing, 2 panels across a
  block (16 m) by 9 round the curve (~7.3 m).
- **Truss arches** under the roof (StadiumStructureAlpha, an alpha-tested lattice; chords
  StadiumStructureGeneric, white): light arches 1.46 m deep and 0.6 m thick at block z 0.3, 12.5,
  19.5, 31.7; the main arch at z 16, 1.1 m thick, 5.4 m deep at the foot to 4.8 m at the top
  (bottom chord 4.7 to 4.1 m below the fabric).
- **Boards** (StadiumScreen2x1, the advert material): two 9.1 x 4 m boards hung under the main
  truss facing the field (straight piece: x 37.8-40.8, y 27.7-30.4, z 6.6-15.7 and 16.3-25.4;
  the air piece 6.3 m lower and 2 m in), one 12.2 x 5.4 m on the back of the roof's foot.
- Raised stands (the Air variant) stand on fabric pillars: a ground piece, then pieces three
  levels tall (A07: pillars at levels 1, 2, 5, the stand at 8).

## Gates, adverts, stadium (the first pass, PROGRESS 18 Oct "M9-2: the look, first pass")
- Gates: the arch's faces a rubber band with the word repeated (START / CHECKPOINT / FINISH), a
  dark underside with lit strips in the gate's colour (start green, checkpoint blue, finish red),
  light rigs on the shoulders, the word on the gate block's curbs, pads painted on the road.
- Adverts: boards round the field (Ad 8x1, 2x1 formats), screens; TMNF's are its sponsors and its
  own logos (ours: fictional brands, `texgen/brands.py`, `adverts.py`).
- Stadium: precast concrete stands with glazed boxes, white membrane roofs on masts, the field's
  mown grass in 8 m stripes, a parking ring outside.

## Light (TMNF's "Day" mood, `env/tm_stadium_env.gd`)
- Latitude 48 deg, day time 0.65 of 24 h, an equinox sun 23 deg up in the south-west, white at
  intensity 1, shadows at 0.4; the ambient (94, 96, 108); the sky gradient from (62, 105, 159) at
  the zenith to (213, 229, 240) at the horizon; clouds between (196, 209, 218) and (250, 251, 251).
- TMNF bakes its shadows and occlusion; we compute the sky occlusion at load (`env/tm_occlusion.gd`)
  and, on Ultra, SDFGI. Membrane roofs let 10-15% of the sun through: TMNF's bakes and photos
  show their undersides light, which SDFGI alone doesn't (Ultra adds the glow, `TmRtx.MEMBRANE`).

## How to compare (local only)
`stadium/tools/run.sh res://race/map_view.tscn -- --track=<ours or --map=TMNF.gbx> --view=<...>
--ref=<ref_visuals output>`: TMNF's meshes and textures in our light at the same camera. Views
that worked: `path:<frac>` (a driver's view), `gate:<block>:<i>:<dist>:<height>:<side>:<look_y>
--gz=<z>` (a wall from outside or the lane, under a roof), `near:<block>:<i>:<zoom>`.
