extends Control

func _ready() -> void:
	$RestartButton.pressed.connect(_on_restart_pressed)

func _on_restart_pressed() -> void:
	GameManager.pending_level_config = GameManager.current_level_config
	get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/level_base.tscn")
