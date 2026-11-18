extends CanvasLayer
## Pasar Desa UI: Buy seeds/materials and manage Market Consignment orders (paid after several in-game hours).

@onready var tab_buy: VBoxContainer = $Panel/VBox/Body/BuyTab
@onready var tab_consign: HBoxContainer = $Panel/VBox/Body/ConsignTab
@onready var buy_list: VBoxContainer = $Panel/VBox/Body/BuyTab/BuyScroll/BuyList
@onready var sell_inv_list: VBoxContainer = $Panel/VBox/Body/ConsignTab/Left/InvScroll/SellInvList
@onready var orders_list: VBoxContainer = $Panel/VBox/Body/ConsignTab/Right/OrdScroll/OrdersList
@onready var coins_label: Label = $Panel/VBox/Header/CoinsLabel
@onready var btn_claim_all: Button = $Panel/VBox/Body/ConsignTab/Right/BtnClaimAll


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	EconomyManager.local_profile_updated.connect(_refresh)
	visible = false


func open_market() -> void:
	visible = true
	_on_tab_buy_pressed()


func _on_tab_buy_pressed() -> void:
	tab_buy.visible = true
	tab_consign.visible = false
	_refresh()


func _on_tab_consign_pressed() -> void:
	tab_buy.visible = false
	tab_consign.visible = true
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	coins_label.text = "Koin: %d" % EconomyManager.get_coins(GameManager.player_uuid)

	for c in buy_list.get_children():
		c.queue_free()
	for it in Catalog.get_shop_items(WorldStateManager.world_level):
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s (%d Koin)" % [it.display_name, it.base_buy_price]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b1 := Button.new()
		b1.text = "Beli x1"
		b1.pressed.connect(func() -> void: EconomyManager.request_buy_item(String(it.id), 1))
		var b5 := Button.new()
		b5.text = "x5"
		b5.pressed.connect(func() -> void: EconomyManager.request_buy_item(String(it.id), 5))
		row.add_child(lbl)
		row.add_child(b1)
		row.add_child(b5)
		buy_list.add_child(row)

	for c in sell_inv_list.get_children():
		c.queue_free()
	var inv: Array = EconomyManager.get_local_player().get("inventory", [])
	for i in range(inv.size()):
		var slot: Dictionary = inv[i]
		var iid := str(slot.get("id", ""))
		var cnt := int(slot.get("count", 0))
		if iid.is_empty() or cnt <= 0:
			continue
		var it := Catalog.get_item(StringName(iid))
		if it == null or it.category == ItemData.Category.TOOL or it.base_sell_price <= 0:
			continue
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s x%d (~%d/bh)" % [it.display_name, cnt, int(round(it.base_sell_price * 1.15))]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b1 := Button.new()
		b1.text = "Titip 1"
		b1.pressed.connect(func() -> void: EconomyManager.request_consign_item(i, 1))
		var ball := Button.new()
		ball.text = "Semua"
		ball.pressed.connect(func() -> void: EconomyManager.request_consign_item(i, cnt))
		row.add_child(lbl)
		row.add_child(b1)
		row.add_child(ball)
		sell_inv_list.add_child(row)

	for c in orders_list.get_children():
		c.queue_free()
	var any_sold := false
	for ord in EconomyManager.get_orders_for_player(GameManager.player_uuid):
		var it := Catalog.get_item(StringName(str(ord["item_id"])))
		var nm := it.display_name if it != null else str(ord["item_id"])
		var lbl := Label.new()
		if bool(ord.get("is_sold", false)):
			any_sold = true
			lbl.text = "[LAKU!] %dx %s -> +%d Koin" % [int(ord["amount"]), nm, int(ord["payout"])]
			lbl.modulate = Color(0.15, 0.55, 0.15)
		else:
			lbl.text = "%dx %s (%.0fj lagi, +%d)" % [int(ord["amount"]), nm, ceilf(float(ord["hours_left"])), int(ord["payout"])]
		orders_list.add_child(lbl)
	btn_claim_all.disabled = not any_sold


func _on_btn_claim_all_pressed() -> void:
	EconomyManager.request_claim_consignments()


func _on_btn_close_pressed() -> void:
	visible = false
