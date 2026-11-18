class_name GameZone
extends Node2D
## Base controller for every outdoor and indoor zone scene.

@export var zone_id: StringName = &"kebun"

var farm_rect: Rect2i = Rect2i()
var map_pixel_size: Vector2 = Vector2(576, 384)
var _crop_sprites: Dictionary = {} # "x,y" -> Sprite2D
var _tree_nodes: Dictionary = {}   # tree_id -> Node2D
var _festival_node: Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var detail_layer: TileMapLayer = $DetailLayer
@onready var soil_layer: TileMapLayer = $FarmSoilLayer
@onready var ysort_root: Node2D = $YSortRoot
@onready var spawn_points: Node2D = $SpawnPoints


func _ready() -> void:
	var zdata := Catalog.get_zone(zone_id)
	if zdata != null:
		map_pixel_size = Vector2(zdata.grid_size) * 16.0
	farm_rect = ZoneTileBuilder.build_zone(String(zone_id), ground_layer, detail_layer, soil_layer)
	_populate_zone_objects()
	_refresh_all_plots()
	_refresh_festival_visibility()

	WorldStateManager.plot_updated.connect(_on_plot_updated)
	WorldStateManager.tree_updated.connect(_on_tree_updated)
	WorldStateManager.world_state_reloaded.connect(_on_world_reloaded)
	TimeManager.festival_state_changed.connect(_on_festival_changed)


func get_spawn_position(marker_name: String) -> Vector2:
	var m := spawn_points.get_node_or_null(marker_name) as Marker2D
	if m != null:
		return m.global_position
	var fallback := spawn_points.get_node_or_null("Default") as Marker2D
	if fallback != null:
		return fallback.global_position
	return map_pixel_size * 0.5


func is_farmable_tile(coords: Vector2i) -> bool:
	return farm_rect.size.x > 0 and farm_rect.has_point(coords)


func _populate_zone_objects() -> void:
	match String(zone_id):
		"kebun":
			_spawn_prop("res://assets/objects/joglo_house.png", Vector2(180, 92), true)
			_spawn_shipping_bin(Vector2(248, 124))
			_spawn_shared_chest(Vector2(120, 124))
		"joglo_interior":
			_spawn_bed(Vector2(256, 72))
			_spawn_station("st_wajan_1", &"wajan_joglo", "Wajan Keripik Pisang", Vector2(72, 72))
			_spawn_station("st_lesung_1", &"lesung", "Lesung & Penggiling", Vector2(128, 72))
			_spawn_station("st_dapur_1", &"dapur_joglo", "Dapur & Sangrai Joglo", Vector2(184, 72))
		"desa_pasar":
			_spawn_prop("res://assets/objects/balai_desa.png", Vector2(216, 76), true)
			_spawn_prop("res://assets/objects/pasar_stall.png", Vector2(360, 134), true)
			_spawn_prop("res://assets/objects/pasar_stall.png", Vector2(436, 134), true)
			_festival_node = _spawn_festival_stage(Vector2(288, 184))
		"hutan":
			_spawn_forest_trees()
		"sawit":
			_spawn_prop("res://assets/objects/pasar_stall.png", Vector2(288, 64), true)
		"tambang":
			_spawn_prop("res://assets/objects/zone_gate.png", Vector2(440, 176), false)

	_spawn_npcs_for_zone()


