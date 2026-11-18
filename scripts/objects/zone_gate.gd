extends StaticBody2D
## Physical barrier blocking a locked zone portal; lets player pay unlock cost once World Level is met.

@export var target_zone_id: String = "hutan"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	WorldStateManager.zone_unlocked.connect(_on_zone_unlocked)
	_refresh()


func get_prompt_text() -> String:
	var z := Catalog.get_zone(StringName(target_zone_id))
	if z == null:
		return "Buka Zona"
	return "Buka %s (Lv %d, %d Koin, %d Kayu)" % [z.display_name, z.required_world_level, z.unlock_cost_coins, z.unlock_cost_wood]


func interact(_player: Node) -> void:
	WorldStateManager.request_unlock_zone(target_zone_id)


func _on_zone_unlocked(zid: String) -> void:
	if zid == target_zone_id:
		_refresh()


func _refresh() -> void:
	var unlocked := WorldStateManager.is_zone_unlocked(target_zone_id)
	visible = not unlocked
	collider.set_deferred("disabled", unlocked)
	var area := get_node_or_null("InteractArea/CollisionShape2D") as CollisionShape2D
	if area != null:
		area.set_deferred("disabled", unlocked)
