class_name DishCard
extends TextureButton

signal card_pressed(order: Order)

var _order: Order

func _ready() -> void:
	pressed.connect(func(): card_pressed.emit(_order))

func set_order(order: Order) -> void:
	_order = order
	$DishIcon.texture = order.recipe_data.icon
