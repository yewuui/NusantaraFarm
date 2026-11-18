extends Node2D
## Forest tree supporting chopping (Eco-Meter -8) and replanting with bibit_pohon (Eco-Meter +6).

@export var tree_id: String = "tree_00"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D = $StaticBody2D/CollisionShape2D


func _ready() -> void:
	add_to_group("eco_tree")
	refresh_visual()


func get_prompt_text() -> String:
	var t: Dictionary = WorldStateManager.forest_trees.get(tree_id, {})
	var st := str(t.get("state", "adult"))
	if st == "adult":
		return "Pohon Dewasa (Pakai Kapak)"
	if st == "stump":
		return "Tunggul (Tanam Bibit Pohon)"
	return "Bibit Pohon Reboisasi"


func interact(player: Node) -> void:
	if player is PlayerController:
		var slot := EconomyManager.get_inventory_slot(GameManager.player_uuid, player.selected_hotbar_index)
		var held := str(slot.get("id", ""))
		WorldStateManager.request_tree_action(tree_id, held)


func refresh_visual() -> void:
	var t: Dictionary = WorldStateManager.forest_trees.get(tree_id, {})
	var st := str(t.get("state", "adult"))
	if st == "adult":
		if ResourceLoader.exists("res://assets/objects/tree_adult.png"):
			sprite.texture = load("res://assets/objects/tree_adult.png") as Texture2D
		collider.set_deferred("disabled", false)
	elif st == "stump":
		if ResourceLoader.exists("res://assets/objects/tree_stump.png"):
			sprite.texture = load("res://assets/objects/tree_stump.png") as Texture2D
		collider.set_deferred("disabled", true)
	else:
		sprite.texture = Catalog.get_crop_stage_texture(6, 1)
		collider.set_deferred("disabled", true)
