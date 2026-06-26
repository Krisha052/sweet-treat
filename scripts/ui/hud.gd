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

func position_card_row(board_bottom_px: float) -> void:
	var vp_h := get_viewport().get_visible_rect().size.y
	var top_y := board_bottom_px + 20.0
	_card_row.anchor_top = top_y / vp_h
	_card_row.anchor_bottom = (top_y + 300.0) / vp_h
	_card_row.offset_top = 0.0
	_card_row.offset_bottom = 0.0

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
	_card_row.visible = false
	var frame: Node = recipe_frame_scene.instantiate()
	frame.tree_exiting.connect(func(): _card_row.visible = true)
	get_parent().add_child(frame)
	frame.open(order)
