class_name Order
extends RefCounted

signal completed(order: Order)

var recipe_data: RecipeData
var _collected_slots: Array[Ingredient] = []

func _init(data: RecipeData) -> void:
	recipe_data = data

func collect(slot: Ingredient) -> bool:
	var id := slot.ingredient_data.id
	if _collected_count(id) < _needed_count(id):
		_collected_slots.append(slot)
		slot.select()
		print("[Credit] %s -> '%s'  (%d/%d for this ingredient, %d/%d total)" % [
			id, recipe_data.display_name,
			_collected_count(id), _needed_count(id),
			_collected_slots.size(), recipe_data.ingredients.size()])
		if is_complete():
			completed.emit(self)
		return true
	return false

func uncollect(slot: Ingredient) -> bool:
	var idx := _collected_slots.find(slot)
	if idx == -1:
		return false
	_collected_slots.remove_at(idx)
	slot.deselect()
	return true

func get_consumed_slots() -> Array[Ingredient]:
	return _collected_slots

# Returns {ingredient_id: remaining_count} for every type still needed.
func get_remaining_needs() -> Dictionary:
	var result: Dictionary = {}
	for ing: IngredientData in recipe_data.ingredients:
		result[ing.id] = result.get(ing.id, 0) + 1
	for slot in _collected_slots:
		var id := slot.ingredient_data.id
		result[id] = result.get(id, 0) - 1
		if result[id] <= 0:
			result.erase(id)
	return result

func is_complete() -> bool:
	for ingredient in recipe_data.ingredients:
		if _collected_count(ingredient.id) < _needed_count(ingredient.id):
			return false
	return true

func _collected_count(ingredient_id: String) -> int:
	var count := 0
	for slot in _collected_slots:
		if slot.ingredient_data.id == ingredient_id:
			count += 1
	return count

func _needed_count(ingredient_id: String) -> int:
	var count := 0
	for ingredient in recipe_data.ingredients:
		if ingredient.id == ingredient_id:
			count += 1
	return count
