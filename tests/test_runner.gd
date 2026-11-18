extends SceneTree
## Headless integration test suite verifying scenes, UI modals, farming, regrow, rain, Joglo crafting,
## Market consignment, K3LH, sleep consensus/drowsy, Festival, Save/Load, and LAN Host setup.

var _failures: Array[String] = []
var _passed: int = 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	await process_frame
	print("=== NUSANTARA FARM HEADLESS TEST SUITE ===")

	await _test_scenes_instantiate()
	await _test_world_root_modals_and_transitions()
	_test_world_and_farming_loop()
	_test_regrow_and_rain_autowater()
	_test_joglo_production_loop()
	_test_consignment_and_shipping_bin()
	_test_time_sleep_coop_consensus_and_drowsy()
	_test_k3lh_eco_meter_crisis_and_recovery()
	_test_quests_and_festival_submit()
	_test_save_and_load_roundtrip()
	_test_lan_host_setup_and_teardown()

	print("=== RESULT: %d passed, %d failed ===" % [_passed, _failures.size()])
	for f in _failures:
		printerr("FAIL: ", f)

	quit(1 if not _failures.is_empty() else 0)


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failures.append(label)
		printerr("  [X] ", label)


func _test_scenes_instantiate() -> void:
	var scenes := [
		"res://scenes/main/MainMenu.tscn",
		"res://scenes/main/CharacterSelect.tscn",
		"res://scenes/main/LanLobby.tscn",
		"res://scenes/main/WorldRoot.tscn",
		"res://scenes/zones/ZonaKebun.tscn",
		"res://scenes/interiors/JogloInterior.tscn",
		"res://scenes/zones/ZonaDesaPasar.tscn",
		"res://scenes/interiors/BalaiDesaInterior.tscn",
		"res://scenes/zones/ZonaHutan.tscn",
		"res://scenes/zones/ZonaSawit.tscn",
		"res://scenes/zones/ZonaPantai.tscn",
		"res://scenes/zones/ZonaTambang.tscn",
	]
	var gm := root.get_node("GameManager")
	var nm := root.get_node("NetworkManager")
	var em := root.get_node("EconomyManager")
	nm.setup_offline_authority()
	em.ensure_player_profile(gm.player_uuid, gm.player_name, gm.avatar_id)

	for path in scenes:
		var ps := load(path) as PackedScene
		_assert(ps != null, "Load PackedScene: " + path)
		if ps != null:
			var inst := ps.instantiate()
			_assert(inst != null, "Instantiate: " + path)
			root.add_child(inst)
			await process_frame
			inst.queue_free()
			await process_frame


func _test_world_root_modals_and_transitions() -> void:
	var gm := root.get_node("GameManager")
	var nm := root.get_node("NetworkManager")
	var em := root.get_node("EconomyManager")
	var dm := root.get_node("DialogueManager")
	nm.setup_offline_authority()
	em.ensure_player_profile(gm.player_uuid, "Budi", "budi")

	var ps := load("res://scenes/main/WorldRoot.tscn") as PackedScene
	_assert(ps != null, "Load WorldRoot for modal test")
	if ps == null:
		return
	var wr: Node = ps.instantiate()
	_assert(wr != null, "Instantiate WorldRoot for modal test")
	if wr == null:
		return
	root.add_child(wr)
	await process_frame

	_assert(wr.current_zone_id == "kebun", "WorldRoot loads default kebun zone")
	wr.load_zone("desa_pasar", "FromKebun")
	await process_frame
	_assert(wr.current_zone_id == "desa_pasar", "WorldRoot transitions cleanly to desa_pasar")

	wr.open_inventory_mode("bag")
	_assert(wr.inventory_ui.visible, "InventoryUI opens cleanly")
	wr.open_inventory_mode("chest")
	_assert(wr.inventory_ui.visible, "InventoryUI chest mode opens cleanly")
	wr.open_production_station("st_wajan_1", &"wajan_joglo", "Wajan")
	_assert(wr.production_ui.visible, "ProductionUI opens cleanly")
	wr.open_market()
	_assert(wr.market_ui.visible, "MarketUI opens cleanly")
	dm.open_npc_dialogue("pak_tani")
	_assert(wr.dialogue_ui.visible, "DialogueUI opens cleanly")
	wr.toggle_modal(wr.map_ui)
	_assert(wr.map_ui.visible, "MapUI opens cleanly")
	wr.toggle_modal(wr.profile_ui)
	_assert(wr.profile_ui.visible, "ProfileUI opens cleanly")
	wr.toggle_modal(wr.settings_ui)
	_assert(wr.settings_ui.visible, "SettingsUI opens cleanly")
	wr.close_all_modals()
	wr.k3lh_modal.open_reminder(60)
	_assert(wr.k3lh_modal.visible and paused, "K3LHModal pauses solo game and opens")
	wr.k3lh_modal._on_btn_continue_pressed()
	_assert(not wr.k3lh_modal.visible and not paused, "K3LHModal resumes cleanly")

	wr.queue_free()
	await process_frame


