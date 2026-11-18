class_name ItemData
extends Resource
## Defines an item, tool, seed, harvest product, or crafted good in Nusantara Farm.

enum Category {
	TOOL,
	SEED,
	CROP,
	PROCESSED,
	FORAGE,
	MATERIAL,
	QUEST_ITEM,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.CROP
@export var atlas_index: int = 0
@export var icon: Texture2D
@export var max_stack: int = 99
@export var base_buy_price: int = 0
@export var base_sell_price: int = 10
@export var is_consumable: bool = false
@export var energy_restore: int = 0
@export var anti_drowsy_hours: float = 0.0
@export var is_giftable: bool = true
@export var required_world_level: int = 1
