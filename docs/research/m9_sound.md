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

## M10-5: TMNF's cues, measured (numbers only; `tools/research/tmnf/sound_survey.py`)
Our cues (`stadium/tools/sfxgen/cues.py`) are synthesized to these shapes; TMNF's files stay local.

| cue | TMNF's sound | length | shape | octave bands 63 Hz..16 kHz (dB) |
|---|---|---|---|---|
| 3, 2, 1 | the same beep each time | 1.11 s | a clean 756 Hz tone (octave -26 dB), struck, -1 to -11 dB over the length | - |
| Go! | the crowd's roar | 1.41 s | sustained -2..-10 dB for 0.9 s, gone by 1.4 s | 0 0 0 -1 -2 -4 -12 -24 -42 |
| checkpoint | a swoosh | 1.5 s | peak at 110 ms, -23 dB by 300 ms, a faint tail | 0 -5 -11 -14 -13 -7 0 0 -5 |
| finish, new record | silent (empty files) | - | - | - |
| gold medal | a big cheer: voices, applause, whistles | 1.8 s | rises 250 ms, holds -7..-17 dB to 1.4 s | 0 0 -4 -6 -12 -15 -6 -7 -30 |
| bronze medal | a smaller cheer | 1.8 s | rises 270 ms, holds -9..-17 dB | 0 0 -4 -6 -12 -8 -12 -10 -31 |
| wall impact | a broadband crash, rattling | 0.73 s | -1..-6 dB for 0.6 s | -7 -3 -3 -2 -3 -2 0 -3 -17 |
| landing | a heavy thump on the road | 1.09 s | peak at 190 ms, -20 dB by 500 ms | 0 -2 0 -3 -3 0 -7 -13 -30 |
| menu focus (Forever menus) | a blip, partials 760/624/487 Hz | 0.05 s | up in 30 ms | -43 -24 -14 0 0 -10 -17 -27 |
| menu confirm (Forever menus) | a tock, 260 Hz and harmonics | 0.11 s | struck, gone in 0.1 s | -62 -44 0 -3 -6 -17 -28 -41 |
| wind | an air loop | 2 s | gusting +-3 dB | -44 -10 -4 0 -2 -10 -22 -31 -38 |

TMNF's older interface set (a 0.5 s 125 Hz "whum" for focus, a bright click for confirm) sits in
its Interface folder too; the Forever menus' own effects (`Menu/Media/audio`) are the ones we follow.
Its skid (a squeal at 820-920 Hz, peaking in the 1 kHz octave) is close to our recording already.
