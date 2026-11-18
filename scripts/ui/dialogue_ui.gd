extends CanvasLayer
## Bamboo-framed NPC Dialogue UI with portrait, typewriter text, gift giving, quest hand-in, and Market access.

var _npc_id: String = ""
var _full_text: String = ""
var _shown_chars: float = 0.0

@onready var portrait_rect: TextureRect = $Panel/HBox/Portrait
@onready var name_label: Label = $Panel/HBox/Right/Header/NameLabel
@onready var hearts_label: Label = $Panel/HBox/Right/Header/HeartsLabel
@onready var body_label: RichTextLabel = $Panel/HBox/Right/BodyLabel
@onready var quest_box: VBoxContainer = $Panel/HBox/Right/QuestBox
@onready var btn_market: Button = $Panel/HBox/Right/Actions/BtnMarket
@onready var btn_gift: Button = $Panel/HBox/Right/Actions/BtnGift


func _ready() -> void:
	$Panel.theme = UIThemeHelper.get_theme()
	visible = false


func _process(delta: float) -> void:
	if not visible or _shown_chars >= _full_text.length():
		return
	_shown_chars += delta * 42.0
	body_label.visible_characters = int(_shown_chars)


func show_dialogue(npc_id: String, text: String) -> void:
	_npc_id = npc_id
	_full_text = text
	_shown_chars = 0.0
	var npc := Catalog.get_npc(StringName(npc_id))
	if npc != null:
		name_label.text = "%s (%s)" % [npc.display_name, npc.role_title]
		portrait_rect.texture = npc.portrait
	var pts := int(EconomyManager.get_local_player().get("npc_hearts", {}).get(npc_id, 0))
	hearts_label.text = "Hati: %d/10" % (pts / 100)

	body_label.text = text
	body_label.visible_characters = 0
	btn_market.visible = npc_id in ["leon", "nisrina"]
	_refresh_quests()
	visible = true


func _refresh_quests() -> void:
	for c in quest_box.get_children():
		c.queue_free()
	var avail := QuestManager.get_available_quests_for_npc(StringName(_npc_id))
	for q in avail:
		var qid := String(q.quest_id)
		var b := Button.new()
		if qid in QuestManager.active_quests:
			if QuestManager.can_turn_in(GameManager.player_uuid, qid):
				b.text = "[Selesaikan Quest] " + q.title
				b.pressed.connect(func() -> void:
					QuestManager.request_complete_quest(qid)
					_refresh_quests()
				)
			else:
				b.text = "[Aktif] " + q.title + " - " + q.description
				b.disabled = true
		else:
			b.text = "[Terima Quest] " + q.title
			b.pressed.connect(func() -> void:
				QuestManager.request_accept_quest(qid)
				_refresh_quests()
			)
		quest_box.add_child(b)


func _on_btn_gift_pressed() -> void:
	var wr := get_tree().get_first_node_in_group("world_root") as WorldRoot
	if wr == null:
		return
	var pr := wr.get_node_or_null("PlayersRoot")
	if pr == null:
		return
	var lp := pr.get_node_or_null("Player_%d" % NetworkManager.get_local_peer_id()) as PlayerController
	if lp != null:
		DialogueManager.request_give_gift(_npc_id, lp.selected_hotbar_index)


func _on_btn_market_pressed() -> void:
	visible = false
	var wr := get_tree().get_first_node_in_group("world_root") as WorldRoot
	if wr != null:
		wr.open_market()


func _on_btn_close_pressed() -> void:
	visible = false
	DialogueManager.close_dialogue()
