extends Control

func _ready() -> void:
	$NextLevelButton.pressed.connect(_on_next_pressed)

func _on_next_pressed() -> void:
	var next_id := GameManager.current_level_id + 1
	var path := "res://data/levels/level_%02d.tres" % (next_id + 1)
	var config: LevelConfig = load(path)
	if not config:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/main_menu.tscn")
		return
	GameManager.pending_level_config = config
	get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/level_base.tscn")
