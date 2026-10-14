extends CanvasLayer
## STUB: the UI module replaces this with the NFSU2-style HUD. API fixed by docs/ARCHITECTURE.md "HUD".

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	add_child(_label)


func set_speed(_kmh: float) -> void: pass
func set_rpm(_ratio: float, _gear: int) -> void: pass
func set_nitro(_amount: float, _active: bool) -> void: pass
func set_run_time(ms: int) -> void:
	if _label:
		_label.text = "%.3f" % (ms / 1000.0) if ms >= 0 else "--:--.---"
func set_best(_ms: int) -> void: pass
func set_checkpoints(_passed: int, _total: int) -> void: pass
func show_split(_ms: int, _delta_ms: int, _has_delta: bool) -> void: pass
func show_finish(_ms: int, _is_pb: bool, _delta_ms: int, _has_delta: bool) -> void: pass
func show_countdown(_n: int) -> void: pass
func show_message(_text: String, _seconds: float = 2.0) -> void: pass
func set_round_time_left(_ms: int) -> void: pass
func set_leaderboard(_entries: Array, _my_id: int) -> void: pass
func set_minimap(_points: PackedVector2Array) -> void: pass
func set_minimap_cars(_local_pos: Vector2, _others: Array) -> void: pass
