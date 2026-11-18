extends Node2D
## Harvest Festival Tumpeng Stage visible on Day 14 & Day 28 (09:00-17:00) in Desa Utama.


func get_prompt_text() -> String:
	return "Festival Panen (Persembahkan Hasil)"


func interact(_player: Node) -> void:
	if not TimeManager.is_festival_active():
		return
	var wr := get_tree().get_first_node_in_group("world_root") as WorldRoot
	if wr != null:
		wr.open_inventory_mode("festival")
