class_name WorldRoot
extends Node2D
## Root gameplay container managing active GameZone switching, peer avatar spawning, day/night lighting, and UI modals.

var current_zone_id: String = "kebun"
var current_zone: GameZone
var _player_nodes: Dictionary = {} # peer_id -> PlayerController
var _player_scene: PackedScene

@onready var zone_container: Node2D = $ZoneContainer
@onready var players_root: Node2D = $PlayersRoot
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var hud: CanvasLayer = $HUD
@onready var inventory_ui: CanvasLayer = $OverlayLayer/InventoryUI
@onready var production_ui: CanvasLayer = $OverlayLayer/ProductionUI
@onready var market_ui: CanvasLayer = $OverlayLayer/MarketUI
@onready var dialogue_ui: CanvasLayer = $OverlayLayer/DialogueUI
@onready var map_ui: CanvasLayer = $OverlayLayer/MapUI
@onready var profile_ui: CanvasLayer = $OverlayLayer/ProfileUI
@onready var settings_ui: CanvasLayer = $OverlayLayer/SettingsUI
@onready var k3lh_modal: CanvasLayer = $OverlayLayer/K3LHModal


func _ready() -> void:
	add_to_group("world_root")
	_player_scene = load("res://scenes/actors/Player.tscn") as PackedScene
	NetworkManager.peer_roster_changed.connect(_sync_players)
	TimeManager.minute_tick.connect(_on_minute_tick)
	DialogueManager.dialogue_opened.connect(_on_dialogue_opened)
	K3LHManager.break_reminder_triggered.connect(_on_k3lh_break_triggered)

	var local_p := EconomyManager.get_local_player()
	var start_zone := str(local_p.get("last_zone", "kebun"))
	var lp: Array = local_p.get("last_pos", [260.0, 210.0])
	load_zone(start_zone, "", Vector2(float(lp[0]), float(lp[1])))
	_sync_players()
	_update_ambient_lighting()
	_play_zone_bgm(start_zone)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_inventory"):
		toggle_modal(inventory_ui)
	elif event.is_action_pressed("ui_map"):
		toggle_modal(map_ui)
	elif event.is_action_pressed("ui_profile"):
		toggle_modal(profile_ui)
	elif event.is_action_pressed("ui_pause"):
		toggle_modal(settings_ui)


func load_zone(zone_id: String, spawn_marker: String = "", explicit_pos: Vector2 = Vector2(-1, -1)) -> void:
	var zdata := Catalog.get_zone(StringName(zone_id))
	if zdata == null or zdata.scene_path.is_empty():
		return
	var scn := load(zdata.scene_path) as PackedScene
	if scn == null:
		return

	if current_zone != null:
		current_zone.queue_free()
		current_zone = null

	current_zone_id = zone_id
	current_zone = scn.instantiate() as GameZone
	zone_container.add_child(current_zone)

	var spawn_pos := explicit_pos
	if spawn_pos.x < 0.0:
		spawn_pos = current_zone.get_spawn_position(spawn_marker)

	var local_pid := NetworkManager.get_local_peer_id()
	if _player_nodes.has(local_pid):
		var local_p: PlayerController = _player_nodes[local_pid]
		local_p.global_position = spawn_pos
		local_p.set_zone_bounds(current_zone.map_pixel_size)

	NetworkManager.request_set_player_zone(zone_id, spawn_pos)
	_sync_players()
	_update_ambient_lighting()
	_play_zone_bgm(zone_id)


func toggle_modal(target: CanvasLayer) -> void:
	var will_open := not target.visible
	close_all_modals()
	if will_open:
		AudioManager.play_sfx("sfx_ui_click.wav")
		if target.has_method("open_panel"):
			target.open_panel()
		else:
			target.visible = true


func close_all_modals() -> void:
	for m in [inventory_ui, production_ui, market_ui, dialogue_ui, map_ui, profile_ui, settings_ui]:
		if m != null:
			m.visible = false


func open_inventory_mode(mode_name: String) -> void:
	close_all_modals()
	inventory_ui.open_with_mode(mode_name)


func open_production_station(station_id: String, station_type: StringName, title: String) -> void:
	close_all_modals()
	production_ui.open_station(station_id, station_type, title)


func open_market() -> void:
	close_all_modals()
	market_ui.open_market()


func get_active_zone() -> GameZone:
	return current_zone


func _sync_players() -> void:
	var roster := NetworkManager.peer_profiles
	for existing_pid in _player_nodes.keys():
		if not roster.has(existing_pid):
			var node: Node = _player_nodes[existing_pid]
			if is_instance_valid(node):
				node.queue_free()
			_player_nodes.erase(existing_pid)

	for pid in roster.keys():
		var info: Dictionary = roster[pid]
		var pnode: PlayerController = _player_nodes.get(pid, null)
		if pnode == null and _player_scene != null:
			pnode = _player_scene.instantiate() as PlayerController
			pnode.name = "Player_%d" % int(pid)
			var pos_arr: Array = info.get("pos", [260.0, 210.0])
			pnode.global_position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
			players_root.add_child(pnode)
			pnode.setup_player(int(pid), str(info.get("player_name", "Petani")), str(info.get("avatar_id", "budi")))
			_player_nodes[pid] = pnode

		if pnode != null:
			var pzone := str(info.get("current_zone", "kebun"))
			pnode.update_zone_visibility(pzone == current_zone_id)
			if int(pid) == NetworkManager.get_local_peer_id() and current_zone != null:
				pnode.set_zone_bounds(current_zone.map_pixel_size)


func _on_minute_tick(_h: int, _m: int) -> void:
	_update_ambient_lighting()


func _update_ambient_lighting() -> void:
	var c := TimeManager.get_ambient_color()
	if current_zone != null:
		var zdata := Catalog.get_zone(current_zone.zone_id)
		if zdata != null and zdata.is_indoor:
			c = Color(1.0, 0.96, 0.90)
	if EconomyManager.is_player_drowsy(GameManager.player_uuid):
		c = c.darkened(0.24)
	canvas_modulate.color = c


func _play_zone_bgm(zone_id: String) -> void:
	if TimeManager.is_festival_active() and zone_id == "desa_pasar":
		AudioManager.play_bgm("bgm_festival.ogg")
		return
	if TimeManager.get_hour() >= 19 or TimeManager.get_hour() < 5:
		AudioManager.play_bgm("bgm_night.ogg")
		return
	match zone_id:
		"kebun", "joglo_interior":
			AudioManager.play_bgm("bgm_farm_day.ogg")
		"desa_pasar", "balai_desa":
			AudioManager.play_bgm("bgm_village_market.ogg")
		"hutan", "sawit":
			AudioManager.play_bgm("bgm_forest.ogg")
		"pantai":
			AudioManager.play_bgm("bgm_beach.ogg")
		"tambang":
			AudioManager.play_bgm("bgm_mine.ogg")


func _on_dialogue_opened(npc_id: String, text: String) -> void:
	close_all_modals()
	dialogue_ui.show_dialogue(npc_id, text)


func _on_k3lh_break_triggered(mins: int) -> void:
	k3lh_modal.open_reminder(mins)
