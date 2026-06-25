extends Node

func _ready() -> void:
	call_deferred("_go_to_main_menu")

func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
