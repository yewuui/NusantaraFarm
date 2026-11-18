class_name CropData
extends Resource
## Defines tropical crop growth, seasonal bonuses, and harvest yield data.

@export var crop_id: StringName = &""
@export var seed_item_id: StringName = &""
@export var harvest_item_id: StringName = &""
@export var display_name: String = ""
@export var atlas_row: int = 0
@export var optimal_seasons: Array[StringName] = [&"kemarau", &"penghujan"]
@export var grow_days_normal: int = 5
@export var grow_days_optimal: int = 4
@export var is_regrowable: bool = false
@export var regrow_days: int = 3
@export var min_yield: int = 1
@export var max_yield: int = 3
@export var harvest_xp: int = 10
@export var education_fact: String = ""
