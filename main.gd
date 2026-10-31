extends Node2D
## Twin-stick touch controls, proof of concept. Everything runs locally and is drawn in code, so there is nothing to
## import. Left stick moves. Right stick acts: Attack shoots, Heal heals, Defend raises a shield, chosen by the three
## buttons above it. Tap the right stick to act on the nearest target; hold and drag to aim (aim assist pulls toward a
## target in a small cone).
##
## Throwaway PoC: the outcomes here (damage, healing, blocking) are decided in GDScript only to try the feel. In the real
## game the client would send the intention and the server would decide.

enum Mode { ATTACK, HEAL, DEFEND }

const WORLD := Rect2(-1200, -1200, 2400, 2400)
const SPEED: float = 220.0
const ASSIST_CONE: float = deg_to_rad(30.0) # half-angle where aim assist kicks in
const ASSIST_PULL: float = 0.65 # 0 = raw aim, 1 = snap fully onto the target
const RANGE := {Mode.ATTACK: 380.0, Mode.HEAL: 280.0, Mode.DEFEND: 420.0}
const COOLDOWN := {Mode.ATTACK: 0.35, Mode.HEAL: 0.9, Mode.DEFEND: 0.0}
const SHIELD_ARC: float = deg_to_rad(65.0) # half-angle the shield covers
const BOLT_SPEED: float = 560.0
const ENEMY_SHOT_SPEED: float = 240.0

var mode: int = Mode.ATTACK
var player := {"pos": Vector2.ZERO, "hp": 100.0, "max": 100.0, "facing": Vector2.UP}
var ally := {"pos": Vector2(-60, 60), "hp": 70.0, "max": 100.0}
var enemies: Array = []
var bolts: Array = [] # {pos, vel, life, friendly}
var floats: Array = [] # {pos, text, color, t}
var beams: Array = [] # {from, to, color, t}
var cd := {Mode.ATTACK: 0.0, Mode.HEAL: 0.0, Mode.DEFEND: 0.0}
var shield_on: bool = false
var aim_dir: Vector2 = Vector2.UP
var aim_target = null # Dictionary or null: what the assist locked onto this frame
var rocks: Array = []

var cam: Camera2D
var ui: Control
var move_stick: Control
var act_stick: Control
var modes: Control
var hud: Control

var _shot_path: String = ""
var _demo: bool = false
var _t: float = 0.0


func _ready() -> void:
	randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a == "--demo":
			_demo = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 260:
		rocks.append({"pos": Vector2(rng.randf_range(WORLD.position.x, WORLD.end.x),
				rng.randf_range(WORLD.position.y, WORLD.end.y)), "r": rng.randf_range(4, 14)})
	for i in 5:
		_spawn_enemy(Vector2(cos(i * 1.3) * 380.0, sin(i * 1.3) * 380.0 - 120.0))

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	ui.add_child(hud)
	move_stick = preload("res://move_stick.gd").new()
	ui.add_child(move_stick)
	act_stick = preload("res://action_stick.gd").new()
	ui.add_child(act_stick)
	modes = preload("res://mode_buttons.gd").new()
	modes.changed.connect(_on_mode)
	ui.add_child(modes)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_on_mode(Mode.ATTACK)


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var pad: float = 22.0
	move_stick.position = Vector2(pad, s.y - move_stick.size.y - pad * 2.0)
	act_stick.position = Vector2(s.x - act_stick.size.x - pad, s.y - act_stick.size.y - pad * 2.0)
	var mx: float = act_stick.position.x + act_stick.size.x / 2.0 - modes.size.x / 2.0
	modes.position = Vector2(minf(mx, s.x - modes.size.x - 8.0), act_stick.position.y - modes.size.y)


func _on_mode(m: int) -> void:
	mode = m
	act_stick.tint = modes.MODES[m].color
	act_stick.queue_redraw()


# --- world -------------------------------------------------------------------------------------------------------------

