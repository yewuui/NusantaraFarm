extends Control
## Minecraft-style LAN/Hotspot Lobby: Host a world with local IP display or Join discovered/IP worlds.

@onready var name_edit: LineEdit = $Panel/VBox/TopIdentity/NameEdit
@onready var avatar_btn: Button = $Panel/VBox/TopIdentity/BtnAvatar
@onready var host_world_edit: LineEdit = $Panel/VBox/Columns/HostBox/HostWorldEdit
@onready var saved_list: VBoxContainer = $Panel/VBox/Columns/HostBox/SavedScroll/SavedList
@onready var ip_label: Label = $Panel/VBox/Columns/HostBox/IpLabel
@onready var lan_list: VBoxContainer = $Panel/VBox/Columns/JoinBox/LanScroll/LanList
@onready var manual_ip_edit: LineEdit = $Panel/VBox/Columns/JoinBox/ManualRow/IpEdit
@onready var status_label: Label = $Panel/VBox/StatusLabel

var _avatar: String = "budi"


func _ready() -> void:
	theme = UIThemeHelper.get_theme()
	_avatar = GameManager.avatar_id
	name_edit.text = GameManager.player_name
	host_world_edit.text = "Kebun Mabar"
	manual_ip_edit.text = "127.0.0.1"
	_refresh_avatar_button()

	var ips := NetworkManager.get_local_ip_addresses()
	ip_label.text = "IP Lokal Anda: %s (Port %d)" % [", ".join(ips), NetworkManager.GAME_PORT]

	NetworkManager.lan_worlds_updated.connect(_on_lan_worlds_updated)
	NetworkManager.connection_failed.connect(_on_conn_failed)
	NetworkManager.start_lan_discovery()
	_populate_saved_worlds()


func _exit_tree() -> void:
	NetworkManager.stop_lan_discovery()


func _on_btn_avatar_pressed() -> void:
	_avatar = "mitha" if _avatar == "budi" else "budi"
	_refresh_avatar_button()


func _on_btn_host_new_pressed() -> void:
	GameManager.set_local_identity(name_edit.text, _avatar)
	status_label.text = "Memulai server LAN..."
	var err := GameManager.start_host_world("", host_world_edit.text, true)
	if err != OK:
		status_label.text = "Gagal membuat server LAN (Error %d)." % err


func _on_btn_join_manual_pressed() -> void:
	GameManager.set_local_identity(name_edit.text, _avatar)
	status_label.text = "Menghubungkan ke %s..." % manual_ip_edit.text
	var err := GameManager.join_lan_world(manual_ip_edit.text, NetworkManager.GAME_PORT)
	if err != OK:
		status_label.text = "IP tidak valid atau gagal terhubung."


func _on_btn_back_pressed() -> void:
	NetworkManager.stop_lan_discovery()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _on_lan_worlds_updated(worlds: Array) -> void:
	for c in lan_list.get_children():
		c.queue_free()
	if worlds.is_empty():
		var lbl := Label.new()
		lbl.text = "Mencari World di Wi-Fi/Hotspot..."
		lan_list.add_child(lbl)
		return
	for w in worlds:
		var ip := str(w.get("ip", "127.0.0.1"))
		var port := int(w.get("port", NetworkManager.GAME_PORT))
		var b := Button.new()
		b.text = "%s (%s) Lv%d [%d/%d] - %s" % [
			str(w.get("world_name", "World")),
			str(w.get("host_name", "Host")),
			int(w.get("world_level", 1)),
			int(w.get("player_count", 1)),
			int(w.get("max_players", 4)),
			ip
		]
		b.pressed.connect(func() -> void:
			GameManager.set_local_identity(name_edit.text, _avatar)
			status_label.text = "Bergabung ke %s..." % ip
			GameManager.join_lan_world(ip, port)
		)
		lan_list.add_child(b)


func _populate_saved_worlds() -> void:
	for c in saved_list.get_children():
		c.queue_free()
	for meta in SaveManager.list_saved_worlds():
		var wid := str(meta.get("world_id", ""))
		var b := Button.new()
		b.text = "Host: %s (Lv %d)" % [str(meta.get("world_name", wid)), int(meta.get("world_level", 1))]
		b.pressed.connect(func() -> void:
			GameManager.set_local_identity(name_edit.text, _avatar)
			GameManager.start_host_world(wid, "", false)
		)
		saved_list.add_child(b)


func _on_conn_failed(reason: String) -> void:
	status_label.text = reason


func _refresh_avatar_button() -> void:
	avatar_btn.text = "Avatar: " + ("Mitha" if _avatar == "mitha" else "Budi")
