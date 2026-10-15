extends Node
## Lives under the root (outside the current scene): waits 2 s, then checks the race scene loaded.


func _ready() -> void:
	get_tree().create_timer(2.0).timeout.connect(_check)


func _check() -> void:
	var cur := get_tree().current_scene
	var path := cur.scene_file_path if cur else ""
	TestHooks.check(path == Game.SCENE_RACE and Game.mode == "online", "lobby_race_scene_loaded", "scene %s mode %s" % [path, Game.mode])
	TestHooks.finish()
