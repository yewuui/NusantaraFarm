extends CanvasLayer
## Global Gameplay HUD: Coins, World Level, Stamina, Clock/Season/Weather, Eco-Meter, Drowsy vignette, Hotbar, and Toast alerts.

@onready var coins_label: Label = $Root/TopLeft/VBox/CoinsLabel
@onready var level_label: Label = $Root/TopLeft/VBox/LevelLabel
@onready var xp_bar: ProgressBar = $Root/TopLeft/VBox/XpBar
@onready var stamina_bar: ProgressBar = $Root/TopLeft/VBox/StaminaBar
@onready var eco_label: Label = $Root/TopLeft/VBox/StatusRow/EcoLabel
@onready var drowsy_label: Label = $Root/TopLeft/VBox/StatusRow/DrowsyLabel

@onready var time_label: Label = $Root/TopRight/VBox/TimeLabel
@onready var weather_label: Label = $Root/TopRight/VBox/WeatherLabel
@onready var festival_label: Label = $Root/TopRight/VBox/FestivalLabel
@onready var sleep_vote_label: Label = $Root/TopRight/VBox/SleepVoteLabel

@onready var hotbar_box: HBoxContainer = $Root/BottomBar/Hotbar
@onready var prompt_label: Label = $Root/PromptLabel
@onready var toast_label: Label = $Root/ToastLabel
@onready var drowsy_vignette: ColorRect = $DrowsyVignette

var _hotbar_buttons: Array[Button] = []
var _toast_timer: float = 0.0

# Satu bingkai kayu untuk tiap slot, plus bingkai krem untuk slot yang aktif.
var _slot_styles: Array[StyleBoxTexture] = []
var _slot_active_style: StyleBoxTexture


func _ready() -> void:
	$Root.theme = UIThemeHelper.get_theme()
	_make_slot_styles()
	for i in range(6):
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.add_theme_stylebox_override("normal", _slot_styles[i])
		b.add_theme_stylebox_override("hover", _slot_styles[i])
		b.add_theme_stylebox_override("pressed", _slot_styles[i])
		b.add_theme_stylebox_override("focus", _slot_styles[i])
		b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78))
		b.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.78))
		b.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.03))
		b.add_theme_constant_override("outline_size", 2)
		b.pressed.connect(_on_hotbar_slot_pressed.bind(i))
		hotbar_box.add_child(b)
		_hotbar_buttons.append(b)

	EconomyManager.local_profile_updated.connect(_refresh_player_stats)
	WorldStateManager.world_xp_changed.connect(_on_world_xp_changed)
	WorldStateManager.eco_meter_changed.connect(_on_eco_changed)
	TimeManager.minute_tick.connect(_on_time_tick)
	TimeManager.day_passed.connect(_on_day_passed)
	TimeManager.sleep_vote_updated.connect(_on_sleep_vote_updated)
	TimeManager.festival_state_changed.connect(_on_festival_changed)
	GameManager.toast_requested.connect(_on_toast_requested)

	toast_label.visible = false
	sleep_vote_label.visible = false
	_refresh_all()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false

	var local_player := _get_local_player_node()
	if local_player != null:
		var ptext := local_player.get_nearby_prompt()
		prompt_label.visible = not ptext.is_empty()
		prompt_label.text = "[E] " + ptext
	else:
		prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	for i in range(6):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_on_hotbar_slot_pressed(i)
			return
	if event.is_action_pressed("hotbar_next"):
		var lp := _get_local_player_node()
		if lp != null:
			_on_hotbar_slot_pressed((lp.selected_hotbar_index + 1) % 6)
	elif event.is_action_pressed("hotbar_prev"):
		var lp := _get_local_player_node()
		if lp != null:
			_on_hotbar_slot_pressed((lp.selected_hotbar_index + 5) % 6)


func _on_hotbar_slot_pressed(idx: int) -> void:
	var lp := _get_local_player_node()
	if lp != null:
		lp.selected_hotbar_index = idx
	_refresh_hotbar()


func _on_btn_tas_pressed() -> void:
	var wr := _get_world_root()
	if wr != null:
		wr.toggle_modal(wr.inventory_ui)


func _on_btn_profil_pressed() -> void:
	var wr := _get_world_root()
	if wr != null:
		wr.toggle_modal(wr.profile_ui)


func _on_btn_peta_pressed() -> void:
	var wr := _get_world_root()
	if wr != null:
		wr.toggle_modal(wr.map_ui)


