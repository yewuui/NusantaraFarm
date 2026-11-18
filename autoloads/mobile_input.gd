extends Node
## Holds virtual joystick input vector and touch button signals for Android/desktop hybrid controls.

signal use_pressed
signal interact_pressed

var move_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_move_vector(value: Vector2) -> void:
	move_vector = value.limit_length(1.0)


func clear() -> void:
	move_vector = Vector2.ZERO


func trigger_use() -> void:
	use_pressed.emit()


func trigger_interact() -> void:
	interact_pressed.emit()
