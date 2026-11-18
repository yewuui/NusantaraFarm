extends Node2D
## Farm Shipping Bin: opens InventoryUI in ship mode so crops/goods settle into coins at 06:00.


func get_prompt_text() -> String:
	return "Peti Panen (Cair jam 06:00)"


func interact(_player: Node) -> void:
	var wr := get_tree().get_first_node_in_group("world_root") as WorldRoot
	if wr != null:
		wr.open_inventory_mode("ship")