func _on_btn_menu_pressed() -> void:
	var wr := _get_world_root()
	if wr != null:
		wr.toggle_modal(wr.settings_ui)


func _refresh_all() -> void:
	_refresh_player_stats()
	_on_world_xp_changed(WorldStateManager.world_level, WorldStateManager.world_xp, Catalog.get_xp_for_next_world_level(WorldStateManager.world_level))
	_on_eco_changed(WorldStateManager.eco_meter)
	_on_time_tick(TimeManager.get_hour(), TimeManager.get_minute())
	_on_festival_changed(TimeManager.is_festival_active())


func _refresh_player_stats() -> void:
	var uuid := GameManager.player_uuid
	coins_label.text = "Koin: %d" % EconomyManager.get_coins(uuid)
	var ratio := EconomyManager.get_stamina_ratio(uuid)
	stamina_bar.value = ratio * 100.0
	var drowsy := EconomyManager.is_player_drowsy(uuid)
	drowsy_label.visible = drowsy
	drowsy_vignette.visible = drowsy
	_refresh_hotbar()


func _make_slot_styles() -> void:
	for i in range(6):
		var tex := load("res://assets/ui/hotbar_slot_%d.png" % (i + 1)) as Texture2D
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		_slot_styles.append(sb)
	var active_tex := load("res://assets/ui/hotbar_slot_active.png") as Texture2D
	_slot_active_style = StyleBoxTexture.new()
	_slot_active_style.texture = active_tex


func _refresh_hotbar() -> void:
	var lp := _get_local_player_node()
	var active_idx := lp.selected_hotbar_index if lp != null else 0
	for i in range(6):
		var b := _hotbar_buttons[i]
		var slot := EconomyManager.get_inventory_slot(GameManager.player_uuid, i)
		var item_id := str(slot.get("id", ""))
		var cnt := int(slot.get("count", 0))
		if item_id.is_empty() or cnt <= 0:
			b.icon = null
			b.text = ""
		else:
			var it := Catalog.get_item(StringName(item_id))
			b.icon = it.icon if it != null else null
			b.text = str(cnt) if cnt > 1 else ""
		var frame_sb := _slot_active_style if i == active_idx else _slot_styles[i]
		b.add_theme_stylebox_override("normal", frame_sb)
		b.add_theme_stylebox_override("focus", frame_sb)


func _on_world_xp_changed(lv: int, xp: int, needed: int) -> void:
	level_label.text = "World Lv %d (%d/%d)" % [lv, xp, needed]
	xp_bar.max_value = maxf(1.0, float(needed))
	xp_bar.value = float(xp)


func _on_eco_changed(val: int) -> void:
	eco_label.text = "Eco: %d" % val
	if val < 50:
		eco_label.modulate = Color(1.0, 0.35, 0.35)
	elif val < 75:
		eco_label.modulate = Color(1.0, 0.85, 0.35)
	else:
		eco_label.modulate = Color(0.55, 1.0, 0.55)


func _on_time_tick(_h: int, _m: int) -> void:
	time_label.text = "H%d %s | %s" % [TimeManager.get_season_day(), TimeManager.get_season_display(), TimeManager.get_formatted_time()]
	weather_label.text = "Cuaca: %s" % TimeManager.weather.capitalize()


func _on_day_passed(_d: int, _s: String, _w: String) -> void:
	_on_time_tick(TimeManager.get_hour(), TimeManager.get_minute())


func _on_sleep_vote_updated(ready_cnt: int, total_cnt: int) -> void:
	sleep_vote_label.visible = ready_cnt > 0
	sleep_vote_label.text = "Tidur: %d/%d" % [ready_cnt, total_cnt]


func _on_festival_changed(active: bool) -> void:
	festival_label.visible = active


func _on_toast_requested(msg: String, kind: String) -> void:
	toast_label.text = msg
	toast_label.visible = true
	_toast_timer = 3.6
	if kind == "warn":
		toast_label.modulate = Color(1.0, 0.55, 0.45)
	elif kind == "success":
		toast_label.modulate = Color(0.65, 1.0, 0.65)
	else:
		toast_label.modulate = Color(1.0, 1.0, 1.0)


func _get_world_root() -> WorldRoot:
	return get_tree().get_first_node_in_group("world_root") as WorldRoot


func _get_local_player_node() -> PlayerController:
	var wr := _get_world_root()
	if wr == null:
		return null
	var pr := wr.get_node_or_null("PlayersRoot")
	if pr == null:
		return null
	return pr.get_node_or_null("Player_%d" % NetworkManager.get_local_peer_id()) as PlayerController
