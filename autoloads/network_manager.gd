extends Node
## Host-authoritative ENet LAN multiplayer and UDP LAN world discovery (Minecraft-style).

signal lan_worlds_updated(worlds: Array)
signal peer_roster_changed
signal connection_succeeded
signal connection_failed(reason: String)
signal server_disconnected_notice

const GAME_PORT: int = 42421
const DISCOVERY_PORT: int = 42420
const MAX_REMOTE_CLIENTS: int = 3 # Host + up to 3 clients = 4 players total
const BROADCAST_INTERVAL: float = 1.5
const DISCOVERY_TIMEOUT: float = 5.0

var peer_profiles: Dictionary = {} # peer_id (int) -> { player_uuid, player_name, avatar_id, current_zone, pos }
var peer_by_uuid: Dictionary = {}  # player_uuid -> peer_id

var _udp_broadcaster: PacketPeerUDP
var _udp_listener: PacketPeerUDP
var _broadcast_timer: float = 0.0
var _is_hosting: bool = false
var _is_listening: bool = false
var _discovered_worlds: Dictionary = {} # ip -> { info + last_seen }


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _is_hosting and _udp_broadcaster != null:
		_broadcast_timer += delta
		if _broadcast_timer >= BROADCAST_INTERVAL:
			_broadcast_timer = 0.0
			_send_lan_beacon()

	if _is_listening and _udp_listener != null:
		_poll_lan_beacons()


func setup_offline_authority() -> void:
	stop_network()
	peer_profiles.clear()
	peer_by_uuid.clear()
	_register_peer_local(1, GameManager.get_local_profile_summary())


func is_host_or_offline() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func is_network_active() -> bool:
	return multiplayer.multiplayer_peer != null


func get_local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func get_local_uuid() -> String:
	return GameManager.player_uuid


func get_uuid_for_peer(peer_id: int) -> String:
	if peer_profiles.has(peer_id):
		return str(peer_profiles[peer_id].get("player_uuid", ""))
	if peer_id == 1:
		return GameManager.player_uuid
	return ""


func get_active_player_count() -> int:
	return maxi(peer_profiles.size(), 1)


func get_local_ip_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			out.append(ip)
	if out.is_empty():
		out.append("127.0.0.1")
	return out


func start_host(port: int = GAME_PORT) -> Error:
	stop_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_REMOTE_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_is_hosting = true
	peer_profiles.clear()
	peer_by_uuid.clear()
	_register_peer_local(1, GameManager.get_local_profile_summary())
	_start_udp_broadcaster()
	return OK


func join_host(ip: String, port: int = GAME_PORT) -> Error:
	stop_network()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func stop_network() -> void:
	_is_hosting = false
	if _udp_broadcaster != null:
		_udp_broadcaster.close()
		_udp_broadcaster = null
	stop_lan_discovery()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	peer_profiles.clear()
	peer_by_uuid.clear()


func start_lan_discovery() -> void:
	stop_lan_discovery()
	_discovered_worlds.clear()
	_udp_listener = PacketPeerUDP.new()
	var err := _udp_listener.bind(DISCOVERY_PORT)
	if err == OK:
		_is_listening = true
	else:
		_udp_listener = null
		_is_listening = false


func stop_lan_discovery() -> void:
	_is_listening = false
	if _udp_listener != null:
		_udp_listener.close()
		_udp_listener = null


func _start_udp_broadcaster() -> void:
	_udp_broadcaster = PacketPeerUDP.new()
	_udp_broadcaster.set_broadcast_enabled(true)
	_udp_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcast_timer = BROADCAST_INTERVAL


func _send_lan_beacon() -> void:
	if _udp_broadcaster == null:
		return
	var payload := {
		"game": "nusantara_farm",
		"world_name": GameManager.active_world_name,
		"host_name": GameManager.player_name,
		"world_level": WorldStateManager.world_level,
		"day": TimeManager.day,
		"season": TimeManager.season,
		"player_count": get_active_player_count(),
		"max_players": MAX_REMOTE_CLIENTS + 1,
		"port": GAME_PORT,
	}
	_udp_broadcaster.put_packet(JSON.stringify(payload).to_utf8_buffer())


func _poll_lan_beacons() -> void:
	var changed := false
	while _udp_listener.get_available_packet_count() > 0:
		var pkt := _udp_listener.get_packet()
		var sender_ip := _udp_listener.get_packet_ip()
		var parsed: Variant = JSON.parse_string(pkt.get_string_from_utf8())
		if parsed is Dictionary and parsed.get("game", "") == "nusantara_farm":
			parsed["ip"] = sender_ip
			parsed["last_seen"] = Time.get_unix_time_from_system()
			_discovered_worlds[sender_ip] = parsed
			changed = true

	var now := Time.get_unix_time_from_system()
	for ip in _discovered_worlds.keys():
		if now - float(_discovered_worlds[ip].get("last_seen", 0.0)) > DISCOVERY_TIMEOUT:
			_discovered_worlds.erase(ip)
			changed = true

	if changed:
		lan_worlds_updated.emit(_discovered_worlds.values())


