extends CanvasLayer

@export var receipt_scene: PackedScene

@onready var _timer_label: Label = $TimerLabel
@onready var _receipt_container: VBoxContainer = $ReceiptContainer

func update_timer(seconds_left: float) -> void:
	_timer_label.text = "%d" % ceili(seconds_left)

func add_receipt(order: Order) -> void:
	if not receipt_scene:
		return
	var receipt: ReceiptDisplay = receipt_scene.instantiate()
	receipt.set_order(order)
	_receipt_container.add_child(receipt)

func remove_receipt(order: Order) -> void:
	for child in _receipt_container.get_children():
		if child is ReceiptDisplay and child._order == order:
			child.queue_free()
			return