func _test_world_and_farming_loop() -> void:
	var gm := root.get_node("GameManager")
	var nm := root.get_node("NetworkManager")
	var tm := root.get_node("TimeManager")
	var wsm := root.get_node("WorldStateManager")
	var em := root.get_node("EconomyManager")

	nm.setup_offline_authority()
	tm.reset_new_world()
	wsm.reset_new_world()
	em.reset_all()
	em.ensure_player_profile(gm.player_uuid, "Budi", "budi")

	tm.day = 15
	tm.season = "penghujan"
	tm.weather = "cerah"

	var tile := Vector2i(8, 15)
	wsm.request_farm_action("kebun", tile, "cangkul")
	var plots_k: Dictionary = wsm.farm_plots["kebun"]
	_assert(plots_k.has("8,15") and int(plots_k["8,15"]["soil"]) == 1, "Hoe creates tilled dry soil")

	wsm.request_farm_action("kebun", tile, "benih_padi")
	_assert(str(plots_k["8,15"]["crop"]) == "padi_lokal", "Planting benih_padi sets crop_id")

	wsm.request_farm_action("kebun", tile, "gembor")
	_assert(int(plots_k["8,15"]["soil"]) == 2, "Watering marks soil wet")

	for _d in range(4):
		wsm.request_farm_action("kebun", tile, "gembor")
		tm.advance_day_by_sleep()

	_assert(bool(plots_k["8,15"]["mature"]), "Padi matures in 4 watered days during Penghujan")
	var before_padi: int = em.get_item_count(gm.player_uuid, "padi")
	wsm.request_farm_action("kebun", tile, "sabit")
	var after_padi: int = em.get_item_count(gm.player_uuid, "padi")
	_assert(after_padi > before_padi, "Harvesting mature Padi grants padi items")
	_assert(str(plots_k["8,15"]["crop"]) == "", "Single-harvest Padi clears plot after harvest")

	wsm.add_world_xp(50)
	_assert(wsm.world_level >= 2, "World Level advances to 2 at 50 EXP")


func _test_regrow_and_rain_autowater() -> void:
	var gm := root.get_node("GameManager")
	var tm := root.get_node("TimeManager")
	var wsm := root.get_node("WorldStateManager")
	var em := root.get_node("EconomyManager")

	var tile := Vector2i(10, 15)
	wsm.request_farm_action("kebun", tile, "cangkul")
	wsm.request_farm_action("kebun", tile, "benih_pisang")
	# Force rainy day pass without manual watering
	wsm.on_day_passed("hujan")
	var plot: Dictionary = wsm.farm_plots["kebun"]["10,15"]
	_assert(int(plot["days"]) == 1 and int(plot["soil"]) == 2, "Rainy weather grows crop & keeps soil wet automatically")

	# Grow to mature and harvest regrowable pisang
	plot["days"] = 6
	plot["mature"] = true
	var before_pisang: int = em.get_item_count(gm.player_uuid, "pisang")
	wsm.request_farm_action("kebun", tile, "sabit")
	_assert(em.get_item_count(gm.player_uuid, "pisang") > before_pisang, "Harvesting Pisang grants pisang")
	_assert(str(plot["crop"]) == "pisang_raja" and not bool(plot["mature"]), "Regrowable Pisang remains planted for regrowth")


