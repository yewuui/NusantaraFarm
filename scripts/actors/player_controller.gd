class_name PlayerController
extends CharacterBody2D
## Unified player controller supporting Budi & Mitha, keyboard/mouse + mobile joystick, tools, and LAN sync.

const BASE_SPEED := 115.0
const SYNC_INTERVAL := 0.05

var peer_id: int = 1
var display_name: String = "Budi"
var avatar_id: String = "budi"
var facing_dir: Vector2 = Vector2.DOWN
var last_dir_name: String = "bawah"
var selected_hotbar_index: int = 0
var _map_bounds: Vector2 = Vector2(576, 384)
var _sync_timer: float = 0.0
var _net_target_pos: Vector2 = Vector2.ZERO
var _net_anim: String = "diam_bawah"
var _step_timer: float = 0.0
var _portal_cooldown: float = 0.0
var _nearby_interactable: Node = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D
@onready var tile_cursor: Sprite2D = $TileCursor
@onready var interact_area: Area2D = $InteractArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	MobileInput.use_pressed.connect(_on_mobile_use)
	MobileInput.interact_pressed.connect(_on_mobile_interact)


func setup_player(pid: int, p_name: String, av_id: String) -> void:
	peer_id = pid
	display_name = p_name
	avatar_id = av_id
	name_label.text = p_name
	_net_target_pos = global_position
	_build_sprite_frames(av_id)

	var is_local := (pid == NetworkManager.get_local_peer_id())
	camera.enabled = is_local
	tile_cursor.visible = is_local
	set_process_unhandled_input(is_local)


func set_zone_bounds(bounds: Vector2) -> void:
	_map_bounds = bounds
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.x)
	camera.limit_bottom = int(bounds.y)


func update_zone_visibility(same_zone: bool) -> void:
	visible = same_zone
	collision_shape.set_deferred("disabled", not same_zone)


func _physics_process(delta: float) -> void:
	if _portal_cooldown > 0.0:
		_portal_cooldown -= delta

	if peer_id != NetworkManager.get_local_peer_id():
		global_position = global_position.lerp(_net_target_pos, minf(1.0, delta * 14.0))
		_play_anim(_net_anim)
		return

	if _is_any_modal_open():
		velocity = Vector2.ZERO
		_play_anim("diam_" + last_dir_name)
		return

	var kb_vec := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var input_vec := (kb_vec + MobileInput.move_vector).limit_length(1.0)
	var spd := BASE_SPEED
	if EconomyManager.is_player_drowsy(GameManager.player_uuid):
		spd *= 0.75

	velocity = input_vec * spd
	if input_vec.length() > 0.05:
		facing_dir = input_vec
		last_dir_name = _dir_to_name(input_vec)
		_play_anim("jalan_" + last_dir_name)
		_step_timer += delta
		if _step_timer >= 0.32:
			_step_timer = 0.0
			AudioManager.play_sfx("sfx_step_grass.wav", 0.08)
	else:
		_play_anim("diam_" + last_dir_name)

	move_and_slide()
	global_position = global_position.clamp(Vector2(12, 16), _map_bounds - Vector2(12, 12))
	_update_tile_cursor()
	_refresh_nearby_interactable()

	if NetworkManager.is_network_active():
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			var cur_anim := String(sprite.animation)
			var wr := _get_world_root()
			var cur_zone: String = wr.current_zone_id if wr != null else "kebun"
			rpc("_rpc_sync_motion", global_position, cur_anim, cur_zone)


func _unhandled_input(event: InputEvent) -> void:
	if peer_id != NetworkManager.get_local_peer_id() or _is_any_modal_open():
		return
	if event.is_action_pressed("action_use"):
		perform_primary_action()
	elif event.is_action_pressed("action_interact"):
		perform_interact()


func perform_primary_action() -> void:
	var wr := _get_world_root()
	if wr == null or wr.current_zone == null:
		return

	var slot := EconomyManager.get_inventory_slot(GameManager.player_uuid, selected_hotbar_index)
	var held_id := str(slot.get("id", ""))

	# Check consumable quick use if clicking consumable in hotbar when not targeting farm/tree
	if not held_id.is_empty():
		var it := Catalog.get_item(StringName(held_id))
		if it != null and it.is_consumable:
			EconomyManager.request_consume_item(selected_hotbar_index)
			return

	# Check nearby EcoTree if in hutan
	if wr.current_zone_id == "hutan":
		var tree := _find_nearest_tree()
		if tree != null:
			WorldStateManager.request_tree_action(tree.tree_id, held_id)
			return

	# Check farm tile
	var target_tile := _get_target_tile_coords()
	if wr.current_zone.is_farmable_tile(target_tile):
		WorldStateManager.request_farm_action(wr.current_zone_id, target_tile, held_id)


func perform_interact() -> void:
	_refresh_nearby_interactable()
	if _nearby_interactable != null and _nearby_interactable.has_method("interact"):
		_nearby_interactable.interact(self)


