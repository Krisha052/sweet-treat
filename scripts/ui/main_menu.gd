extends Control

func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/level_select.tscn")
