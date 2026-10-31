extends Control
## Left stick: movement. Same idea as client/joystick.gd. Drag the knob to run, let go to stop. `vec` is the push in
## screen space, length 0 to 1. Each stick follows its own finger index, so both thumbs work at once.

const RADIUS: float = 60.0
var vec: Vector2 = Vector2.ZERO
var _finger: int = -2 # touch index holding it, -1 for the mouse, -2 for none


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(RADIUS * 2.0 + 40.0, RADIUS * 2.0 + 40.0)
	custom_minimum_size = size


func held() -> bool:
	return _finger != -2


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed and _finger == -2:
			_finger = ev.index
			_push(ev.position)
		elif not ev.pressed and ev.index == _finger:
			_let_go()
		accept_event()
	elif ev is InputEventScreenDrag:
		if ev.index == _finger:
			_push(ev.position)
		accept_event()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if DisplayServer.is_touchscreen_available():
			accept_event() # the mouse copy of a touch we already handled
			return
		if ev.pressed:
			_finger = -1
			_push(ev.position)
		elif _finger == -1:
			_let_go()
		accept_event()
	elif ev is InputEventMouseMotion and _finger == -1:
		_push(ev.position)
		accept_event()


func _push(p: Vector2) -> void:
	vec = ((p - size / 2.0) / RADIUS).limit_length(1.0)
	if vec.length() < 0.12: # small dead zone
		vec = Vector2.ZERO
	queue_redraw()


func _let_go() -> void:
	_finger = -2
	vec = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var on: bool = held()
	draw_circle(c, RADIUS + 8.0, Color(0.05, 0.04, 0.04, 0.25 if on else 0.14))
	draw_arc(c, RADIUS + 8.0, 0.0, TAU, 48, Color(0.92, 0.84, 0.66, 0.5 if on else 0.25), 2.0, true)
	var k: Vector2 = c + vec * RADIUS
	draw_circle(k, 26.0, Color(0.92, 0.84, 0.66, 0.45 if on else 0.22))
	draw_arc(k, 26.0, 0.0, TAU, 32, Color(0.2, 0.15, 0.1, 0.5), 2.0, true)
