class_name Order
extends RefCounted

signal completed(order: Order)

var recipe_data: RecipeData
var _collected_ids: Array[String] = []

func _init(data: RecipeData) -> void:
	recipe_data = data

func collect(ingredient_id: String) -> void:
	if _is_needed(ingredient_id) and ingredient_id not in _collected_ids:
		_collected_ids.append(ingredient_id)
		if is_complete():
			completed.emit(self)

func is_complete() -> bool:
	for ingredient in recipe_data.ingredients:
		if ingredient.id not in _collected_ids:
			return false
	return true

func _is_needed(ingredient_id: String) -> bool:
	for ingredient in recipe_data.ingredients:
		if ingredient.id == ingredient_id:
			return true
	return false
