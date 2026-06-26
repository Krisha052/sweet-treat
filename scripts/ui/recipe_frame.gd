extends CanvasLayer

const _QUAVER := preload("res://assets/fonts/quaver.ttf")

func _ready() -> void:
	$Root.modulate.a = 0.0
	$Root/RecipePage/CloseButton.pressed.connect(_close)

func open(order: Order) -> void:
	$Root/RecipePage/DishIcon.texture = order.recipe_data.icon
	_build_list(order.recipe_data)
	var tw := create_tween()
	tw.tween_property($Root, "modulate:a", 1.0, 0.2)

func _build_list(recipe: RecipeData) -> void:
	var list: VBoxContainer = $Root/RecipePage/IngredientList
	for child in list.get_children():
		child.queue_free()

	var seen: Dictionary = {}
	var order_ids: Array = []
	for ing: IngredientData in recipe.ingredients:
		if ing.id not in seen:
			seen[ing.id] = {"data": ing, "count": 0}
			order_ids.append(ing.id)
		seen[ing.id]["count"] += 1

	for id in order_ids:
		var entry = seen[id]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = "x%d" % entry["count"]
		label.add_theme_font_override("font", _QUAVER)
		label.add_theme_font_size_override("font_size", 44)
		label.add_theme_color_override("font_color", Color("#3d2b1f"))
		label.custom_minimum_size = Vector2(100, 0)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var icon := TextureRect.new()
		icon.texture = entry["data"].icon
		icon.custom_minimum_size = Vector2(130, 130)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(icon)

		list.add_child(row)

func _close() -> void:
	var tw := create_tween()
	tw.tween_property($Root, "modulate:a", 0.0, 0.2)
	await tw.finished
	queue_free()
