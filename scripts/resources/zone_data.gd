class_name ZoneData
extends Resource
## Defines map zone dimensions, unlock prerequisites, and display metadata.

@export var zone_id: StringName = &""
@export var display_name: String = ""
@export var scene_path: String = ""
@export var grid_size: Vector2i = Vector2i(36, 24)
@export var is_indoor: bool = false
@export var unlocked_by_default: bool = true
@export var required_world_level: int = 1
@export var required_quest_id: StringName = &""
@export var unlock_cost_coins: int = 0
@export var unlock_cost_wood: int = 0
@export var map_pin_pos: Vector2 = Vector2(100, 100)
@export var map_display_size: Vector2 = Vector2(56, 36)
