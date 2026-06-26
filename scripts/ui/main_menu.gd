extends Control

func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)
	_pulse_start_button()

func _pulse_start_button() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($StartButton, "modulate:a", 0.55, 0.7)
	tween.tween_property($StartButton, "modulate:a", 1.0, 0.7)

func _on_start_pressed() -> void:
	var level_index := SaveManager.get_unlocked_level_index()
	var path := "res://data/levels/level_%02d.tres" % (level_index + 1)
	var config: LevelConfig = load(path)
	if not config:
		config = load("res://data/levels/level_01.tres")
	GameManager.pending_level_config = config
	get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/level_base.tscn")
