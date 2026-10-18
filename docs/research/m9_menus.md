# M9-0: TMNF's menus, in words

How TMNF's menus are laid out and look (surveyed locally from its menu pack: names, layout, the
skin's look; nothing copied), and where the remake has the same (M9-4, M9-5, M9-6, M9-7;
`ui/tm_menu.gd`, `ui/tm_ui.gd`, `ui/tm_glass_box.gd`, icons by `tools/texgen/ui.py`).

## Look
- Dark green, partly transparent glass panels over a blurred view of the Stadium; a gloss band
  across each panel's top, a border brighter at the top edge.
- White capitals for labels and buttons; lime green for what is focused or selected and for the
  main action (race, join); dimmed grey-green for secondary text.
- Glossy sphere checkboxes; medal discs (author, gold, silver, bronze); the series' colours on
  the campaign tabs: White, Green, Blue, Red, Black.
- Ours: panels (0.04, 0.08, 0.06) at 84%; lime (0.60, 0.88, 0.17); text (0.95, 0.97, 0.95), dim
  (0.66, 0.74, 0.70); series White (0.92, 0.93, 0.95), Green (0.30, 0.78, 0.35), Blue (0.30,
  0.52, 1.0), Red (0.92, 0.25, 0.20), Black (0.12, 0.12, 0.14). Panels are drawn as vectors
  (TmGlassBox), sharp at any resolution. The backdrop: the car in the Stadium, depth of field
  keeping the car sharp, the edges graded dark green.

## Structure
- A bar across the top: the logo, where you are (e.g. SOLO / CAMPAIGN), your nickname (with
  its colour codes) and zone.
- Main: SOLO, ONLINE, EDITORS, PROFILE, OPTIONS, QUIT.
- Solo: CAMPAIGN (a tab per series; a card per track with its map from above, number, name,
  medal and best time; the selected track's panel with the four medal times and your best, and
  RACE), REPLAYS, open a track file.
- Online: the server list (name, track, players, mode, time left), JOIN, REFRESH, join by
  address; accounts with a password and zone, the ladder points, world and zone rankings.
- Editors: the track editor (TMNF's: place blocks on the 32 x 8 x 32 grid, validate by driving
  for the author time, save) and the replay editor. Ours: NEW TRACK and the saved tracks; replays
  are watched from Solo > Replays (free and chase cameras).
- Profile: nickname with TMNF's $-codes ($RGB colours, $o bold, $i italic, $w wide, $n narrow,
  $s shadow, $t caps, $g default colour, $z reset, $l links, $$ a dollar; 75 characters), zone
  (continent, country), the car's colour, medal counts.
- Options. Ours: fullscreen, HD textures and shading,
  shadows, sound, music and its volume, racing your best ghost, graphics quality (Low / High /
  Ultra; on RTX cards DLSS and path tracing), clearing the records.
- Esc goes back a page. In a race: a pause menu (resume, restart, quit) and the finish card
  (time, medal, record, splits; replay, save replay, next track).

## In race
- The countdown: big figures 3, 2, 1, GO popping in.
- HUD: time, checkpoint splits against the best (green ahead, red behind), speed, laps.
