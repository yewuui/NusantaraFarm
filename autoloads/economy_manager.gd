extends Node
## Manages per-player wallet, Tas Pinggang (inventory), Stamina, individual Skills, Market Consignments, and Shipping Bin.

signal local_profile_updated

const DEFAULT_INVENTORY_SIZE := 15
const MAX_CONSIGNMENT_SLOTS := 6

var players: Dictionary = {}            # uuid -> player dict
var consignment_orders: Array = []      # Array of { order_id, seller_uuid, item_id, amount, hours_left, payout, is_sold }
var shipping_bin: Array = []            # Array of { seller_uuid, item_id, amount, base_payout }
var _next_order_num: int = 1


func reset_all() -> void:
	players.clear()
	consignment_orders.clear()
	shipping_bin.clear()
	_next_order_num = 1


func ensure_player_profile(uuid: String, p_name: String, avatar: String) -> Dictionary:
	var created_or_changed := false
	if not players.has(uuid):
		created_or_changed = true
		var inv: Array = []
		for _i in range(DEFAULT_INVENTORY_SIZE):
			inv.append({"id": "", "count": 0})
		# Starter kit
		inv[0] = {"id": "gembor", "count": 1}
		inv[1] = {"id": "cangkul", "count": 1}
		inv[2] = {"id": "kapak", "count": 1}
		inv[3] = {"id": "sabit", "count": 1}
		inv[4] = {"id": "benih_padi", "count": 5}
		inv[5] = {"id": "benih_pisang", "count": 2}
		inv[6] = {"id": "bibit_pohon", "count": 2}

		players[uuid] = {
			"player_uuid": uuid,
			"player_name": p_name,
			"avatar_id": avatar,
			"coins": 150,
			"stamina": 100.0,
			"max_stamina": 100.0,
			"is_drowsy": false,
			"anti_drowsy_until": 0,
			"inventory_size": DEFAULT_INVENTORY_SIZE,
			"inventory": inv,
			"skills": {
				"cangkul": {"lv": 1, "xp": 0},
				"siram": {"lv": 1, "xp": 0},
				"panen": {"lv": 1, "xp": 0},
				"produksi": {"lv": 1, "xp": 0},
			},
			"npc_hearts": {
				"pak_tani": 0,
				"nisrina": 0,
				"kades": 0,
				"leon": 0,
				"bahri": 0,
			},
			"daily_talked": {},
			"daily_gifted": {},
			"last_zone": "kebun",
			"last_pos": [260.0, 210.0],
		}
	else:
		if str(players[uuid].get("player_name", "")) != p_name or str(players[uuid].get("avatar_id", "")) != avatar:
			players[uuid]["player_name"] = p_name
			players[uuid]["avatar_id"] = avatar
			created_or_changed = true
	if created_or_changed and uuid == GameManager.player_uuid:
		local_profile_updated.emit()
	return players[uuid]


func get_local_player() -> Dictionary:
	if players.has(GameManager.player_uuid):
		return players[GameManager.player_uuid]
	return ensure_player_profile(GameManager.player_uuid, GameManager.player_name, GameManager.avatar_id)


func get_player_dict(uuid: String) -> Dictionary:
	return players.get(uuid, {})


func get_coins(uuid: String) -> int:
	return int(players.get(uuid, {}).get("coins", 0))


func add_coins(uuid: String, delta: int) -> void:
	if not players.has(uuid):
		return
	players[uuid]["coins"] = maxi(0, int(players[uuid]["coins"]) + delta)
	_sync_player_to_owner(uuid)


func get_stamina_ratio(uuid: String) -> float:
	var p: Dictionary = players.get(uuid, {})
	if p.is_empty():
		return 1.0
	return clampf(float(p["stamina"]) / maxf(1.0, float(p["max_stamina"])), 0.0, 1.0)


func is_player_drowsy(uuid: String) -> bool:
	return bool(players.get(uuid, {}).get("is_drowsy", false))


