# Session 13 code review: findings

A multi-agent review (read-only) of session 13's menus, replays, editor and online code, 18 Oct.
Its verifiers confirmed the first 14; the rest were never verified (the run hit the account's
usage limit). Each is checked by reading the code before it is fixed. Status: open / fixed
(commit) / not a defect (why).

| # | status | sev | where | finding |
|---|---|---|---|---|
| 0 | fixed: selection on press only, DELETE names its target | high | `ui/tm_menu.gd:579` | Replays page: DELETE and WATCH act on the last row the mouse or focus passed over, not the selected row |
| 1 | fixed: replays keep the laps and checkpoints; lap lines count laps, lap_done | medium | `race/replay.gd:373` | Replay HUD treats lap-line splits as checkpoints: wrong counts, no laps shown in lap races |
| 2 | fixed: TestHooks.is_testing from the command line only | medium | `race/replay.gd:114` | Viewer never shows its error in normal play (blank screen) because TestHooks.is_testing() is true after menu navigation |
| 3 | fixed: the viewer's keys in _input; the time line seeks on change | medium | `race/replay.gd:447` | Replay keyboard shortcuts break once a bar control has focus (focus follows the mouse) |
| 4 | fixed: TAIL_MS recorded after the finish; paused: still car, sound held | medium | `race/replay.gd:325` | Puppet keeps its finish speed, throttle and spinning wheels while time stands still (2.5 s tail, pause) |
| 5 | fixed: Esc from the viewer comes back to the finish menu (SAVE still there) | medium | `race/race.gd:299` | Watching the run from the finish menu discards it: SAVE REPLAY is impossible afterwards |
| 6 | fixed: only _last hidden; names lose $-codes and a leading _ | medium | `race/tm_replay.gd:212` | Saved replays whose file name starts with '_' never appear in the list |
| 7 | fixed: the turbo cue on its rising edge (a seek resets it) | low | `race/replay.gd:336` | Turbo sound is lost after seeking backwards in the viewer |
| 8 | fixed: F_TURBO on the turbo's start only; the race's cue too | low | `race/tm_replay.gd:74` | F_TURBO is recorded on every tick spent on a pad, not once per turbo, so the turbo cue retriggers |
| 9 | fixed: audio.race set | low | `race/replay.gd:96` | Viewer's audio isn't connected to its TmRace: no countdown beeps, GO or checkpoint sounds |
| 10 | fixed: units from the placed variant and its own box | high | `race/tm_user_tracks.gd:147` | Ground-only multi-cell blocks get wrong cells when turned (footprint falls back to 1x1) |
| 11 | fixed: refused off the ground | medium | `editor/tm_editor_model.gd:46` | Ground-only blocks can be placed above the ground: invisible, and a ground-only checkpoint makes the track unfinishable |
| 12 | fixed: no leading _ in file names | medium | `race/tm_user_tracks.gd:70` | Track names starting with a non-identifier character are saved as '_...sftrack', which the Editors list hides |
| 13 | fixed: no-start tracks refused (race message, Editors note) | medium | `race/race.gd:53` | PLAY on an empty or unfinished editor track quits the game, or drops the car under the map |
| 14 | fixed: a lap track starting on its line needs a checkpoint | medium | `editor/tm_editor_model.gd:132` | A track whose start is a start/finish line and that has no checkpoint validates in under 2 s |
| 15 | fixed: cells use the ground variant at ground level | low | `race/tm_user_tracks.gd:156` | cells() uses the air variant's units even at ground level, where the ground variant has different units |
| 16 | fixed: the save message shows | low | `editor/tm_editor.gd:423` | Save result ('Saved to ...' / "Couldn't save") is never shown, so a failed save before TEST does nothing visibly |
| 17 | fixed: ghost and message refresh after placing | low | `editor/tm_editor.gd:369` | After a successful place() the ghost and message are not refreshed (ghost stays green on the now-occupied cell) |
| 18 | fixed: key repeats only for moves | low | `editor/tm_editor.gd:493` | Editor key handler accepts key-repeat echoes: holding Esc arms and confirms 'leave without saving' in one press |
| 19 | fixed: the medal table redraws | low | `race/race.gd:208` | HUD medal table is not refreshed when a test drive validates the track without setting a new record |
| 20 | fixed: 32 levels (MAX_LEVEL 31) | low | `race/tm_user_tracks.gd:17` | StadiumSculptBridgeSuspendSlope2 (and Mirror) are offered in the palette but can never be placed |
| 21 | fixed: is_testing; load errors show a message, Esc back | high | `race/race.gd:58` | In normal play, a track that fails to load closes the game; even without that, the error screen has no way out |
| 22 | fixed: selection on press only, DELETE names its target | high | `ui/tm_menu.gd:693` | Editors/Replays (and server list, campaign) selection follows the mouse: DELETE/PLAY/EDIT/WATCH/JOIN act on the last row hovered |
| 23 | fixed: is_testing from the command line only | medium | `net/tm_master.gd:37` | Master server becomes unreachable for the whole session after the first scene change, and its HTTP calls lose their timeout |
| 24 | fixed: TestHooks.is_testing from the command line only | low | `race/replay.gd:114` | Replay viewer never shows its error message in real play (black screen) |
| 25 | fixed: the menu stores the page raced from (return_page) | low | `race/race.gd:301` | Races of a track file return to the wrong menu page (Gbx -> main, any .sftrack -> Editors) |
| 26 | fixed: canvas textures default to Linear Mipmap (project.godot) | low | `tools/texgen/ui.py:29` | UI icon mipmaps are generated but never sampled, so medals and the logo alias when scaled down |
| 27 | fixed: guests fall back to Player when codes-only; server test | low | `server/lib/game.js:178` | Guest names made only of $-codes are accepted and show as blank names |
| 28 | fixed: selection on press only, DELETE names its target | high | `ui/tm_menu.gd:692` | Replays/Editors lists: focus or hover changes the selection, so DELETE/EDIT/PLAY/WATCH act on a different row than the highlighted one (wrong file deleted) |
| 29 | fixed: is_testing from the command line only | high | `net/tm_master.gd:37` | Master never finds the server and requests lose their timeout once the menu has written any TestHooks arg (normal play) |
| 30 | fixed: is_testing; load errors show a message, Esc back | medium | `race/race.gd:53` | A track or replay that fails to load quits the whole game (or shows nothing) when opened from the menu, because is_testing() is always true by then |
| 31 | fixed: disarmed on every visit to Options | medium | `ui/tm_menu.gd:809` | 'CLEAR ALL RECORDS' stays armed across page visits: a single press later wipes every record |
| 32 | fixed: rows select on press, JOIN/SPECTATE the picked one | medium | `ui/tm_menu.gd:1088` | JOIN always joins the first listed server, never the one the player chose |
| 33 | fixed: follow_focus on the lists | low | `ui/tm_menu.gd:540` | Replays and editors scroll lists don't follow keyboard/pad focus |
| 34 | fixed earlier (integers) | low | `ui/tm_menu.gd:988` | Ladder points shown as floats ('1000.0 LADDER POINTS', '1000.0' in rankings) |
| 35 | fixed: old content removed before the panel sizes | low | `ui/tm_race_menu.gd:82` | Race menu panel keeps the size of the previous content (old children still counted) when refilled |
| 36 | fixed earlier (--settings test file) | low | `tests/test_menu.gd:16` | Tests write to (and depend on) the player's real user://settings.cfg |
| 37 | fixed: focus stays on the picked swatch or zone | low | `ui/tm_menu.gd:874` | Profile page: choosing a zone or a car colour rebuilds the page and throws focus back to the nickname field |
| 38 | fixed: local time (UTC offset added) | low | `ui/tm_menu.gd:679` | Editors page 'CHANGED' column shows UTC instead of local time |
| 39 | fixed: guarded rebuild; a rejected token shows the log-in form; one account refresh per visit | low | `ui/tm_menu.gd:997` | Online page: LOG OUT drags the player back to Online after the await; a rejected token leaves the logged-in panel showing |
| 40 | fixed: the server list scrolls | low | `ui/tm_menu.gd:1084` | Server list has no scroll: many servers push JOIN BY ADDRESS/CONNECT off the screen |
| 41 | fixed: the toast checks the music setting | low | `audio/tm_music.gd:132` | 'NOW PLAYING' toast appears even when music is switched off |

