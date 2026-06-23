extends Control

@export var level_configs: Array[LevelConfig] = []
@export var level_button_scene: PackedScene

func _ready() -> void:
	_populate()

func _populate() -> void:
	for i in level_configs.size():
		if not level_button_scene:
			break
		var config := level_configs[i]
		var btn: Button = level_button_scene.instantiate()
		btn.text = "Level %d" % (i + 1)
		btn.disabled = not SaveManager.is_level_unlocked(i)
		btn.pressed.connect(_on_level_pressed.bind(config))
		add_child(btn)

func _on_level_pressed(config: LevelConfig) -> void:
	GameManager.start_level(config.level_id)
	# TODO: load the level scene corresponding to config.level_id
	pass
