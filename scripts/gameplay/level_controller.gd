extends Node2D

signal time_updated(seconds_left: float)

@onready var _timer: Timer = $Timer
@onready var _order_manager: OrderManager = $OrderManager
@onready var _hud = $HUD
@onready var _bg: ColorRect = $BackgroundLayer/Background

const _INGREDIENT_SCENE := preload("res://scenes/gameplay/ingredient.tscn")
const BOARD_COLS := 5
const BOARD_ROWS := 5

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

	_order_manager.board_node = $Ingredients
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
	const CELL := 150.0
	const SPRITE_SCALE := 0.8
	var row_w := BOARD_COLS * CELL
	var origin_x := (vp.x - row_w) * 0.5 + CELL * 0.5
	var origin_y := clampf(
		vp.y * 0.22,
		CELL * 0.5 + 10.0,
		vp.y - BOARD_ROWS * CELL + CELL * 0.5 - 10.0
	)

	print("Level %d: init %dx%d board, vp=(%.0f,%.0f), origin=(%.0f,%.0f)" % [
		level_config.level_id, BOARD_COLS, BOARD_ROWS, vp.x, vp.y, origin_x, origin_y])

	for i in BOARD_COLS * BOARD_ROWS:
		var col := i % BOARD_COLS
		var row := i / BOARD_COLS
		var pos := Vector2(origin_x + col * CELL, origin_y + row * CELL)
		var node := _INGREDIENT_SCENE.instantiate() as Ingredient
		node.ingredient_data = _random_ingredient()
		node.position = pos
		node.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		node.get_node("Sprite2D").scale = Vector2(0.875, 0.875)
		node.tapped.connect(_on_ingredient_tapped)
		$Ingredients.add_child(node)

	# Guarantee at least one recipe is satisfiable from the starting board.
	var ok := false
	var rerolls := 0
	for attempt in range(20):
		var free: Dictionary = {}
		for child in $Ingredients.get_children():
			var slot := child as Ingredient
			if slot and not slot.selected:
				free[slot.ingredient_data.id] = free.get(slot.ingredient_data.id, 0) + 1
		for recipe in level_config.recipe_pool:
			if _is_recipe_satisfiable(recipe, free):
				ok = true
				break
		if ok:
			break
		rerolls += 1
		for child in $Ingredients.get_children():
			var slot := child as Ingredient
			if slot:
				slot.refill(_random_ingredient())
	if rerolls > 0:
		print("[Board] Initial: needed %d re-roll(s) to satisfy a recipe" % rerolls)
	if not ok:
		push_warning("[Board] Initial: no satisfiable recipe after 20 attempts; force-placing")
		var free := _board_free_counts()
		var deficit := _min_deficit_for_pool(free)
		if not deficit.is_empty():
			if not _apply_force_placement(deficit, []):
				push_warning("[Board] Initial: force-placement failed — no eligible slots")

	var board_bottom := origin_y + (BOARD_ROWS - 1) * CELL + CELL * 0.5
	_hud.position_card_row(board_bottom)

func _random_ingredient() -> IngredientData:
	return _eligible_ingredients[randi() % _eligible_ingredients.size()]

func _find_ingredient_data(type_id: String) -> IngredientData:
	for d in _eligible_ingredients:
		if d.id == type_id:
			return d
	return null

func _board_free_counts() -> Dictionary:
	var counts: Dictionary = {}
	for child in $Ingredients.get_children():
		var slot := child as Ingredient
		if slot and not slot.selected:
			counts[slot.ingredient_data.id] = counts.get(slot.ingredient_data.id, 0) + 1
	return counts

# Returns the smallest-deficit {type_id: count} needed to make any recipe in the
# pool satisfiable from free_counts. Used at the initial board site where no
# active orders exist yet.
func _min_deficit_for_pool(free_counts: Dictionary) -> Dictionary:
	var best_deficit: Dictionary = {}
	var best_total := -1
	for recipe in level_config.recipe_pool:
		var needed: Dictionary = {}
		for ing: IngredientData in recipe.ingredients:
			needed[ing.id] = needed.get(ing.id, 0) + 1
		var deficit: Dictionary = {}
		for type_id in needed:
			var d: int = needed[type_id] - free_counts.get(type_id, 0)
			if d > 0:
				deficit[type_id] = d
		var total := 0
		for v in deficit.values():
			total += v
		if best_total < 0 or total < best_total:
			best_total = total
			best_deficit = deficit
	return best_deficit

