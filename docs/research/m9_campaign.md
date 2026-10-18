# M9-8 research: TMNF's campaign, measured (numbers and descriptions only)

Our A-E campaign (65 original tracks, owner: "Only our own A-E") follows the shape of TMNF's
Nations campaign: the same five series, the same kinds of track, the same times, checkpoints and
laps, the same surfaces. Measured locally from the official install (recreate it with
`tools/research/tmnf/setup_measurements.sh W --quick`; nothing of it is in the repo) with our own
tools: `tools/research/tmnf/campaign_stats.py <W>/tmnf/app/GameData/Tracks/Campaigns/Nations
[--md]` (the tables below) and `track_ascii.py <X.Challenge.Gbx>` (a track's blocks as ASCII maps
per level).

## The series
| series | tracks | kinds |
|---|---|---|
| A White | 15 | Race 9, Speed 2, Acrobatic 2, Obstacle 1, Endurance 1 |
| B Green | 15 | Race 8, Speed 2, Acrobatic 2, Obstacle 2, Endurance 1 |
| C Blue | 15 | Race 7, Speed 2, Acrobatic 2, Obstacle 2, Endurance 2 |
| D Red | 15 | Race 6, Speed 2, Acrobatic 2, Obstacle 2, Endurance 3 |
| E Black | 5 | Obstacle 2, Endurance 3 |

- Race: a lap of the stadium's tricks, the standard. Speed: wide, fast, turbos, few turns.
  Acrobatic: a short stunt (6-16 s: a ramp, a jump, a loop). Obstacle: narrow, precise, walls and
  drops. Endurance: long, often laps (3, 5, 10; E05 is 60 laps, an hour).
- Gold is 1.05-1.06 x the author time in every series; silver and bronze follow TMNF's rule.

## Per series (averages; the drive mix is the share of driving blocks by surface)
| series | tracks | author avg | author min-max | gold/author | laps>1 | cps avg | top avg | road % | platform % | circuit % | dirtroad % | tilt % | tuberoad % | loops | turbos | ramps |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| White | 15 | 0:23.86 | 0:05.95-1:04.48 | 1.061 | 1 | 1.1 | 11.5 | 7 | 43 | 37 | 5 | 0 | 9 | 0 | 20 | 9 |
| Green | 15 | 0:33.93 | 0:13.02-1:42.50 | 1.061 | 1 | 2.6 | 12.8 | 11 | 43 | 37 | 1 | 1 | 7 | 37 | 40 | 2 |
| Blue | 15 | 0:48.52 | 0:13.90-1:56.91 | 1.056 | 2 | 3.1 | 13.5 | 14 | 55 | 20 | 2 | 2 | 6 | 83 | 38 | 4 |
| Red | 15 | 1:34.00 | 0:14.65-7:50.66 | 1.057 | 4 | 5.1 | 13.7 | 15 | 34 | 31 | 7 | 2 | 10 | 197 | 84 | 7 |
| Black | 5 | 14:35.96 | 0:45.56-60:05.94 | 1.057 | 2 | 13.6 | 16.0 | 13 | 48 | 19 | 4 | 0 | 15 | 117 | 33 | 0 |

