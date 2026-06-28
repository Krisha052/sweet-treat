class_name LevelConfig
extends Resource

@export var level_id: int = 0
@export var time_limit_seconds: float = 60.0
@export var max_simultaneous_orders: int = 3
@export var recipe_pool: Array[RecipeData] = []
@export var board_cols: int = 6
@export var board_rows: int = 6
