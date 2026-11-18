extends Area2D
## Portal triggering zone transition when local player enters (respects zone unlock state).

@export var target_zone_id: String = "desa_pasar"
@export var target_spawn_marker: String = "FromKebun"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is PlayerController):
		return
	var pc := body as PlayerController
	if pc.peer_id != NetworkManager.get_local_peer_id() or not pc.can_enter_portal():
		return
	if not WorldStateManager.is_zone_unlocked(target_zone_id):
		var z := Catalog.get_zone(StringName(target_zone_id))
		var zname := z.display_name if z != null else target_zone_id
		GameManager.show_toast("%s masih terkunci! Periksa syarat di gerbang atau Quest." % zname, "warn")
		return
	pc.mark_portal_used()
	AudioManager.play_sfx("sfx_door.wav")
	var wr := get_tree().get_first_node_in_group("world_root") as WorldRoot
	if wr != null:
		wr.load_zone(target_zone_id, target_spawn_marker)