## Per track
| id | kind | author | gold | laps | cps | blocks | top | span | road | platform | circuit | dirtroad | tilt | tuberoad | loop | turbo | ramp | dirt | water | deco |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A01 | Race | 0:24.54 | 0:25.87 | 1 | 2 | 397 | 24 | 32x24 | 0 | 2 | 241 | 0 | 0 | 46 | 0 | 0 | 0 | 24 | 0 | 37 |
| A02 | Race | 0:16.25 | 0:17.27 | 1 | 1 | 299 | 3 | 27x15 | 0 | 0 | 0 | 16 | 0 | 0 | 0 | 0 | 0 | 267 | 0 | 13 |
| A03 | Race | 0:18.75 | 0:19.84 | 1 | 1 | 318 | 29 | 28x21 | 25 | 0 | 0 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | 196 | 66 |
| A04 | Acrobatic | 0:05.95 | 0:06.36 | 1 | 0 | 364 | 4 | 18x12 | 1 | 9 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 185 | 151 |
| A05 | Race | 0:16.91 | 0:18.05 | 1 | 2 | 343 | 7 | 20x14 | 0 | 0 | 0 | 12 | 0 | 14 | 0 | 0 | 0 | 262 | 0 | 21 |
| A06 | Obstacle | 0:28.58 | 0:30.26 | 1 | 2 | 450 | 18 | 31x14 | 24 | 0 | 0 | 0 | 0 | 8 | 0 | 0 | 7 | 1 | 365 | 4 |
| A07 | Race | 0:29.14 | 0:30.97 | 1 | 1 | 428 | 14 | 15x15 | 0 | 328 | 56 | 0 | 0 | 4 | 0 | 0 | 0 | 0 | 0 | 30 |
| A08 | Endurance | 1:04.48 | 1:08.38 | 3 | 1 | 475 | 4 | 28x20 | 0 | 17 | 208 | 0 | 0 | 15 | 0 | 1 | 0 | 0 | 163 | 59 |
| A09 | Race | 0:25.98 | 0:27.76 | 1 | 2 | 444 | 9 | 24x26 | 24 | 10 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 264 | 105 |
| A10 | Acrobatic | 0:09.64 | 0:10.14 | 1 | 0 | 218 | 10 | 22x11 | 2 | 0 | 34 | 0 | 0 | 6 | 0 | 2 | 1 | 1 | 158 | 0 |
| A11 | Race | 0:19.32 | 0:20.45 | 1 | 1 | 293 | 3 | 14x18 | 6 | 0 | 0 | 14 | 0 | 0 | 0 | 1 | 0 | 257 | 0 | 10 |
| A12 | Speed | 0:19.09 | 0:20.07 | 1 | 1 | 642 | 13 | 24x30 | 16 | 381 | 0 | 0 | 0 | 6 | 0 | 9 | 0 | 0 | 0 | 70 |
| A13 | Race | 0:31.70 | 0:33.79 | 1 | 1 | 465 | 27 | 29x25 | 19 | 105 | 91 | 0 | 2 | 66 | 0 | 2 | 0 | 0 | 0 | 17 |
| A14 | Race | 0:22.17 | 0:23.52 | 1 | 1 | 602 | 3 | 24x23 | 7 | 0 | 0 | 22 | 0 | 0 | 0 | 0 | 0 | 521 | 36 | 13 |
| A15 | Speed | 0:25.33 | 0:26.96 | 1 | 1 | 568 | 4 | 32x27 | 9 | 0 | 99 | 28 | 0 | 0 | 0 | 3 | 0 | 292 | 0 | 126 |
| B01 | Race | 0:26.20 | 0:27.80 | 1 | 2 | 618 | 11 | 25x29 | 30 | 0 | 0 | 4 | 5 | 61 | 0 | 2 | 0 | 411 | 0 | 65 |
| B02 | Race | 0:27.41 | 0:29.05 | 1 | 2 | 77 | 6 | 16x18 | 31 | 0 | 0 | 0 | 11 | 0 | 0 | 0 | 0 | 0 | 0 | 16 |
| B03 | Race | 0:27.11 | 0:28.79 | 1 | 3 | 447 | 4 | 26x14 | 12 | 0 | 0 | 13 | 0 | 0 | 0 | 1 | 0 | 367 | 0 | 41 |
| B04 | Acrobatic | 0:13.02 | 0:13.79 | 1 | 0 | 271 | 16 | 25x6 | 8 | 42 | 0 | 0 | 0 | 0 | 20 | 4 | 0 | 0 | 0 | 0 |
| B05 | Race | 0:26.28 | 0:27.57 | 1 | 2 | 827 | 10 | 22x14 | 24 | 152 | 0 | 0 | 2 | 11 | 0 | 1 | 1 | 1 | 0 | 528 |
| B06 | Obstacle | 0:27.46 | 0:29.43 | 1 | 1 | 552 | 22 | 32x20 | 0 | 116 | 234 | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 0 |
| B07 | Race | 0:30.36 | 0:32.19 | 1 | 4 | 743 | 16 | 30x22 | 9 | 114 | 0 | 0 | 5 | 18 | 0 | 2 | 0 | 2 | 325 | 51 |
| B08 | Endurance | 1:42.50 | 1:47.96 | 5 | 1 | 690 | 3 | 30x22 | 7 | 6 | 189 | 0 | 0 | 0 | 0 | 2 | 0 | 1 | 0 | 483 |
| B09 | Acrobatic | 0:13.99 | 0:14.87 | 1 | 0 | 1003 | 7 | 26x8 | 1 | 29 | 0 | 0 | 0 | 4 | 0 | 1 | 0 | 0 | 0 | 834 |
| B10 | Speed | 0:37.82 | 0:40.26 | 1 | 4 | 1690 | 24 | 29x23 | 43 | 5 | 130 | 0 | 0 | 27 | 0 | 4 | 0 | 6 | 0 | 1393 |
| B11 | Race | 0:31.44 | 0:33.70 | 1 | 5 | 1041 | 11 | 25x28 | 19 | 5 | 0 | 5 | 3 | 0 | 0 | 1 | 0 | 459 | 0 | 512 |
| B12 | Race | 0:45.50 | 0:47.50 | 1 | 3 | 729 | 11 | 26x24 | 28 | 135 | 153 | 0 | 0 | 27 | 0 | 2 | 0 | 1 | 302 | 19 |
| B13 | Obstacle | 0:25.65 | 0:27.17 | 1 | 3 | 216 | 11 | 30x11 | 15 | 8 | 0 | 0 | 0 | 0 | 17 | 9 | 0 | 0 | 9 | 95 |
| B14 | Speed | 0:32.98 | 0:35.19 | 1 | 3 | 1365 | 22 | 32x23 | 16 | 375 | 64 | 0 | 0 | 6 | 0 | 4 | 0 | 1 | 0 | 97 |
| B15 | Race | 0:41.19 | 0:43.84 | 1 | 6 | 1104 | 18 | 32x29 | 17 | 2 | 85 | 2 | 0 | 0 | 0 | 4 | 1 | 911 | 0 | 22 |
| C01 | Race | 0:29.58 | 0:31.20 | 1 | 2 | 233 | 11 | 19x18 | 15 | 0 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | 1 | 0 | 142 |
| C02 | Race | 0:42.47 | 0:44.88 | 1 | 4 | 791 | 8 | 30x32 | 16 | 14 | 0 | 22 | 7 | 0 | 0 | 2 | 0 | 491 | 0 | 227 |
| C03 | Acrobatic | 0:13.90 | 0:14.59 | 1 | 0 | 1140 | 7 | 18x20 | 6 | 6 | 0 | 0 | 0 | 0 | 4 | 1 | 0 | 0 | 152 | 957 |
| C04 | Race | 0:39.80 | 0:41.32 | 1 | 4 | 960 | 11 | 32x18 | 18 | 281 | 59 | 0 | 0 | 21 | 8 | 2 | 1 | 2 | 0 | 398 |
| C05 | Endurance | 1:56.39 | 2:04.30 | 2 | 6 | 1085 | 15 | 23x31 | 36 | 17 | 78 | 11 | 0 | 0 | 0 | 1 | 0 | 674 | 0 | 99 |
| C06 | Speed | 0:55.59 | 0:59.03 | 1 | 4 | 685 | 14 | 32x29 | 46 | 104 | 114 | 0 | 0 | 17 | 21 | 3 | 0 | 5 | 0 | 304 |
| C07 | Race | 0:40.34 | 0:41.98 | 1 | 3 | 476 | 8 | 26x24 | 23 | 92 | 20 | 13 | 0 | 0 | 0 | 0 | 1 | 202 | 0 | 41 |
| C08 | Obstacle | 0:27.72 | 0:29.73 | 1 | 2 | 670 | 30 | 31x10 | 21 | 546 | 0 | 0 | 5 | 0 | 0 | 2 | 0 | 0 | 0 | 0 |
| C09 | Race | 0:50.12 | 0:53.35 | 1 | 3 | 433 | 14 | 23x19 | 35 | 8 | 0 | 0 | 8 | 24 | 9 | 5 | 1 | 1 | 0 | 207 |
| C10 | Acrobatic | 0:15.03 | 0:15.82 | 1 | 0 | 144 | 7 | 13x10 | 7 | 0 | 0 | 0 | 6 | 0 | 0 | 1 | 0 | 0 | 0 | 124 |
| C11 | Race | 0:50.04 | 0:52.89 | 1 | 3 | 1079 | 26 | 27x32 | 43 | 35 | 26 | 15 | 3 | 5 | 0 | 4 | 0 | 681 | 0 | 227 |
| C12 | Obstacle | 0:34.68 | 0:36.53 | 1 | 3 | 529 | 7 | 18x20 | 13 | 20 | 0 | 0 | 0 | 16 | 8 | 0 | 0 | 0 | 272 | 160 |
| C13 | Race | 0:44.87 | 0:47.55 | 1 | 5 | 902 | 11 | 24x29 | 36 | 78 | 18 | 0 | 3 | 38 | 16 | 5 | 1 | 0 | 598 | 22 |
| C14 | Endurance | 1:56.91 | 2:01.28 | 3 | 2 | 707 | 14 | 32x17 | 22 | 148 | 0 | 0 | 11 | 31 | 10 | 2 | 0 | 2 | 0 | 402 |
| C15 | Speed | 0:50.34 | 0:53.92 | 1 | 6 | 852 | 20 | 32x25 | 28 | 59 | 204 | 0 | 2 | 4 | 7 | 10 | 0 | 399 | 0 | 10 |
| D01 | endurance | 2:33.26 | 2:43.04 | 5 | 3 | 556 | 21 | 27x24 | 0 | 9 | 318 | 0 | 0 | 36 | 0 | 3 | 0 | 0 | 0 | 51 |
| D02 | Race | 0:52.63 | 0:56.86 | 1 | 4 | 445 | 18 | 32x20 | 31 | 59 | 0 | 0 | 15 | 15 | 16 | 4 | 0 | 6 | 0 | 234 |
| D03 | Acrobatic | 0:15.94 | 0:16.69 | 1 | 0 | 529 | 17 | 24x20 | 5 | 35 | 0 | 0 | 0 | 0 | 15 | 4 | 0 | 0 | 453 | 0 |
| D04 | Race | 0:52.86 | 0:55.69 | 1 | 4 | 767 | 17 | 27x17 | 45 | 273 | 45 | 0 | 4 | 47 | 11 | 7 | 3 | 8 | 0 | 45 |
| D05 | Race | 1:11.43 | 1:15.09 | 1 | 8 | 610 | 10 | 29x25 | 21 | 21 | 23 | 9 | 0 | 2 | 11 | 7 | 3 | 299 | 0 | 183 |
| D06 | Obstacle | 1:10.53 | 1:14.28 | 3 | 1 | 223 | 7 | 28x17 | 9 | 46 | 0 | 0 | 0 | 0 | 67 | 3 | 0 | 0 | 0 | 8 |
| D07 | Race | 1:00.37 | 1:04.55 | 1 | 5 | 554 | 7 | 26x28 | 14 | 51 | 19 | 38 | 0 | 0 | 7 | 5 | 0 | 392 | 0 | 9 |
| D08 | Speed | 0:52.44 | 0:55.97 | 1 | 9 | 991 | 11 | 28x31 | 38 | 66 | 58 | 5 | 0 | 0 | 16 | 11 | 0 | 303 | 0 | 461 |
| D09 | obstacle | 0:46.47 | 0:48.67 | 1 | 8 | 295 | 28 | 32x9 | 11 | 35 | 32 | 0 | 0 | 3 | 0 | 5 | 0 | 6 | 0 | 118 |
| D10 | Race | 0:57.62 | 0:59.61 | 1 | 7 | 551 | 8 | 19x20 | 41 | 5 | 0 | 0 | 12 | 59 | 0 | 5 | 0 | 7 | 0 | 366 |
| D11 | Acrobatic | 0:14.65 | 0:15.63 | 1 | 1 | 596 | 9 | 30x21 | 0 | 46 | 8 | 0 | 0 | 0 | 0 | 8 | 1 | 0 | 503 | 8 |
| D12 | Speed | 0:42.79 | 0:45.67 | 1 | 7 | 355 | 13 | 32x28 | 19 | 54 | 143 | 0 | 0 | 0 | 54 | 9 | 0 | 2 | 0 | 6 |
| D13 | Race | 1:11.21 | 1:14.02 | 1 | 8 | 954 | 8 | 32x32 | 4 | 0 | 0 | 59 | 0 | 6 | 0 | 6 | 0 | 824 | 0 | 35 |
| D14 | Endurance | 2:57.09 | 3:06.54 | 3 | 5 | 376 | 29 | 32x27 | 77 | 0 | 0 | 0 | 17 | 36 | 0 | 2 | 0 | 6 | 0 | 197 |
| D15 | Endurance | 7:50.66 | 8:18.25 | 10 | 6 | 892 | 3 | 28x31 | 1 | 0 | 0 | 37 | 0 | 0 | 0 | 5 | 0 | 761 | 0 | 78 |
| E01 | Obstacle | 0:45.56 | 0:47.07 | 1 | 6 | 472 | 16 | 31x26 | 12 | 244 | 0 | 0 | 0 | 0 | 117 | 18 | 0 | 2 | 0 | 36 |
| E02 | Endurance | 4:37.48 | 4:52.26 | 1 | 25 | 907 | 12 | 32x32 | 278 | 53 | 0 | 0 | 0 | 314 | 0 | 1 | 0 | 0 | 0 | 0 |
| E03 | Endurance | 5:29.78 | 5:48.29 | 3 | 12 | 1196 | 6 | 32x32 | 2 | 3 | 0 | 105 | 0 | 0 | 0 | 0 | 0 | 985 | 0 | 68 |
| E04 | Obstacle | 2:01.06 | 2:08.64 | 1 | 18 | 1389 | 17 | 32x23 | 0 | 866 | 225 | 0 | 0 | 6 | 0 | 9 | 0 | 0 | 0 | 92 |
| E05 | Endurance | 60:05.94 | 65:00.00 | 60 | 7 | 500 | 29 | 32x32 | 30 | 14 | 245 | 0 | 0 | 45 | 0 | 5 | 0 | 9 | 0 | 24 |
(cps: checkpoint blocks; top: the highest level a driving block sits at; span: the map area the
track's blocks cover, in blocks; the surface columns count blocks, borders and walls included, so
area surfaces count high.)

