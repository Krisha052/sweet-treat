extends Node

signal level_won
signal level_failed

var current_level_id: int = 0
var _win: bool = false
var _fail: bool = false

func start_level(level_id: int) -> void:
	current_level_id = level_id
	_win = false
	_fail = false

func set_win() -> void:
	if _win or _fail:
		return
	_win = true
	SaveManager.unlock_level(current_level_id + 1)
	level_won.emit()

func set_fail() -> void:
	if _win or _fail:
		return
	_fail = true
	level_failed.emit()
