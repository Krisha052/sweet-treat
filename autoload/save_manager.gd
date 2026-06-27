extends Node

const SAVE_PATH := "user://save.cfg"

var _unlocked_level_index: int = 0

func _ready() -> void:
	_load()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_unlocked_level_index = cfg.get_value("progress", "unlocked_level_index", 0)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_level_index", _unlocked_level_index)
	cfg.save(SAVE_PATH)

func unlock_level(level_index: int) -> void:
	if level_index > _unlocked_level_index:
		_unlocked_level_index = level_index
		_save()

func get_unlocked_level_index() -> int:
	return _unlocked_level_index

func is_level_unlocked(level_index: int) -> bool:
	return level_index <= _unlocked_level_index

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.has_feature("debug"):
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo \
			and key.ctrl_pressed and key.shift_pressed \
			and key.keycode == KEY_R:
		_unlocked_level_index = 0
		_save()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
