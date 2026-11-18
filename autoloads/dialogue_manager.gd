extends Node
## Coordinates NPC dialogue UI, daily social points, gift giving, and market/festival triggers.

signal dialogue_opened(npc_id: String, text: String)
signal dialogue_closed

var active_npc_id: String = ""


func open_npc_dialogue(npc_id: String) -> void:
	var npc := Catalog.get_npc(StringName(npc_id))
	if npc == null:
		return
	active_npc_id = npc_id
	request_record_talk(npc_id)

	var line := ""
	if TimeManager.is_festival_active() and not npc.greetings_festival.is_empty():
		line = npc.greetings_festival
	elif TimeManager.weather == "hujan" and not npc.greetings_rain.is_empty():
		line = npc.greetings_rain[randi() % npc.greetings_rain.size()]
	elif not npc.greetings_day.is_empty():
		line = npc.greetings_day[randi() % npc.greetings_day.size()]

	if npc_id == "kades" and K3LHManager.is_eco_crisis:
		line = "PERHATIAN K3LH: Eco-Meter hutan kita turun di bawah 50 (%d)! Segera lakukan reboisasi atau bantu warga desa!" % WorldStateManager.eco_meter

	dialogue_opened.emit(npc_id, line)


func close_dialogue() -> void:
	active_npc_id = ""
	dialogue_closed.emit()


@rpc("any_peer", "call_local", "reliable")
func request_record_talk(npc_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_record_talk", npc_id)
		return
	var sender_id := 1 if not NetworkManager.is_network_active() else maxi(1, multiplayer.get_remote_sender_id())
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	var p := EconomyManager.get_player_dict(uuid)
	if p.is_empty():
		return
	var talked: Dictionary = p.get("daily_talked", {})
	if not talked.has(npc_id):
		talked[npc_id] = true
		p["daily_talked"] = talked
		EconomyManager.add_npc_hearts(uuid, npc_id, 20)


@rpc("any_peer", "call_local", "reliable")
func request_give_gift(npc_id: String, inv_idx: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_give_gift", npc_id, inv_idx)
		return
	var sender_id := 1 if not NetworkManager.is_network_active() else maxi(1, multiplayer.get_remote_sender_id())
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	var p := EconomyManager.get_player_dict(uuid)
	var npc := Catalog.get_npc(StringName(npc_id))
	if p.is_empty() or npc == null:
		return
	var gifted: Dictionary = p.get("daily_gifted", {})
	if gifted.has(npc_id):
		WorldStateManager._notify_uuid(uuid, "Hari ini sudah memberi hadiah ke %s." % npc.display_name, "info")
		return
	var slot := EconomyManager.get_inventory_slot(uuid, inv_idx)
	var item_id := str(slot.get("id", ""))
	var it := Catalog.get_item(StringName(item_id))
	if it == null or not it.is_giftable:
		WorldStateManager._notify_uuid(uuid, "Item ini tidak cocok dijadikan hadiah.", "warn")
		return
	if not EconomyManager.remove_item_from_player(uuid, item_id, 1):
		return

	gifted[npc_id] = true
	p["daily_gifted"] = gifted
	var pts := 20
	var msg := "%s menerima hadiahmu (+20 Hati)." % npc.display_name
	if StringName(item_id) in npc.liked_items:
		pts = 60
		msg = "%s sangat menyukai %s! (+60 Hati)" % [npc.display_name, it.display_name]
	elif StringName(item_id) in npc.disliked_items:
		pts = -10
		msg = "%s kurang menyukai hadiah ini (-10 Hati)." % npc.display_name
	EconomyManager.add_npc_hearts(uuid, npc_id, pts)
	WorldStateManager._notify_uuid(uuid, msg, "success" if pts > 0 else "warn")
	WorldStateManager._play_sfx_on_peer(sender_id, "sfx_heart_up.wav")