func _spawn_enemy(p: Vector2) -> void:
	enemies.append({"pos": p, "home": p, "hp": 60.0, "max": 60.0, "goal": p, "shoot": randf_range(1.0, 2.5),
			"dead": 0.0, "hit": 0.0})


func _process(dt: float) -> void:
	_t += dt
	if _demo:
		_drive_demo()
	_move_player(dt)
	_update_aim()
	_act(dt)
	_update_ally(dt)
	_update_enemies(dt)
	_update_bolts(dt)
	for f in floats:
		f.t += dt
		f.pos.y -= 30.0 * dt
	floats = floats.filter(func(f): return f.t < 0.9)
	for b in beams:
		b.t += dt
	beams = beams.filter(func(b): return b.t < 0.25)
	for k in cd:
		cd[k] = maxf(0.0, cd[k] - dt)
		modes.cooldowns[k] = cd[k] / COOLDOWN[k] if COOLDOWN[k] > 0.0 else 0.0
	cam.position = player.pos
	queue_redraw()
	modes.queue_redraw()
	hud.queue_redraw()
	if _shot_path != "" and _t > 2.2:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _move_player(dt: float) -> void:
	var v: Vector2 = move_stick.vec
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") # desktop testing
	if v == Vector2.ZERO and kb != Vector2.ZERO:
		v = kb
	if v != Vector2.ZERO:
		player.facing = v.normalized()
	var speed: float = SPEED * (0.5 if shield_on else 1.0)
	player.pos = (player.pos + v * speed * dt).clamp(WORLD.position, WORLD.end)


## Aim assist: with no drag, lock onto the best target in range; with a drag, pull the aim toward a target inside the
## cone around the drag direction, or keep the raw direction if there is none.
func _update_aim() -> void:
	var raw: Vector2 = act_stick.aim
	var cands: Array = _candidates()
	var best = null
	var best_score: float = INF
	for c in cands:
		var to: Vector2 = c.pos - player.pos
		var d: float = to.length()
		if d > RANGE[mode] or (d < 1.0 and not is_same(c, player)):
			continue
		var score: float
		if raw == Vector2.ZERO:
			score = d if mode != Mode.HEAL else c.hp / c.max # heal: most hurt first
		else:
			var ang: float = absf(raw.angle_to(to)) if d >= 1.0 else 0.0
			if ang > ASSIST_CONE:
				continue
			score = ang
		if score < best_score:
			best_score = score
			best = c
	aim_target = best
	if raw != Vector2.ZERO:
		aim_dir = raw.normalized()
		if best != null and not is_same(best, player):
			var to_t: Vector2 = (best.pos - player.pos).normalized()
			aim_dir = aim_dir.rotated(aim_dir.angle_to(to_t) * ASSIST_PULL)
	elif best != null and not is_same(best, player):
		aim_dir = (best.pos - player.pos).normalized()
	else:
		aim_dir = player.facing


func _candidates() -> Array:
	if mode == Mode.HEAL:
		var out: Array = [player]
		out.append(ally)
		return out
	return enemies.filter(func(e): return e.dead <= 0.0)


func _act(_dt: float) -> void:
	var tapped: bool = act_stick.consume_press()
	var holding: bool = act_stick.held()
	shield_on = mode == Mode.DEFEND and holding
	if mode == Mode.DEFEND or not (holding or tapped) or cd[mode] > 0.0:
		return
	cd[mode] = COOLDOWN[mode]
	if mode == Mode.ATTACK:
		bolts.append({"pos": player.pos + aim_dir * 20.0, "vel": aim_dir * BOLT_SPEED, "life": RANGE[mode] / BOLT_SPEED,
				"friendly": true})
	elif mode == Mode.HEAL:
		var t: Dictionary = aim_target if aim_target != null else player
		var amt: float = minf(18.0, t.max - t.hp)
		t.hp += amt
		beams.append({"from": player.pos, "to": t.pos, "color": Color(0.4, 1.0, 0.5), "t": 0.0})
		_float(t.pos, "+%d" % int(amt) if amt > 0.0 else "full", Color(0.5, 1.0, 0.55))


