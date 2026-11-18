extends Node
## Manages K3LH pillars: 60-minute active break reminder, family-safe rules, and Eco-Meter crisis monitoring.

signal break_reminder_triggered(minutes_played: int)
signal eco_crisis_changed(is_crisis: bool)

var is_eco_crisis: bool = false
var _session_running: bool = false
var _elapsed_seconds: float = 0.0
var _last_crisis_notified: bool = false


func _process(delta: float) -> void:
	if not _session_running:
		return
	if not bool(GameManager.settings.get("k3lh_enabled", true)):
		return
	if get_tree().paused:
		return

	_elapsed_seconds += delta
	var limit_seconds := float(int(GameManager.settings.get("k3lh_minutes", 60)) * 60)
	if limit_seconds > 0.0 and _elapsed_seconds >= limit_seconds:
		_elapsed_seconds = 0.0
		AudioManager.play_sfx("sfx_k3lh_bell.wav")
		break_reminder_triggered.emit(int(GameManager.settings.get("k3lh_minutes", 60)))


func reset_new_world() -> void:
	is_eco_crisis = false
	_last_crisis_notified = false
	_elapsed_seconds = 0.0


func start_session_timer() -> void:
	_session_running = true
	_elapsed_seconds = 0.0


func stop_session_timer() -> void:
	_session_running = false
	_elapsed_seconds = 0.0


func evaluate_eco_status(eco_val: int) -> void:
	var crisis := eco_val < 50
	if crisis != is_eco_crisis:
		is_eco_crisis = crisis
		eco_crisis_changed.emit(crisis)
	if crisis and not _last_crisis_notified:
		_last_crisis_notified = true
		GameManager.show_toast("PERINGATAN K3LH: Eco-Meter < 50! Stamina boros +30%, denda 15%, & reputasi turun!", "warn")
		AudioManager.play_sfx("sfx_eco_warn.wav")
	elif not crisis and _last_crisis_notified:
		_last_crisis_notified = false
		GameManager.show_toast("Eco-Meter pulih (>= 50)! Penalti lingkungan dicabut.", "success")


func on_day_passed() -> void:
	if is_eco_crisis:
		GameManager.show_toast("Eco-Meter masih kritis (%d). Reboisasi hutan atau bantu quest warga!" % WorldStateManager.eco_meter, "warn")