func _on_peer_connected(_peer_id: int) -> void:
	# Wait for client handshake RPC containing player_uuid, player_name, avatar_id.
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host_or_offline():
		TimeManager.clear_sleep_vote(peer_id)
		var uuid := get_uuid_for_peer(peer_id)
		if not uuid.is_empty():
			peer_by_uuid.erase(uuid)
		peer_profiles.erase(peer_id)
		SaveManager.save_all()
		_broadcast_roster()


func _on_connected_to_server() -> void:
	rpc_id(1, "_server_register_client", GameManager.get_local_profile_summary())
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	stop_network()
	connection_failed.emit("Gagal terhubung ke Host. Periksa IP atau jaringan Wi-Fi/Hotspot.")


func _on_server_disconnected() -> void:
	stop_network()
	server_disconnected_notice.emit()
	GameManager.return_to_main_menu()


@rpc("any_peer", "reliable")
func _server_register_client(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var uuid := str(profile.get("player_uuid", ""))
	if uuid.is_empty():
		uuid = "guest_%d" % sender_id
		profile["player_uuid"] = uuid

	var pdata := EconomyManager.ensure_player_profile(
		uuid,
		str(profile.get("player_name", "Teman")),
		str(profile.get("avatar_id", "mitha"))
	)
	profile["current_zone"] = str(pdata.get("last_zone", "kebun"))
	profile["pos"] = pdata.get("last_pos", [260.0, 200.0])

	_register_peer_local(sender_id, profile)
	_broadcast_roster()

	# Send full world + time + quest + player profile snapshot to joining client
	rpc_id(sender_id, "_client_receive_initial_snapshot", {
		"world_name": GameManager.active_world_name,
		"time": TimeManager.serialize_state(),
		"world": WorldStateManager.serialize_state(),
		"quests": QuestManager.serialize_state(),
		"player": EconomyManager.get_player_dict(uuid),
		"roster": peer_profiles,
	})


@rpc("authority", "reliable")
func _client_receive_initial_snapshot(snapshot: Dictionary) -> void:
	GameManager.active_world_name = str(snapshot.get("world_name", "Desa Mabar"))
	TimeManager.apply_snapshot(snapshot.get("time", {}))
	WorldStateManager.apply_snapshot(snapshot.get("world", {}))
	QuestManager.apply_snapshot(snapshot.get("quests", {}))
	EconomyManager.apply_local_player_snapshot(snapshot.get("player", {}))
	peer_profiles = snapshot.get("roster", {})
	GameManager.enter_world_as_client()


func _register_peer_local(peer_id: int, profile: Dictionary) -> void:
	var copy := profile.duplicate(true)
	if not copy.has("current_zone"):
		copy["current_zone"] = "kebun"
	if not copy.has("pos"):
		copy["pos"] = [260.0, 200.0]
	peer_profiles[peer_id] = copy
	var uuid := str(copy.get("player_uuid", ""))
	if not uuid.is_empty():
		peer_by_uuid[uuid] = peer_id


func _broadcast_roster() -> void:
	if multiplayer.is_server() and is_network_active():
		rpc("_client_update_roster", peer_profiles)
	peer_roster_changed.emit()


@rpc("authority", "call_local", "reliable")
func _client_update_roster(roster: Dictionary) -> void:
	peer_profiles = roster
	peer_by_uuid.clear()
	for pid in peer_profiles.keys():
		var uuid := str(peer_profiles[pid].get("player_uuid", ""))
		if not uuid.is_empty():
			peer_by_uuid[uuid] = int(pid)
	peer_roster_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func request_set_player_zone(zone_id: String, spawn_pos: Vector2) -> void:
	if not is_host_or_offline():
		rpc_id(1, "request_set_player_zone", zone_id, spawn_pos)
		return
	var sender_id := multiplayer.get_remote_sender_id() if is_network_active() else 1
	if sender_id == 0:
		sender_id = 1
	if peer_profiles.has(sender_id):
		peer_profiles[sender_id]["current_zone"] = zone_id
		peer_profiles[sender_id]["pos"] = [spawn_pos.x, spawn_pos.y]
		var uuid := get_uuid_for_peer(sender_id)
		EconomyManager.set_player_location(uuid, zone_id, spawn_pos)
	if is_network_active():
		rpc("_client_player_zone_changed", sender_id, zone_id, spawn_pos)
	else:
		_client_player_zone_changed(sender_id, zone_id, spawn_pos)


@rpc("authority", "call_local", "reliable")
func _client_player_zone_changed(peer_id: int, zone_id: String, spawn_pos: Vector2) -> void:
	if peer_profiles.has(peer_id):
		peer_profiles[peer_id]["current_zone"] = zone_id
		peer_profiles[peer_id]["pos"] = [spawn_pos.x, spawn_pos.y]
	peer_roster_changed.emit()
