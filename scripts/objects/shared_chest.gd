extends Node2D
## Shared Farm Chest: lets solo or Co-op teammates deposit and withdraw materials together.


func get_prompt_text() -> String:
	return "Peti Bersama Kebun"


func interact(_player: Node) -> void:
	var wr := get_tree().get_first_node_in_group("world_root") as WorldRoot
	if wr != null:
		wr.open_inventory_mode("chest")
