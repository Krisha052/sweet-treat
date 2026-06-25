extends Node

signal order_spawned(order: Order)
signal order_completed(order: Order)
signal all_orders_cleared

@export var level_config: LevelConfig

var _active_orders: Array[Order] = []
var _next_recipe_index: int = 0

func setup(config: LevelConfig) -> void:
	level_config = config
	_next_recipe_index = 0
	var count := mini(level_config.max_simultaneous_orders, level_config.recipe_pool.size())
	for i in count:
		_spawn_next_order()

func _spawn_next_order() -> void:
	if _next_recipe_index >= level_config.recipe_pool.size():
		return
	_spawn_order(level_config.recipe_pool[_next_recipe_index])
	_next_recipe_index += 1

func _spawn_order(recipe: RecipeData) -> void:
	var order := Order.new(recipe)
	order.completed.connect(_on_order_completed)
	_active_orders.append(order)
	order_spawned.emit(order)

func on_ingredient_collected(data: IngredientData) -> void:
	for order in _active_orders:
		if not order.is_complete() and order.collect(data.id):
			return

func _on_order_completed(order: Order) -> void:
	_active_orders.erase(order)
	order_completed.emit(order)
	if _next_recipe_index < level_config.recipe_pool.size():
		_spawn_next_order()
	elif _active_orders.is_empty():
		all_orders_cleared.emit()
