extends CanvasLayer
## Profil Pak Tani UI: shows World Level, individual Skills, NPC Relationships, Eco-Meter K3LH, and Active Quests.

@onready var portrait: TextureRect = $Panel/VBox/Body/Left/Portrait
@onready var player_label: Label = $Panel/VBox/Body/Left/PlayerLabel
@onready var world_lvl_label: Label = $Panel/VBox/Body/Left/WorldLvlLabel
@onready var skills_box: VBoxContainer = $Panel/VBox/Body/Mid/SkillsBox
@onready var hearts_box: VBoxContainer = $Panel/VBox/Body/Right/HeartsBox
@onready var eco_info_label: Label = $Panel/VBox/EcoInfoLabel


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	visible = false


func open_panel() -> void:
	visible = true
	_refresh()


func _refresh() -> void:
	var p := EconomyManager.get_local_player()
	var av := str(p.get("avatar_id", "budi"))
	var ppath := "res://assets/portraits/%s.png" % av
	if ResourceLoader.exists(ppath):
		portrait.texture = load(ppath) as Texture2D
	player_label.text = "%s (%d Koin)" % [str(p.get("player_name", "Budi")), int(p.get("coins", 0))]
	var needed := Catalog.get_xp_for_next_world_level(WorldStateManager.world_level)
	world_lvl_label.text = "World Level %d\nEXP: %d / %d" % [WorldStateManager.world_level, WorldStateManager.world_xp, needed]

	for c in skills_box.get_children():
		c.queue_free()
	var skills: Dictionary = p.get("skills", {})
	for sid in ["cangkul", "siram", "panen", "produksi"]:
		var sk: Dictionary = skills.get(sid, {"lv": 1, "xp": 0})
		var lbl := Label.new()
		lbl.text = "%s: Lv %d (EXP %d)" % [sid.capitalize(), int(sk.get("lv", 1)), int(sk.get("xp", 0))]
		skills_box.add_child(lbl)

	for c in hearts_box.get_children():
		c.queue_free()
	var hearts: Dictionary = p.get("npc_hearts", {})
	for nid in hearts.keys():
		var npc := Catalog.get_npc(StringName(nid))
		var nm := npc.display_name if npc != null else String(nid)
		var pts := int(hearts[nid])
		var lbl := Label.new()
		lbl.text = "%s: %d/10 Hati" % [nm, pts / 100]
		hearts_box.add_child(lbl)

	var eco := WorldStateManager.eco_meter
	var eco_status := "Lestari" if eco >= 75 else ("Waspada" if eco >= 50 else "KRISIS (Penalti K3LH Aktif!)")
	eco_info_label.text = "Eco-Meter Desa: %d/100 [%s] | Quest Aktif: %d" % [eco, eco_status, QuestManager.active_quests.size()]


func _on_btn_close_pressed() -> void:
	visible = false