func _update_ally(dt: float) -> void:
	var want: Vector2 = player.pos - player.facing * 70.0 + player.facing.orthogonal() * 40.0
	if ally.hp > 0.0:
		ally.pos = ally.pos.move_toward(want, SPEED * 0.9 * dt) if ally.pos.distance_to(want) > 12.0 else ally.pos


func _update_enemies(dt: float) -> void:
	for e in enemies:
		e.hit = maxf(0.0, e.hit - dt)
		if e.dead > 0.0:
			e.dead -= dt
			if e.dead <= 0.0:
				e.hp = e.max
				e.pos = e.home
			continue
		if e.pos.distance_to(e.goal) < 6.0:
			e.goal = e.home + Vector2(randf_range(-120, 120), randf_range(-120, 120))
		e.pos = e.pos.move_toward(e.goal, 50.0 * dt)
		e.shoot -= dt
		if e.shoot <= 0.0:
			e.shoot = randf_range(1.6, 2.6)
			var tgt: Dictionary = ally if ally.hp > 0.0 and randf() < 0.3 else player
			if e.pos.distance_to(tgt.pos) < 360.0:
				var dir: Vector2 = (tgt.pos - e.pos).normalized()
				bolts.append({"pos": e.pos + dir * 16.0, "vel": dir * ENEMY_SHOT_SPEED, "life": 2.0, "friendly": false})


func _update_bolts(dt: float) -> void:
	var keep: Array = []
	for b in bolts:
		b.pos += b.vel * dt
		b.life -= dt
		var gone: bool = b.life <= 0.0
		if b.friendly:
			for e in enemies:
				if not gone and e.dead <= 0.0 and b.pos.distance_to(e.pos) < 18.0:
					e.hp -= 20.0
					e.hit = 0.12
					_float(e.pos, "-20", Color(1.0, 0.75, 0.4))
					if e.hp <= 0.0:
						e.dead = 4.0
						_float(e.pos, "down", Color(1, 1, 1))
					gone = true
		else:
			if not gone and shield_on and b.pos.distance_to(player.pos) < 46.0 \
					and absf(aim_dir.angle_to(b.pos - player.pos)) < SHIELD_ARC:
				_float(b.pos, "block", Color(0.6, 0.8, 1.0))
				gone = true
			elif not gone and b.pos.distance_to(player.pos) < 16.0:
				_hurt(player, 10.0)
				gone = true
			elif not gone and ally.hp > 0.0 and b.pos.distance_to(ally.pos) < 14.0:
				_hurt(ally, 10.0)
				gone = true
		if not gone:
			keep.append(b)
	bolts = keep


func _hurt(who: Dictionary, amt: float) -> void:
	who.hp = maxf(0.0, who.hp - amt)
	_float(who.pos, "-%d" % int(amt), Color(1.0, 0.4, 0.35))
	if is_same(who, player) and who.hp <= 0.0:
		who.hp = who.max # PoC: just pop back up
		_float(who.pos, "revived", Color(1, 1, 1))


func _float(p: Vector2, text: String, col: Color) -> void:
	floats.append({"pos": p + Vector2(randf_range(-6, 6), -24), "text": text, "color": col, "t": 0.0})


# --- drawing -----------------------------------------------------------------------------------------------------------

