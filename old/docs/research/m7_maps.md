# M7-6 maps: Trackmania Exchange styles → 24 new SpeedFest maps

Owner (session 7): "The maps are literally copy paste of each other ... get inspiration from 10000+
maps from trackmania (TMX) ... I want 30+ HIGH QUALITY, different maps." TMX maps are their authors'
work: we study styles and design originals; nothing is copied.

## 1. What TMX players build (sample of 1,000 recent maps, TMX JSON API, 2026-10-16)

| Tag | Share | Tag | Share |
|---|---|---|---|
| Altered Nadeo | 16.7% | Dirt | 5.7% |
| LOL | 16.2% | SnowCar | 5.4% |
| Underwater | 13.1% | Ice | 4.8% |
| DesertCar | 12.8% | RallyCar | 4.4% |
| Race | 10.2% | Plastic | 4.3% |
| Mini | 9.6% | Transitional | 3.6% |
| SpeedMapping | 9.3% | FullSpeed | 3.4% |
| Reactor | 8.0% | Grass / Wood | 2.4% each |
| Tech | 5.7% | Bobsleigh / SpeedFun / Precision | ~1.8% each |

Author-time lengths: p25 15 s, **median 25 s**, p75 43 s. The owner's 10–30 s window is the core
of what people play. (72 tags exist; Engine Off, No Steer, Slow Motion, Fragile, Cruise are
TM2020 special-block styles.)

## 2. What makes a map good (rules we design and test against)

- **One signature idea per map**, and the rest of the map sets it up. No boost→turn→loop→wall
  ride→jump template.
- **Flow and readability**: the next move is visible before you need it (signs, pads, colour of
  the surface); no blind drops; landings are wide.
- **A choice or a skill**: a shortcut with a cost, a surface that rewards technique, a line that
  is faster but riskier.
- **Checkpoints** every 6–10 s, before the hard part (respawns are cheap).
- **Different rhythm per map**: tech (slow, precise), fullspeed (no braking), mixed transitional,
  platform (precision), stunt (air).
- **Verified**: test_tracks geometry, AutoDriver (analog + keyboard emulation) finishes with 0
  respawns, target time 10–30 s.

## 3. Pieces available (after M7-6 steps 1–2)

Turns (bank), straights (climb/drop), loops (lateral shift), wall rides, jumps (kicker, gap,
drop, finish-through), half-pipe 180s, buildings (rooftops, drive-through, facades), grind rails
(non-magnetic), gaps (`nodeck`), boost / super boost / **side** pads, ground surfaces **grass,
gravel, sand, dirt, ice, plastic**, weather puddles, and **special pads: engine off, no steering,
cruise control, reactor boost, reset**.

## 4. The 24 new maps (theme · style · target)

| # | id | Name | Theme | Style | ~s | Signature |
|---|---|---|---|---|---|---|
| 1 | frost | Frostbite | arena | Ice | 20 | banked ice bowl turns: brake on asphalt, slide the ice |
| 2 | dust | Dust Devil | coast | Dirt | 22 | dirt hairpins you drift, dune hops |
| 3 | blackout | Blackout | city | Engine Off | 20 | the engine cuts at the top; momentum only, down through the towers |
| 4 | glide | Glider | arena | Reactor | 18 | reactor over a 60 m gap, steer in the air to the landing |
| 5 | techlab | Tech Lab | arena | Tech | 24 | tight hairpins and chicanes on a narrow deck, no walls |
| 6 | fullsend | Full Send | coast | FullSpeed | 26 | never brake: sweepers, drops, boosts |
| 7 | cruise | Autopilot | city | Cruise | 20 | cruise locks the speed through a wall ride and loop; you only steer |
| 8 | plastic | Plastic Fantastic | arena | Plastic | 18 | plastic slows you: boosts placed so lines matter |
| 9 | sausage | Sausage Run | coast | Bumps | 16 | rolling humps: keep the wheels down |
| 10 | mixer | Surface Mixer | arena | Transitional | 25 | asphalt → dirt → ice → grass → plastic |
| 11 | platform | Stepping Stones | arena | Platform | 15 | short hops between narrow platforms |
| 12 | snake | Snake Alley | city | Tech | 22 | S-bend chain between towers |
| 13 | nosteer | Locked In | arena | No Steer | 16 | no-steer chutes: line up before the pad |
| 14 | canyon | Canyon Run | coast | Race | 28 | cliff wall ride into a canyon drop |
| 15 | icepipe | Ice Pipe | arena | Ice/Bobsleigh | 20 | an ice half-pipe slalom |
| 16 | grassland | Green Mile | coast | Grass | 22 | grass cuts on every corner |
| 17 | skyline | Skyline Hop | city | Platform/Rooftop | 18 | roof to roof, the last on a rail |
| 18 | dropzone | Drop Zone | arena | Stunt | 16 | three big drops, each landing a turn |
| 19 | rally | Rally Stage | coast | Dirt/Gravel | 28 | a rally stage: dirt, gravel, crests |
| 20 | spiral | Spiral | arena | Race | 20 | a climbing banked spiral, then a dive |
| 21 | neonrush | Neon Rush | city | SpeedFun | 22 | boosts and a big wall ride, pure flow |
| 22 | zigzag | Zig Zag | arena | Tech | 18 | alternating 90s on and off the boost |
| 23 | coastline | Coastline | coast | FullSpeed | 24 | long fast sea-level sweeps, puddles in rain |
| 24 | finale | Grand Finale | arena | Mixed | 30 | a bit of everything, ends through the arch |

With the 10 existing maps: 34. Each new map is one file in `game/tracks/defs/`, registered in
`TrackDefs`, `test_tracks` RANGES and the LIVE playlist. Built in batches of four, each batch
verified and pushed (branch `m7-maps`).
