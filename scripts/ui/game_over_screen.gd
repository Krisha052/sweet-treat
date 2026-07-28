extends Control

func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($GameOverImage, "modulate", Color.BLACK, 0.4)
	tween.tween_property($GameOverImage, "modulate", Color.WHITE, 0.4)

	await get_tree().create_timer(3.0).timeout
	tween.kill()
	await AdManager.show_interstitial()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/restart_game_screen.tscn")
