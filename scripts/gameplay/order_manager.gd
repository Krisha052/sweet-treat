extends Node

signal order_completed(order: Order)
signal all_orders_cleared

@export var level_config: LevelConfig

var _active_orders: Array[Order] = []

func setup(config: LevelConfig) -> void:
	level_config = config
	_spawn_initial_orders()

func _spawn_initial_orders() -> void:
	if not level_config:
		return
	var count := mini(level_config.max_simultaneous_orders, level_config.recipe_pool.size())
	for i in count:
		_spawn_order(level_config.recipe_pool[i])

func _spawn_order(recipe: RecipeData) -> void:
	var order := Order.new(recipe)
	order.completed.connect(_on_order_completed)
	_active_orders.append(order)

func on_ingredient_collected(data: IngredientData) -> void:
	for order in _active_orders:
		if not order.is_complete():
			order.collect(data.id)
			return

func _on_order_completed(order: Order) -> void:
	_active_orders.erase(order)
	order_completed.emit(order)
	if _active_orders.is_empty():
		all_orders_cleared.emit()
