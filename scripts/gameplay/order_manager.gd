class_name OrderManager
extends Node

signal order_spawned(order: Order)
signal order_completed(order: Order, consumed_slots: Array[Ingredient])
signal all_orders_cleared

@export var level_config: LevelConfig

var board_node: Node2D
var _active_orders: Array[Order] = []
var _selected_pool: Array[Ingredient] = []
var _total_orders: int = 0
var _completed_count: int = 0

func setup(config: LevelConfig) -> void:
	level_config = config
	_total_orders = config.recipe_pool.size()
	_completed_count = 0
	_active_orders.clear()
	_selected_pool.clear()

func spawn_order(recipe: RecipeData) -> void:
	var order := Order.new(recipe)
	_active_orders.append(order)
	order_spawned.emit(order)

func toggle_ingredient(slot: Ingredient) -> void:
	if slot.selected:
		_selected_pool.erase(slot)
		slot.deselect()
	else:
		slot.select()
		_selected_pool.append(slot)
		_check_completions()

func _check_completions() -> void:
	var found := true
	while found:
		found = false
		for order in _active_orders:
			if order.is_satisfied_by(_selected_pool):
				var consumed := _consume_for_order(order)
				_finalize_order(order, consumed)
				found = true
				break

# Extracts exactly the needed slots from _selected_pool, deselects them, returns them.
# _selected_pool is updated before any signals fire.
func _consume_for_order(order: Order) -> Array[Ingredient]:
	var consumed: Array[Ingredient] = []
	var needed: Dictionary = {}
	for ing: IngredientData in order.recipe_data.ingredients:
		needed[ing.id] = needed.get(ing.id, 0) + 1
	for type_id: String in needed:
		var count: int = needed[type_id]
		var i := 0
		while i < _selected_pool.size() and count > 0:
			if _selected_pool[i].ingredient_data.id == type_id:
				_selected_pool[i].deselect()
				consumed.append(_selected_pool[i])
				_selected_pool.remove_at(i)
				count -= 1
			else:
				i += 1
	print("[Complete] '%s' consumed %d slot(s); pool now %d" % [
		order.recipe_data.display_name, consumed.size(), _selected_pool.size()])
	return consumed

func _finalize_order(order: Order, consumed: Array[Ingredient]) -> void:
	_active_orders.erase(order)
	_completed_count += 1
	order_completed.emit(order, consumed)
	if _completed_count >= _total_orders and _active_orders.is_empty():
		all_orders_cleared.emit()

func _free_board_counts() -> Dictionary:
	var counts: Dictionary = {}
	if not board_node:
		return counts
	for child in board_node.get_children():
		var ing := child as Ingredient
		if ing and not ing.selected:
			counts[ing.ingredient_data.id] = counts.get(ing.ingredient_data.id, 0) + 1
	return counts

func _combined_counts() -> Dictionary:
	var counts := _free_board_counts()
	for slot: Ingredient in _selected_pool:
		var id := slot.ingredient_data.id
		counts[id] = counts.get(id, 0) + 1
	return counts

func _is_completable(order: Order, available: Dictionary) -> bool:
	var required: Dictionary = {}
	for ing: IngredientData in order.recipe_data.ingredients:
		required[ing.id] = required.get(ing.id, 0) + 1
	for type_id: String in required:
		if available.get(type_id, 0) < required[type_id]:
			return false
	return true

func any_active_order_satisfiable() -> bool:
	if _active_orders.is_empty():
		return true
	var combined := _combined_counts()
	for order in _active_orders:
		if _is_completable(order, combined):
			return true
	return false

func get_committed_demand() -> Dictionary:
	var demand: Dictionary = {}
	for order in _active_orders:
		for ing: IngredientData in order.recipe_data.ingredients:
			demand[ing.id] = demand.get(ing.id, 0) + 1
	return demand

# Returns {type_id: count} — the deficit needed to make the cheapest active order
# completable from free_counts + selected pool, deducting other orders' committed demand.
# Returns {} if no active orders or no deficit exists.
func get_force_deficit(free_counts: Dictionary) -> Dictionary:
	if _active_orders.is_empty():
		return {}
	var combined := free_counts.duplicate()
	for slot: Ingredient in _selected_pool:
		var id := slot.ingredient_data.id
		combined[id] = combined.get(id, 0) + 1
	var total_committed := get_committed_demand()
	var best_deficit: Dictionary = {}
	var best_total := -1
	for order in _active_orders:
		var needed: Dictionary = {}
		for ing: IngredientData in order.recipe_data.ingredients:
			needed[ing.id] = needed.get(ing.id, 0) + 1
		var deficit: Dictionary = {}
		for type_id: String in needed:
			var others: int = total_committed.get(type_id, 0) - needed.get(type_id, 0)
			var avail: int = max(0, combined.get(type_id, 0) - max(0, others))
			var d: int = needed[type_id] - avail
			if d > 0:
				deficit[type_id] = d
		var total: int = 0
		for v: int in deficit.values():
			total += v
		if best_total < 0 or total < best_total:
			best_total = total
			best_deficit = deficit
	return best_deficit

func needs_next_order() -> bool:
	return _completed_count < _total_orders and \
		_active_orders.size() < level_config.max_simultaneous_orders
