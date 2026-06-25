class_name Ingredient
extends Area2D

signal tapped(slot: Ingredient)

@export var ingredient_data: IngredientData

var selected: bool = false

func _ready() -> void:
	if not ingredient_data:
		return
	_apply_texture()

func _apply_texture() -> void:
	var sprite: Sprite2D = $Sprite2D
	if ingredient_data.icon:
		sprite.texture = ingredient_data.icon
	else:
		var img := Image.create(60, 60, false, Image.FORMAT_RGBA8)
		img.fill(ingredient_data.color)
		sprite.texture = ImageTexture.create_from_image(img)

func select() -> void:
	selected = true
	$Sprite2D.modulate = Color("#8a8f13")

func deselect() -> void:
	selected = false
	$Sprite2D.modulate = Color.WHITE

func refill(new_data: IngredientData) -> void:
	# TODO: replace with slide-down animation in visual pass
	ingredient_data = new_data
	deselect()
	_apply_texture()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if pressed:
		_flash()
		tapped.emit(self)

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
