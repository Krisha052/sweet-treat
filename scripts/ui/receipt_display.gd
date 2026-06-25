class_name ReceiptDisplay
extends Control

var _order: Order

func set_order(order: Order) -> void:
	_order = order
	_refresh()

func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = _order.recipe_data.display_name
	vbox.add_child(title)

	for ingredient in _order.recipe_data.ingredients:
		var row := Label.new()
		row.text = "- " + ingredient.display_name
		vbox.add_child(row)
