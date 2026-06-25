class_name Order
extends RefCounted

signal completed(order: Order)

var recipe_data: RecipeData
var _collected_ids: Array[String] = []

func _init(data: RecipeData) -> void:
	recipe_data = data

func collect(ingredient_id: String) -> void:
	if _collected_ids.count(ingredient_id) < _needed_count(ingredient_id):
		_collected_ids.append(ingredient_id)
		if is_complete():
			completed.emit(self)

func is_complete() -> bool:
	for ingredient in recipe_data.ingredients:
		if _collected_ids.count(ingredient.id) < _needed_count(ingredient.id):
			return false
	return true

func _needed_count(ingredient_id: String) -> int:
	var count := 0
	for ingredient in recipe_data.ingredients:
		if ingredient.id == ingredient_id:
			count += 1
	return count
