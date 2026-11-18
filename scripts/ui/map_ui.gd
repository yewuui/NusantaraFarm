extends CanvasLayer
## World Map modal showing all 6 outdoor zones, unlock status, and real-time player pins (including LAN teammates).

@onready var map_rect: TextureRect = $Panel/VBox/MapContainer/MapRect
@onready var pins_layer: Control = $Panel/VBox/MapContainer/PinsLayer
@onready var legend_label: Label = $Panel/VBox/LegendLabel


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	visible = false


func open_panel() -> void:
	visible = true
	_refresh()


func _refresh() -> void:
	for c in pins_layer.get_children():
		c.queue_free()

	# Zone unlock badges
	var lock_notes: PackedStringArray = []
	for zid in ["kebun", "desa_pasar", "hutan", "sawit", "pantai", "tambang"]:
		var z := Catalog.get_zone(StringName(zid))
		if z == null:
			continue
		var unlocked := WorldStateManager.is_zone_unlocked(zid)
		var lbl := Label.new()
		lbl.text = z.display_name + ("" if unlocked else " [Terkunci]")
		lbl.position = z.map_pin_pos - Vector2(28, 12)
		lbl.modulate = Color(1, 1, 1) if unlocked else Color(0.85, 0.45, 0.45)
		pins_layer.add_child(lbl)
		if not unlocked:
			lock_notes.append("%s (Lv %d)" % [z.display_name, z.required_world_level])

	# Player pins
	for pid in NetworkManager.peer_profiles.keys():
		var info: Dictionary = NetworkManager.peer_profiles[pid]
		var pz := str(info.get("current_zone", "kebun"))
		if pz == "joglo_interior":
			pz = "kebun"
		elif pz == "balai_desa":
			pz = "desa_pasar"
		var z := Catalog.get_zone(StringName(pz))
		if z == null:
			continue
		var pin := TextureRect.new()
		var av := str(info.get("avatar_id", "budi"))
		var ppath := "res://assets/portraits/%s.png" % av
		if ResourceLoader.exists(ppath):
			pin.texture = load(ppath) as Texture2D
		pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pin.custom_minimum_size = Vector2(18, 18)
		pin.size = Vector2(18, 18)
		pin.position = z.map_pin_pos
		pin.tooltip_text = str(info.get("player_name", "Petani"))
		pins_layer.add_child(pin)

	legend_label.text = "Semua zona terbuka!" if lock_notes.is_empty() else ("Terkunci: " + ", ".join(lock_notes))


func _on_btn_close_pressed() -> void:
	visible = false
