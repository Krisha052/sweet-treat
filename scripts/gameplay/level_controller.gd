extends Node

signal time_updated(seconds_left: float)

@export var level_config: LevelConfig

@onready var _timer: Timer = $Timer

var _time_remaining: float = 0.0

func _ready() -> void:
	if not level_config:
		return
	_time_remaining = level_config.time_limit_seconds
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_tick)
	_timer.start()

func _on_tick() -> void:
	_time_remaining -= 1.0
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_timer.stop()
		GameManager.set_fail()

func on_all_orders_cleared() -> void:
	_timer.stop()
	GameManager.set_win()
