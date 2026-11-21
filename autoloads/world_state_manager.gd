extends Node
## Server-authoritative World State: shared World Level/EXP, farm plots, forest trees & Eco-Meter, Joglo stations, unlocked zones, and shared chest.

signal world_level_up(new_level: int)
signal world_xp_changed(level: int, xp: int, needed: int)
signal eco_meter_changed(new_value: int)
signal plot_updated(zone_id: String, tile_key: String)
signal tree_updated(tree_id: String)
signal machine_updated(station_id: String)
signal zone_unlocked(zone_id: String)
signal chest_updated
signal world_state_reloaded

const MAX_CHEST_SLOTS := 20
## Development: semua zona dibuka dulu. Set ke false saat mau rilis/produksi.
const DEV_UNLOCK_ALL_ZONES := true
const DEFAULT_FOREST_POSITIONS := [
	Vector2(112, 112), Vector2(192, 96), Vector2(288, 112), Vector2(384, 96),
	Vector2(464, 128), Vector2(144, 240), Vector2(240, 272), Vector2(336, 256),
	Vector2(432, 272), Vector2(176, 320), Vector2(304, 320), Vector2(448, 320),
]

var world_level: int = 1
var world_xp: int = 0
var eco_meter: int = 80
var unlocked_zones: Dictionary = {}
var farm_plots: Dictionary = {}       # zone_id -> { "x,y": { soil, crop, days, mature, empty_days } }
var forest_trees: Dictionary = {}     # tree_id -> { state: "adult"|"stump"|"sapling", days: int, pos: [x,y] }
var active_machines: Dictionary = {}  # station_id -> { recipe_id, owner_uuid, hours_left, total_hours, done }
var shared_chest: Array = []          # Array of 20 { id, count }
var festival_claims: Dictionary = {}  # "y_d" -> { uuid: true }


func _ready() -> void:
	reset_new_world()


func reset_new_world() -> void:
	world_level = 1
	world_xp = 0
	eco_meter = 80
	unlocked_zones = {
		"kebun": true,
		"joglo_interior": true,
		"desa_pasar": true,
		"balai_desa": true,
		"hutan": false,
		"sawit": false,
		"pantai": false,
		"tambang": false,
	}
	if DEV_UNLOCK_ALL_ZONES:
		for zone_id in unlocked_zones.keys():
			unlocked_zones[zone_id] = true
	farm_plots = {
		"kebun": {},
		"sawit": {},
	}
	forest_trees.clear()
	for i in range(DEFAULT_FOREST_POSITIONS.size()):
		var p: Vector2 = DEFAULT_FOREST_POSITIONS[i]
		forest_trees["tree_%02d" % i] = {
			"state": "adult",
			"days": 0,
			"pos": [p.x, p.y],
		}
	active_machines.clear()
	shared_chest.clear()
	for _i in range(MAX_CHEST_SLOTS):
		shared_chest.append({"id": "", "count": 0})
	festival_claims.clear()
	K3LHManager.evaluate_eco_status(eco_meter)
	world_state_reloaded.emit()


func is_zone_unlocked(zone_id: String) -> bool:
	if DEV_UNLOCK_ALL_ZONES:
		return true
	return bool(unlocked_zones.get(zone_id, false))


func add_world_xp(amount: int) -> void:
	if amount <= 0 or not NetworkManager.is_host_or_offline():
		return
	world_xp += amount
	var needed := Catalog.get_xp_for_next_world_level(world_level)
	var leveled := false
	while world_xp >= needed:
		world_xp -= needed
		world_level += 1
		leveled = true
		needed = Catalog.get_xp_for_next_world_level(world_level)
	_broadcast_world_progress(leveled)


func modify_eco_meter(delta_eco: int) -> void:
	if not NetworkManager.is_host_or_offline():
		return
	eco_meter = clampi(eco_meter + delta_eco, 0, 100)
	K3LHManager.evaluate_eco_status(eco_meter)
	if NetworkManager.is_network_active():
		rpc("_client_sync_eco_meter", eco_meter)
	else:
		eco_meter_changed.emit(eco_meter)


