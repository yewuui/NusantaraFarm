class_name QuestData
extends Resource
## Defines a villager or world-progression quest with item/action goals and rewards.

@export var quest_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var giver_npc_id: StringName = &"pak_tani"
@export var required_world_level: int = 1
@export var prerequisite_quest_id: StringName = &""
@export var required_items: Dictionary = {} # { StringName: int }
@export var reward_coins: int = 50
@export var reward_world_xp: int = 40
@export var reward_eco: int = 0
@export var reward_hearts: int = 100
@export var unlocks_zone_id: StringName = &""
