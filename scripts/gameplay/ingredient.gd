class_name Ingredient
extends Area2D

signal tapped(slot: Ingredient)

@export var ingredient_data: IngredientData

var selected: bool = false
var _tap_guard: bool = false
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_base_scale = scale
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
	if _tap_guard:
		return
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if pressed:
		_tap_guard = true
		call_deferred(&"_clear_tap_guard")
		_flash()
		tapped.emit(self)

func _clear_tap_guard() -> void:
	_tap_guard = false

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.35, 0.08)
	tween.tween_property(self, "scale", _base_scale, 0.15)
