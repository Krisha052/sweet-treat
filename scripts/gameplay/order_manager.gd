class_name OrderManager
extends Node

signal order_spawned(order: Order)
signal order_completed(order: Order)
signal all_orders_cleared

@export var level_config: LevelConfig

var _active_orders: Array[Order] = []
var _total_orders: int = 0
var _completed_count: int = 0

func setup(config: LevelConfig) -> void:
	level_config = config
	_total_orders = config.recipe_pool.size()
	_completed_count = 0
	_active_orders.clear()

func spawn_order(recipe: RecipeData) -> void:
	var order := Order.new(recipe)
	order.completed.connect(_on_order_completed)
	_active_orders.append(order)
	order_spawned.emit(order)

func on_ingredient_tapped(slot: Ingredient) -> void:
	for order in _active_orders:
		if not order.is_complete() and order.collect(slot):
			return

func try_deselect(slot: Ingredient) -> void:
	for order in _active_orders:
		if order.uncollect(slot):
			return

func needs_next_order() -> bool:
	return _completed_count < _total_orders and \
		_active_orders.size() < level_config.max_simultaneous_orders

func _on_order_completed(order: Order) -> void:
	_active_orders.erase(order)
	_completed_count += 1
	order_completed.emit(order)
	if _completed_count >= _total_orders and _active_orders.is_empty():
		all_orders_cleared.emit()
