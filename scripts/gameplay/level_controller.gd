extends Node2D

signal time_updated(seconds_left: float)

@onready var _timer: Timer = $Timer
@onready var _order_manager = $OrderManager
@onready var _hud = $HUD

const _FALLBACK_SCENE := preload("res://scenes/gameplay/ingredient.tscn")

var level_config: LevelConfig
var _time_remaining: float = 0.0

func _ready() -> void:
	var config := GameManager.pending_level_config
	GameManager.pending_level_config = null
	if not config:
		# Fallback for running scene directly from the editor without main menu.
		config = load("res://data/levels/level_01.tres")

	level_config = config
	GameManager.start_level(config)

	_spawn_ingredients(config)

	_order_manager.order_spawned.connect(_hud.add_receipt)
	_order_manager.order_completed.connect(_hud.remove_receipt)

	for ingredient in $Ingredients.get_children():
		ingredient.collected.connect(_order_manager.on_ingredient_collected)

	_order_manager.setup(config)

	_time_remaining = config.time_limit_seconds
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_tick)
	_timer.start()
	time_updated.emit(_time_remaining)

func _spawn_ingredients(config: LevelConfig) -> void:
	var unique: Array[IngredientData] = []
	for recipe in config.recipe_pool:
		for ing: IngredientData in recipe.ingredients:
			var found := false
			for u in unique:
				if u.id == ing.id:
					found = true
					break
			if not found:
				unique.append(ing)

	var n := unique.size()
	var ids: PackedStringArray = []
	for d in unique:
		ids.append(d.id)
	print("Level %d: spawning %d ingredient(s): %s" % [config.level_id, n, ", ".join(ids)])

	# Ingredient textures are 160×160px; use 180px cells (20px gap between edges).
	# Grid is centered on the viewport and wraps after MAX_COLS columns.
	const CELL := 180.0
	const MAX_COLS := 4
	var vp := get_viewport().get_visible_rect().size
	var cols := mini(n, mini(MAX_COLS, maxi(1, floori(vp.x / CELL))))
	var n_rows := ceili(float(n) / float(cols))
	var row_w := float(cols) * CELL
	var grid_h := float(n_rows) * CELL
	var origin_x := (vp.x - row_w) * 0.5 + CELL * 0.5
	var origin_y := clampf(
		vp.y * 0.75 - float(n_rows - 1) * CELL * 0.5,
		CELL * 0.5 + 10.0,
		vp.y - grid_h + CELL * 0.5 - 10.0
	)

	for i in n:
		var col := i % cols
		var row := i / cols
		var items_in_row := mini(n - row * cols, cols)
		var row_shift := float(cols - items_in_row) * CELL * 0.5
		var pos := Vector2(origin_x + float(col) * CELL + row_shift, origin_y + float(row) * CELL)

		var data: IngredientData = unique[i]
		var template: PackedScene = data.scene if data.scene else _FALLBACK_SCENE
		var node := template.instantiate() as Node2D
		node.set("ingredient_data", data)
		node.position = pos
		$Ingredients.add_child(node)
		print("  [%d] %s -> (%.0f, %.0f)" % [i, data.id, pos.x, pos.y])

func _on_tick() -> void:
	_time_remaining -= 1.0
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_timer.stop()
		GameManager.set_fail()

func on_all_orders_cleared() -> void:
	_timer.stop()
	GameManager.set_win()
