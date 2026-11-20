extends Node
## Manages 24-minute days (1 real sec = 1 in-game min), 2 tropical seasons, weather, night sleep consensus, and Debuff Mengantuk.

signal minute_tick(hour: int, minute: int)
signal hour_passed(hour: int)
signal day_passed(day: int, season: String, weather: String)
signal sleep_vote_updated(ready_count: int, total_count: int)
signal festival_state_changed(is_active: bool)

const MINUTES_PER_DAY := 1440
const START_MINUTE := 360 # 06:00
const DAYS_PER_SEASON := 14

var total_minutes_elapsed: int = START_MINUTE
var minute_of_day: int = START_MINUTE
var day: int = 1 # 1..28
var year: int = 1
var season: String = "kemarau" # "kemarau" (1..14) | "penghujan" (15..28)
var weather: String = "cerah"  # "cerah" | "berawan" | "hujan"

var sleeping_peers: Dictionary = {} # peer_id -> true
var _running: bool = false
var _accum: float = 0.0
var _last_festival_active: bool = false


func _process(delta: float) -> void:
	if not _running:
		return
	if not NetworkManager.is_host_or_offline():
		# Clients smoothly mirror clock locally between host syncs
		_accum += delta
		if _accum >= 1.0:
			_accum -= 1.0
			_step_local_clock_only()
		return

	_accum += delta
	while _accum >= 1.0:
		_accum -= 1.0
		advance_minutes(1)


func set_running(enabled: bool) -> void:
	_running = enabled


func reset_new_world() -> void:
	total_minutes_elapsed = START_MINUTE
	minute_of_day = START_MINUTE
	day = 1
	year = 1
	season = "kemarau"
	weather = "cerah"
	sleeping_peers.clear()
	_accum = 0.0
	_last_festival_active = false


func get_hour() -> int:
	return minute_of_day / 60


func get_minute() -> int:
	return minute_of_day % 60


func get_formatted_time() -> String:
	var disp_min := (get_minute() / 10) * 10
	return "%02d:%02d" % [get_hour(), disp_min]


func get_season_display() -> String:
	return "Kemarau" if season == "kemarau" else "Penghujan"


func get_season_day() -> int:
	return day if day <= DAYS_PER_SEASON else day - DAYS_PER_SEASON


func can_sleep_now() -> bool:
	var h := get_hour()
	return h >= 18 or h < 6


func is_festival_active() -> bool:
	return (day == 14 or day == 28) and get_hour() >= 9 and get_hour() < 17


func get_ambient_color() -> Color:
	var h := float(minute_of_day) / 60.0
	if h >= 6.0 and h < 9.0:
		return Color(1.0, 0.94, 0.86)
	if h >= 9.0 and h < 16.0:
		if weather == "hujan":
			return Color(0.78, 0.85, 0.94)
		elif weather == "berawan":
			return Color(0.92, 0.94, 0.96)
		return Color(1.0, 1.0, 1.0)
	if h >= 16.0 and h < 18.5:
		return Color(1.0, 0.78, 0.62)
	if h >= 18.5 and h < 24.0:
		return Color(0.45, 0.50, 0.72)
	# 00:00 - 05:59 dini hari
	return Color(0.32, 0.36, 0.58)


func advance_minutes(steps: int) -> void:
	for _i in range(steps):
		var prev_hour := get_hour()
		total_minutes_elapsed += 1
		minute_of_day += 1

		if minute_of_day >= MINUTES_PER_DAY:
			minute_of_day = 0
			# Midnight passed -> trigger Debuff Mengantuk for awake players not shielded by coffee
			_apply_midnight_drowsy()

		var curr_hour := get_hour()
		var curr_min := get_minute()

		if curr_hour != prev_hour:
			hour_passed.emit(curr_hour)
			WorldStateManager.on_hour_passed()
			EconomyManager.on_hour_passed()
			if curr_hour == 6 and curr_min == 0:
				_trigger_new_day(false)

		minute_tick.emit(curr_hour, curr_min)

		var fest := is_festival_active()
		if fest != _last_festival_active:
			_last_festival_active = fest
			festival_state_changed.emit(fest)

	if NetworkManager.is_network_active() and NetworkManager.is_host_or_offline():
		if get_minute() % 10 == 0:
			rpc("_client_sync_clock", total_minutes_elapsed, minute_of_day, day, year, season, weather)


func _step_local_clock_only() -> void:
	var prev_hour := get_hour()
	total_minutes_elapsed += 1
	minute_of_day = (minute_of_day + 1) % MINUTES_PER_DAY
	if get_hour() != prev_hour:
		hour_passed.emit(get_hour())
	minute_tick.emit(get_hour(), get_minute())


