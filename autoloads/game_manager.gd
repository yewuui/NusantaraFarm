extends Node
## Manages player local profile (UUID, avatar choice, settings), input map setup, and high-level game flow.

signal settings_changed
signal toast_requested(message: String, kind: String)

const CLIENT_PROFILE_PATH := "user://client_profile.json"

enum SessionMode { SOLO, HOST, CLIENT }

var player_uuid: String = ""
var player_name: String = "Budi"
var avatar_id: String = "budi" # "budi" or "mitha"
var session_mode: SessionMode = SessionMode.SOLO
var active_world_id: String = ""
var active_world_name: String = "Desa Nusantara"

var settings: Dictionary = {
	"music_volume": 70.0,
	"sfx_volume": 90.0,
	"k3lh_enabled": true,
	"k3lh_minutes": 60,
	"show_touch_controls": false,
}


func _ready() -> void:
	_ensure_input_actions()
	_load_client_profile()
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		settings["show_touch_controls"] = true
	AudioManager.apply_volumes(settings["music_volume"], settings["sfx_volume"])


func _ensure_input_actions() -> void:
	var key_bindings := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"action_use": [KEY_SPACE],
		"action_interact": [KEY_E],
		"ui_inventory": [KEY_TAB, KEY_B],
		"ui_map": [KEY_M],
		"ui_profile": [KEY_P],
		"ui_pause": [KEY_ESCAPE],
		"hotbar_1": [KEY_1],
		"hotbar_2": [KEY_2],
		"hotbar_3": [KEY_3],
		"hotbar_4": [KEY_4],
		"hotbar_5": [KEY_5],
		"hotbar_6": [KEY_6],
	}
	for action_name in key_bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)
		for key_code in key_bindings[action_name]:
			if not _action_has_key(action_name, key_code):
				var ev := InputEventKey.new()
				ev.physical_keycode = key_code
				InputMap.action_add_event(action_name, ev)

	_add_mouse_button("action_use", MOUSE_BUTTON_LEFT)
	_add_mouse_button("action_interact", MOUSE_BUTTON_RIGHT)
	_add_mouse_wheel("hotbar_prev", MOUSE_BUTTON_WHEEL_UP)
	_add_mouse_wheel("hotbar_next", MOUSE_BUTTON_WHEEL_DOWN)


func _action_has_key(action_name: String, key_code: Key) -> bool:
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey and ev.physical_keycode == key_code:
			return true
	return false


func _add_mouse_button(action_name: String, button_idx: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventMouseButton and ev.button_index == button_idx:
			return
	var mev := InputEventMouseButton.new()
	mev.button_index = button_idx
	InputMap.action_add_event(action_name, mev)


func _add_mouse_wheel(action_name: String, button_idx: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)
	_add_mouse_button(action_name, button_idx)


func _load_client_profile() -> void:
	if FileAccess.file_exists(CLIENT_PROFILE_PATH):
		var f := FileAccess.open(CLIENT_PROFILE_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				player_uuid = str(parsed.get("player_uuid", ""))
				player_name = str(parsed.get("player_name", "Budi"))
				avatar_id = str(parsed.get("avatar_id", "budi"))
				var saved_settings: Variant = parsed.get("settings", {})
				if saved_settings is Dictionary:
					for k in saved_settings.keys():
						settings[k] = saved_settings[k]
	if player_uuid.is_empty():
		player_uuid = _generate_uuid()
		save_client_profile()


func save_client_profile() -> void:
	var payload := {
		"player_uuid": player_uuid,
		"player_name": player_name,
		"avatar_id": avatar_id,
		"settings": settings,
	}
	var f := FileAccess.open(CLIENT_PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))


func update_settings(new_settings: Dictionary) -> void:
	for k in new_settings.keys():
		settings[k] = new_settings[k]
	AudioManager.apply_volumes(settings["music_volume"], settings["sfx_volume"])
	save_client_profile()
	settings_changed.emit()


func set_local_identity(new_name: String, new_avatar: String) -> void:
	player_name = new_name.strip_edges() if not new_name.strip_edges().is_empty() else "Petani"
	avatar_id = "mitha" if new_avatar == "mitha" else "budi"
	save_client_profile()


func get_local_profile_summary() -> Dictionary:
	return {
		"player_uuid": player_uuid,
		"player_name": player_name,
		"avatar_id": avatar_id,
	}


func start_new_solo_world(world_name: String) -> void:
	session_mode = SessionMode.SOLO
	active_world_name = world_name.strip_edges() if not world_name.strip_edges().is_empty() else "Kebun Nusantara"
	active_world_id = _slugify(active_world_name) + "_" + str(Time.get_unix_time_from_system())
	NetworkManager.setup_offline_authority()
	_reset_world_for_new_game()
	EconomyManager.ensure_player_profile(player_uuid, player_name, avatar_id)
	SaveManager.save_all()
	_enter_world_scene()


func load_solo_world(world_id: String) -> bool:
	session_mode = SessionMode.SOLO
	NetworkManager.setup_offline_authority()
	if not SaveManager.load_world(world_id):
		return false
	active_world_id = world_id
	EconomyManager.ensure_player_profile(player_uuid, player_name, avatar_id)
	_enter_world_scene()
	return true


func start_host_world(world_id: String, world_name: String, is_new: bool) -> Error:
	session_mode = SessionMode.HOST
	if is_new:
		active_world_name = world_name.strip_edges() if not world_name.strip_edges().is_empty() else "Desa Mabar"
		active_world_id = _slugify(active_world_name) + "_" + str(Time.get_unix_time_from_system())
		_reset_world_for_new_game()
	else:
		if not SaveManager.load_world(world_id):
			return ERR_CANT_OPEN
		active_world_id = world_id

	var err := NetworkManager.start_host()
	if err != OK:
		return err
	EconomyManager.ensure_player_profile(player_uuid, player_name, avatar_id)
	SaveManager.save_all()
	_enter_world_scene()
	return OK


func join_lan_world(ip: String, port: int) -> Error:
	session_mode = SessionMode.CLIENT
	return NetworkManager.join_host(ip, port)


func enter_world_as_client() -> void:
	_enter_world_scene()


func return_to_main_menu() -> void:
	if NetworkManager.is_host_or_offline() and not active_world_id.is_empty():
		SaveManager.save_all()
	NetworkManager.stop_network()
	K3LHManager.stop_session_timer()
	TimeManager.set_running(false)
	active_world_id = ""
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func show_toast(msg: String, kind: String = "info") -> void:
	toast_requested.emit(msg, kind)


func _reset_world_for_new_game() -> void:
	TimeManager.reset_new_world()
	WorldStateManager.reset_new_world()
	EconomyManager.reset_all()
	QuestManager.reset_new_world()
	K3LHManager.reset_new_world()


func _enter_world_scene() -> void:
	K3LHManager.start_session_timer()
	TimeManager.set_running(true)
	get_tree().change_scene_to_file("res://scenes/main/WorldRoot.tscn")


func _slugify(text: String) -> String:
	var out := text.to_lower().replace(" ", "_")
	var clean := ""
	for i in range(out.length()):
		var ch := out[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			clean += ch
	return clean if not clean.is_empty() else "world"


func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "p_%d_%06x" % [int(Time.get_unix_time_from_system()), rng.randi_range(0, 0xFFFFFF)]
