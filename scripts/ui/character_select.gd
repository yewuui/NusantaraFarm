extends Control
## Character & New World creation screen (choose Budi or Mitha).

var _selected_avatar: String = "budi"

@onready var name_input: LineEdit = $Panel/VBox/Form/NameEdit
@onready var world_input: LineEdit = $Panel/VBox/Form/WorldEdit
@onready var portrait_preview: TextureRect = $Panel/VBox/AvatarRow/Portrait
@onready var btn_budi: Button = $Panel/VBox/AvatarRow/Buttons/BtnBudi
@onready var btn_mitha: Button = $Panel/VBox/AvatarRow/Buttons/BtnMitha


func _ready() -> void:
	theme = UIThemeHelper.get_theme()
	_selected_avatar = GameManager.avatar_id
	name_input.text = GameManager.player_name
	world_input.text = "Desa Subur"
	_refresh_avatar()


func _on_btn_budi_pressed() -> void:
	_selected_avatar = "budi"
	_refresh_avatar()


func _on_btn_mitha_pressed() -> void:
	_selected_avatar = "mitha"
	_refresh_avatar()


func _on_btn_start_pressed() -> void:
	AudioManager.play_sfx("sfx_ui_click.wav")
	GameManager.set_local_identity(name_input.text, _selected_avatar)
	GameManager.start_new_solo_world(world_input.text)


func _on_btn_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _refresh_avatar() -> void:
	var ppath := "res://assets/portraits/%s.png" % _selected_avatar
	if ResourceLoader.exists(ppath):
		portrait_preview.texture = load(ppath) as Texture2D
	btn_budi.disabled = (_selected_avatar == "budi")
	btn_mitha.disabled = (_selected_avatar == "mitha")
