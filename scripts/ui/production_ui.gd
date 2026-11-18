extends CanvasLayer
## Joglo Production Station UI showing Input -> Recipe -> Output and active craft progress.

var _station_id: String = ""
var _station_type: StringName = &"wajan_joglo"
var _selected_recipe: RecipeData

@onready var title_label: Label = $Panel/VBox/Header/TitleLabel
@onready var recipe_list: VBoxContainer = $Panel/VBox/Body/RecipeScroll/RecipeList
@onready var input_label: Label = $Panel/VBox/Body/DetailBox/FlowRow/InputLabel
@onready var time_label: Label = $Panel/VBox/Body/DetailBox/FlowRow/TimeLabel
@onready var output_label: Label = $Panel/VBox/Body/DetailBox/FlowRow/OutputLabel
@onready var status_label: Label = $Panel/VBox/Body/DetailBox/StatusLabel
@onready var btn_craft: Button = $Panel/VBox/Body/DetailBox/BtnCraft


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	WorldStateManager.machine_updated.connect(_on_machine_updated)
	EconomyManager.local_profile_updated.connect(_refresh)
	visible = false


func open_station(station_id: String, station_type: StringName, title: String) -> void:
	_station_id = station_id
	_station_type = station_type
	title_label.text = title.to_upper()
	_selected_recipe = null
	visible = true
	_populate_recipes()
	_refresh()


func _populate_recipes() -> void:
	for c in recipe_list.get_children():
		c.queue_free()
	for r_any in Catalog.recipes.values():
		var r := r_any as RecipeData
		# Allow dapur_joglo to also handle sangrai/peras when World Level unlocked
		var matches := (r.station_type == _station_type) or (_station_type == &"dapur_joglo" and r.station_type in [&"sangrai", &"peras"])
		if not matches:
			continue
		if _selected_recipe == null:
			_selected_recipe = r
		var b := Button.new()
		b.text = "%s (Lv %d)" % [r.display_name, r.required_world_level]
		b.pressed.connect(func() -> void:
			_selected_recipe = r
			_refresh()
		)
		recipe_list.add_child(b)


func _refresh() -> void:
	if not visible:
		return
	var active: Dictionary = WorldStateManager.active_machines.get(_station_id, {})
	if not active.is_empty():
		var r := Catalog.get_recipe(StringName(str(active.get("recipe_id", ""))))
		input_label.text = "Sedang\nDiolah"
		output_label.text = r.display_name if r != null else "Produk"
		if bool(active.get("done", false)):
			time_label.text = "SELESAI!"
			status_label.text = "Produk siap diambil ke Tas Pinggang."
			btn_craft.text = "AMBIL HASIL"
			btn_craft.disabled = false
		else:
			time_label.text = "Sisa %.1fj" % float(active.get("hours_left", 1.0))
			status_label.text = "Menunggu proses selesai..."
			btn_craft.text = "MEMASAK..."
			btn_craft.disabled = true
		return

	if _selected_recipe == null:
		input_label.text = "-"
		time_label.text = "-"
		output_label.text = "-"
		status_label.text = "Tidak ada resep."
		btn_craft.disabled = true
		return

	var ing_lines: PackedStringArray = []
	var can_craft := WorldStateManager.world_level >= _selected_recipe.required_world_level
	for ing_id in _selected_recipe.ingredients.keys():
		var need := int(_selected_recipe.ingredients[ing_id])
		var have := EconomyManager.get_item_count(GameManager.player_uuid, String(ing_id))
		var it := Catalog.get_item(StringName(ing_id))
		var nm := it.display_name if it != null else String(ing_id)
		ing_lines.append("%s: %d/%d" % [nm, have, need])
		if have < need:
			can_craft = false

	input_label.text = "\n".join(ing_lines)
	time_label.text = "%.1f Jam\n+%d EXP" % [_selected_recipe.process_hours, _selected_recipe.craft_xp]
	var out_it := Catalog.get_item(_selected_recipe.output_item_id)
	output_label.text = "%s\n(x%d)" % [out_it.display_name if out_it != null else "", _selected_recipe.output_amount]

	if WorldStateManager.world_level < _selected_recipe.required_world_level:
		status_label.text = "Butuh World Level %d" % _selected_recipe.required_world_level
	elif can_craft:
		status_label.text = "Bahan lengkap! Siap diolah."
	else:
		status_label.text = "Bahan belum mencukupi."

	btn_craft.text = "PRODUKSI"
	btn_craft.disabled = not can_craft


func _on_btn_craft_pressed() -> void:
	var active: Dictionary = WorldStateManager.active_machines.get(_station_id, {})
	if not active.is_empty():
		if bool(active.get("done", false)):
			WorldStateManager.request_collect_craft(_station_id)
		return
	if _selected_recipe != null:
		WorldStateManager.request_start_craft(_station_id, String(_selected_recipe.recipe_id))


func _on_machine_updated(sid: String) -> void:
	if sid == _station_id:
		_refresh()


func _on_btn_close_pressed() -> void:
	visible = false