func consume_stamina(uuid: String, base_cost: float, is_outdoor: bool) -> bool:
	if not players.has(uuid):
		return false
	var mult := 1.0
	if bool(players[uuid].get("is_drowsy", false)):
		mult += 0.25
	if is_outdoor and K3LHManager.is_eco_crisis:
		mult += 0.30
	var cost := base_cost * mult
	if float(players[uuid]["stamina"]) < cost:
		return false
	players[uuid]["stamina"] = maxf(0.0, float(players[uuid]["stamina"]) - cost)
	_sync_player_to_owner(uuid)
	return true


func restore_stamina(uuid: String, amount: float, cure_drowsy: bool = false) -> void:
	if not players.has(uuid):
		return
	players[uuid]["stamina"] = minf(float(players[uuid]["max_stamina"]), float(players[uuid]["stamina"]) + amount)
	if cure_drowsy:
		players[uuid]["is_drowsy"] = false
	_sync_player_to_owner(uuid)


func evaluate_midnight_drowsy(uuid: String, total_minutes: int) -> void:
	if not players.has(uuid):
		return
	if total_minutes > int(players[uuid].get("anti_drowsy_until", 0)):
		players[uuid]["is_drowsy"] = true
		_sync_player_to_owner(uuid)


func get_skill_level(uuid: String, skill_id: String) -> int:
	return int(players.get(uuid, {}).get("skills", {}).get(skill_id, {}).get("lv", 1))


func get_skill_stamina_factor(uuid: String, skill_id: String) -> float:
	var lv := get_skill_level(uuid, skill_id)
	return maxf(0.55, 1.0 - float(lv - 1) * 0.05)


func add_skill_xp(uuid: String, skill_id: String, xp: int) -> void:
	if not players.has(uuid):
		return
	var skills: Dictionary = players[uuid]["skills"]
	if not skills.has(skill_id):
		return
	var sk: Dictionary = skills[skill_id]
	var lv := int(sk["lv"])
	if lv >= 10:
		return
	sk["xp"] = int(sk["xp"]) + xp
	var needed := lv * 60
	if int(sk["xp"]) >= needed:
		sk["xp"] = int(sk["xp"]) - needed
		sk["lv"] = lv + 1
	_sync_player_to_owner(uuid)


func get_inventory_slot(uuid: String, idx: int) -> Dictionary:
	var inv: Array = players.get(uuid, {}).get("inventory", [])
	if idx < 0 or idx >= inv.size():
		return {}
	return inv[idx]


func clear_inventory_slot(uuid: String, idx: int) -> void:
	if not players.has(uuid):
		return
	var inv: Array = players[uuid]["inventory"]
	if idx >= 0 and idx < inv.size():
		inv[idx] = {"id": "", "count": 0}
		_sync_player_to_owner(uuid)


func get_item_count(uuid: String, item_id: String) -> int:
	var total := 0
	for slot in players.get(uuid, {}).get("inventory", []):
		if str(slot.get("id", "")) == item_id:
			total += int(slot.get("count", 0))
	return total


func add_item_to_player(uuid: String, item_id: String, count: int) -> bool:
	if not players.has(uuid) or count <= 0:
		return false
	var it := Catalog.get_item(StringName(item_id))
	var max_stack := it.max_stack if it != null else 99
	var inv: Array = players[uuid]["inventory"]
	var remaining := count

	for slot in inv:
		if str(slot["id"]) == item_id and int(slot["count"]) < max_stack:
			var add := mini(max_stack - int(slot["count"]), remaining)
			slot["count"] = int(slot["count"]) + add
			remaining -= add
			if remaining <= 0:
				_sync_player_to_owner(uuid)
				return true

	for slot in inv:
		if str(slot["id"]) == "":
			var add := mini(max_stack, remaining)
			slot["id"] = item_id
			slot["count"] = add
			remaining -= add
			if remaining <= 0:
				_sync_player_to_owner(uuid)
				return true

	_sync_player_to_owner(uuid)
	return remaining == 0


