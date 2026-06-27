class_name OrderManager
extends Node

signal order_spawned(order: Order)
signal order_completed(order: Order)
signal all_orders_cleared

@export var level_config: LevelConfig

var board_node: Node2D  # set by level_controller after board init
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
	var tapped_id := slot.ingredient_data.id

	# Orders that still need the tapped ingredient type (oldest first).
	var candidates: Array[Order] = []
	for order in _active_orders:
		if not order.is_complete() and tapped_id in order.get_remaining_needs():
			candidates.append(order)

	if candidates.is_empty():
		return

	# Snapshot of free (unselected) board counts — tapped slot is still unselected here.
	var free := _free_board_counts()

	# Prefer the oldest order that the current board can fully satisfy.
	for order in candidates:
		if _is_completable(order, free):
			order.collect(slot)
			return

	# Fallback: oldest-first FIFO so taps are never silently dropped.
	candidates[0].collect(slot)

func _free_board_counts() -> Dictionary:
	var counts: Dictionary = {}
	if not board_node:
		return counts
	for child in board_node.get_children():
		var ing := child as Ingredient
		if ing and not ing.selected:
			counts[ing.ingredient_data.id] = counts.get(ing.ingredient_data.id, 0) + 1
	return counts

func _is_completable(order: Order, free: Dictionary) -> bool:
	var remaining := order.get_remaining_needs()
	for type_id: String in remaining:
		if free.get(type_id, 0) < remaining[type_id]:
			return false
	return true

func any_active_order_satisfiable() -> bool:
	if _active_orders.is_empty():
		return true
	var free := _free_board_counts()
	for order in _active_orders:
		if _is_completable(order, free):
			return true
	return false

func get_committed_demand() -> Dictionary:
	var demand: Dictionary = {}
	for order in _active_orders:
		for type_id in order.get_remaining_needs():
			demand[type_id] = demand.get(type_id, 0) + order.get_remaining_needs()[type_id]
	return demand

# Returns {type_id: count} — the deficit needed to make the cheapest active order
# completable from free_counts, deducting other orders' committed demand.
# Returns {} if no active orders or no deficit exists.
func get_force_deficit(free_counts: Dictionary) -> Dictionary:
	if _active_orders.is_empty():
		return {}
	var total_committed := get_committed_demand()
	var best_deficit: Dictionary = {}
	var best_total := -1
	for order in _active_orders:
		var needs := order.get_remaining_needs()
		var deficit: Dictionary = {}
		for type_id in needs:
			var others: int = total_committed.get(type_id, 0) - needs.get(type_id, 0)
			var avail: int = max(0, free_counts.get(type_id, 0) - max(0, others))
			var d: int = needs[type_id] - avail
			if d > 0:
				deficit[type_id] = d
		var total := 0
		for v in deficit.values():
			total += v
		if best_total < 0 or total < best_total:
			best_total = total
			best_deficit = deficit
	return best_deficit

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