## Details

### 0. Replays page: DELETE and WATCH act on the last row the mouse or focus passed over, not the selected row
`stadium/ui/tm_menu.gd:579` (high). replay_selected is set on every row's focus_entered (line 579), and TmUi.button-style rows grab focus on mouse_entered (line 580). DELETE (lines 598-604) and WATCH (588-590) both use replay_selected. When the mouse moves from the clicked row down to the buttons under the list, it crosses every row below, and each one becomes replay_selected. The pressed (highlighted) row stays the one the user clicked. With keyboard or gamepad, ui_down from a row also walks through every lower row before it reaches WATCH or DELETE. The two-press DELETE never names the file, so it removes a different replay (DirAccess.remove_absolute at line 602). The same hover-select also means one click on a hovered row watches it straight away, although the page doc says a row selects and a second press watches.

Scenario: Three saved replays are listed. Click the top row, then move the mouse straight down to DELETE and press it twice. The bottom row's file is deleted, because it was the last row hovered, while the top row is still shown as selected. With the keyboard, Down from row 1 reaches DELETE only through rows 2 and 3, so only the last row can ever be deleted.

Suggested: Set replay_selected only in the row's pressed handler, or read the selection from the ButtonGroup (group.get_pressed_button()) when WATCH or DELETE is pressed. Stop updating the selection on hover or focus. Reset DELETE's 'PRESS AGAIN' state whenever the selection changes.

### 1. Replay HUD treats lap-line splits as checkpoints: wrong counts, no laps shown in lap races
`stadium/race/replay.gd:373` (medium). replay.splits holds every checkpoint and every lap-line time of the run. _clock() takes all of them except the finish as 'checkpoints' (cps). It sets race.taken[k] for each one passed, never resets taken per lap, never sets race.lap and never emits lap_done. Each lap line is emitted as checkpoint_taken with a running total (_splits_shown). The replay header doesn't store the lap count either, and the viewer builds its TmRace from challenge.nb_laps (line 88). race.gd honours a --laps override, which the viewer ignores.

