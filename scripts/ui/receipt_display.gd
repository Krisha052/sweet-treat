class_name ReceiptDisplay
extends Control

var _order: Order

func set_order(order: Order) -> void:
	_order = order
	_refresh()

func _refresh() -> void:
	# TODO: populate ingredient label/icon rows from _order.recipe_data.ingredients
	pass
