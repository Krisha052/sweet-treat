class_name Order
extends RefCounted

var recipe_data: RecipeData

func _init(data: RecipeData) -> void:
	recipe_data = data

func is_satisfied_by(pool: Array[Ingredient]) -> bool:
	var pool_counts: Dictionary = {}
	for slot: Ingredient in pool:
		var id := slot.ingredient_data.id
		pool_counts[id] = pool_counts.get(id, 0) + 1
	var required: Dictionary = {}
	for ing: IngredientData in recipe_data.ingredients:
		required[ing.id] = required.get(ing.id, 0) + 1
	for type_id: String in required:
		if pool_counts.get(type_id, 0) < required[type_id]:
			return false
	return true