## How the surfaces are laid out (from the ASCII maps)
- **Circuit** (A01, most of B and C): a raised plate, `StadiumCircuitBase` cells, 1-3 cells wide,
  usually at level 2 or high on tube A-frames; every side of the plate that faces nothing gets a
  border block in the neighbouring cell (`CircuitBorderStraight`, `CornerIn`/`CornerOut` at the
  corners, `GTCurve2In`/`Out` for rounded 2x2 turns): a 16 m wall with stands and screens whose
  inner face stands 8.985 m inside the border's cell, so a one-cell lane is ~50 m between walls.
  Slopes: `CircuitSlopeStart` / `SlopeStraight` (two levels per block) / `SlopeEnd`, with slope
  borders beside them. Gates on it are the platform gates (`StadiumPlatformCheckpoint`) or ring
  checkpoints over slopes (`StadiumCheckpointRingV`). It meets the road through
  `StadiumPlatformToRoad*` blocks (start, finish).
- **Platform** (A07, A12, the Obstacle and Speed tracks): wide plates (3-6 cells) and the platform
  walls (`PlatformWall1/2/4`, `WallBorder`, 1-4 levels high) that make corridors and drops;
  platform turbos, checkpoints, slopes (`PlatformSlope2Straight`, `BiSlope2Start/End`) and the
  quarter-pipe loops (`PlatformLoopStart/End`).
