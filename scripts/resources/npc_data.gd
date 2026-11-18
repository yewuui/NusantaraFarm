class_name NPCData
extends Resource
## Defines villager identity, portrait, gift preferences, and zone placement.

@export var npc_id: StringName = &""
@export var display_name: String = ""
@export var role_title: String = ""
@export var sprite_index: int = 0
@export var portrait: Texture2D
@export var liked_items: Array[StringName] = []
@export var disliked_items: Array[StringName] = []
@export var default_zone: StringName = &"desa_pasar"
@export var default_position: Vector2 = Vector2(240, 160)
@export var greetings_day: Array[String] = []
@export var greetings_rain: Array[String] = []
@export var greetings_festival: String = ""
