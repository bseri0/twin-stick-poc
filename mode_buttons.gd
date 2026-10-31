extends Control
## The three small selectors above the right stick: Attack, Heal, Defend. Tap one to choose what the right stick does.

signal changed(mode: int)

const MODES: Array = [
	{"name": "ATK", "color": Color(0.88, 0.32, 0.26)},
	{"name": "HEAL", "color": Color(0.36, 0.82, 0.42)},
	{"name": "DEF", "color": Color(0.36, 0.6, 0.92)},
]
const R: float = 24.0 # button radius
const GAP: float = 12.0
var mode: int = 0
var cooldowns: Array = [0.0, 0.0, 0.0] # 0 to 1, drawn as a sweep


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(MODES.size() * (R * 2.0 + GAP), R * 2.0 + 22.0)
	custom_minimum_size = size


func _centre(i: int) -> Vector2:
	return Vector2(GAP / 2.0 + R + i * (R * 2.0 + GAP), R + 2.0)


func _gui_input(ev: InputEvent) -> void:
	var p := Vector2.INF
	if ev is InputEventScreenTouch and ev.pressed:
		p = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT \
			and not DisplayServer.is_touchscreen_available():
		p = ev.position
	if p == Vector2.INF:
		if ev is InputEventScreenTouch or ev is InputEventMouseButton:
			accept_event()
		return
	for i in MODES.size():
		if p.distance_to(_centre(i)) <= R + GAP / 2.0:
			if i != mode:
				mode = i
				changed.emit(mode)
				queue_redraw()
			break
	accept_event()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in MODES.size():
		var c: Vector2 = _centre(i)
		var col: Color = MODES[i].color
		var sel: bool = i == mode
		draw_circle(c, R, Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.85 if sel else 0.5))
		if cooldowns[i] > 0.0:
			draw_arc(c, R - 5.0, -PI / 2.0, -PI / 2.0 + TAU * cooldowns[i], 24, Color(0, 0, 0, 0.6), 8.0)
		draw_arc(c, R, 0.0, TAU, 32, Color(col, 1.0 if sel else 0.45), 4.0 if sel else 2.0, true)
		var label: String = MODES[i].name
		var fs: int = 13
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + Vector2(-w / 2.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(1, 1, 1, 1.0 if sel else 0.6))