func _test_joglo_production_loop() -> void:
	var gm := root.get_node("GameManager")
	var tm := root.get_node("TimeManager")
	var wsm := root.get_node("WorldStateManager")
	var em := root.get_node("EconomyManager")

	em.add_item_to_player(gm.player_uuid, "pisang", 10)
	em.add_item_to_player(gm.player_uuid, "minyak_dasar", 1)
	wsm.request_start_craft("st_wajan_1", "keripik_pisang")
	_assert(wsm.active_machines.has("st_wajan_1"), "Joglo production station starts recipe")

	tm.advance_minutes(120)
	_assert(bool(wsm.active_machines["st_wajan_1"]["done"]), "Keripik Pisang finishes after 2 hours")
	wsm.request_collect_craft("st_wajan_1")
	_assert(em.get_item_count(gm.player_uuid, "keripik_pisang") >= 1, "Collecting Joglo craft adds Keripik Pisang")


func _test_consignment_and_shipping_bin() -> void:
	var gm := root.get_node("GameManager")
	var tm := root.get_node("TimeManager")
	var wsm := root.get_node("WorldStateManager")
	var em := root.get_node("EconomyManager")

	wsm.eco_meter = 80
	var chips_before: int = em.get_item_count(gm.player_uuid, "keripik_pisang")
	_assert(chips_before >= 1, "Has keripik_pisang for consignment")
	var inv: Array = em.get_local_player()["inventory"]
	var chip_idx := -1
	for i in range(inv.size()):
		if str(inv[i]["id"]) == "keripik_pisang":
			chip_idx = i
			break
	var coins_before: int = em.get_coins(gm.player_uuid)
	em.request_consign_item(chip_idx, 1)
	var orders: Array = em.get_orders_for_player(gm.player_uuid)
	_assert(orders.size() == 1 and not bool(orders[0]["is_sold"]), "Consignment order created and pending")

	tm.advance_minutes(240)
	_assert(bool(em.get_orders_for_player(gm.player_uuid)[0]["is_sold"]), "Consignment sells after 4 in-game hours")
	em.request_claim_consignments()
	var coins_after: int = em.get_coins(gm.player_uuid)
	_assert(coins_after == coins_before + 600, "Consignment pays 125% (600) when Eco >= 75")

	em.add_item_to_player(gm.player_uuid, "cabai", 2)
	inv = em.get_local_player()["inventory"]
	var cabai_idx := -1
	for i in range(inv.size()):
		if str(inv[i]["id"]) == "cabai":
			cabai_idx = i
			break
	em.request_ship_item(cabai_idx, 2)
	var pre_ship_coins: int = em.get_coins(gm.player_uuid)
	tm.advance_day_by_sleep()
	_assert(em.get_coins(gm.player_uuid) == pre_ship_coins + 60, "Shipping bin settles 100% base price at 06:00")


func _test_time_sleep_coop_consensus_and_drowsy() -> void:
	var gm := root.get_node("GameManager")
	var nm := root.get_node("NetworkManager")
	var tm := root.get_node("TimeManager")
	var em := root.get_node("EconomyManager")

	tm.minute_of_day = 600 # 10:00
	_assert(not tm.can_sleep_now(), "Cannot sleep at 10:00 daytime")
	var day_before: int = tm.day
	tm.request_toggle_sleep(true)
	_assert(tm.day == day_before, "Daytime sleep request does not advance day")

	tm.minute_of_day = 1435 # 23:55
	tm.advance_minutes(5)   # crosses 00:00
	_assert(em.is_player_drowsy(gm.player_uuid), "Staying up past 00:00 triggers Debuff Mengantuk")

	em.add_item_to_player(gm.player_uuid, "kopi_seduh", 1)
	var inv: Array = em.get_local_player()["inventory"]
	for i in range(inv.size()):
		if str(inv[i]["id"]) == "kopi_seduh":
			em.request_consume_item(i)
			break
	_assert(not em.is_player_drowsy(gm.player_uuid), "Kopi Seduh clears Debuff Mengantuk")

	# Simulate 2-player consensus: 1/2 does NOT skip day, 2/2 DOES skip day
	nm.peer_profiles[2] = {"player_uuid": "guest_mock", "player_name": "Mitha", "avatar_id": "mitha"}
	tm.minute_of_day = 1200 # 20:00
	var d_before: int = tm.day
	tm.request_toggle_sleep(true)
	_assert(tm.day == d_before and tm.sleeping_peers.size() == 1, "1/2 sleep vote waits for teammate (Minecraft-style)")
	nm.peer_profiles.erase(2)
	tm.sleeping_peers.clear()

	# Solo 1/1 sleep advances day to 06:00
	tm.request_toggle_sleep(true)
	_assert(tm.day == d_before + 1 and tm.get_hour() == 6, "Night sleep skips to 06:00 next day when all online sleep")