func remove_item_from_player(uuid: String, item_id: String, count: int) -> bool:
	if get_item_count(uuid, item_id) < count:
		return false
	var inv: Array = players[uuid]["inventory"]
	var remaining := count
	for slot in inv:
		if str(slot["id"]) == item_id:
			var take := mini(int(slot["count"]), remaining)
			slot["count"] = int(slot["count"]) - take
			remaining -= take
			if int(slot["count"]) <= 0:
				slot["id"] = ""
				slot["count"] = 0
			if remaining <= 0:
				break
	_sync_player_to_owner(uuid)
	return true


func add_npc_hearts(uuid: String, npc_id: String, pts: int) -> void:
	if not players.has(uuid):
		return
	var hearts: Dictionary = players[uuid]["npc_hearts"]
	hearts[npc_id] = clampi(int(hearts.get(npc_id, 0)) + pts, 0, 1000)
	_sync_player_to_owner(uuid)


func add_all_npc_hearts(uuid: String, pts: int) -> void:
	if not players.has(uuid):
		return
	var hearts: Dictionary = players[uuid]["npc_hearts"]
	for nid in hearts.keys():
		hearts[nid] = clampi(int(hearts[nid]) + pts, 0, 1000)
	_sync_player_to_owner(uuid)


func set_player_location(uuid: String, zone_id: String, pos: Vector2) -> void:
	if players.has(uuid):
		players[uuid]["last_zone"] = zone_id
		players[uuid]["last_pos"] = [pos.x, pos.y]


func on_hour_passed() -> void:
	if not NetworkManager.is_host_or_offline():
		return
	var changed := false
	for ord in consignment_orders:
		if bool(ord.get("is_sold", false)):
			continue
		ord["hours_left"] = maxf(0.0, float(ord["hours_left"]) - 1.0)
		if float(ord["hours_left"]) <= 0.0:
			ord["is_sold"] = true
			changed = true
			var seller := str(ord["seller_uuid"])
			WorldStateManager._notify_uuid(seller, "Daganganmu di Pasar sudah laku! Temui Mas Leon/Pasar untuk ambil Koin.", "success")
			WorldStateManager._play_sfx_on_peer(int(NetworkManager.peer_by_uuid.get(seller, 1)), "sfx_consign_notif.wav")
	if changed or not consignment_orders.is_empty():
		_sync_consignments()


func on_day_passed(from_sleep: bool, eco_meter: int) -> void:
	if not NetworkManager.is_host_or_offline():
		return
	# Settle Shipping Bin
	var payouts_by_uuid: Dictionary = {}
	for entry in shipping_bin:
		var seller := str(entry["seller_uuid"])
		var val := int(entry["base_payout"])
		if eco_meter < 50:
			val = int(round(float(val) * 0.85))
		payouts_by_uuid[seller] = int(payouts_by_uuid.get(seller, 0)) + val
	shipping_bin.clear()

	for seller in payouts_by_uuid.keys():
		var earned := int(payouts_by_uuid[seller])
		add_coins(seller, earned)
		WorldStateManager.add_world_xp(10)
		WorldStateManager._notify_uuid(seller, "Peti Panen cair: +%d Koin!" % earned, "success")

	# Reset daily social flags + heal if slept + apply eco crisis heart decay
	for uuid in players.keys():
		var p: Dictionary = players[uuid]
		p["daily_talked"] = {}
		p["daily_gifted"] = {}
		if from_sleep:
			p["stamina"] = float(p["max_stamina"])
			p["is_drowsy"] = false
		if eco_meter < 50:
			var hearts: Dictionary = p["npc_hearts"]
			for nid in hearts.keys():
				hearts[nid] = maxi(0, int(hearts[nid]) - 15)
		_sync_player_to_owner(uuid)


