extends Node
## STUB: the audio module replaces this with real music/UI/SFX playback.
## API fixed by docs/ARCHITECTURE.md "Audio". Use buses Settings.BUS_MUSIC / Settings.BUS_SFX.


func play_ui(_name: String) -> void:
	pass


func play_sfx(_name: String, _volume_db: float = 0.0, _pitch: float = 1.0) -> void:
	pass


func play_music(_name: String) -> void:
	pass


func stop_music() -> void:
	pass
