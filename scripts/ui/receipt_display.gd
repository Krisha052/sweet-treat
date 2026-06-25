class_name ReceiptDisplay
extends VBoxContainer

var _order: Order

func set_order(order: Order) -> void:
	_order = order
	_refresh()

func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var title := Label.new()
	title.text = _order.recipe_data.display_name
	add_child(title)

	for ingredient in _order.recipe_data.ingredients:
		var row := Label.new()
		row.text = "- " + ingredient.display_name
		add_child(row)
