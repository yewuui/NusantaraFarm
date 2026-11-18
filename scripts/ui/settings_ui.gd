extends CanvasLayer
## Settings & K3LH configuration screen (Audio sliders, K3LH 60m reminder, touch toggle, Save & Quit).

@onready var music_slider: HSlider = $Panel/VBox/Cols/AudioBox/MusicSlider
@onready var music_val: Label = $Panel/VBox/Cols/AudioBox/MusicVal
@onready var sfx_slider: HSlider = $Panel/VBox/Cols/AudioBox/SfxSlider
@onready var sfx_val: Label = $Panel/VBox/Cols/AudioBox/SfxVal
@onready var touch_check: CheckButton = $Panel/VBox/Cols/AudioBox/TouchCheck
@onready var k3lh_check: CheckButton = $Panel/VBox/Cols/K3LHBox/K3LHCheck
@onready var k3lh_slider: HSlider = $Panel/VBox/Cols/K3LHBox/K3LHSlider
@onready var k3lh_val: Label = $Panel/VBox/Cols/K3LHBox/K3LHVal
@onready var btn_quit_world: Button = $Panel/VBox/Buttons/BtnQuitWorld


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	visible = false


func open_panel() -> void:
	music_slider.value = float(GameManager.settings.get("music_volume", 70.0))
	sfx_slider.value = float(GameManager.settings.get("sfx_volume", 90.0))
	touch_check.button_pressed = bool(GameManager.settings.get("show_touch_controls", false))
	k3lh_check.button_pressed = bool(GameManager.settings.get("k3lh_enabled", true))
	k3lh_slider.value = float(GameManager.settings.get("k3lh_minutes", 60))
	btn_quit_world.visible = not GameManager.active_world_id.is_empty()
	_update_labels()
	visible = true


func _update_labels() -> void:
	music_val.text = "Musik: %d%%" % int(music_slider.value)
	sfx_val.text = "Efek Suara: %d%%" % int(sfx_slider.value)
	k3lh_val.text = "Durasi Reminder: %d Menit" % int(k3lh_slider.value)


func _on_slider_changed(_v: float) -> void:
	_update_labels()


func _on_btn_save_pressed() -> void:
	GameManager.update_settings({
		"music_volume": music_slider.value,
		"sfx_volume": sfx_slider.value,
		"show_touch_controls": touch_check.button_pressed,
		"k3lh_enabled": k3lh_check.button_pressed,
		"k3lh_minutes": int(k3lh_slider.value),
	})
	visible = false


func _on_btn_quit_world_pressed() -> void:
	visible = false
	GameManager.return_to_main_menu()


func _on_btn_close_pressed() -> void:
	visible = false