# Overwrites the minimum set of board slots to cover deficit.
# Prefers priority_slots (already re-rolled this cycle); spills to other
# non-selected slots only if needed. Returns false and touches nothing if
# there are not enough eligible slots to cover the full deficit.
func _apply_force_placement(deficit: Dictionary, priority_slots: Array) -> bool:
	if deficit.is_empty():
		return true
	var total_needed := 0
	for v in deficit.values():
		total_needed += v

	# Priority candidates (consumed/re-rolled slots — already deselected by refill()).
	var candidates: Array[Ingredient] = []
	for s in priority_slots:
		var slot := s as Ingredient
		if slot:
			candidates.append(slot)

	# Spill candidates: non-priority, non-selected board slots.
	var spill_needed := max(0, total_needed - candidates.size())
	var spill_pool: Array[Ingredient] = []
	for child in $Ingredients.get_children():
		var slot := child as Ingredient
		if slot and not (slot in priority_slots) and not slot.selected:
			spill_pool.append(slot)

	if spill_pool.size() < spill_needed:
		return false  # not enough eligible slots — no partial placement

	for slot in spill_pool:
		if candidates.size() >= total_needed:
			break
		candidates.append(slot)

	var remaining := deficit.duplicate()
	for slot in candidates:
		if remaining.is_empty():
			break
		var type_id: String = remaining.keys()[0]
		var ing := _find_ingredient_data(type_id)
		if ing:
			slot.refill(ing)
			remaining[type_id] -= 1
			if remaining[type_id] <= 0:
				remaining.erase(type_id)
	return remaining.is_empty()

# --- Tap routing ---

func _on_ingredient_tapped(slot: Ingredient) -> void:
	if slot.selected:
		_order_manager.try_deselect(slot)
	else:
		_order_manager.on_ingredient_tapped(slot)

# --- Order completion + board refill ---

func _on_order_completed_cb(order: Order) -> void:
	_hud.remove_card(order)

	# Refill consumed slots, retrying until at least one remaining active order
	# is satisfiable from the new board (up to 20 attempts).
	var consumed := order.get_consumed_slots()
	var satisfied := false
	var rerolls := 0
	for attempt in range(20):
		for slot in consumed:
			slot.refill(_random_ingredient())
		if _order_manager.any_active_order_satisfiable():
			satisfied = true
			break
		rerolls += 1
	if rerolls > 0:
		print("[Board] Refill: needed %d re-roll(s) to satisfy an active order" % rerolls)
	if not satisfied:
		push_warning("[Board] Refill: no satisfiable order after 20 attempts; force-placing")
		var free := _board_free_counts()
		var deficit := _order_manager.get_force_deficit(free)
		if not deficit.is_empty():
			if not _apply_force_placement(deficit, consumed):
				push_warning("[Board] Refill: force-placement failed — no eligible slots")

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

	# Deduct what active orders already need so we don't double-book resources.
	var committed := _order_manager.get_committed_demand()
	var available: Dictionary = {}
	for type_id in free_counts:
		var remaining := free_counts[type_id] - committed.get(type_id, 0)
		if remaining > 0:
			available[type_id] = remaining

	# Find all recipes the uncommitted board can still satisfy.
	var satisfiable: Array[RecipeData] = []
	for recipe in level_config.recipe_pool:
		if _is_recipe_satisfiable(recipe, available):
			satisfiable.append(recipe)

	if satisfiable.is_empty():
		var fallback: RecipeData = level_config.recipe_pool[randi() % level_config.recipe_pool.size()]
		print("[BoardMatch] No recipe fits uncommitted board — random fallback: %s" % fallback.display_name)
		return fallback

	var chosen: RecipeData = satisfiable[randi() % satisfiable.size()]
	var names: PackedStringArray = []
	for r in satisfiable:
		names.append(r.display_name)
	print("[BoardMatch] %d satisfiable on uncommitted board: [%s] -> chose: %s" % [
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
	var next_path := "res://data/levels/level_%02d.tres" % (GameManager.current_level_id + 2)
	if ResourceLoader.exists(next_path):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/next_level_screen.tscn")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/game_complete_screen.tscn")