func _apply_midnight_drowsy() -> void:
	for uuid in EconomyManager.players.keys():
		var pid: int = NetworkManager.peer_by_uuid.get(uuid, 1 if uuid == GameManager.player_uuid else -1)
		if pid != -1 and sleeping_peers.has(pid):
			continue
		EconomyManager.evaluate_midnight_drowsy(uuid, total_minutes_elapsed)


@rpc("any_peer", "call_local", "reliable")
func request_toggle_sleep(wants_sleep: bool) -> void:
	if not NetworkManager.is_host_or_offline():
		rpc_id(1, "request_toggle_sleep", wants_sleep)
		return
	var sender_id := multiplayer.get_remote_sender_id() if NetworkManager.is_network_active() else 1
	if sender_id == 0:
		sender_id = 1

	if wants_sleep and not can_sleep_now():
		return

	if wants_sleep:
		sleeping_peers[sender_id] = true
	else:
		sleeping_peers.erase(sender_id)

	var total_players := NetworkManager.get_active_player_count()
	var ready_count := sleeping_peers.size()
	_sync_sleep_vote(ready_count, total_players)

	if ready_count >= total_players and total_players > 0:
		advance_day_by_sleep()


func clear_sleep_vote(peer_id: int) -> void:
	if sleeping_peers.erase(peer_id):
		_sync_sleep_vote(sleeping_peers.size(), NetworkManager.get_active_player_count())


func advance_day_by_sleep() -> void:
	if not NetworkManager.is_host_or_offline():
		return
	sleeping_peers.clear()
	# Jump to 06:00 next morning
	var mins_to_morning := (START_MINUTE - minute_of_day)
	if mins_to_morning <= 0:
		mins_to_morning += MINUTES_PER_DAY
	var hours_skipped := int(ceil(float(mins_to_morning) / 60.0))
	total_minutes_elapsed += mins_to_morning
	minute_of_day = START_MINUTE

	for _h in range(hours_skipped):
		WorldStateManager.on_hour_passed()
		EconomyManager.on_hour_passed()

	_trigger_new_day(true)
	_sync_sleep_vote(0, NetworkManager.get_active_player_count())


func _trigger_new_day(from_sleep: bool) -> void:
	day += 1
	if day > DAYS_PER_SEASON * 2:
		day = 1
		year += 1
	season = "kemarau" if day <= DAYS_PER_SEASON else "penghujan"
	weather = _roll_weather()

	WorldStateManager.on_day_passed(weather)
	EconomyManager.on_day_passed(from_sleep, WorldStateManager.eco_meter)
	K3LHManager.on_day_passed()
	SaveManager.save_all()

	if NetworkManager.is_network_active():
		rpc("_client_on_day_passed", total_minutes_elapsed, minute_of_day, day, year, season, weather)
	else:
		day_passed.emit(day, season, weather)

	var fest := is_festival_active()
	if fest != _last_festival_active:
		_last_festival_active = fest
		festival_state_changed.emit(fest)


func _roll_weather() -> String:
	var r := randf()
	if season == "kemarau":
		if r < 0.75:
			return "cerah"
		return "berawan"
	else:
		if r < 0.70:
			return "hujan"
		if r < 0.90:
			return "berawan"
		return "cerah"


func _sync_sleep_vote(ready_count: int, total_count: int) -> void:
	if NetworkManager.is_network_active():
		rpc("_client_sleep_vote_updated", ready_count, total_count)
	else:
		sleep_vote_updated.emit(ready_count, total_count)


@rpc("authority", "call_local", "reliable")
func _client_sleep_vote_updated(ready_count: int, total_count: int) -> void:
	sleep_vote_updated.emit(ready_count, total_count)


@rpc("authority", "reliable")
func _client_sync_clock(tot: int, mod: int, d: int, y: int, s: String, w: String) -> void:
	total_minutes_elapsed = tot
	minute_of_day = mod
	day = d
	year = y
	season = s
	weather = w
	minute_tick.emit(get_hour(), get_minute())


@rpc("authority", "call_local", "reliable")
func _client_on_day_passed(tot: int, mod: int, d: int, y: int, s: String, w: String) -> void:
	total_minutes_elapsed = tot
	minute_of_day = mod
	day = d
	year = y
	season = s
	weather = w
	day_passed.emit(day, season, weather)


func serialize_state() -> Dictionary:
	return {
		"total_minutes_elapsed": total_minutes_elapsed,
		"minute_of_day": minute_of_day,
		"day": day,
		"year": year,
		"season": season,
		"weather": weather,
	}


func apply_snapshot(data: Dictionary) -> void:
	total_minutes_elapsed = int(data.get("total_minutes_elapsed", START_MINUTE))
	minute_of_day = int(data.get("minute_of_day", START_MINUTE))
	day = int(data.get("day", 1))
	year = int(data.get("year", 1))
	season = str(data.get("season", "kemarau"))
	weather = str(data.get("weather", "cerah"))
	_last_festival_active = is_festival_active()
