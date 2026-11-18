extends Node
## Atomic JSON Save/Load manager separating World State from individual Player UUID profiles.

signal save_completed(success: bool)

const SAVES_ROOT := "user://saves/"


func save_all() -> bool:
	if not NetworkManager.is_host_or_offline():
		return false
	var world_id := GameManager.active_world_id
	if world_id.is_empty():
		return false

	var world_dir := SAVES_ROOT + world_id + "/"
	var players_dir := world_dir + "players/"
	DirAccess.make_dir_recursive_absolute(players_dir)

	var meta := {
		"world_id": world_id,
		"world_name": GameManager.active_world_name,
		"world_level": WorldStateManager.world_level,
		"day": TimeManager.day,
		"season": TimeManager.season,
		"year": TimeManager.year,
		"saved_at": Time.get_unix_time_from_system(),
	}
	var world_payload := {
		"time": TimeManager.serialize_state(),
		"world": WorldStateManager.serialize_state(),
		"economy": EconomyManager.serialize_world_economy(),
		"quests": QuestManager.serialize_state(),
	}

	var ok := _atomic_write_json(world_dir + "world_meta.json", meta)
	ok = ok and _atomic_write_json(world_dir + "world_state.json", world_payload)

	for uuid in EconomyManager.players.keys():
		ok = ok and _atomic_write_json(players_dir + uuid + ".json", EconomyManager.players[uuid])

	save_completed.emit(ok)
	return ok


func load_world(world_id: String) -> bool:
	var world_dir := SAVES_ROOT + world_id + "/"
	var meta := _read_json(world_dir + "world_meta.json")
	var payload := _read_json(world_dir + "world_state.json")
	if meta.is_empty() or payload.is_empty():
		return false

	GameManager.active_world_id = world_id
	GameManager.active_world_name = str(meta.get("world_name", "Desa Nusantara"))

	TimeManager.apply_snapshot(payload.get("time", {}))
	WorldStateManager.apply_snapshot(payload.get("world", {}))
	EconomyManager.reset_all()
	EconomyManager.apply_world_economy(payload.get("economy", {}))
	QuestManager.apply_snapshot(payload.get("quests", {}))

	var players_dir := world_dir + "players/"
	if DirAccess.dir_exists_absolute(players_dir):
		var d := DirAccess.open(players_dir)
		if d != null:
			d.list_dir_begin()
			var fn := d.get_next()
			while not fn.is_empty():
				if fn.ends_with(".json"):
					var pdata := _read_json(players_dir + fn)
					if not pdata.is_empty():
						var uuid := str(pdata.get("player_uuid", fn.get_basename()))
						EconomyManager.players[uuid] = pdata
				fn = d.get_next()
			d.list_dir_end()
	return true


func list_saved_worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SAVES_ROOT):
		return out
	var d := DirAccess.open(SAVES_ROOT)
	if d == null:
		return out
	d.list_dir_begin()
	var sub := d.get_next()
	while not sub.is_empty():
		if d.current_is_dir() and not sub.begins_with("."):
			var meta := _read_json(SAVES_ROOT + sub + "/world_meta.json")
			if not meta.is_empty():
				out.append(meta)
		sub = d.get_next()
	d.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("saved_at", 0)) > float(b.get("saved_at", 0))
	)
	return out


func _atomic_write_json(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_dst := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_dst)
	return DirAccess.rename_absolute(abs_tmp, abs_dst) == OK


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
