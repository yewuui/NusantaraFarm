extends Node2D
## Joglo crafting station: displays idle/active status and opens ProductionUI or collects finished output.

@export var station_id: String = "st_wajan_1"
@export var station_type: StringName = &"wajan_joglo"
@export var station_title: String = "Wajan Keripik"

@onready var sprite: Sprite2D = $Sprite2D
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	WorldStateManager.machine_updated.connect(_on_machine_updated)
	_refresh()


func get_prompt_text() -> String:
	var m: Dictionary = WorldStateManager.active_machines.get(station_id, {})
	if not m.is_empty() and bool(m.get("done", false)):
		return "Ambil Hasil (%s)" % station_title
	return "Gunakan %s" % station_title


func interact(_player: Node) -> void:
	var m: Dictionary = WorldStateManager.active_machines.get(station_id, {})
	if not m.is_empty() and bool(m.get("done", false)):
		WorldStateManager.request_collect_craft(station_id)
		return
	var wr := get_tree().get_first_node_in_group("world_root") as WorldRoot
	if wr != null:
		wr.open_production_station(station_id, station_type, station_title)


func _on_machine_updated(sid: String) -> void:
	if sid == station_id:
		_refresh()


func _refresh() -> void:
	var m: Dictionary = WorldStateManager.active_machines.get(station_id, {})
	var path := "res://assets/objects/production_station.png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			var at := AtlasTexture.new()
			at.atlas = tex
			var frame := 1 if (not m.is_empty() and not bool(m.get("done", false))) else 0
			at.region = Rect2(frame * 32, 0, 32, 32)
			sprite.texture = at

	if m.is_empty():
		status_label.text = ""
	elif bool(m.get("done", false)):
		status_label.text = "[SIAP!]"
	else:
		status_label.text = "%.0fj" % ceilf(float(m.get("hours_left", 1.0)))
