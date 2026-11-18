class_name NPCController
extends Node2D
## Villager NPC node showing sprite, quest indicator, and opening DialogueManager on interaction.

@export var npc_id: StringName = &"pak_tani"

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var quest_badge: Label = $QuestBadge


func _ready() -> void:
	var npc := Catalog.get_npc(npc_id)
	if npc != null:
		name_label.text = npc.display_name
		_set_npc_region(npc.sprite_index)
	QuestManager.quests_updated.connect(_refresh_badge)
	EconomyManager.local_profile_updated.connect(_refresh_badge)
	_refresh_badge()


func get_prompt_text() -> String:
	var npc := Catalog.get_npc(npc_id)
	return "Bicara (%s)" % (npc.display_name if npc != null else String(npc_id))


func interact(_player: Node) -> void:
	DialogueManager.open_npc_dialogue(String(npc_id))


func _set_npc_region(idx: int) -> void:
	var path := "res://assets/characters/npcs_sheet.png"
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(idx * 16, 0, 16, 32)
	sprite.texture = at


func _refresh_badge() -> void:
	var has_turn_in := false
	for qid in QuestManager.active_quests:
		var q := Catalog.get_quest(StringName(qid))
		if q != null and q.giver_npc_id == npc_id and QuestManager.can_turn_in(GameManager.player_uuid, qid):
			has_turn_in = true
			break
	if has_turn_in:
		quest_badge.text = "?"
		quest_badge.visible = true
		return
	var avail := QuestManager.get_available_quests_for_npc(npc_id)
	for q in avail:
		if not (String(q.quest_id) in QuestManager.active_quests):
			quest_badge.text = "!"
			quest_badge.visible = true
			return
	quest_badge.visible = false
