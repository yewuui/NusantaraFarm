extends CanvasLayer
## K3LH Active Break Reminder modal triggered after configured active gameplay minutes.

@onready var msg_label: Label = $Panel/VBox/MsgLabel


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	visible = false


func open_reminder(minutes_played: int) -> void:
	msg_label.text = "Kamu sudah bermain selama %d menit.\nYuk istirahat sejenak, minum air putih, dan regangkan mata serta tanganmu!" % minutes_played
	if not NetworkManager.is_network_active():
		get_tree().paused = true
	visible = true


func _on_btn_continue_pressed() -> void:
	visible = false
	get_tree().paused = false


func _on_btn_rest_exit_pressed() -> void:
	visible = false
	get_tree().paused = false
	GameManager.return_to_main_menu()
