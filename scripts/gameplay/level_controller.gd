extends Node2D

signal time_updated(seconds_left: float)

@onready var _timer: Timer = $Timer
@onready var _order_manager: OrderManager = $OrderManager
@onready var _hud = $HUD
@onready var _bg: ColorRect = $BackgroundLayer/Background

const _INGREDIENT_SCENE := preload("res://scenes/gameplay/ingredient.tscn")
const BOARD_COLS := 4
const BOARD_ROWS := 4

var level_config: LevelConfig
var _time_remaining: float = 0.0
var _eligible_ingredients: Array[IngredientData] = []

func _ready() -> void:
	var config := GameManager.pending_level_config
	GameManager.pending_level_config = null
	if not config:
		# Fallback for running scene directly from the editor without main menu.
		config = load("res://data/levels/level_01.tres")

	level_config = config
	GameManager.start_level(config)
	_hud.set_level(config.level_id)

	_build_eligible_set(config)
	_init_board()

	_order_manager.order_spawned.connect(_hud.add_card)
	_order_manager.order_completed.connect(_on_order_completed_cb)
	_order_manager.setup(config)

	var initial_count := mini(config.max_simultaneous_orders, config.recipe_pool.size())
	for _i in initial_count:
		_order_manager.spawn_order(_pick_next_recipe())

	_time_remaining = config.time_limit_seconds
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_tick)
	_timer.start()
	time_updated.emit(_time_remaining)

# --- Board setup ---

func _build_eligible_set(config: LevelConfig) -> void:
	_eligible_ingredients.clear()
	for recipe in config.recipe_pool:
		for ing: IngredientData in recipe.ingredients:
			var found := false
			for e in _eligible_ingredients:
				if e.id == ing.id:
					found = true
					break
			if not found:
				_eligible_ingredients.append(ing)
	var ids: PackedStringArray = []
	for d in _eligible_ingredients:
		ids.append(d.id)
	print("Level %d: eligible ingredients (%d): %s" % [
		config.level_id, _eligible_ingredients.size(), ", ".join(ids)])

func _init_board() -> void:
	var vp := get_viewport().get_visible_rect().size
	const CELL := 180.0
	var row_w := BOARD_COLS * CELL
	var origin_x := (vp.x - row_w) * 0.5 + CELL * 0.5
	var origin_y := clampf(
		vp.y * 0.40,
		CELL * 0.5 + 10.0,
		vp.y - BOARD_ROWS * CELL + CELL * 0.5 - 10.0
	)

	print("Level %d: init %dx%d board, vp=(%.0f,%.0f), origin=(%.0f,%.0f)" % [
		level_config.level_id, BOARD_COLS, BOARD_ROWS, vp.x, vp.y, origin_x, origin_y])

	for i in BOARD_COLS * BOARD_ROWS:
		var col := i % BOARD_COLS
		var row := i / BOARD_COLS
		var pos := Vector2(origin_x + col * CELL, origin_y + row * CELL)
		var data := _random_ingredient()
		var node := _INGREDIENT_SCENE.instantiate() as Ingredient
		node.ingredient_data = data
		node.position = pos
		node.tapped.connect(_on_ingredient_tapped)
		$Ingredients.add_child(node)

func _random_ingredient() -> IngredientData:
	return _eligible_ingredients[randi() % _eligible_ingredients.size()]

# --- Tap routing ---

func _on_ingredient_tapped(slot: Ingredient) -> void:
	if slot.selected:
		_order_manager.try_deselect(slot)
	else:
		_order_manager.on_ingredient_tapped(slot)

# --- Order completion + board refill ---

func _on_order_completed_cb(order: Order) -> void:
	_hud.remove_card(order)

	# Refill every slot consumed by this order with a fresh random ingredient.
	for slot in order.get_consumed_slots():
		var new_data := _random_ingredient()
		print("[Refill] slot was %s -> now %s" % [slot.ingredient_data.id, new_data.id])
		slot.refill(new_data)

	# Spawn the next order if the level still has outstanding orders.
	if _order_manager.needs_next_order():
		_order_manager.spawn_order(_pick_next_recipe())

# --- Recipe selection by board state ---

func _pick_next_recipe() -> RecipeData:
	# Count free (unselected) slots by ingredient id.
	var free_counts: Dictionary = {}
	for child in $Ingredients.get_children():
		var slot := child as Ingredient
		if slot and not slot.selected:
			free_counts[slot.ingredient_data.id] = \
				free_counts.get(slot.ingredient_data.id, 0) + 1

	# Find all recipes the current free board can satisfy.
	var satisfiable: Array[RecipeData] = []
	for recipe in level_config.recipe_pool:
		if _is_recipe_satisfiable(recipe, free_counts):
			satisfiable.append(recipe)

	if satisfiable.is_empty():
		var fallback: RecipeData = level_config.recipe_pool[randi() % level_config.recipe_pool.size()]
		print("[BoardMatch] No satisfiable recipe — random fallback: %s" % fallback.display_name)
		return fallback

	var chosen: RecipeData = satisfiable[randi() % satisfiable.size()]
	var names: PackedStringArray = []
	for r in satisfiable:
		names.append(r.display_name)
	print("[BoardMatch] %d satisfiable: [%s] -> chose: %s" % [
		satisfiable.size(), ", ".join(names), chosen.display_name])
	return chosen

func _is_recipe_satisfiable(recipe: RecipeData, free_counts: Dictionary) -> bool:
	var needed: Dictionary = {}
	for ing: IngredientData in recipe.ingredients:
		needed[ing.id] = needed.get(ing.id, 0) + 1
	for id in needed:
		if free_counts.get(id, 0) < needed[id]:
			return false
	return true

# --- Timer ---

func _on_tick() -> void:
	_time_remaining -= 1.0
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_timer.stop()
		GameManager.set_fail()
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/game_over_screen.tscn")

func on_all_orders_cleared() -> void:
	_timer.stop()
	GameManager.set_win()
	_begin_win_sequence()

func _begin_win_sequence() -> void:
	_bg.color = Color("#8a8f13")
	await get_tree().create_timer(3.0).timeout
	# TODO: show interstitial ad here
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/next_level_screen.tscn")
