extends Node2D
## Joglo bed: allows night-only (18:00-05:59) Co-op sleep consensus or solo stamina/drowsy recovery.

var _local_resting: bool = false
var _rest_timer: float = 0.0
var _drowsy_cure_timer: float = 0.0


func _process(delta: float) -> void:
	if not _local_resting:
		return
	var local_pid := NetworkManager.get_local_peer_id()
	if not TimeManager.can_sleep_now():
		_stop_resting(local_pid)
		return
	_rest_timer += delta
	_drowsy_cure_timer += delta
	if _rest_timer >= 5.0:
		_rest_timer = 0.0
		EconomyManager.restore_stamina(GameManager.player_uuid, 15.0, false)
	if _drowsy_cure_timer >= 10.0 and EconomyManager.is_player_drowsy(GameManager.player_uuid):
		EconomyManager.restore_stamina(GameManager.player_uuid, 0.0, true)
		GameManager.show_toast("Istirahat sejenak menghilangkan rasa mengantuk.", "success")


func get_prompt_text() -> String:
	if not TimeManager.can_sleep_now():
		return "Kasur Joglo (Hanya Malam)"
	return "Batalkan Tidur" if _local_resting else "Tidur / Istirahat Malam"


func interact(_player: Node) -> void:
	if not TimeManager.can_sleep_now():
		GameManager.show_toast("Belum waktunya tidur! Tidur hanya bisa pada malam hari (18:00–05:59).", "info")
		return
	var local_pid := NetworkManager.get_local_peer_id()
	if _local_resting:
		_stop_resting(local_pid)
	else:
		_local_resting = true
		_rest_timer = 0.0
		_drowsy_cure_timer = 0.0
		TimeManager.request_toggle_sleep(true)
		if NetworkManager.get_active_player_count() > 1:
			GameManager.show_toast("Menunggu pemain lain ikut tidur untuk ganti hari, sambil memulihkan Stamina...", "info")


func _stop_resting(_pid: int) -> void:
	_local_resting = false
	TimeManager.request_toggle_sleep(false)


func _on_area_body_exited(body: Node2D) -> void:
	if body is PlayerController and body.peer_id == NetworkManager.get_local_peer_id() and _local_resting:
		_stop_resting(body.peer_id)
