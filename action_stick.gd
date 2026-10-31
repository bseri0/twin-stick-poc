extends Control
## Right stick: the action button with a little aim. Tap it to act on the nearest target. Hold it to keep acting;
## drag while holding to point the action, and aim assist bends that toward the nearest target in a small cone.
## `aim` is the push (zero means "auto-target"), `pressed_now` is true for one frame on touch-down.

const RADIUS: float = 52.0
const DRAG_DEAD: float = 0.25 # pushes shorter than this count as "just pressed", so a tap auto-targets
var aim: Vector2 = Vector2.ZERO
var pressed_now: bool = false
var tint: Color = Color(0.92, 0.84, 0.66)
var _finger: int = -2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(RADIUS * 2.0 + 40.0, RADIUS * 2.0 + 40.0)
	custom_minimum_size = size


func held() -> bool:
	return _finger != -2


func consume_press() -> bool:
	var p: bool = pressed_now
	pressed_now = false
	return p


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed and _finger == -2:
			_finger = ev.index
			pressed_now = true
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
			accept_event()
			return
		if ev.pressed:
			_finger = -1
			pressed_now = true
			_push(ev.position)
		elif _finger == -1:
			_let_go()
		accept_event()
	elif ev is InputEventMouseMotion and _finger == -1:
		_push(ev.position)
		accept_event()


func _push(p: Vector2) -> void:
	aim = ((p - size / 2.0) / RADIUS).limit_length(1.0)
	if aim.length() < DRAG_DEAD:
		aim = Vector2.ZERO
	queue_redraw()


func _let_go() -> void:
	_finger = -2
	aim = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var on: bool = held()
	draw_circle(c, RADIUS + 8.0, Color(tint.r * 0.2, tint.g * 0.2, tint.b * 0.2, 0.45 if on else 0.3))
	draw_arc(c, RADIUS + 8.0, 0.0, TAU, 48, Color(tint, 0.85 if on else 0.5), 3.0, true)
	var k: Vector2 = c + aim * RADIUS
	draw_circle(k, 30.0, Color(tint, 0.55 if on else 0.35))
	if aim != Vector2.ZERO:
		draw_line(c, c + aim.normalized() * (RADIUS + 8.0), Color(tint, 0.8), 2.0, true)