func _spawn_prop(tex_path: String, pos: Vector2, with_collider: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	if ResourceLoader.exists(tex_path):
		sp.texture = load(tex_path) as Texture2D
	sp.position = pos
	if with_collider and sp.texture != null:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var sz := sp.texture.get_size()
		rect.size = Vector2(sz.x * 0.85, sz.y * 0.45)
		col.shape = rect
		col.position = Vector2(0, sz.y * 0.2)
		body.add_child(col)
		sp.add_child(body)
	ysort_root.add_child(sp)
	return sp


func _spawn_shipping_bin(pos: Vector2) -> void:
	var scn := load("res://scenes/objects/ShippingBin.tscn") as PackedScene
	if scn != null:
		var inst := scn.instantiate()
		inst.position = pos
		ysort_root.add_child(inst)


func _spawn_shared_chest(pos: Vector2) -> void:
	var scn := load("res://scenes/objects/SharedChest.tscn") as PackedScene
	if scn != null:
		var inst := scn.instantiate()
		inst.position = pos
		ysort_root.add_child(inst)


func _spawn_bed(pos: Vector2) -> void:
	var scn := load("res://scenes/objects/Bed.tscn") as PackedScene
	if scn != null:
		var inst := scn.instantiate()
		inst.position = pos
		ysort_root.add_child(inst)


func _spawn_station(st_id: String, st_type: StringName, label_txt: String, pos: Vector2) -> void:
	var scn := load("res://scenes/objects/ProductionStation.tscn") as PackedScene
	if scn != null:
		var inst := scn.instantiate()
		inst.position = pos
		inst.station_id = st_id
		inst.station_type = st_type
		inst.station_title = label_txt
		ysort_root.add_child(inst)


func _spawn_festival_stage(pos: Vector2) -> Node2D:
	var scn := load("res://scenes/objects/FestivalStage.tscn") as PackedScene
	if scn != null:
		var inst := scn.instantiate() as Node2D
		inst.position = pos
		ysort_root.add_child(inst)
		return inst
	return null


func _spawn_forest_trees() -> void:
	var scn := load("res://scenes/objects/EcoTree.tscn") as PackedScene
	if scn == null:
		return
	for tid in WorldStateManager.forest_trees.keys():
		var t: Dictionary = WorldStateManager.forest_trees[tid]
		var arr: Array = t.get("pos", [200, 200])
		var inst := scn.instantiate()
		inst.tree_id = tid
		inst.position = Vector2(float(arr[0]), float(arr[1]))
		ysort_root.add_child(inst)
		_tree_nodes[tid] = inst


func _spawn_npcs_for_zone() -> void:
	var scn := load("res://scenes/actors/NPC.tscn") as PackedScene
	if scn == null:
		return
	for npc_any in Catalog.npcs.values():
		var npc := npc_any as NPCData
		if npc.default_zone == zone_id:
			var inst := scn.instantiate()
			inst.npc_id = npc.npc_id
			inst.position = npc.default_position
			ysort_root.add_child(inst)


func _refresh_all_plots() -> void:
	for sp in _crop_sprites.values():
		if is_instance_valid(sp):
			sp.queue_free()
	_crop_sprites.clear()
	soil_layer.clear()

	var zdict: Dictionary = WorldStateManager.farm_plots.get(String(zone_id), {})
	for key in zdict.keys():
		_apply_plot_visual(key, zdict[key])


func _on_plot_updated(upd_zone: String, tile_key: String) -> void:
	if upd_zone != String(zone_id):
		return
	var zdict: Dictionary = WorldStateManager.farm_plots.get(upd_zone, {})
	if zdict.has(tile_key):
		_apply_plot_visual(tile_key, zdict[tile_key])
	else:
		var coords := _parse_key(tile_key)
		soil_layer.erase_cell(coords)
		if _crop_sprites.has(tile_key):
			_crop_sprites[tile_key].queue_free()
			_crop_sprites.erase(tile_key)


func _apply_plot_visual(tile_key: String, plot: Dictionary) -> void:
	var coords := _parse_key(tile_key)
	var soil_state := int(plot.get("soil", 0))
	if soil_state == 1:
		soil_layer.set_cell(coords, 0, ZoneTileBuilder.T_TILLED_DRY)
	elif soil_state == 2:
		soil_layer.set_cell(coords, 0, ZoneTileBuilder.T_TILLED_WET)
	else:
		soil_layer.erase_cell(coords)

	var crop_id := str(plot.get("crop", ""))
	if crop_id.is_empty():
		if _crop_sprites.has(tile_key):
			_crop_sprites[tile_key].queue_free()
			_crop_sprites.erase(tile_key)
		return

	var crop := Catalog.get_crop(StringName(crop_id))
	if crop == null:
		return
	var sp: Sprite2D = _crop_sprites.get(tile_key, null)
	if sp == null:
		sp = Sprite2D.new()
		sp.position = Vector2(coords.x * 16 + 8, coords.y * 16 + 4)
		ysort_root.add_child(sp)
		_crop_sprites[tile_key] = sp

	var stage := 0
	if bool(plot.get("mature", false)):
		stage = 4
	else:
		var ratio := float(plot.get("days", 0)) / maxf(1.0, float(crop.grow_days_normal))
		stage = clampi(int(floor(ratio * 4.0)), 0, 3)
	sp.texture = Catalog.get_crop_stage_texture(crop.atlas_row, stage)


func _on_tree_updated(tree_id: String) -> void:
	if _tree_nodes.has(tree_id):
		_tree_nodes[tree_id].refresh_visual()


func _on_world_reloaded() -> void:
	_refresh_all_plots()
	for tid in _tree_nodes.keys():
		_tree_nodes[tid].refresh_visual()


func _on_festival_changed(_active: bool) -> void:
	_refresh_festival_visibility()


func _refresh_festival_visibility() -> void:
	if _festival_node != null:
		_festival_node.visible = TimeManager.is_festival_active()


func _parse_key(tile_key: String) -> Vector2i:
	var parts := tile_key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
