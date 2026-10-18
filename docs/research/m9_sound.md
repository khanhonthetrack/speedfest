# M9-0: TMNF's engine sound, in numbers

How TMNF's car sounds (its SoundEngine settings and car tuning, read locally; numbers only), and
how the remake does the same with its own synthesized sounds (M9-3; `audio/tm_sounds.gd`,
`audio/tm_car_audio.gd`, `stadium/tools/sfxgen/engine.py`).

## The gear model (sound only: TMNF's drive force is a function of speed, not of gear)
- Six gears; each reaches the rev limit at its top speed: 85, 110, 160, 220, 370, 400 km/h.
- Up-shift when the speed passes 0.95, 0.9, 0.95, 0.95, 1.0 of the gear below's top (gears 2-6);
  down-shift under 0.5, 0.57, 0.55, 0.6 of it (gears 3-6).
- Rev limit 11000 rpm, idle 1200 rpm; reverse tops at 85 km/h.
- At an up-shift TMNF cuts the drive for 25 ms; the sound dips (ours: the load layers for ~70 ms,
  with a clunk).

## The layers
Six loops, four under load and two coasting, each with an rpm band where it fades in and out and
a pitch that follows rpm / its recorded rpm; the throttle crossfades load and coast.

| layer | base rpm (ours) | volume | fades in (rpm) | fades out (rpm) | load |
|---|---|---|---|---|---|
| idle | 1200 | 0.85 | - | 1700-3800 | yes |
| low | 3600 | 0.6 | 500-1600 | 5200-8000 | yes |
| mid | 6600 | 0.75 | 3600-6000 | 8200-12000 | yes |
| high | 9600 | 0.9 | 6600-9200 | - | yes |
| coast low | 3600 | 0.8 | 0-600 | 6500-12000 | no |
| coast high | 9000 | 0.55 | 5000-7500 | - | no |

The bands and volumes follow TMNF's; the base rpm are our own loops'.

## Behaviour around the layers
- The rpm can't jump: it climbs and falls at most ~26000 rpm/s between ticks.
- The rev limiter flutters at the top of a gear; in the air the engine revs freely on throttle.
- Other sounds: tyre skid while wheels slide, wind rising with speed, turbo (a rush with a turbine
  whine), the countdown's beeps and go, checkpoint and lap cues, wall impacts by strength.

## Our engine's character
A four-cylinder racing engine (two firing pulses a revolution, so 11000 rpm gives TMNF's top
fundamental), exhaust ring and thump through a short pipe, intake roar under load, valvetrain
whine and crackles off load; band energies checked against TMNF's own engine samples.
`stadium/tools/sfxgen/preview.py OUT.wav` renders a standing start for listening.
