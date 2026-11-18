class_name RecipeData
extends Resource
## Defines a Joglo production station recipe converting raw goods into crafted products.

@export var recipe_id: StringName = &""
@export var display_name: String = ""
@export var station_type: StringName = &"wajan_joglo"
@export var required_world_level: int = 1
@export var ingredients: Dictionary = {} # { StringName: int }
@export var output_item_id: StringName = &""
@export var output_amount: int = 1
@export var process_hours: float = 2.0
@export var craft_xp: int = 15