Scenario: Watch a replay of a 2-lap track with 3 checkpoints (splits c1,c2,c3,L1,c1',c2',c3',F). The centre flashes '1 / 3', '2 / 3', '3 / 3', then '4 / 3' at the lap line (instead of 'Lap 2 / 2'), up to '7 / 3'. The top-right counter climbs to '7 / 3' and stays at 'Lap 1 / 2' for the whole replay.

Suggested: Store the lap count in the header (or the kind of each split). In _clock, rebuild race.lap and the current lap's race.taken: with laps > 1, every (checkpoint_count+1)-th split is a lap line. Emit lap_done for lap-line splits and checkpoint_taken with the count within the lap. Build the TmRace with the recorded lap count.

### 2. Viewer never shows its error in normal play (blank screen) because TestHooks.is_testing() is true after menu navigation
`stadium/race/replay.gd:114` (medium). _fail() returns without showing the note when TestHooks.is_testing(), which is just `not args.is_empty()`. The game passes state between scenes through TestHooks.args: menu.watch() sets 'replay' and 'replay_back', and race.watch_replay() does the same. So in real play is_testing() is always true in the viewer and the message is never shown. On failure _ready returns before _cameras(), so no camera exists. The player gets an empty screen with no hint that Esc goes back. race.gd:53-55 has the same root cause, and there it quits the whole game (TestHooks.finish()) when a track fails to load after menu navigation.

Scenario: Make a track in the editor and test-drive it, so a best-run autosave is listed under Solo > Replays. Delete the track on the Editors page, then press Watch on that replay. TmUserTracks.challenge_file fails, _fail() is silent and the screen shows nothing. Corrupt replay files and TMNF-campaign replays with no TMNF install found end the same way.

Suggested: Gate the note on an explicit test flag, e.g. TestHooks.has_arg('frames') or a dedicated 'headless_test' arg, not on args being non-empty, or always show it. Add a fallback Camera3D in the failure path. Apply the same fix in race.gd's load failure.

### 3. Replay keyboard shortcuts break once a bar control has focus (focus follows the mouse)
`stadium/race/replay.gd:447` (medium). The shortcuts are handled in _unhandled_input, but the bar's buttons come from TmUi.button, which connects mouse_entered to grab_focus (tm_ui.gd:268), and the HSlider is focusable (FOCUS_ALL). Once any bar control has focus, the GUI receives the keys first. Space (ui_accept) presses the focused button, so the hovered '+', '-' or CAMERA button acts too. With PAUSE focused, Space toggles twice (key press in _unhandled_input, button release) and nothing changes. Left/Right are used for focus navigation between PAUSE, -, +, the slider and CAMERA, or step the focused slider. The slider's value_changed isn't connected and is overwritten the next tick, so seeking with the keys does nothing.

Scenario: Move the mouse over the CAMERA button (or click the time line to seek), then press Space to pause and Right to skip 5 s. Space changes the camera or does nothing, and Right only moves the focus or nudges the slider back. The replay keeps playing at the same place.

Suggested: Set focus_mode = Control.FOCUS_NONE on the bar's buttons and slider (and skip the hover grab_focus for them), or handle the replay keys in _input/_shortcut_input and mark them handled before the GUI sees them.

### 4. Puppet keeps its finish speed, throttle and spinning wheels while time stands still (2.5 s tail, pause)
`stadium/race/replay.gd:325` (medium). race.gd records only while race.racing() (line 160), so the last sample is at the finish. The viewer still plays TAIL_MS = 2500 ms past the finish, and state() clamps to the last sample. The car stops dead on the line but keeps the recorded velocity, gas and sliding flags: the HUD speed stays at the finish speed, TmCarVisual spins the wheels from local_velocity, and TmCarAudio keeps the engine at full revs with wind and skid loops. When playback ends (playing=false) or the user pauses mid-run, _apply keeps feeding the same velocity and throttle, so the frozen car keeps roaring and its wheels keep turning indefinitely.

Scenario: Watch any finished replay to the end. At the finish the car freezes at the line for 2.5 s and then for good, showing e.g. '312' km/h with the engine at full throttle and the wheels spinning. Pausing at any point does the same.

Suggested: Keep recording after the finish for TAIL_MS (sample times finish_ms + k*INTERVAL with the auto-braking car), so the tail shows the car slowing down. In the viewer, when not playing or past the last sample, zero body.lin_vel and gas for the HUD, visual and audio (or mute or pause TmCarAudio).

### 5. Watching the run from the finish menu discards it: SAVE REPLAY is impossible afterwards
`stadium/race/race.gd:299` (medium). REPLAY writes the run to _last.replay and changes scene to the viewer with replay_back=race. Esc in the viewer loads race.tscn again (replay.gd:488-490), which starts a fresh attempt with a new TmReplay. The finish menu and the run's replay object are gone. _last.replay is hidden from Solo > Replays by list()'s '_' prefix filter (tm_replay.gd:212), and the viewer offers no save. Unless the run was a new record (autosaved), the replay the player just watched can no longer be kept.

Scenario: Finish a run that isn't a record, press REPLAY, watch it and press Esc. You're back on the countdown of a new attempt. The run appears nowhere in Solo > Replays and there's no button left to save it; the next REPLAY overwrites _last.replay.

Suggested: Return to the finish state after watching, e.g. keep the run in memory or in _last.replay and reopen the finish menu with SAVE REPLAY when coming back with replay_back=race. Or offer SAVE in the viewer when opened from a race (save a copy of _last.replay under file_name()).

### 6. Saved replays whose file name starts with '_' never appear in the list
`stadium/race/tm_replay.gd:212` (medium). list() skips every file that begins with '_' so it hides _last.replay. file_name() turns every character that isn't an ASCII identifier char, digit, '-' or ' ' into '_', and the name starts with the track name. A TMNF map whose name starts with a $-code (very common: '$s$fffMy Map'), a punctuation mark or a non-ASCII letter (an editor track named 'Été' or '(test)') gives a file like '_s_fffMy Map 0m45s67 ....replay'.

Scenario: Open a .Challenge.Gbx named '$o$f00Speed', finish and press SAVE REPLAY. The button says SAVED and the file is written, but Solo > Replays never lists it, so it can't be watched or deleted from the game.

Suggested: Hide only the exact LAST + EXT file in list() (f == LAST + EXT), or strip $-codes (TmNick.strip) and give sanitised names a non-underscore prefix in file_name().

### 7. Turbo sound is lost after seeking backwards in the viewer
`stadium/race/replay.gd:336` (low). The viewer plays turbos by setting model.turbo_until_ms = int(t_ms) + 1000, and body.now_ms follows the replay clock. TmCarAudio cues the turbo only when model.turbo_until_ms exceeds its own _turbo_until (tm_car_audio.gd:113-116). That value only grows and is never reset. After a seek back (Home, Left, the time line, or PLAY at the end, which restarts from the countdown), each turbo's turbo_until_ms is below the highest value already seen, so no turbo sound plays until playback passes the furthest point reached before.

Scenario: Watch a replay past a turbo pad at 30 s, press Home and play again. The turbo at 10 s (turbo_until 11000 < 31000) is silent, as is every turbo before 30 s.

Suggested: On a jump in _apply, also reset the audio's turbo tracking (e.g. audio._turbo_until = -1, or a reset() method on TmCarAudio). Or keep a monotonic now_ms for the puppet that doesn't follow seeks.

### 8. F_TURBO is recorded on every tick spent on a pad, not once per turbo, so the turbo cue retriggers
`stadium/race/tm_replay.gd:74` (low). TmCarModel.tick calls start_turbo every sub-step while a wheel touches a turbo surface (tm_car_model.gd:143-147), so turbo_until_ms = now_ms + TURBO_MS moves forward every tick on the pad. record() flags F_TURBO whenever turbo_until_ms changes (lines 74-77), so every sample during the pad crossing carries F_TURBO, not just the one where the turbo started (as the doc says). The viewer sets a new turbo_until_ms for each flagged sample, and TmCarAudio cues 'turbo' on every increase. Crossing one pad restarts the whoosh every 20 ms of replay time, and at x1/8 every 160 ms. The race itself has the same retrigger in tm_car_audio.gd:113-116 (a new cue every frame while on the pad).

Scenario: Drive over a yellow turbo strip at 60 m/s (about 10-15 ticks on the surface). The replay holds 5-8 consecutive F_TURBO samples, and the viewer plays a stuttering burst of overlapping turbo cues instead of one.

Suggested: Record F_TURBO only on a rising edge: when the previous turbo had already expired (_turbo_seen <= car.now_ms - TICK) and the new one is active. Make TmCarAudio cue only when a turbo starts after the last one ended, not on every extension.

### 9. Viewer's audio isn't connected to its TmRace: no countdown beeps, GO or checkpoint sounds
`stadium/race/replay.gd:96` (low). The viewer builds a TmRace to drive the HUD's countdown, clock and checkpoint flashes, but adds TmCarAudio without setting audio.race. TmCarAudio connects checkpoint_taken/lap_done and plays the countdown beeps and GO only when race is set before _ready (tm_car_audio.gd:62-64, 102-112). So the replay's countdown and checkpoints are silent, unlike in the race the viewer reproduces.

Scenario: Open any replay. The 3-2-1-GO figures and the checkpoint time flashes appear with no beep, GO or checkpoint cue.

Suggested: Set audio.race = race before add_child(audio) (race is created on line 88). Checkpoint cues then follow the checkpoint_taken emitted in _clock, and seeks (which don't emit) stay silent.

### 10. Ground-only multi-cell blocks get wrong cells when turned (footprint falls back to 1x1)
`stadium/race/tm_user_tracks.gd:147` (high). TmUserTracks.units() (and so cells(), anchor(), clip_at(), why_not(), road_variant()) calls TmTrackBuilder._rotated_units, which takes the units from the ground variant when the air variant has none, but sizes the rotation box with TmBlockCatalogue.footprint(entry, false) (stadium/race/tm_track_builder.gd:167). For a block with no air units, footprint(entry, false) falls back to the air variant again (the same empty list), so it returns Vector3i.ONE. For dir 1, 2 and 3 the min corner is then wrong and the rotated unit offsets come out shifted, often negative. The mesh is still placed with TmBlockCatalogue.block_transform(entry, coord, dir, ground=true), which uses the correct ground footprint. So the editor's occupancy, map-edge check, cursor anchor and clip matching no longer line up with what is drawn. About 45 palette blocks are affected: the Dirt family (RoadDirtGTCurve2/3, DiagonaleLeft/Right, HillSlope2/GT2/Tilt*, DirtHighGTCurve3...), StadiumInflatableCastleBig and CastleDoor, and the Sculpt arches and bridges.

Scenario: Select StadiumInflatableCastleDoor (3x3x1, ground only) with rot 2 and the cursor at (10,1,10). units() gives x offsets {-2,-1,0}, so anchor() puts the block at (12,1,10) and the model reserves x 10..12. block_transform draws the castle over x 12..14. Two results: blocks can be placed at x 13 and 14 inside the drawn castle, and x 10 and 11 are refused as 'the space is taken' although they are empty. With the cursor at x 30, the model cells (28..30) pass inside() but the mesh covers 30..32 and sticks out of the stadium. StadiumRoadDirtGTCurve2 with rot 1 reserves cells at x-1 while it is drawn at x..x+1, so StadiumRoadDirt placed at the curve's ends does not join (road_variant reads clip_at on the wrong cells) and the curve can overlap other blocks.

Suggested: In _rotated_units, size the rotation box from the same unit list it rotates: use footprint(entry, true) when the air units are empty, or compute the size directly from `units`. Also fix footprint(entry, false) so it falls back to the ground units when the air variant has none.

### 11. Ground-only blocks can be placed above the ground: invisible, and a ground-only checkpoint makes the track unfinishable
`stadium/editor/tm_editor_model.gd:46` (medium). why_not() only checks the map bounds, free cells and the one-start rule. It never checks that a block whose air variant is empty (has_ground and no air units/mobils) sits at level G. Above ground, challenge_blocks() marks such a block ground=false, so shape_name(entry, false, ...) returns "". The editor builds nothing for it, and the race builds nothing for it either: TmMapBuilder counts it as 'empty' but still registers its waypoint. The ghost path hides the problem too. In _update_ghost (tm_editor.gd:209-215) lib.make("") returns null, so the ghost disappears and the function returns before `message = why`. The user gets no ghost and no warning, and the click places an invisible block.

Scenario: Select StadiumRoadDirtCheckpoint, StadiumRoadDirtHighCheckpoint or StadiumGrassCheckpoint (all in the palette's DIRT/WAYPOINTS lists), press Page Up to level 3, then click. The block is saved but nothing is drawn. In the race, TmMapBuilder still registers the checkpoint and race.gd counts it (cps += 1) with a trigger floating in mid-air with no road. The track can never be finished, so it can never be validated. StadiumRoadDirt and the inflatables placed in the air are likewise invisible but still block their cells.

Suggested: In why_not(), refuse a block with no air units/mobils when any cell has y != G (for example, 'it only goes on the ground'). In _update_ghost, set `message` (and show the red box) even when no ghost mesh can be built.

### 12. Track names starting with a non-identifier character are saved as '_...sftrack', which the Editors list hides
`stadium/race/tm_user_tracks.gd:70` (medium). path_for() replaces every character that is not an ASCII identifier character, a digit, '-' or ' ' with '_'. list() (line 88) skips every file whose name begins with '_'. So a new track whose name starts with '$', '#', '(', '!', '[', '.', an apostrophe or a non-ASCII letter (for example 'É') is saved under a name that starts with '_'. It then never appears on the Editors page and cannot be edited, played or deleted from the game. The file still exists on disk.

Scenario: NEW TRACK, type the name '$f00Red Ring' (TMNF-style $ colour codes, which the profile nicknames also use) or '#1 Sprint', place blocks and press SAVE or TEST. The file is written as '_f00Red Ring.sftrack' or '_1 Sprint.sftrack'. After EXIT the Editors page does not list it.

Suggested: Strip leading '_' (and '$' codes, for example via TmNick.strip) from `base` in path_for, or prefix such names with 'track '. Alternatively, drop the '_' filter in list(), or use a reserved prefix that path_for can never produce.

### 13. PLAY on an empty or unfinished editor track quits the game, or drops the car under the map
`stadium/race/race.gd:53` (medium). TmUserTracks.challenge() sets ch.error when a track has no blocks (tm_user_tracks.gd:290-291). race.gd _ready then calls TestHooks.is_testing(), which is just `not args.is_empty()` and is always true in normal play once the menu has put 'map' or 'page' into TestHooks.args. So it calls TestHooks.fail() and TestHooks.finish(), and finish() quits the application with exit code 1. Users can save empty tracks: SAVE does not check missing(). The Editors page offers PLAY on every listed track (tm_menu.gd:706). A track with blocks but no start loads without error, but has_start is false and the car is placed at Transform3D() (the map corner, 9 m below the grass), where it falls forever.

Scenario: Editors > NEW TRACK > Ctrl+S (no blocks) > EXIT > select the track > PLAY. The whole game closes. Alternatively, place a few roads without a start, save, then PLAY: the car spawns under the stadium and falls endlessly with no way to finish.

Suggested: In race.gd, show _message(challenge.error) unless this is a real test run (use an explicit flag rather than is_testing()). On the Editors page, disable PLAY, or show the reason, when TmEditorModel.new(t).missing() is not empty or the track has no blocks.

### 14. A track whose start is a start/finish line and that has no checkpoint validates in under 2 s
`stadium/editor/tm_editor_model.gd:132` (medium). missing() accepts a lone StadiumRoadMainStartFinishLine as both start and finish (it also accepts FINISH + START_FINISH with no START). Editor tracks always have laps = 1. TmMapBuilder spawns the car on the start/finish block at z 3.7, and its trigger plane is at z 16 (TmTriggers). With no checkpoints, TmRace.cross(START_FINISH) sees taken.size() >= 0 and lap (1) >= laps (1), so the race finishes as soon as the car rolls about 12 m through the gate it started in. race.gd then calls validate_file with that time, so the track is validated with a meaningless author time of about 1.5 s and gold/silver/bronze medals derived from it.

Scenario: Place only StadiumRoadMainStartFinishLine (or it plus a StadiumRoadMainFinishLine somewhere) and press TEST. missing() returns "", the car crosses its own start gate after about 1.5 s, 'TRACK VALIDATED' is shown, and the file is saved with author of about 1500 ms.

Suggested: When the start is a START_FINISH block (no START block), require at least one checkpoint in missing() (or require laps > 1). Alternatively, have TmRace ignore the start/finish line until a checkpoint has been taken.

### 15. cells() uses the air variant's units even at ground level, where the ground variant has different units
`stadium/race/tm_user_tracks.gd:156` (low). units() and cells() always rotate the air units when the air variant has any. At level G, challenge_blocks and the editor build the ground variant (has_ground), and for several palette blocks its unit set differs from the air one. Examples: StadiumFabricCornerIn, FabricStraight1x1 and FabricPillarCornerInAir have extra or fewer ground units; FabricPillarAir and FabricPillarCornerOut have 1 ground unit against 3 air units; SculptBridgeSlopeStart and its Mirror have ground unit [0,0,0] while air has [0,0,1],[0,1,0]..[0,4,0]. The model's occupancy then differs from the geometry that is shown.

Scenario: Place StadiumSculptBridgeSlopeStart on the ground. Its ground variant occupies the cell at offset (0,0,0), but the model reserves the air units instead, so a StadiumRoadMain can be placed in that cell and overlaps the bridge's base. Meanwhile cells at levels +3 and +4 above it are refused although the ground variant is only 3 levels tall. Similarly, StadiumFabricStraight1x1 on the ground leaves its ground-only unit (1,5,0) free for other blocks.

Suggested: Give units()/cells()/anchor() a ground flag (coord.y == G and has_ground(id)) and rotate that variant's units with that variant's footprint. Use it in why_not, place, reindex and challenge_blocks' occupancy.

### 16. Save result ('Saved to ...' / "Couldn't save") is never shown, so a failed save before TEST does nothing visibly
`stadium/editor/tm_editor.gd:423` (low). save() sets `message` but only calls _refresh_status(); only _refresh_info() displays `message`. The next cursor update runs _update_ghost, which overwrites `message` with why_not() before _refresh_info runs, so the save message never reaches the screen. In test() a failed save just returns (line 435-436) with no visible feedback.

Scenario: Press Ctrl+S: no 'Saved to X.sftrack' appears. If the file cannot be written (read-only folder, invalid name on Windows), SAVE and F5/TEST silently do nothing. The only sign is that '· UNSAVED' stays in the help panel.

Suggested: Call _refresh_info() in save() after setting `message`, and keep save/test messages from being overwritten until the cursor next changes (for example, a separate status line).

### 17. After a successful place() the ghost and message are not refreshed (ghost stays green on the now-occupied cell)
`stadium/editor/tm_editor.gd:369` (low). place() calls rebuild() on success but, unlike erase(), undo() and redo(), not _update_ghost(). The left-click handler also sets `cursor` without calling _update_cursor(). The ghost therefore keeps its green 'fits' material over the block just placed, the box and ghost may sit on the previous cell, and `message` is not re-evaluated. If the 'Unsaved changes: Esc again leaves without saving' warning was showing, it stays armed after new placements, so the next Esc discards them.

Scenario: Click to place a road; without moving to another cell the ghost still shows green although the space is now taken. Or press Esc (warning shown), place two more blocks without crossing a cell border, then press Esc again expecting another warning: the editor leaves and the new blocks are lost.

Suggested: Call _update_cursor() (or _update_ghost() and _refresh_info()) after a successful model.place(), and call _update_cursor() when the left click moves the cursor.

### 18. Editor key handler accepts key-repeat echoes: holding Esc arms and confirms 'leave without saving' in one press
`stadium/editor/tm_editor.gd:493` (low). _unhandled_input accepts any pressed InputEventKey, including echo events, unlike race.gd, which filters `not event.echo`. leave() treats a second Esc while `message` begins with 'Unsaved' as confirmation. Holding Esc past the OS key-repeat delay therefore shows the warning and then leaves immediately without saving. F5 held down calls test() (and save()) repeatedly.

Scenario: With unsaved changes, press and hold Esc for about half a second. The first event shows the warning, the repeat event calls leave() again, and the editor goes to the menu, discarding the changes.

Suggested: Ignore echo events for Esc, F5 and Ctrl+S (`if k.echo and k.keycode in [KEY_ESCAPE, KEY_F5, KEY_S]: return`), or filter all echoes except undo/redo.

### 19. HUD medal table is not refreshed when a test drive validates the track without setting a new record
`stadium/race/race.gd:208` (low). After validate_file, _on_finished updates the challenge's medal fields and assigns `hud.challenge = challenge`. That is the same object, and TmRaceHud.challenge has no setter, so _update_info() is not called. The table is rebuilt only through the `best` setter, which runs only when new_record is true, and restart() / hud.reset() never rebuild it. Validation without a new record happens when the layout's record already exists, for example from a PLAY on the Editors page, which records times but does not validate, or when the finish is between the old author time and the record.

Scenario: PLAY an unvalidated track from the Editors page and finish in 30 s. Then EDIT, TEST and finish in 32 s. The track is validated with author 32 s, but the HUD's Author/Gold/Silver/Bronze rows keep showing no times for every retry in that session.

Suggested: Give TmRaceHud.challenge a setter that calls _update_info(), or call a public refresh method after updating the medals.

### 20. StadiumSculptBridgeSuspendSlope2 (and Mirror) are offered in the palette but can never be placed
`stadium/race/tm_user_tracks.gd:17` (low). MAX_LEVEL is 24 and inside() requires every cell to have y <= 24 and >= G (1). StadiumSculptBridgeSuspendSlope2 and its Mirror have unit y offsets up to 24 (25 levels), so their top cell is at least level 25 for any coord. why_not() always answers 'outside the stadium', yet palette_ids() lists both blocks (rendered icons exist). TMNF's map is 32 levels high (TmChallenge.size = 32,32,32).

Scenario: DECORATION tab: select SculptBridgeSuspendSlope2 and try any cell or level. The ghost is always red with 'outside the stadium'.

Suggested: Raise MAX_LEVEL to the map's height (31), or drop blocks taller than MAX_LEVEL - G + 1 from palette_ids().

### 21. In normal play, a track that fails to load closes the game; even without that, the error screen has no way out
`stadium/race/race.gd:58` (high). TestHooks.is_testing() is just `not args.is_empty()`. TestHooks.args is also how the scenes pass state to each other: menu.race() always sets track/map, the editor's test() sets map/back, and watch()/watch_replay() set replay. So by the time race.gd _ready runs, is_testing() is always true, even in an exported build launched without arguments. When the challenge fails to load, the race therefore calls TestHooks.fail() and TestHooks.finish(), and finish() calls get_tree().quit(1). The game closes instead of showing the message. The fallback path is broken as well: _ready returns before `menu` is created, so Esc in _unhandled_input (line 244, menu.toggle_pause()) is a null call and Enter (respawn uses `race`) is too. The player has no way back to the menu.

Scenario: 1) Editors > NEW TRACK > Ctrl+S on an empty track > EXIT, then Editors > PLAY that track. TmUserTracks.challenge() sets the error "the track ... has no blocks", is_testing() is true because args has "map", and the game quits with exit code 1. 2) Solo > OPEN A TRACK FILE and pick any *.Gbx that is not a readable Stadium challenge (the filter accepts *.Replay.Gbx too); the game quits. 3) Joining a server whose round track this client does not have (e.g. a newer SFxx, or the server's `--tracks=tmnf` without a TMNF install); the game quits as soon as the race loads.

Suggested: Stop reading test mode from the shared args dictionary. Record in TestHooks._ready whether the command line had any user args (e.g. `var testing := not args.is_empty()` before any scene writes to args, or move scene-to-scene state into a separate dictionary), and use that in is_testing(). Also give the race's error screen an exit: in _unhandled_input, when menu == null, send Esc/Enter back to the menu (or editor) instead of calling menu/race methods.

### 22. Editors/Replays (and server list, campaign) selection follows the mouse: DELETE/PLAY/EDIT/WATCH/JOIN act on the last row hovered
`stadium/ui/tm_menu.gd:693` (high). Every row does `mouse_entered -> grab_focus`, and `focus_entered` sets track_selected (line 693) or replay_selected (line 586). The action buttons below the list use whatever was last hovered, not the row that is drawn as selected (the ButtonGroup's pressed row). With the mouse there is no way to pick a row without acting on it: hovering already selects it, so the first click runs the 'second press' branch (lines 690 and 583) and immediately opens the editor or the replay. So the only way to reach PLAY, EDIT, WATCH or DELETE is to move the mouse down from the row to the buttons. That path crosses every row below the intended one, and each crossed row re-selects itself. DELETE then calls DirAccess.remove_absolute(track_selected) (line 713) or remove_absolute(replay_selected) (line 609) on the wrong file, and the PRESS AGAIN prompt does not say which one. The server list does the same (rows line 1084; JOIN and SPECTATE use the focused row), and campaign cards race on their first click (lines 456 and 458) although the comment on select() says the second press races.

Scenario: Editors page with tracks A (newest, top), B, C. Hover A, move the pointer straight down to DELETE and press it twice. track_selected is C, the last row crossed, so C.sftrack is deleted permanently while A still shows as selected. The same happens with PLAY (races C), EDIT (opens C) and Replays > WATCH or DELETE. On the Online page, hovering server 1 and moving down to JOIN crosses servers 2..N and joins the last one.

Suggested: Do not change the selection on hover: remove `mouse_entered.connect(row.grab_focus)` for list rows, or update the selection only on press. Make the first press select and a second press (or a double-click) act. Have EDIT, PLAY, WATCH, DELETE and JOIN use the ButtonGroup's pressed button (group.get_pressed_button()), and show the selected item's name in the delete confirmation.

### 23. Master server becomes unreachable for the whole session after the first scene change, and its HTTP calls lose their timeout
`stadium/net/tm_master.gd:37` (medium). find() returns false when `TestHooks.is_testing()` is true and `base` is not yet cached (line 37), and _request() sets `req.timeout = 0.0` under the same condition (line 69). As in the race finding, args is non-empty once any scene has written to it: menu.race, the editor's TEST, watch() or watch_replay(). After that, a session that has not already resolved the official address never will. The server list, log in, register, rankings and online records all report 'the master server isn't reachable', and the race's Master.submit_record silently drops the finish. Every master request also runs without a timeout, so a black-holed address leaves 'Looking for servers...' on screen indefinitely.

Scenario: Launch the game (no args), go to Editors > NEW TRACK > TEST, drive, then EDITOR > EXIT > ONLINE. No servers are listed and LOG IN says the master isn't reachable until the game is restarted. The same happens after Solo > Replays > WATCH > Esc, after Solo > Open a track file > race > MENU, or when the first official.json fetch failed (offline at launch) and the player has raced since.

Suggested: Use a command-line-only test flag (see the race finding), or check TestHooks.has_arg("master") explicitly for tests instead of is_testing(). Keep the 8 s timeout in normal play. Retry find() when base is empty rather than giving up for the session.

### 24. Replay viewer never shows its error message in real play (black screen)
`stadium/race/replay.gd:114` (low). _fail() returns without calling _note() when TestHooks.is_testing() is true. Both ways into the viewer, menu.watch() and race.watch_replay(), write to TestHooks.args first, so is_testing() is always true here. When the replay or its track cannot be loaded, the player gets an empty scene with no camera, no text and no 'Esc: back' hint.

Scenario: Solo > Replays > WATCH a replay of a TMNF campaign track (track "A01") on a machine without TMNF, or a replay of an .sftrack that has since been deleted. The screen stays blank with no explanation; only Esc (which the player is not told about) gets them out.

Suggested: Same root fix as the race finding: use a command-line-only test flag, or always call _note() and only skip it under a real test flag.

### 25. Races of a track file return to the wrong menu page (Gbx -> main, any .sftrack -> Editors)
`stadium/race/race.gd:301` (low). _to_menu() picks the page from the map's extension, not from where the race was started. A .Gbx opened from Solo > OPEN A TRACK FILE returns to the main page instead of Solo. An .sftrack opened the same way (possibly from outside user://tracks) returns to the Editors page, where that track is not listed. Nothing records the page the race was launched from.

Scenario: Solo > OPEN A TRACK FILE > pick X.Challenge.Gbx > finish > MENU lands on the main menu, not Solo. Picking ~/Downloads/friend.sftrack lands on the Editors page, which does not list it.

Suggested: In menu.race(), store the page the race was started from (e.g. TestHooks.args["race_from"] = page) and have _to_menu() return to it, falling back to the current extension-based choice.

### 26. UI icon mipmaps are generated but never sampled, so medals and the logo alias when scaled down
`stadium/tools/texgen/ui.py:29` (low). ui.py writes .import files with mipmaps/generate=true (the committed assets/ui/*.png.import match) so that the icons, drawn at 2-5x their display size, filter cleanly when scaled down, as the comment says. But canvas items only sample mipmaps when their texture filter is a *_MIPMAPS mode. project.godot does not set rendering/textures/canvas_textures/default_texture_filter (default Linear), and no TextureRect or Button sets texture_filter. The mipmaps are therefore ignored: the 1200x300 logo shown at 320x80 and the 128 px medals shown at 24-44 px are bilinear-downscaled 3-5x and shimmer or alias.

Scenario: Open the campaign page. The 24 px medal icons on the cards and the top-bar logo show jagged, aliased edges, because the generated mipmaps are never used.

Suggested: Set rendering/textures/canvas_textures/default_texture_filter=2 (Linear Mipmap) in project.godot, or set texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS on the menu, HUD and race-menu icon TextureRects and buttons.

### 27. Guest names made only of $-codes are accepted and show as blank names
`stadium/server/lib/game.js:178` (low). With the name limit raised to 75 characters, codes included, a guest's name is only passed through cleanText(msg.name, 75) || 'Player'. Accounts reject a nickname that shows nothing once its codes are stripped (accounts.js uses stripNick), but guests are not checked, so a name such as "$o$i$f00" is kept. Every client strips codes for display (TmNick.strip), so that player appears with an empty name on the board, in chat (": text", " joined") and on their car's name tag. The profile editor allows such a name, and the client only falls back to "Player" when the setting is empty. No server test covers the new limit or this case.

Scenario: Set the Profile nickname to "$o$i" and join a server as a guest. The ranking board shows "1.    0:42.00" with no name, chat shows " joined", and the car's tag is blank.

Suggested: For guests, fall back to 'Player' when stripNick(name).trim() is empty, as Accounts.register/update already do. Add a test in stadium/server/test for the 75-character limit and for a codes-only name.

### 28. Replays/Editors lists: focus or hover changes the selection, so DELETE/EDIT/PLAY/WATCH act on a different row than the highlighted one (wrong file deleted)
`stadium/ui/tm_menu.gd:692` (high). Each row sets the selection on focus_entered (track_selected = p at line 692, replay_selected = path at line 585), and every row grabs focus on mouse_entered (lines 586 and 693). The visible 'selected' highlight is the toggle (button_pressed), which only changes when a row is pressed. The action buttons (WATCH and DELETE at 594-611, EDIT, PLAY and DELETE at 701-714) sit below the ScrollContainer, so the keyboard, the pad or the mouse can only reach them by passing over every row below the chosen one. Each of those rows silently becomes the selection. The DELETE arming ('PRESS AGAIN') is not reset when the selection changes. Also, because hovering already selects a row, a single click on a row runs edit()/watch() right away (lines 689-690 and 582-583), where the doc comment says the first press only selects. The campaign cards have the same pattern (lines 457-458): moving to the RACE button changes which track is shown and raced.

Scenario: Editors page with 4 tracks. Row 1 is highlighted and focused. The player presses Down to reach DELETE. Focus passes rows 2, 3 and 4, so track_selected becomes row 4's path. Row 1 still shows the pressed (selected) glass. DELETE, then PRESS AGAIN, calls DirAccess.remove_absolute on track 4's .sftrack: the wrong user-made track is lost for good. Replays work the same way (line 608). With the mouse, moving from row 1 down to DELETE crosses rows 2-4 and gives the same result.

Suggested: Make the pressed toggle the only selection: set track_selected/replay_selected in the row's pressed (or toggled) handler, not in focus_entered. Do not grab focus on mouse_entered for list rows, or at least do not change the selection on hover. Reset the DELETE button's armed text when the selection changes. Race or watch only on a real second press of the already-toggled row.

### 29. Master never finds the server and requests lose their timeout once the menu has written any TestHooks arg (normal play)
`stadium/net/tm_master.gd:37` (high). TestHooks.is_testing() returns `not args.is_empty()` (autoload/test_hooks.gd:62-63). In normal play the menu and the scenes pass state through TestHooks.args: race() writes track/map (tm_menu.gd:1194-1196), watch() writes replay and replay_back, edit() writes edit, and race.gd, replay.gd and the editor write page, track and map. After the first such scene hop, is_testing() is true for the rest of the session. From then on, Master.find() returns false whenever base is not known yet (line 37-38), and _request() sets req.timeout = 0.0, which means no timeout at all (line 69). If the master was not discovered before the first scene change, or the first lookup failed, the master can never be reached in that session. If a request then stalls, _finding stays true and every later find() waits forever.

Scenario: Launch the game, then Solo > OPEN A TRACK FILE (or Replays > WATCH, or Editors > edit a track) and come back to the menu. Open Online: the servers tab says 'No servers are online right now', LOG IN and REGISTER fail with 'the master server isn't reachable', rankings and world records never load, and race.gd's Master.submit_record silently drops finishes. All of this lasts until the game is restarted. Launching with --race=SF01 gives the same result from the start.

Suggested: Do not infer test mode from the shared args dictionary. Store a flag in TestHooks._ready (for example _testing := not args.is_empty(), taken from the real command-line args only) and have is_testing() return it. Or give Master its own explicit switch (has_arg("master") / has_arg("menu_dry")). Keep the 8 s timeout in normal play.

### 30. A track or replay that fails to load quits the whole game (or shows nothing) when opened from the menu, because is_testing() is always true by then
`stadium/race/race.gd:53` (medium). race.gd: when the challenge does not load, `if TestHooks.is_testing(): TestHooks.fail(...); TestHooks.finish()`. finish() calls get_tree().quit(1). Every race launched from the menu has TestHooks.args['track' or 'map'] set by TmMenu.race(), so is_testing() is always true and the player's game exits instead of showing _message(challenge.error). In the same way, replay.gd:114 `_fail` returns without its note whenever is_testing() is true, and watch() always sets args['replay'], so a replay that fails to load opens an empty scene with no explanation.

Scenario: (1) Solo > OPEN A TRACK FILE. The filter accepts any *.Gbx, so the player picks a .Replay.Gbx or a TM2 .Map.Gbx; TmChallenge.load_file errors and the game closes. (2) Editors > PLAY on a saved track with no blocks ('has no blocks' error): the game closes. (3) Online > join a server whose round track is not in the local campaign (tm_menu.gd:1163): the game closes. (4) Delete a user track, then Solo > Replays > WATCH a replay of it: a blank viewer with no message.

Suggested: Same root fix as the Master finding: base is_testing() on the original command-line args only (captured in TestHooks._ready), so the menu's hand-over args do not turn normal play into test mode.

### 31. 'CLEAR ALL RECORDS' stays armed across page visits: a single press later wipes every record
`stadium/ui/tm_menu.gd:809` (medium). The two-press confirmation keeps its state in the member _clear_armed, which is never reset when the options page is rebuilt or left. The rebuilt button shows 'CLEAR ALL RECORDS' again, but _clear_armed is still true from the earlier first press.

Scenario: Options > press CLEAR ALL RECORDS once (it reads 'PRESS AGAIN TO CLEAR ALL RECORDS'), change your mind and press BACK. Later, open Options again and press CLEAR ALL RECORDS once, for example by accident with the pad: TmRecords.clear() runs at once and deletes all best times and ghosts without the confirmation.

Suggested: Reset _clear_armed = false at the start of _page_options() (or in show_page), or keep the armed state on the button itself (for example its text, as the DELETE buttons do).

### 32. JOIN always joins the first listed server, never the one the player chose
`stadium/ui/tm_menu.gd:1088` (medium). JOIN looks for a server row with focus. When JOIN is pressed, JOIN itself has the focus: TmUi.button grabs focus on mouse_entered, and the keyboard or pad has to move focus onto JOIN to press it. So no row ever has_focus(), and the fallback `(server_rows[0] as Button).pressed.emit()` always runs. The rows are not toggle buttons, so the player's choice is not remembered anywhere.

Scenario: The server list shows 'Official Rounds' first and 'Official Time Attack' second. The player moves to the second row, then to JOIN, and presses it: _connect() is called with the first server's address.

Suggested: Remember the last focused or pressed row in a member (for example _server_selected, set on focus_entered or pressed) and join that one from JOIN. Or make the rows toggle buttons in a ButtonGroup, as on the replays page.

### 33. Replays and editors scroll lists don't follow keyboard/pad focus
`stadium/ui/tm_menu.gd:540` (low). The rows live in a ScrollContainer whose follow_focus is left at its default (false) at lines 540-543 and 650-653. Focus can move onto rows that are clipped below the visible area (470 px is about 8 replay rows, 400 px about 6 track rows), but the list does not scroll to them.

Scenario: With 12 saved replays, pressing Down on the Replays page moves focus past row 8 into rows the player cannot see. They cannot tell which replay WATCH or Enter will act on.

Suggested: Set scroll.follow_focus = true on both ScrollContainers. Consider the same for the online servers list once it is scrollable.

### 34. Ladder points shown as floats ('1000.0 LADDER POINTS', '1000.0' in rankings)
`stadium/ui/tm_menu.gd:988` (low). Godot's JSON parser returns every number as a float, and str() on a float in Godot 4 keeps the '.0'. The account panel (line 988) and the rankings LADDER column (line 1137) use str() directly on the server's integer ladder value.

Scenario: After logging in, the account panel reads '1000.0 LADDER POINTS' and every ranking row reads '1000.0', '1012.0', and so on.

Suggested: Format as an integer: "%d" % int(a.get("ladder", 0)) (keep '-' when the field is missing) and str(int(p.get("ladder", 0))).

### 35. Race menu panel keeps the size of the previous content (old children still counted) when refilled
`stadium/ui/tm_race_menu.gd:82` (low). _fill() calls queue_free() on the old children of _box (lines 50-51), but they stay in the tree until the end of the frame. It then adds the new ones and calls _panel.reset_size() and set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE) (82-83). The minimum size used for the offsets therefore includes both the old and the new content. Because the offsets are explicit, the panel does not shrink when the old children are freed.

Scenario: Pause a race, resume, then pause again: the second PAUSED panel is about twice as tall, with empty glass under the buttons, and is centred off. The same happens when Esc opens the pause menu over the result panel (tall panel), and again on resume, when the result card is refilled with the pause menu's height added at the bottom.

Suggested: Remove the old children before freeing them (_box.remove_child(c); c.queue_free()), or reset the size and offsets in a deferred call after the old nodes are gone.

### 36. Tests write to (and depend on) the player's real user://settings.cfg
`stadium/tests/test_menu.gd:16` (low). TmUi.set_setting always saves to user://settings.cfg, which is the same user dir the real game uses. test_menu overwrites the real nickname and zone (through the profile page) and test_online sets name, zone and token (lines 68-70). Both only restore them at the very end (test_menu.gd:45-46, test_online.gd:58-59), so an aborted, crashed or timed-out run leaves the player renamed, moved to another zone and logged out. test_menu also reads the real token: on a machine where the player is logged in, _page_online shows LOG OUT instead of LOG IN/REGISTER, and menu_online_page fails.

Scenario: The developer is logged in to the official master and runs the stadium test gate. test_menu fails 'menu_online_page'. If test_online is killed by the runner's timeout while waiting on the server, the real settings keep name '$f00Tes$ffter', zone 'Europe|United Kingdom' and an empty token.

Suggested: Let tests redirect the settings file (for example a --settings=user://test_settings.cfg arg read by TmUi._settings(), like --records and --replays), or override the keys through TestHooks set_<key> args instead of set_setting. Set the token explicitly in test_menu.

### 37. Profile page: choosing a zone or a car colour rebuilds the page and throws focus back to the nickname field
`stadium/ui/tm_menu.gd:874` (low). The swatch handler (869) and the zone picker handler (900) call show_page("profile"), and _page_profile always ends with edit.grab_focus.call_deferred(). Keyboard and pad users lose their place after every pick and land in a text field.

Scenario: With a pad, the player moves down to the colour swatches and presses A on a colour: focus jumps back to the NICKNAME LineEdit at the top. Trying the next colour means navigating all the way down again.

Suggested: Update the swatch styles and the car in place instead of rebuilding the page. Or pass which control to focus into the rebuild (for example remember 'colour' or 'zone' and focus that swatch or the picker).

### 38. Editors page 'CHANGED' column shows UTC instead of local time
`stadium/ui/tm_menu.gd:679` (low). Time.get_datetime_string_from_unix_time(int(e["time"]), true) formats the file's unix modification time as UTC. Replays' DATE column is local time, and players expect local time.

Scenario: A player in UTC+7 saves a track at 21:00 local time; the Editors list says it changed at 14:00.

Suggested: Add the local offset before formatting (unix + Time.get_time_zone_from_system()["bias"] * 60), or use Time.get_datetime_string_from_unix_time on the local-adjusted value.

### 39. Online page: LOG OUT drags the player back to Online after the await; a rejected token leaves the logged-in panel showing
`stadium/ui/tm_menu.gd:997` (low). The LOG OUT lambda awaits Master.log_out() (a network call) and then calls show_page("online") without checking that the page is still 'online', unlike the LOG IN path (1030) and _refresh_account (1044). Also, when _refresh_account()'s Master.refresh() gets a 401, Master._forget() clears the token, but the page is not rebuilt because why is non-empty. The panel keeps showing LOG OUT and the ladder as if the player were logged in.

Scenario: (1) Press LOG OUT, then Esc to Main while the request is in flight: when it completes, the menu jumps back to Online. (2) Start the game with an expired token and open Online: the account panel shows the logged-in view (LOG OUT, '- LADDER POINTS') although Master has already logged the player out.

Suggested: Guard with `if page == "online": show_page("online")` in the LOG OUT lambda. In _refresh_account, rebuild the online page when Master.logged_in() became false (or connect Master.account_changed to a guarded rebuild).

### 40. Server list has no scroll: many servers push JOIN BY ADDRESS/CONNECT off the screen
`stadium/ui/tm_menu.gd:1084` (low). _servers_tab adds every server row (52 px plus 6 px spacing) and the JOIN button straight into `body`, a VBoxContainer with a 430 px minimum height and no ScrollContainer. The master returns all official servers plus every community server, so the right panel grows past the 900 px viewport.

Scenario: With 8 or more listed servers, the right panel (starting at y=130) grows past the bottom of the 1600x900 view, and JOIN, the address field, CONNECT and the status line can no longer be seen or clicked.

Suggested: Put the server rows in a ScrollContainer (with follow_focus = true) of fixed height, like the rankings tab, and keep JOIN outside it.

### 41. 'NOW PLAYING' toast appears even when music is switched off
`stadium/audio/tm_music.gd:132` (low). With the music setting off, the players still play at -80 dB (level_db) and _next() still emits now_playing. toast() shows the current track on every menu or race load (line 132-134) and on every track change (line 128), with no check of TmUi.setting("music").

Scenario: The player turns Music off in Options. Every time the menu opens or a race starts, and at every silent track change, a 'NOW PLAYING ...' toast still appears.

Suggested: In the show lambda (or before calling it), return early when not bool(TmUi.setting("music")). Or have Music not advance and emit now_playing while music is off.
