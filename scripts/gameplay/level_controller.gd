extends Node2D

signal time_updated(seconds_left: float)

@onready var _timer: Timer = $Timer
@onready var _order_manager = $OrderManager
@onready var _hud = $HUD

const _FALLBACK_SCENE := preload("res://scenes/gameplay/ingredient.tscn")

var level_config: LevelConfig
var _time_remaining: float = 0.0

func _ready() -> void:
	var config := GameManager.pending_level_config
	GameManager.pending_level_config = null
	if not config:
		# Fallback for running scene directly from the editor without main menu.
		config = load("res://data/levels/level_01.tres")

	level_config = config
	GameManager.start_level(config)

	_spawn_ingredients(config)

	_order_manager.order_spawned.connect(_hud.add_receipt)
	_order_manager.order_completed.connect(_hud.remove_receipt)

	for ingredient in $Ingredients.get_children():
		ingredient.collected.connect(_order_manager.on_ingredient_collected)

	_order_manager.setup(config)

	_time_remaining = config.time_limit_seconds
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_tick)
	_timer.start()
	time_updated.emit(_time_remaining)

func _spawn_ingredients(config: LevelConfig) -> void:
	var unique: Array[IngredientData] = []
	for recipe in config.recipe_pool:
		for ing: IngredientData in recipe.ingredients:
			var found := false
			for u in unique:
				if u.id == ing.id:
					found = true
					break
			if not found:
				unique.append(ing)

	var n := unique.size()
	var spacing := 80.0
	var start_x := -(n - 1) * spacing * 0.5
	for i in n:
		var data: IngredientData = unique[i]
		var template: PackedScene = data.scene if data.scene else _FALLBACK_SCENE
		var node := template.instantiate() as Node2D
		node.set("ingredient_data", data)
		node.position = Vector2(start_x + i * spacing, 400.0)
		$Ingredients.add_child(node)

func _on_tick() -> void:
	_time_remaining -= 1.0
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_timer.stop()
		GameManager.set_fail()

func on_all_orders_cleared() -> void:
	_timer.stop()
	GameManager.set_win()
