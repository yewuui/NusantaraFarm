extends Control
## Main Menu screen with New Game, Continue Saved World, LAN Co-op, Settings, and Quit.

@onready var root_box: Control = $CenterContainer/VBox
@onready var load_panel: PanelContainer = $LoadPanel
@onready var saves_list: VBoxContainer = $LoadPanel/VBox/Scroll/SavesList
@onready var settings_ui: CanvasLayer = $SettingsUI
@onready var btn_continue: Button = $CenterContainer/VBox/BtnContinue


func _ready() -> void:
	theme = UIThemeHelper.get_theme()
	AudioManager.play_bgm("bgm_menu.ogg")
	load_panel.visible = false
	settings_ui.visible = false
	var saves := SaveManager.list_saved_worlds()
	btn_continue.disabled = saves.is_empty()


func _on_btn_new_pressed() -> void:
	AudioManager.play_sfx("sfx_ui_click.wav")
	get_tree().change_scene_to_file("res://scenes/main/CharacterSelect.tscn")


func _on_btn_continue_pressed() -> void:
	AudioManager.play_sfx("sfx_ui_click.wav")
	_populate_saves()
	load_panel.visible = true


func _on_btn_lan_pressed() -> void:
	AudioManager.play_sfx("sfx_ui_click.wav")
	get_tree().change_scene_to_file("res://scenes/main/LanLobby.tscn")


func _on_btn_settings_pressed() -> void:
	AudioManager.play_sfx("sfx_ui_click.wav")
	settings_ui.open_panel()


func _on_btn_quit_pressed() -> void:
	get_tree().quit()


func _on_btn_close_load_pressed() -> void:
	load_panel.visible = false


func _populate_saves() -> void:
	for c in saves_list.get_children():
		c.queue_free()
	for meta in SaveManager.list_saved_worlds():
		var wid := str(meta.get("world_id", ""))
		var wname := str(meta.get("world_name", wid))
		var lv := int(meta.get("world_level", 1))
		var d := int(meta.get("day", 1))
		var s := "Kemarau" if str(meta.get("season", "kemarau")) == "kemarau" else "Penghujan"
		var b := Button.new()
		b.text = "%s (World Lv %d - Hari %d %s)" % [wname, lv, d, s]
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx("sfx_ui_click.wav")
			GameManager.load_solo_world(wid)
		)
		saves_list.add_child(b)
