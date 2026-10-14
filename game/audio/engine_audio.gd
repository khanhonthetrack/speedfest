class_name EngineAudio
extends Node3D
## STUB: the audio module replaces this with layered, RPM-driven engine sound.
## API fixed by docs/ARCHITECTURE.md "Audio".


func setup(_car_id: String, _is_local: bool) -> void:
	pass


func set_params(_rpm_ratio: float, _throttle: float, _speed_kmh: float, _drift: float, _nitro: bool, _grounded: bool) -> void:
	pass
