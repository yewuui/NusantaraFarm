extends CanvasLayer
## Tas Pinggang modal supporting normal bag management, Shipping Bin, Shared Chest, and Festival submission.

var _mode: String = "bag" # "bag" | "ship" | "chest" | "festival"
var _selected_idx: int = -1

@onready var title_label: Label = $Panel/VBox/Header/TitleLabel
@onready var grid: GridContainer = $Panel/VBox/Body/GridScroll/Grid
@onready var chest_panel: VBoxContainer = $Panel/VBox/Body/ChestBox
@onready var chest_grid: GridContainer = $Panel/VBox/Body/ChestBox/ChestGrid
@onready var detail_name: Label = $Panel/VBox/Body/DetailBox/ItemName
@onready var detail_desc: Label = $Panel/VBox/Body/DetailBox/ItemDesc
@onready var btn_action: Button = $Panel/VBox/Body/DetailBox/BtnAction
@onready var btn_swap_hotbar: Button = $Panel/VBox/Body/DetailBox/BtnSwapHotbar


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	EconomyManager.local_profile_updated.connect(_refresh)
	WorldStateManager.chest_updated.connect(_refresh)
	visible = false


func open_panel() -> void:
	open_with_mode("bag")


func open_with_mode(mode_name: String) -> void:
	_mode = mode_name
	_selected_idx = -1
	visible = true
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	match _mode:
		"bag": title_label.text = "TAS PINGGANG"
		"ship": title_label.text = "PETI PANEN (Cair Jam 06:00)"
		"chest": title_label.text = "PETI BERSAMA KEBUN"
		"festival": title_label.text = "FESTIVAL PANEN DESA"

	chest_panel.visible = (_mode == "chest")

	for c in grid.get_children():
		c.queue_free()
	var p := EconomyManager.get_local_player()
	var inv: Array = p.get("inventory", [])
	for i in range(inv.size()):
		var slot: Dictionary = inv[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		var item_id := str(slot.get("id", ""))
		var cnt := int(slot.get("count", 0))
		if not item_id.is_empty() and cnt > 0:
			var it := Catalog.get_item(StringName(item_id))
			b.icon = it.icon if it != null else null
			b.text = str(cnt) if cnt > 1 else ""
		if i == _selected_idx:
			b.modulate = Color(1.0, 0.9, 0.45)
		b.pressed.connect(func() -> void:
			_selected_idx = i
			_refresh_detail()
			_refresh()
		)
		grid.add_child(b)

	if _mode == "chest":
		for c in chest_grid.get_children():
			c.queue_free()
		for j in range(WorldStateManager.shared_chest.size()):
			var cs: Dictionary = WorldStateManager.shared_chest[j]
			var cb := Button.new()
			cb.custom_minimum_size = Vector2(26, 26)
			var cid := str(cs.get("id", ""))
			var ccnt := int(cs.get("count", 0))
			if not cid.is_empty() and ccnt > 0:
				var cit := Catalog.get_item(StringName(cid))
				cb.icon = cit.icon if cit != null else null
				cb.text = str(ccnt) if ccnt > 1 else ""
			cb.pressed.connect(func() -> void:
				WorldStateManager.request_chest_withdraw(j)
			)
			chest_grid.add_child(cb)

	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_idx < 0:
		detail_name.text = "Pilih item..."
		detail_desc.text = ""
		btn_action.visible = false
		btn_swap_hotbar.visible = false
		return

	var slot := EconomyManager.get_inventory_slot(GameManager.player_uuid, _selected_idx)
	var item_id := str(slot.get("id", ""))
	var cnt := int(slot.get("count", 0))
	if item_id.is_empty() or cnt <= 0:
		detail_name.text = "Slot Kosong"
		detail_desc.text = ""
		btn_action.visible = false
		btn_swap_hotbar.visible = false
		return

	var it := Catalog.get_item(StringName(item_id))
	if it == null:
		return
	detail_name.text = "%s (x%d)" % [it.display_name, cnt]
	detail_desc.text = "%s\nHarga dasar: %d Koin" % [it.description, it.base_sell_price]

	btn_swap_hotbar.visible = (_mode == "bag" and _selected_idx >= 8)
	btn_action.visible = true
	match _mode:
		"bag":
			btn_action.visible = it.is_consumable
			btn_action.text = "Makan / Minum"
		"ship":
			btn_action.text = "Kirim Semua (%d)" % cnt
		"chest":
			btn_action.text = "Simpan ke Peti"
		"festival":
			btn_action.text = "Persembahkan (x1)"


func _on_btn_action_pressed() -> void:
	if _selected_idx < 0:
		return
	var slot := EconomyManager.get_inventory_slot(GameManager.player_uuid, _selected_idx)
	var cnt := int(slot.get("count", 0))
	match _mode:
		"bag":
			EconomyManager.request_consume_item(_selected_idx)
		"ship":
			EconomyManager.request_ship_item(_selected_idx, cnt)
		"chest":
			WorldStateManager.request_chest_deposit(_selected_idx)
		"festival":
			WorldStateManager.request_festival_submit(_selected_idx)
			visible = false


func _on_btn_swap_hotbar_pressed() -> void:
	if _selected_idx >= 8:
		EconomyManager.request_swap_inventory_slots(_selected_idx, 7)
		_selected_idx = 7


func _on_btn_close_pressed() -> void:
	visible = false