func get_nearby_prompt() -> String:
	if _nearby_interactable != null and _nearby_interactable.has_method("get_prompt_text"):
		return _nearby_interactable.get_prompt_text()
	return ""


func can_enter_portal() -> bool:
	return _portal_cooldown <= 0.0


func mark_portal_used() -> void:
	_portal_cooldown = 0.65


func _on_mobile_use() -> void:
	if peer_id == NetworkManager.get_local_peer_id() and not _is_any_modal_open():
		perform_primary_action()


func _on_mobile_interact() -> void:
	if peer_id == NetworkManager.get_local_peer_id() and not _is_any_modal_open():
		perform_interact()


func _update_tile_cursor() -> void:
	var wr := _get_world_root()
	if wr == null or wr.current_zone == null:
		tile_cursor.visible = false
		return
	var coords := _get_target_tile_coords()
	var show_cursor := wr.current_zone.is_farmable_tile(coords)
	tile_cursor.visible = show_cursor
	if show_cursor:
		tile_cursor.global_position = Vector2(coords.x * 16 + 8, coords.y * 16 + 8)


func _get_target_tile_coords() -> Vector2i:
	if not bool(GameManager.settings.get("show_touch_controls", false)):
		var mpos := get_global_mouse_position()
		if mpos.distance_to(global_position) <= 28.0:
			return Vector2i(int(floor(mpos.x / 16.0)), int(floor(mpos.y / 16.0)))
	var step := _cardinal_vec(last_dir_name) * 16.0
	var p := global_position + step
	return Vector2i(int(floor(p.x / 16.0)), int(floor(p.y / 16.0)))


func _find_nearest_tree() -> Node:
	var best: Node = null
	var best_d := 34.0
	for a in interact_area.get_overlapping_areas():
		var owner_node := a.get_parent()
		if owner_node != null and owner_node.is_in_group("eco_tree"):
			var d := global_position.distance_to(owner_node.global_position)
			if d < best_d:
				best_d = d
				best = owner_node
	return best


func _refresh_nearby_interactable() -> void:
	var best: Node = null
	var best_d := 48.0
	for a in interact_area.get_overlapping_areas():
		var candidate: Node = a
		if not candidate.has_method("interact") and a.get_parent() != null and a.get_parent().has_method("interact"):
			candidate = a.get_parent()
		if candidate.has_method("interact"):
			var d := global_position.distance_to(a.global_position)
			if d < best_d:
				best_d = d
				best = candidate
	_nearby_interactable = best


func _dir_to_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "kanan" if v.x > 0.0 else "kiri"
	return "bawah" if v.y > 0.0 else "atas"


func _cardinal_vec(dname: String) -> Vector2:
	match dname:
		"atas": return Vector2.UP
		"kanan": return Vector2.RIGHT
		"kiri": return Vector2.LEFT
	return Vector2.DOWN


func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != StringName(anim_name):
			sprite.animation = StringName(anim_name)
		if not sprite.is_playing():
			sprite.play()


func _build_sprite_frames(av_id: String) -> void:
	var path := "res://assets/characters/%s_sheet.png" % ("mitha" if av_id == "mitha" else "budi")
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var sf := SpriteFrames.new()
	var rows := ["bawah", "atas", "kanan", "kiri"]
	for r in range(rows.size()):
		var dname: String = rows[r]
		var idle_name := "diam_" + dname
		sf.add_animation(idle_name)
		sf.set_animation_speed(idle_name, 2.0)
		var idle_at := AtlasTexture.new()
		idle_at.atlas = tex
		idle_at.region = Rect2(0, r * 32, 16, 32)
		sf.add_frame(idle_name, idle_at)

		var walk_name := "jalan_" + dname
		sf.add_animation(walk_name)
		sf.set_animation_speed(walk_name, 7.0)
		for f in range(4):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * 16, r * 32, 16, 32)
			sf.add_frame(walk_name, at)

	sprite.sprite_frames = sf
	sprite.offset = Vector2(0, -10)
	sprite.play("diam_bawah")


func _get_world_root() -> WorldRoot:
	return get_tree().get_first_node_in_group("world_root") as WorldRoot


func _is_any_modal_open() -> bool:
	var wr := _get_world_root()
	if wr == null:
		return false
	for m in [wr.inventory_ui, wr.production_ui, wr.market_ui, wr.dialogue_ui, wr.map_ui, wr.profile_ui, wr.settings_ui, wr.k3lh_modal]:
		if m != null and m.visible:
			return true
	return false


@rpc("any_peer", "unreliable_ordered")
func _rpc_sync_motion(pos: Vector2, anim: String, z_id: String) -> void:
	if peer_id == NetworkManager.get_local_peer_id() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_net_target_pos = pos
	_net_anim = anim
	var wr := _get_world_root()
	if wr != null:
		update_zone_visibility(z_id == wr.current_zone_id)