- **Road** (`StadiumRoadMain*`, what our SF tracks use): the narrow tarmac with clips, GT curves,
  slopes, turbos, loops; in TMNF's campaign mostly the start and finish and connections.
- **Dirt** (A02, A05, A11, A14): `StadiumRoadDirt*` on the ground among dirt hills
  (`StadiumDirtHill`, `StadiumDirt`), with `RoadDirtToRoad` where it meets the road.
- **Tube roads** (`StadiumTubeRoad*`) carry roads high; tube pillars hold everything up.
- **Water** (`StadiumPool`, `StadiumWater`): lakes beside and under the track (Speed, Race).
- Decoration: inflatables, fabric stands, sculptures, control (camera/glass/pub) blocks along roads.

## What our campaign takes from this
- Times per series: A 15-30 s (Acrobatic 6-10 s, one Endurance ~1 min, 3 laps), B 25-45 s,
  C 30-60 s (two Endurance ~2 min), D 45 s-1:15 (three Endurance 2:30-8 min with laps), E 0:45-5:30
  (E05 an endurance of many laps).
- Checkpoints: A 1-2, B 1-5, C 2-6, D 3-9, E 5-25.
- Surfaces: every series mixes circuit, platform, road and dirt as TMNF's does (road alone is
  what made our SF tracks look cheap next to TMNF's).