func _test_k3lh_eco_meter_crisis_and_recovery() -> void:
	var gm := root.get_node("GameManager")
	var wsm := root.get_node("WorldStateManager")
	var em := root.get_node("EconomyManager")
	var k3 := root.get_node("K3LHManager")

	wsm.eco_meter = 80
	k3.evaluate_eco_status(80)
	_assert(not k3.is_eco_crisis, "Eco 80 is healthy")

	for i in range(4):
		em.restore_stamina(gm.player_uuid, 100.0, true)
		wsm.request_tree_action("tree_%02d" % i, "kapak")

	_assert(wsm.eco_meter == 48 and k3.is_eco_crisis, "Chopping 4 trees drops Eco-Meter to 48 and triggers crisis")

	wsm.request_tree_action("tree_00", "bibit_pohon")
	_assert(wsm.eco_meter == 54 and not k3.is_eco_crisis, "Replanting recovers Eco-Meter >= 50 and clears crisis")


func _test_quests_and_festival_submit() -> void:
	var gm := root.get_node("GameManager")
	var tm := root.get_node("TimeManager")
	var wsm := root.get_node("WorldStateManager")
	var em := root.get_node("EconomyManager")
	var qm := root.get_node("QuestManager")

	wsm.world_level = 2
	em.add_item_to_player(gm.player_uuid, "padi", 8)
	qm.request_complete_quest("q_panen_padi")
	_assert("q_panen_padi" in qm.completed_quests, "First farming quest completes")

	qm.request_accept_quest("q_buka_hutan")
	qm.request_complete_quest("q_buka_hutan")
	_assert(wsm.is_zone_unlocked("hutan"), "Completing q_buka_hutan unlocks Hutan Tropis")

	# Festival Panen Day 14 @ 10:00
	tm.day = 14
	tm.minute_of_day = 600
	_assert(tm.is_festival_active(), "Festival Panen active on Day 14 at 10:00")
	em.add_item_to_player(gm.player_uuid, "pisang", 1)
	var inv: Array = em.get_local_player()["inventory"]
	var p_idx := -1
	for i in range(inv.size()):
		if str(inv[i]["id"]) == "pisang":
			p_idx = i
			break
	var pre_fest_coins: int = em.get_coins(gm.player_uuid)
	wsm.request_festival_submit(p_idx)
	_assert(em.get_coins(gm.player_uuid) > pre_fest_coins, "Festival submission rewards coins & XP")


func _test_save_and_load_roundtrip() -> void:
	var gm := root.get_node("GameManager")
	var wsm := root.get_node("WorldStateManager")
	var em := root.get_node("EconomyManager")
	var sm := root.get_node("SaveManager")

	gm.active_world_id = "test_world_roundtrip"
	gm.active_world_name = "Kebun Uji"
	em.add_coins(gm.player_uuid, 333)
	var expected_coins: int = em.get_coins(gm.player_uuid)
	var expected_eco: int = wsm.eco_meter
	var ok_save: bool = sm.save_all()
	_assert(ok_save, "SaveManager.save_all succeeds")

	wsm.reset_new_world()
	em.reset_all()
	var ok_load: bool = sm.load_world("test_world_roundtrip")
	_assert(ok_load, "SaveManager.load_world succeeds")
	_assert(em.get_coins(gm.player_uuid) == expected_coins, "Loaded player coins match saved value")
	_assert(wsm.eco_meter == expected_eco, "Loaded Eco-Meter matches saved value")

	# Cleanup test save directory
	var base_abs := ProjectSettings.globalize_path("user://saves/test_world_roundtrip")
	_remove_dir_recursive(base_abs)
	gm.active_world_id = ""


func _remove_dir_recursive(path_abs: String) -> void:
	var d := DirAccess.open(path_abs)
	if d == null:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while not fn.is_empty():
		if fn != "." and fn != "..":
			var sub := path_abs.path_join(fn)
			if d.current_is_dir():
				_remove_dir_recursive(sub)
			else:
				DirAccess.remove_absolute(sub)
		fn = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(path_abs)


func _test_lan_host_setup_and_teardown() -> void:
	var nm := root.get_node("NetworkManager")
	var err: Error = nm.start_host(42429)
	_assert(err == OK and nm.is_network_active(), "ENet LAN Host starts cleanly on port 42429")
	nm.stop_network()
	_assert(not nm.is_network_active(), "Network stops cleanly without leak")
