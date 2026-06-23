extends Area3D

signal collected(data: IngredientData)

@export var ingredient_data: IngredientData

func _input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	var pressed := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if pressed:
		collected.emit(ingredient_data)
