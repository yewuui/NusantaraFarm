extends CanvasLayer
## Shows virtual joystick and touch action buttons on mobile or when toggled in Settings.


func _ready() -> void:
	$Root.theme = UIThemeHelper.get_theme()
	GameManager.settings_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = bool(GameManager.settings.get("show_touch_controls", false))


func _on_btn_use_pressed() -> void:
	MobileInput.trigger_use()


func _on_btn_interact_pressed() -> void:
	MobileInput.trigger_interact()
