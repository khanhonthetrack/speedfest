# PLAN — SpeedFest on the Stadium foundation

Set by the owner on 2026-10-19 (verbatim in `docs/TRANSCRIPT.md`):

> 1. Remove the browser version of speedfest. 2. Put all the files for the "main" to some "old"
> folder. 3. Put the stadium part as the "main". 4. The stadium branch is the foundation of the game.
> 5. Introduce a garage, with 5 cars. There will be a formula car, but now modify it to look like
> FIA F4 car. Then, one sportscar, one polonez type, one more offroad, and another sportcars. Add
> tuning options, with around 10 options of modificiations for each cars, remmeber about lights and
> other fancy stuff. It should feel like need for speed underground 2. Cars should have different
> specs each, such as top speed, boost gain etc. You have maniapark for inspiration.
> 3. Now, instead of stadium as the background, it should be a city, so a lot of buildings, tall
> buildings. 4. It shiuld be neon lights, lots of them. So, the tracks should have some neon lights
> (also make use of rtx). 5. Dont use cheap assets, it is high budget. Dont be scared of space or
> anything. You have all the tm exchange etc for inspiration. 6. Set the environement to be at night.

## S1 — Restructure (done)
- [x] Browser version deleted: `server/public` (47 MB web export), `game/web/shell.html`, the Web
      export preset, `tools/export_web.sh`, `tools/publish_web_build.sh`, the three browser test
      harnesses, `render.yaml`.
- [x] The old game archived under `old/` (`old/game`, `old/server`, `old/tools`, `old/docs`).
- [x] `stadium/` promoted to `game/`; new root `tools/` (run_scene, godot_import, check_scripts,
      test_all); `README.md`, `CLAUDE.md` and the docs rewritten for the new layout.
- [x] The ported tests still pass (model lab 44, car body 22, car shapes 11, gbx 3).

## S2 — Foundation
- [ ] `Settings` autoload: quality 0–3, RTX-fork detection, one `tune_environment()` that owns the
      night look (sky, fog, glow, SDFGI, SSR, SSIL, volumetric fog, TAA).
- [ ] `Garage` autoload: owned cars, per-car tuning, paint and lights; saved to `user://garage.json`.
- [ ] `Game` autoload: the selected car and track, race results.
- [ ] `MeshKit` ported into `game/core/` (procedural geometry accumulator, one surface per material).

## S3 — The five cars
| id | name | type | character |
|---|---|---|---|
| `f4` | Vireo F4 | FIA F4 single-seater | highest grip and corner speed, low mass, small boost tank |
| `kaze` | Kaze RS | JDM sportscar | balanced, drift-friendly, fast boost refill |
| `vector` | Vector GT8 | euro/US sportscar | highest top speed, heavy, slower turn-in |
| `polonez` | Lodowiec 1600 | Polonez-type classic | boxy, soft, loose tail, big boost gain, modest top speed |
| `ridge` | Ridge RX | offroad truck | dirt/kerb grip, long travel, torque off the line, low top speed |
- [ ] Specs per car on the TMNF model (`accel_mul`, `grip_mul`, `brake_mul`, `steer_mul`,
      `slide_grip`, `max_speed`) plus mass, boost capacity and boost gain.
- [ ] Procedural models (no binary art): body, glass, lights, wheels, interior, wings.

## S4 — Tuning (NFSU2 style, 16 slots)
Performance: engine, turbo, nitrous, tyres, brakes, suspension, gearbox, weight.
Visual: body kit, spoiler, rims, paint + finish, vinyl, neon underglow, headlights, window tint.
- [ ] Catalogue with levels, labels, price and effect per slot.
- [ ] Effects applied to the car model multipliers and to the procedural model.

## S5 — Garage screen
- [ ] Carousel of the five cars on a lit turntable, spec bars, category/part menus, live preview.

## S6 — Night city
- [ ] Tower generator (emissive window grids, setbacks, rooftop masts and aircraft lights).
- [ ] Neon: facade tubes, kanji/word signs, animated billboards, street-level glow, light poles.
- [ ] District layout around the track, distant skyline, night sky, volumetric fog.

## S7 — Track
- [ ] Track definition + builder: road ribbon, neon edge strips, tube barriers, light arches,
      boost pads, checkpoints, start/finish, respawn.
- [ ] Circuit 1: Neon Downtown. Plus the arena kept as a physics lab.

## S8 — Race and HUD
- [ ] Countdown, lap and checkpoint timing, best time, respawn, results.
- [ ] HUD: speed, time, splits, boost meter, lap counter.
- [ ] Main menu -> garage -> race flow.

## Ownership
One agent at a time (owner rule). Module boundaries: `core/` (physics, never edited for looks),
`cars/`, `city/`, `track/`, `ui/`, `race/`.
