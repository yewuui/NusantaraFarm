extends Node
## Manages world-shared quests, prerequisites, item delivery verification, and zone unlocks.

signal quests_updated

var active_quests: Array[String] = []
var completed_quests: Array[String] = []


func _ready() -> void:
	reset_new_world()


func reset_new_world() -> void:
	active_quests = ["q_panen_padi", "q_keripik_nisrina"]
	completed_quests.clear()
	quests_updated.emit()


func get_available_quests_for_npc(npc_id: StringName) -> Array[QuestData]:
	var out: Array[QuestData] = []
	for q_any in Catalog.quests.values():
		var q := q_any as QuestData
		if q.giver_npc_id != npc_id:
			continue
		var qid := String(q.quest_id)
		if qid in completed_quests:
			continue
		if q.required_world_level > WorldStateManager.world_level:
			continue
		if not q.prerequisite_quest_id.is_empty() and not (String(q.prerequisite_quest_id) in completed_quests):
			continue
		out.append(q)
	return out


func can_turn_in(uuid: String, quest_id: String) -> bool:
	if not (quest_id in active_quests):
		return false
	var q := Catalog.get_quest(StringName(quest_id))
	if q == null or WorldStateManager.world_level < q.required_world_level:
		return false
	for req_id in q.required_items.keys():
		if EconomyManager.get_item_count(uuid, String(req_id)) < int(q.required_items[req_id]):
			return false
	return true


@rpc("any_peer", "call_local", "reliable")
func request_accept_quest(quest_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_accept_quest", quest_id)
		return
	if quest_id in active_quests or quest_id in completed_quests:
		return
	active_quests.append(quest_id)
	_sync_quests()


@rpc("any_peer", "call_local", "reliable")
func request_complete_quest(quest_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_complete_quest", quest_id)
		return
	var sender_id := 1 if not NetworkManager.is_network_active() else maxi(1, multiplayer.get_remote_sender_id())
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	if not can_turn_in(uuid, quest_id):
		WorldStateManager._notify_uuid(uuid, "Syarat barang atau World Level quest belum terpenuhi.", "warn")
		return
	var q := Catalog.get_quest(StringName(quest_id))
	for req_id in q.required_items.keys():
		EconomyManager.remove_item_from_player(uuid, String(req_id), int(q.required_items[req_id]))

	active_quests.erase(quest_id)
	completed_quests.append(quest_id)
	EconomyManager.add_coins(uuid, q.reward_coins)
	EconomyManager.add_npc_hearts(uuid, String(q.giver_npc_id), q.reward_hearts)
	WorldStateManager.add_world_xp(q.reward_world_xp)
	if q.reward_eco > 0:
		WorldStateManager.modify_eco_meter(q.reward_eco)
	if not q.unlocks_zone_id.is_empty():
		WorldStateManager.unlock_zone_immediate(String(q.unlocks_zone_id))

	WorldStateManager._notify_uuid(uuid, "Quest '%s' selesai! +%d Koin, +%d World EXP." % [q.title, q.reward_coins, q.reward_world_xp], "success")
	WorldStateManager._play_sfx_on_peer(sender_id, "sfx_lvl_up.wav")
	_sync_quests()


func _sync_quests() -> void:
	if NetworkManager.is_network_active():
		rpc("_client_sync_quests", active_quests, completed_quests)
	else:
		quests_updated.emit()


@rpc("authority", "call_local", "reliable")
func _client_sync_quests(act: Array, comp: Array) -> void:
	active_quests.assign(act)
	completed_quests.assign(comp)
	quests_updated.emit()


func serialize_state() -> Dictionary:
	return {
		"active_quests": active_quests,
		"completed_quests": completed_quests,
	}


func apply_snapshot(data: Dictionary) -> void:
	active_quests.assign(data.get("active_quests", ["q_panen_padi", "q_keripik_nisrina"]))
	completed_quests.assign(data.get("completed_quests", []))
	quests_updated.emit()
