class_name ResultOverlay
extends CanvasLayer

var _label: Label
var _retry_btn: Button
var _next_btn: Button

func _ready() -> void:
	layer = 10
	_build_ui()
	visible = false
	GameManager.level_won.connect(_on_level_won)
	GameManager.level_failed.connect(_on_level_failed)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_retry_btn = Button.new()
	_retry_btn.text = "Retry"
	_retry_btn.pressed.connect(_on_retry)
	hbox.add_child(_retry_btn)

	_next_btn = Button.new()
	_next_btn.text = "Next Level"
	_next_btn.pressed.connect(_on_next_level)
	hbox.add_child(_next_btn)

func _on_level_won() -> void:
	_label.text = "Level Complete!"
	_next_btn.visible = true
	visible = true

func _on_level_failed() -> void:
	_label.text = "Time's Up!"
	_next_btn.visible = false
	visible = true

func _on_retry() -> void:
	GameManager.pending_level_config = GameManager.current_level_config
	get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/level_base.tscn")

func _on_next_level() -> void:
	# Phase 2: wire to level select. Goes to main menu for now.
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/main_menu.tscn")