func on_hour_passed() -> void:
	if not NetworkManager.is_host_or_offline():
		return
	for sid in active_machines.keys():
		var m: Dictionary = active_machines[sid]
		if bool(m.get("done", false)):
			continue
		m["hours_left"] = maxf(0.0, float(m.get("hours_left", 0.0)) - 1.0)
		if float(m["hours_left"]) <= 0.0:
			m["done"] = true
			var owner_uuid := str(m.get("owner_uuid", ""))
			_notify_uuid(owner_uuid, "Produk Joglo selesai dibuat!", "success")
		_sync_machine(sid, m)


func on_day_passed(weather: String) -> void:
	if not NetworkManager.is_host_or_offline():
		return
	var is_raining := (weather == "hujan")
	var season_name := TimeManager.season

	for zone_id in farm_plots.keys():
		var zdict: Dictionary = farm_plots[zone_id]
		var to_erase: Array[String] = []
		for key in zdict.keys():
			var plot: Dictionary = zdict[key]
			var crop_id := str(plot.get("crop", ""))
			var soil := int(plot.get("soil", 0))
			if not crop_id.is_empty():
				if soil == 2 or is_raining:
					var crop := Catalog.get_crop(StringName(crop_id))
					if crop != null:
						plot["days"] = int(plot.get("days", 0)) + 1
						var req_days := crop.grow_days_optimal if StringName(season_name) in crop.optimal_seasons else crop.grow_days_normal
						if int(plot["days"]) >= req_days:
							plot["mature"] = true
				plot["soil"] = 2 if is_raining else 1
				plot["empty_days"] = 0
			else:
				if soil == 1:
					plot["empty_days"] = int(plot.get("empty_days", 0)) + 1
					if int(plot["empty_days"]) >= 3:
						to_erase.append(key)
				elif soil == 2:
					plot["soil"] = 2 if is_raining else 1
		for k in to_erase:
			zdict.erase(k)

	# Grow forest saplings
	for tid in forest_trees.keys():
		var t: Dictionary = forest_trees[tid]
		if str(t.get("state", "")) == "sapling":
			t["days"] = int(t.get("days", 0)) + 1
			if int(t["days"]) >= 5:
				t["state"] = "adult"
				t["days"] = 0
				modify_eco_meter(4)

	if NetworkManager.is_network_active():
		rpc("_client_sync_farm_and_trees", farm_plots, forest_trees)
	else:
		world_state_reloaded.emit()


