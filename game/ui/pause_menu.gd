extends CanvasLayer
## STUB: the UI module replaces this. Emits resumed / restart_requested / quit_requested.

signal resumed
signal restart_requested
signal quit_requested


func open() -> void:
	visible = true


func close() -> void:
	visible = false