func _draw() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var view := Rect2(cam.get_screen_center_position() - vs / 2.0, vs).grow(40.0)
	draw_rect(view, Color(0.17, 0.2, 0.15))
	var g: float = 64.0
	var x0: float = floorf(view.position.x / g) * g
	var y0: float = floorf(view.position.y / g) * g
	var line := Color(0.22, 0.26, 0.19)
	var x: float = x0
	while x < view.end.x:
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), line, 1.0)
		x += g
	var y: float = y0
	while y < view.end.y:
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), line, 1.0)
		y += g
	draw_rect(WORLD, Color(0.5, 0.42, 0.3), false, 4.0)
	for r in rocks:
		if view.has_point(r.pos):
			draw_circle(r.pos, r.r, Color(0.3, 0.3, 0.27))

	# aim guide
	var col: Color = modes.MODES[mode].color
	if act_stick.held() and mode != Mode.DEFEND:
		draw_line(player.pos, player.pos + aim_dir * RANGE[mode], Color(col, 0.35), 3.0, true)
	if aim_target != null and not is_same(aim_target, player):
		draw_arc(aim_target.pos, 24.0, 0.0, TAU, 32, Color(col, 0.6 + 0.3 * sin(_t * 8.0)), 2.5, true)

	for e in enemies:
		if e.dead > 0.0:
			continue
		draw_circle(e.pos, 15.0, Color(1, 1, 1) if e.hit > 0.0 else Color(0.75, 0.22, 0.2))
		_bar(e.pos + Vector2(0, -26), e.hp / e.max, Color(0.9, 0.3, 0.25))

	if ally.hp > 0.0:
		draw_circle(ally.pos, 13.0, Color(0.3, 0.55, 0.9))
	else:
		draw_arc(ally.pos, 13.0, 0.0, TAU, 24, Color(0.3, 0.55, 0.9, 0.5), 2.0, true)
	_bar(ally.pos + Vector2(0, -24), ally.hp / ally.max, Color(0.4, 0.85, 0.45))

	draw_circle(player.pos, 16.0, Color(0.92, 0.84, 0.66))
	draw_line(player.pos, player.pos + player.facing * 22.0, Color(0.2, 0.15, 0.1), 3.0, true)
	if shield_on:
		var a: float = aim_dir.angle()
		draw_arc(player.pos, 40.0, a - SHIELD_ARC, a + SHIELD_ARC, 24, Color(0.45, 0.7, 1.0, 0.85), 7.0, true)

	for b in bolts:
		draw_circle(b.pos, 5.0 if b.friendly else 6.0, Color(1.0, 0.85, 0.4) if b.friendly else Color(0.85, 0.3, 0.9))
	for b in beams:
		draw_line(b.from, b.to, Color(b.color, 1.0 - b.t / 0.25), 4.0, true)
	var font: Font = ThemeDB.fallback_font
	for f in floats:
		draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(f.color, 1.0 - f.t / 0.9))


func _bar(c: Vector2, frac: float, col: Color) -> void:
	var w: float = 30.0
	draw_rect(Rect2(c - Vector2(w / 2.0, 2.0), Vector2(w, 4.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(c - Vector2(w / 2.0, 2.0), Vector2(w * clampf(frac, 0.0, 1.0), 4.0)), col)


func _draw_hud() -> void:
	var font: Font = ThemeDB.fallback_font
	var y: float = 24.0
	for row in [["You", player, Color(0.92, 0.84, 0.66)], ["Ally", ally, Color(0.3, 0.55, 0.9)]]:
		hud.draw_string(font, Vector2(16, y + 12), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, row[2])
		hud.draw_rect(Rect2(60, y, 160, 14), Color(0, 0, 0, 0.55))
		hud.draw_rect(Rect2(60, y, 160 * row[1].hp / row[1].max, 14), Color(0.4, 0.85, 0.45))
		y += 22.0
	var tip: String = ["ATTACK: tap = shoot nearest, hold + drag = aim",
			"HEAL: tap = most hurt, drag toward ally to pick",
			"DEFEND: hold to raise shield, drag to turn it"][mode]
	hud.draw_string(font, Vector2(16, y + 14), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))


## --demo: fakes both thumbs so a headless run shows something happening (used for the screenshot check).
func _drive_demo() -> void:
	move_stick.vec = Vector2(cos(_t * 0.7), sin(_t * 0.7)) * 0.8
	if _t > 1.2 and not act_stick.held():
		act_stick._finger = 99
		act_stick.aim = Vector2(0.9, -0.4)
		act_stick.queue_redraw()