@rpc("any_peer", "call_local", "reliable")
func request_farm_action(zone_id: String, coords: Vector2i, tool_or_seed_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_farm_action", zone_id, coords, tool_or_seed_id)
		return
	var sender_id := _get_sender_peer_id()
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	if uuid.is_empty():
		return
	if not farm_plots.has(zone_id):
		return

	var key := "%d,%d" % [coords.x, coords.y]
	var zdict: Dictionary = farm_plots[zone_id]
	var plot: Dictionary = zdict.get(key, {"soil": 0, "crop": "", "days": 0, "mature": false, "empty_days": 0})
	var crop_id := str(plot.get("crop", ""))
	var is_mature := bool(plot.get("mature", false))

	# 1. Harvest if mature regardless of hand item (or with sabit/hand)
	if not crop_id.is_empty() and is_mature:
		if not EconomyManager.consume_stamina(uuid, 1.0, not Catalog.get_zone(StringName(zone_id)).is_indoor):
			_notify_uuid(uuid, "Stamina habis! Makan camilan atau istirahat di Joglo.", "warn")
			return
		var crop := Catalog.get_crop(StringName(crop_id))
		if crop != null:
			var panen_lv := EconomyManager.get_skill_level(uuid, "panen")
			var qty := randi_range(crop.min_yield, crop.max_yield)
			if randf() < float(panen_lv) * 0.04:
				qty += 1
			EconomyManager.add_item_to_player(uuid, String(crop.harvest_item_id), qty)
			EconomyManager.add_skill_xp(uuid, "panen", 10)
			add_world_xp(crop.harvest_xp)
			_notify_uuid(uuid, "Panen +%d %s!" % [qty, Catalog.get_item(crop.harvest_item_id).display_name], "success")
			if crop.is_regrowable:
				plot["mature"] = false
				plot["days"] = maxi(0, crop.grow_days_normal - crop.regrow_days)
			else:
				plot["crop"] = ""
				plot["days"] = 0
				plot["mature"] = false
			zdict[key] = plot
			_sync_plot(zone_id, key, plot)
			_play_sfx_on_peer(sender_id, "sfx_harvest.wav")
		return

	# 2. Hoe empty ground
	if tool_or_seed_id == "cangkul":
		if int(plot.get("soil", 0)) == 0:
			var stam_cost := 2.0 * EconomyManager.get_skill_stamina_factor(uuid, "cangkul")
			if not EconomyManager.consume_stamina(uuid, stam_cost, true):
				_notify_uuid(uuid, "Stamina tidak cukup untuk mencangkul.", "warn")
				return
			plot["soil"] = 2 if TimeManager.weather == "hujan" else 1
			plot["empty_days"] = 0
			zdict[key] = plot
			EconomyManager.add_skill_xp(uuid, "cangkul", 8)
			_sync_plot(zone_id, key, plot)
			_play_sfx_on_peer(sender_id, "sfx_hoe.wav")
		return

	# 3. Water tilled ground
	if tool_or_seed_id == "gembor":
		if int(plot.get("soil", 0)) == 1:
			var stam_cost := 2.0 * EconomyManager.get_skill_stamina_factor(uuid, "siram")
			if not EconomyManager.consume_stamina(uuid, stam_cost, true):
				_notify_uuid(uuid, "Stamina tidak cukup untuk menyiram.", "warn")
				return
			plot["soil"] = 2
			zdict[key] = plot
			EconomyManager.add_skill_xp(uuid, "siram", 8)
			_sync_plot(zone_id, key, plot)
			_play_sfx_on_peer(sender_id, "sfx_water.wav")
		return

	# 4. Plant seed
	var seed_crop := Catalog.get_crop_by_seed(StringName(tool_or_seed_id))
	if seed_crop != null:
		if int(plot.get("soil", 0)) >= 1 and crop_id.is_empty():
			if EconomyManager.remove_item_from_player(uuid, tool_or_seed_id, 1):
				plot["crop"] = String(seed_crop.crop_id)
				plot["days"] = 0
				plot["mature"] = false
				plot["empty_days"] = 0
				zdict[key] = plot
				_sync_plot(zone_id, key, plot)
				_play_sfx_on_peer(sender_id, "sfx_seed.wav")
		elif int(plot.get("soil", 0)) == 0:
			_notify_uuid(uuid, "Cangkul tanah terlebih dahulu sebelum menanam!", "info")


@rpc("any_peer", "call_local", "reliable")
func request_tree_action(tree_id: String, tool_or_seed_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_tree_action", tree_id, tool_or_seed_id)
		return
	var sender_id := _get_sender_peer_id()
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	if uuid.is_empty() or not forest_trees.has(tree_id):
		return

	var t: Dictionary = forest_trees[tree_id]
	var state := str(t.get("state", "adult"))

	if tool_or_seed_id == "kapak" and state == "adult":
		if not EconomyManager.consume_stamina(uuid, 5.0, true):
			_notify_uuid(uuid, "Stamina habis!", "warn")
			return
		t["state"] = "stump"
		t["days"] = 0
		EconomyManager.add_item_to_player(uuid, "kayu", 3)
		EconomyManager.add_item_to_player(uuid, "bibit_pohon", 1)
		modify_eco_meter(-8)
		_notify_uuid(uuid, "Dapat +3 Kayu & +1 Bibit Pohon. Eco-Meter -8 (tanam ulang bibit!).", "info")
		_sync_tree(tree_id, t)
		_play_sfx_on_peer(sender_id, "sfx_tree_fall.wav")
		return

	if tool_or_seed_id == "bibit_pohon" and state == "stump":
		if EconomyManager.remove_item_from_player(uuid, "bibit_pohon", 1):
			t["state"] = "sapling"
			t["days"] = 0
			modify_eco_meter(6)
			add_world_xp(8)
			_notify_uuid(uuid, "Reboisasi berhasil! Eco-Meter +6, World EXP +8.", "success")
			_sync_tree(tree_id, t)
			_play_sfx_on_peer(sender_id, "sfx_seed.wav")


@rpc("any_peer", "call_local", "reliable")
func request_start_craft(station_id: String, recipe_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_start_craft", station_id, recipe_id)
		return
	var sender_id := _get_sender_peer_id()
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	if uuid.is_empty():
		return
	if active_machines.has(station_id):
		_notify_uuid(uuid, "Stasiun sedang digunakan!", "warn")
		return
	var recipe := Catalog.get_recipe(StringName(recipe_id))
	if recipe == null or recipe.required_world_level > world_level:
		_notify_uuid(uuid, "Resep belum terbuka untuk World Level saat ini.", "warn")
		return
	for ing_id in recipe.ingredients.keys():
		if EconomyManager.get_item_count(uuid, String(ing_id)) < int(recipe.ingredients[ing_id]):
			_notify_uuid(uuid, "Bahan belum lengkap!", "warn")
			return
	for ing_id in recipe.ingredients.keys():
		EconomyManager.remove_item_from_player(uuid, String(ing_id), int(recipe.ingredients[ing_id]))

	var prod_lv := EconomyManager.get_skill_level(uuid, "produksi")
	var speed_mult := maxf(0.5, 1.0 - float(prod_lv - 1) * 0.04)
	var hours := maxf(0.5, recipe.process_hours * speed_mult)
	var entry := {
		"recipe_id": recipe_id,
		"owner_uuid": uuid,
		"hours_left": hours,
		"total_hours": hours,
		"done": false,
	}
	active_machines[station_id] = entry
	_sync_machine(station_id, entry)
	_play_sfx_on_peer(sender_id, "sfx_craft_start.wav")


@rpc("any_peer", "call_local", "reliable")
func request_collect_craft(station_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_collect_craft", station_id)
		return
	var sender_id := _get_sender_peer_id()
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	if uuid.is_empty() or not active_machines.has(station_id):
		return
	var entry: Dictionary = active_machines[station_id]
	if not bool(entry.get("done", false)):
		return
	var recipe := Catalog.get_recipe(StringName(str(entry.get("recipe_id", ""))))
	if recipe == null:
		return
	var out_qty := recipe.output_amount
	if EconomyManager.get_skill_level(uuid, "produksi") >= 5 and randf() < 0.10:
		out_qty += 1
	if not EconomyManager.add_item_to_player(uuid, String(recipe.output_item_id), out_qty):
		_notify_uuid(uuid, "Tas Pinggang penuh! Kosongkan slot sebelum mengambil hasil olahan.", "warn")
		return
	EconomyManager.add_skill_xp(uuid, "produksi", 12)
	add_world_xp(recipe.craft_xp)
	active_machines.erase(station_id)
	_sync_machine(station_id, {})
	_notify_uuid(uuid, "Selesai mengolah +%d %s!" % [out_qty, Catalog.get_item(recipe.output_item_id).display_name], "success")
	_play_sfx_on_peer(sender_id, "sfx_craft_done.wav")


@rpc("any_peer", "call_local", "reliable")
func request_unlock_zone(zone_id: String) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_unlock_zone", zone_id)
		return
	var sender_id := _get_sender_peer_id()
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	var zdata := Catalog.get_zone(StringName(zone_id))
	if zdata == null or is_zone_unlocked(zone_id):
		return
	if world_level < zdata.required_world_level:
		_notify_uuid(uuid, "Butuh World Level %d untuk membuka %s." % [zdata.required_world_level, zdata.display_name], "warn")
		return
	if zdata.unlock_cost_coins > 0 and EconomyManager.get_coins(uuid) < zdata.unlock_cost_coins:
		_notify_uuid(uuid, "Butuh %d Koin untuk perbaikan akses." % zdata.unlock_cost_coins, "warn")
		return
	if zdata.unlock_cost_wood > 0 and EconomyManager.get_item_count(uuid, "kayu") < zdata.unlock_cost_wood:
		_notify_uuid(uuid, "Butuh %d Kayu Tropis untuk perbaikan akses." % zdata.unlock_cost_wood, "warn")
		return

	if zdata.unlock_cost_coins > 0:
		EconomyManager.add_coins(uuid, -zdata.unlock_cost_coins)
	if zdata.unlock_cost_wood > 0:
		EconomyManager.remove_item_from_player(uuid, "kayu", zdata.unlock_cost_wood)

	unlock_zone_immediate(zone_id)


func unlock_zone_immediate(zone_id: String) -> void:
	if is_zone_unlocked(zone_id):
		return
	unlocked_zones[zone_id] = true
	if NetworkManager.is_network_active():
		rpc("_client_zone_unlocked", zone_id)
	else:
		zone_unlocked.emit(zone_id)
	SaveManager.save_all()


@rpc("any_peer", "call_local", "reliable")
func request_chest_deposit(inv_idx: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_chest_deposit", inv_idx)
		return
	var uuid := NetworkManager.get_uuid_for_peer(_get_sender_peer_id())
	var slot := EconomyManager.get_inventory_slot(uuid, inv_idx)
	if slot.is_empty() or str(slot.get("id", "")) == "":
		return
	var item_id := str(slot["id"])
	var it := Catalog.get_item(StringName(item_id))
	if it != null and it.category == ItemData.Category.TOOL:
		_notify_uuid(uuid, "Alat kerja pribadi tidak bisa disimpan di peti bersama.", "info")
		return
	var count := int(slot["count"])
	if _add_to_chest(item_id, count):
		EconomyManager.clear_inventory_slot(uuid, inv_idx)
		_sync_chest()
	else:
		_notify_uuid(uuid, "Peti bersama penuh!", "warn")


@rpc("any_peer", "call_local", "reliable")
func request_chest_withdraw(chest_idx: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_chest_withdraw", chest_idx)
		return
	var uuid := NetworkManager.get_uuid_for_peer(_get_sender_peer_id())
	if chest_idx < 0 or chest_idx >= shared_chest.size():
		return
	var cslot: Dictionary = shared_chest[chest_idx]
	var item_id := str(cslot.get("id", ""))
	var count := int(cslot.get("count", 0))
	if item_id.is_empty() or count <= 0:
		return
	if EconomyManager.add_item_to_player(uuid, item_id, count):
		shared_chest[chest_idx] = {"id": "", "count": 0}
		_sync_chest()
	else:
		_notify_uuid(uuid, "Tas Pinggang penuh! Kosongkan slot terlebih dahulu.", "warn")


@rpc("any_peer", "call_local", "reliable")
func request_festival_submit(inv_idx: int) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_festival_submit", inv_idx)
		return
	var sender_id := _get_sender_peer_id()
	var uuid := NetworkManager.get_uuid_for_peer(sender_id)
	if not TimeManager.is_festival_active():
		return
	var dkey := "%d_%d" % [TimeManager.year, TimeManager.day]
	var day_map: Dictionary = festival_claims.get(dkey, {})
	if day_map.has(uuid):
		_notify_uuid(uuid, "Kamu sudah berpartisipasi pada Festival Panen hari ini!", "info")
		return
	var slot := EconomyManager.get_inventory_slot(uuid, inv_idx)
	var item_id := str(slot.get("id", ""))
	var it := Catalog.get_item(StringName(item_id))
	if it == null or it.category == ItemData.Category.TOOL or it.category == ItemData.Category.SEED:
		_notify_uuid(uuid, "Pilih hasil panen atau olahan Joglo untuk dipersembahkan di Tumpeng Festival.", "warn")
		return
	EconomyManager.remove_item_from_player(uuid, item_id, 1)
	day_map[uuid] = true
	festival_claims[dkey] = day_map
	var prize_coins := clampi(it.base_sell_price * 2 + 200, 200, 1000)
	EconomyManager.add_coins(uuid, prize_coins)
	add_world_xp(100)
	EconomyManager.add_all_npc_hearts(uuid, 50)
	_notify_uuid(uuid, "Festival Panen Raya! Hadiah +%d Koin, +100 World EXP & +50 Hati Warga!" % prize_coins, "success")
	_play_sfx_on_peer(sender_id, "sfx_lvl_up.wav")


func _add_to_chest(item_id: String, count: int) -> bool:
	# Ensure full amount can fit to avoid partial-add duplication/loss.
	var space := 0
	for s in shared_chest:
		if str(s["id"]) == item_id:
			space += maxi(0, 99 - int(s["count"]))
		elif str(s["id"]) == "":
			space += 99
		if space >= count:
			break
	if space < count:
		return false

	var remaining := count
	for s in shared_chest:
		if str(s["id"]) == item_id and int(s["count"]) < 99:
			var add := mini(99 - int(s["count"]), remaining)
			s["count"] = int(s["count"]) + add
			remaining -= add
			if remaining <= 0:
				return true
	for s in shared_chest:
		if str(s["id"]) == "":
			s["id"] = item_id
			s["count"] = remaining
			return true
	return false


func _get_sender_peer_id() -> int:
	if not NetworkManager.is_network_active():
		return 1
	var sid := multiplayer.get_remote_sender_id()
	return 1 if sid == 0 else sid


func _notify_uuid(uuid: String, msg: String, kind: String) -> void:
	if uuid == GameManager.player_uuid or not NetworkManager.is_network_active():
		GameManager.show_toast(msg, kind)
		return
	var pid: int = int(NetworkManager.peer_by_uuid.get(uuid, -1))
	if pid > 1:
		rpc_id(pid, "_client_toast", msg, kind)


func _play_sfx_on_peer(peer_id: int, sfx: String) -> void:
	if peer_id == NetworkManager.get_local_peer_id() or not NetworkManager.is_network_active():
		AudioManager.play_sfx(sfx, 0.05)
	elif peer_id > 1:
		rpc_id(peer_id, "_client_play_sfx", sfx)


func _broadcast_world_progress(leveled: bool) -> void:
	var needed := Catalog.get_xp_for_next_world_level(world_level)
	if NetworkManager.is_network_active():
		rpc("_client_sync_world_progress", world_level, world_xp, needed, leveled)
	else:
		world_xp_changed.emit(world_level, world_xp, needed)
		if leveled:
			world_level_up.emit(world_level)
			GameManager.show_toast("World Level naik ke Level %d!" % world_level, "success")
			AudioManager.play_sfx("sfx_lvl_up.wav")


func _sync_plot(zone_id: String, key: String, plot: Dictionary) -> void:
	if NetworkManager.is_network_active():
		rpc("_client_sync_plot", zone_id, key, plot)
	else:
		plot_updated.emit(zone_id, key)


func _sync_tree(tree_id: String, t: Dictionary) -> void:
	if NetworkManager.is_network_active():
		rpc("_client_sync_tree", tree_id, t)
	else:
		tree_updated.emit(tree_id)


func _sync_machine(station_id: String, entry: Dictionary) -> void:
	if NetworkManager.is_network_active():
		rpc("_client_sync_machine", station_id, entry)
	else:
		machine_updated.emit(station_id)


func _sync_chest() -> void:
	if NetworkManager.is_network_active():
		rpc("_client_sync_chest", shared_chest)
	else:
		chest_updated.emit()


@rpc("authority", "reliable")
func _client_toast(msg: String, kind: String) -> void:
	GameManager.show_toast(msg, kind)


@rpc("authority", "reliable")
func _client_play_sfx(sfx: String) -> void:
	AudioManager.play_sfx(sfx, 0.05)


@rpc("authority", "call_local", "reliable")
func _client_sync_world_progress(lv: int, xp: int, needed: int, leveled: bool) -> void:
	world_level = lv
	world_xp = xp
	world_xp_changed.emit(lv, xp, needed)
	if leveled:
		world_level_up.emit(lv)
		GameManager.show_toast("World Level naik ke Level %d!" % lv, "success")
		AudioManager.play_sfx("sfx_lvl_up.wav")


@rpc("authority", "call_local", "reliable")
func _client_sync_eco_meter(val: int) -> void:
	eco_meter = val
	K3LHManager.evaluate_eco_status(eco_meter)
	eco_meter_changed.emit(eco_meter)


@rpc("authority", "call_local", "reliable")
func _client_sync_plot(zone_id: String, key: String, plot: Dictionary) -> void:
	if not farm_plots.has(zone_id):
		farm_plots[zone_id] = {}
	farm_plots[zone_id][key] = plot
	plot_updated.emit(zone_id, key)


@rpc("authority", "call_local", "reliable")
func _client_sync_tree(tree_id: String, t: Dictionary) -> void:
	forest_trees[tree_id] = t
	tree_updated.emit(tree_id)


@rpc("authority", "call_local", "reliable")
func _client_sync_machine(station_id: String, entry: Dictionary) -> void:
	if entry.is_empty():
		active_machines.erase(station_id)
	else:
		active_machines[station_id] = entry
	machine_updated.emit(station_id)


@rpc("authority", "call_local", "reliable")
func _client_sync_chest(chest_data: Array) -> void:
	shared_chest = chest_data
	chest_updated.emit()


@rpc("authority", "call_local", "reliable")
func _client_zone_unlocked(zone_id: String) -> void:
	unlocked_zones[zone_id] = true
	zone_unlocked.emit(zone_id)
	var z := Catalog.get_zone(StringName(zone_id))
	if z != null:
		GameManager.show_toast("Zona baru terbuka: %s!" % z.display_name, "success")


@rpc("authority", "call_local", "reliable")
func _client_sync_farm_and_trees(plots_data: Dictionary, trees_data: Dictionary) -> void:
	farm_plots = plots_data
	forest_trees = trees_data
	world_state_reloaded.emit()


func serialize_state() -> Dictionary:
	return {
		"world_level": world_level,
		"world_xp": world_xp,
		"eco_meter": eco_meter,
		"unlocked_zones": unlocked_zones,
		"farm_plots": farm_plots,
		"forest_trees": forest_trees,
		"active_machines": active_machines,
		"shared_chest": shared_chest,
		"festival_claims": festival_claims,
	}


func apply_snapshot(data: Dictionary) -> void:
	world_level = int(data.get("world_level", 1))
	world_xp = int(data.get("world_xp", 0))
	eco_meter = int(data.get("eco_meter", 80))
	unlocked_zones = data.get("unlocked_zones", unlocked_zones)
	farm_plots = data.get("farm_plots", farm_plots)
	forest_trees = data.get("forest_trees", forest_trees)
	active_machines = data.get("active_machines", {})
	var chest_in: Variant = data.get("shared_chest", [])
	if chest_in is Array and not chest_in.is_empty():
		shared_chest = chest_in
	festival_claims = data.get("festival_claims", {})
	K3LHManager.evaluate_eco_status(eco_meter)
	world_state_reloaded.emit()
