extends Node

signal level_won
signal level_failed

var current_level_id: int = 0
var current_level_config: LevelConfig = null
var pending_level_config: LevelConfig = null
var _win: bool = false
var _fail: bool = false

func start_level(config: LevelConfig) -> void:
	current_level_id = config.level_id
	current_level_config = config
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