@rpc("any_peer", "call_local", "reliable")
func request_buy_item(item_id: String, amount: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_buy_item", item_id, amount)
		return
	var uuid := NetworkManager.get_uuid_for_peer(_get_sender_peer_id())
	var it := Catalog.get_item(StringName(item_id))
	if it == null or amount <= 0 or it.base_buy_price <= 0:
		return
	var total_cost := it.base_buy_price * amount
	if get_coins(uuid) < total_cost:
		WorldStateManager._notify_uuid(uuid, "Koin tidak cukup!", "warn")
		return
	if add_item_to_player(uuid, item_id, amount):
		add_coins(uuid, -total_cost)
		WorldStateManager._notify_uuid(uuid, "Membeli %dx %s" % [amount, it.display_name], "success")
		WorldStateManager._play_sfx_on_peer(_get_sender_peer_id(), "sfx_coins.wav")


@rpc("any_peer", "call_local", "reliable")
func request_consign_item(inv_idx: int, amount: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_consign_item", inv_idx, amount)
		return
	var uuid := NetworkManager.get_uuid_for_peer(_get_sender_peer_id())
	var slot := get_inventory_slot(uuid, inv_idx)
	var item_id := str(slot.get("id", ""))
	var avail := int(slot.get("count", 0))
	if item_id.is_empty() or amount <= 0 or avail < amount:
		return
	var it := Catalog.get_item(StringName(item_id))
	if it == null or it.category == ItemData.Category.TOOL or it.base_sell_price <= 0:
		WorldStateManager._notify_uuid(uuid, "Barang ini tidak bisa dititip jual.", "warn")
		return
	if get_orders_for_player(uuid).size() >= MAX_CONSIGNMENT_SLOTS:
		WorldStateManager._notify_uuid(uuid, "Slot titip jual penuh! Ambil hasil penjualan dulu.", "warn")
		return
	if not remove_item_from_player(uuid, item_id, amount):
		return

	var eco := WorldStateManager.eco_meter
	var margin := 1.25 if eco >= 75 else 1.15
	var payout := int(round(float(it.base_sell_price * amount) * margin))
	var hours := 4.0 if it.category == ItemData.Category.PROCESSED else 3.0
	var order := {
		"order_id": "ord_%04d" % _next_order_num,
		"seller_uuid": uuid,
		"item_id": item_id,
		"amount": amount,
		"hours_left": hours,
		"payout": payout,
		"is_sold": false,
	}
	_next_order_num += 1
	consignment_orders.append(order)
	_sync_consignments()
	WorldStateManager._notify_uuid(uuid, "Dititipkan ke Pasar (%dx %s). Laku dalam %.0f jam in-game!" % [amount, it.display_name, hours], "info")


@rpc("any_peer", "call_local", "reliable")
func request_claim_consignments() -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_claim_consignments")
		return
	var sender_id := _get_sender_peer_id()
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	var total_coins := 0
	var remaining: Array = []
	var claimed_count := 0
	for ord in consignment_orders:
		if str(ord["seller_uuid"]) == uuid and bool(ord.get("is_sold", false)):
			var pay := int(ord["payout"])
			if WorldStateManager.eco_meter < 50:
				pay = int(round(float(pay) * 0.85))
			total_coins += pay
			claimed_count += 1
		else:
			remaining.append(ord)
	consignment_orders = remaining
	if claimed_count > 0:
		add_coins(uuid, total_coins)
		WorldStateManager.add_world_xp(10 * claimed_count)
		_sync_consignments()
		WorldStateManager._notify_uuid(uuid, "Hasil konsinyasi Pasar diambil: +%d Koin!" % total_coins, "success")
		WorldStateManager._play_sfx_on_peer(sender_id, "sfx_coins.wav")


@rpc("any_peer", "call_local", "reliable")
func request_ship_item(inv_idx: int, amount: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_ship_item", inv_idx, amount)
		return
	var uuid := NetworkManager.get_uuid_for_peer(_get_sender_peer_id())
	var slot := get_inventory_slot(uuid, inv_idx)
	var item_id := str(slot.get("id", ""))
	if item_id.is_empty() or amount <= 0 or int(slot.get("count", 0)) < amount:
		return
	var it := Catalog.get_item(StringName(item_id))
	if it == null or it.category == ItemData.Category.TOOL or it.base_sell_price <= 0:
		WorldStateManager._notify_uuid(uuid, "Barang ini tidak bisa masuk Peti Panen.", "warn")
		return
	if remove_item_from_player(uuid, item_id, amount):
		shipping_bin.append({
			"seller_uuid": uuid,
			"item_id": item_id,
			"amount": amount,
			"base_payout": it.base_sell_price * amount,
		})
		WorldStateManager._notify_uuid(uuid, "%dx %s dimasukkan ke Peti Panen (cair jam 06:00)." % [amount, it.display_name], "info")


@rpc("any_peer", "call_local", "reliable")
func request_consume_item(inv_idx: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_consume_item", inv_idx)
		return
	var uuid := NetworkManager.get_uuid_for_peer(_get_sender_peer_id())
	var slot := get_inventory_slot(uuid, inv_idx)
	var item_id := str(slot.get("id", ""))
	var it := Catalog.get_item(StringName(item_id))
	if it == null or not it.is_consumable:
		return
	if remove_item_from_player(uuid, item_id, 1):
		restore_stamina(uuid, float(it.energy_restore), false)
		if it.anti_drowsy_hours > 0.0:
			players[uuid]["is_drowsy"] = false
			players[uuid]["anti_drowsy_until"] = TimeManager.total_minutes_elapsed + int(it.anti_drowsy_hours * 60.0)
			_sync_player_to_owner(uuid)
			WorldStateManager._notify_uuid(uuid, "Minum %s! Stamina +%d & tahan kantuk %.0f jam!" % [it.display_name, it.energy_restore, it.anti_drowsy_hours], "success")
		else:
			WorldStateManager._notify_uuid(uuid, "Makan %s! Stamina +%d." % [it.display_name, it.energy_restore], "success")


@rpc("any_peer", "call_local", "reliable")
func request_swap_inventory_slots(idx_a: int, idx_b: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_swap_inventory_slots", idx_a, idx_b)
		return
	var uuid := NetworkManager.get_uuid_for_peer(_get_sender_peer_id())
	if not players.has(uuid):
		return
	var inv: Array = players[uuid]["inventory"]
	if idx_a < 0 or idx_b < 0 or idx_a >= inv.size() or idx_b >= inv.size():
		return
	var tmp: Dictionary = inv[idx_a]
	inv[idx_a] = inv[idx_b]
	inv[idx_b] = tmp
	_sync_player_to_owner(uuid)


func get_orders_for_player(uuid: String) -> Array:
	var out: Array = []
	for ord in consignment_orders:
		if str(ord["seller_uuid"]) == uuid:
			out.append(ord)
	return out


func _get_sender_peer_id() -> int:
	if not NetworkManager.is_network_active():
		return 1
	var sid := multiplayer.get_remote_sender_id()
	return 1 if sid == 0 else sid


func _sync_player_to_owner(uuid: String) -> void:
	if uuid == GameManager.player_uuid:
		local_profile_updated.emit()
		return
	if NetworkManager.is_network_active():
		var pid: int = int(NetworkManager.peer_by_uuid.get(uuid, -1))
		if pid > 1:
			rpc_id(pid, "_client_receive_player_profile", players[uuid])


func _sync_consignments() -> void:
	if NetworkManager.is_network_active():
		rpc("_client_receive_consignments", consignment_orders)
	local_profile_updated.emit()


@rpc("authority", "reliable")
func _client_receive_player_profile(profile_dict: Dictionary) -> void:
	apply_local_player_snapshot(profile_dict)


@rpc("authority", "reliable")
func _client_receive_consignments(orders: Array) -> void:
	consignment_orders = orders
	local_profile_updated.emit()


func apply_local_player_snapshot(profile_dict: Dictionary) -> void:
	var uuid := str(profile_dict.get("player_uuid", GameManager.player_uuid))
	players[uuid] = profile_dict
	if uuid == GameManager.player_uuid:
		local_profile_updated.emit()


func serialize_world_economy() -> Dictionary:
	return {
		"consignment_orders": consignment_orders,
		"shipping_bin": shipping_bin,
		"next_order_num": _next_order_num,
	}


func apply_world_economy(data: Dictionary) -> void:
	consignment_orders = data.get("consignment_orders", [])
	shipping_bin = data.get("shipping_bin", [])
	_next_order_num = int(data.get("next_order_num", 1))
