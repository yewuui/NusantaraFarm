extends Control
## Responsive touch/mouse virtual joystick writing to MobileInput.

@export var radius: float = 30.0
@export var knob_radius: float = 12.0
@export var deadzone: float = 0.14

const MOUSE_POINTER := -2
var _active_pointer: int = -1
var _knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, Color(0.95, 0.85, 0.68, 0.25))
	draw_arc(center, radius, 0.0, TAU, 24, Color(0.48, 0.32, 0.16, 0.65), 2.0)
	draw_circle(center + _knob_offset, knob_radius, Color(0.88, 0.68, 0.36, 0.78))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_pointer == -1:
			_active_pointer = event.index
			_update_knob(event.position)
			accept_event()
		elif not event.pressed and event.index == _active_pointer:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_pointer:
		_update_knob(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _active_pointer == -1:
			_active_pointer = MOUSE_POINTER
			_update_knob(event.position)
			accept_event()
		elif not event.pressed and _active_pointer == MOUSE_POINTER:
			_release()
			accept_event()
	elif event is InputEventMouseMotion and _active_pointer == MOUSE_POINTER:
		_update_knob(event.position)
		accept_event()


func _update_knob(pos: Vector2) -> void:
	var offset := pos - size * 0.5
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob_offset = offset
	var raw := offset / radius
	var mag := raw.length()
	if mag <= deadzone:
		MobileInput.set_move_vector(Vector2.ZERO)
	else:
		MobileInput.set_move_vector(raw.normalized() * minf((mag - deadzone) / (1.0 - deadzone), 1.0))
	queue_redraw()


func _release() -> void:
	_active_pointer = -1
	_knob_offset = Vector2.ZERO
	MobileInput.clear()
	queue_redraw()
