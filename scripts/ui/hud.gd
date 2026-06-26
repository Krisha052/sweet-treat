extends CanvasLayer

const DishCard := preload("res://scripts/ui/dish_card.gd")

@export var dish_card_scene: PackedScene
@export var recipe_frame_scene: PackedScene

@onready var _timer_label: Label = $TimerLabel
@onready var _level_label: Label = $LevelLabel
@onready var _card_row: HFlowContainer = $DishCardRow

func set_level(level_id: int) -> void:
	_level_label.text = "Lv. %d" % (level_id + 1)

func update_timer(seconds_left: float) -> void:
	_timer_label.text = "%d" % ceili(seconds_left)

func add_card(order: Order) -> void:
	if not dish_card_scene:
		return
	var card: DishCard = dish_card_scene.instantiate()
	card.set_order(order)
	card.card_pressed.connect(_on_card_pressed)
	_card_row.add_child(card)

func remove_card(order: Order) -> void:
	for child in _card_row.get_children():
		if child is DishCard and child._order == order:
			child.queue_free()
			return

func _on_card_pressed(order: Order) -> void:
	if not recipe_frame_scene:
		return
	var frame: Node = recipe_frame_scene.instantiate()
	get_parent().add_child(frame)
	frame.open(order)
