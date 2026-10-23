class_name TmRace
extends RefCounted
## Time-attack rules, TMNF style: a countdown with the car held still, then the race clock in
## 10 ms ticks (one per physics tick); checkpoints in any order, each once per lap; the finish (or
## the lap line on its last lap) counts only when every checkpoint of the lap is taken. Respawn
## goes back to the last checkpoint or lap line taken (the clock keeps running); with none taken
## yet it restarts the race. Pure logic: the race scene feeds it ticks and waypoint crossings.

signal started
signal checkpoint_taken(count: int, time_ms: int)   ## count: checkpoints taken this lap
signal lap_done(lap: int, time_ms: int)             ## lap: laps completed so far
signal finished(time_ms: int)

enum State { COUNTDOWN, RACING, FINISHED }

const TICK_MS := 10
## TMNF's start (measured from its own runs, M10-5): after a (re)start the clock shows -2.60 s;
## the figures 3, 2, 1 and Go! come every 0.75 s from -2.0 s, each shown 0.65 s.
const COUNTDOWN_MS := 2600
const FIGURES := ["3", "2", "1", "go"]
const FIGURE_FROM_MS := -2000
const FIGURE_STEP_MS := 750
const FIGURE_SHOW_MS := 650

var state := State.COUNTDOWN
var countdown_ms := COUNTDOWN_MS    ## left before the start
var time_ms := 0                    ## race clock
var checkpoint_count := 0           ## checkpoints per lap on the map
var laps := 1
var lap := 0                        ## laps completed
var taken := {}                     ## waypoint index -> true: checkpoints taken this lap
var splits: Array[int] = []         ## clock at each checkpoint and lap line, the whole race
var respawn_index := -1             ## waypoint of the last checkpoint / lap line taken; -1: none
var finish_ms := -1
var finish_index := -1              ## the waypoint whose line finished the race (several finishes: which)


func _init(cp_count: int = 0, lap_count: int = 1) -> void:
	checkpoint_count = cp_count
	laps = maxi(1, lap_count)


func restart() -> void:
	state = State.COUNTDOWN
	countdown_ms = COUNTDOWN_MS
	time_ms = 0
	lap = 0
	taken.clear()
	splits.clear()
	respawn_index = -1
	finish_ms = -1
	finish_index = -1


## One 10 ms tick: the countdown, or the clock while racing.
func tick() -> void:
	match state:
		State.COUNTDOWN:
			countdown_ms -= TICK_MS
			if countdown_ms <= 0:
				countdown_ms = 0
				state = State.RACING
				started.emit()
		State.RACING:
			time_ms += TICK_MS


func racing() -> bool:
	return state == State.RACING


## The car crossed waypoint `index` (of TmBlockCatalogue.Waypoint `kind`) during the last tick.
func cross(index: int, kind: int) -> void:
	if state != State.RACING:
		return
	match kind:
		TmBlockCatalogue.Waypoint.CHECKPOINT:
			if taken.has(index):
				return
			taken[index] = true
			splits.append(time_ms)
			respawn_index = index
			checkpoint_taken.emit(taken.size(), time_ms)
		TmBlockCatalogue.Waypoint.FINISH:
			if taken.size() >= checkpoint_count:
				finish_index = index
				_finish()
		TmBlockCatalogue.Waypoint.START_FINISH:
			if taken.size() < checkpoint_count:
				return
			lap += 1
			if lap >= laps:
				finish_index = index
				_finish()
				return
			splits.append(time_ms)
			taken.clear()
			respawn_index = index
			lap_done.emit(lap, time_ms)


func _finish() -> void:
	state = State.FINISHED
	finish_ms = time_ms
	splits.append(time_ms)
	finished.emit(time_ms)


## The medal a time earns against the map's times: "author", "gold", "silver", "bronze" or "".
static func medal(ms: int, ch: TmChallenge) -> String:
	if ms < 0:
		return ""
	if ch.author_ms > 0 and ms <= ch.author_ms:
		return "author"
	if ch.gold_ms > 0 and ms <= ch.gold_ms:
		return "gold"
	if ch.silver_ms > 0 and ms <= ch.silver_ms:
		return "silver"
	if ch.bronze_ms > 0 and ms <= ch.bronze_ms:
		return "bronze"
	return ""


## A race time as TMNF shows it: m:ss.cc
## The countdown figure showing at race time t_ms (negative before the start): "3", "2", "1",
## "go" or "".
static func figure_at(t_ms: int) -> String:
	var k := floori(float(t_ms - FIGURE_FROM_MS) / FIGURE_STEP_MS)
	if k < 0 or k >= FIGURES.size():
		return ""
	return FIGURES[k] if t_ms - FIGURE_FROM_MS - k * FIGURE_STEP_MS < FIGURE_SHOW_MS else ""


## The clock: the race time, or before the start how long is left as a negative time (as TMNF's).
func clock_ms() -> int:
	return -countdown_ms if state == State.COUNTDOWN else time_ms


static func time_text(ms: int) -> String:
	if ms < 0:
		return "-:--.--"
	return "%d:%02d.%02d" % [ms / 60000, (ms / 1000) % 60, (ms % 1000) / 10]
