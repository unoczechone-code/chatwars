# Enemy — all kinds share one node, configured from data. Silhouettes differ by shape,
# not just colour, so the three types are distinguishable at a glance on a small screen.
extends Area2D
class_name Enemy

signal died(enemy: Enemy, score_value: int)

const KIND_FALLER := "faller"
const KIND_WEAVER := "weaver"
const KIND_BRUTE := "brute"
const KIND_BOSS := "boss"

# Boss attack phases.
const ATK_NONE := ""
const ATK_FAN := "fan"
const ATK_SWEEP := "sweep"

var kind := KIND_FALLER
var hp := 1
var max_hp := 1
var speed := 100.0
var contact_damage := 5
var score_value := 10
var radius := 26.0

var dead := false

var _t := 0.0
var _base_x := 0.0
var _amp := 0.0
var _freq := 1.0
var _is_boss := false
var _flash := 0.0

# Boss state
var _burst_wait := 0.0
var _sweep_wait := 0.0
var _burst_period := 2.6
var _sweep_period := 6.5
var _burst_count := 7
var _telegraph := ATK_NONE
var _telegraph_t := 0.0
var _telegraph_dur := 0.0
var _drift_dir := 1.0


func _init() -> void:
	add_to_group("enemies")


func setup(cfg: Dictionary) -> void:
	kind = String(cfg.get("kind", KIND_FALLER))
	hp = int(cfg.get("hp", 10))
	max_hp = hp
	speed = float(cfg.get("speed", 100.0))
	contact_damage = int(cfg.get("damage", 5))
	score_value = int(cfg.get("score", 10))
	radius = float(cfg.get("radius", 26.0))
	_amp = float(cfg.get("amplitude", 0.0))
	_freq = float(cfg.get("frequency", 1.0))
	_is_boss = kind == KIND_BOSS
	_burst_count = int(cfg.get("burst_count", 7))
	_burst_period = float(cfg.get("burst_interval", 2.6))
	_sweep_period = float(cfg.get("sweep_interval", 6.5))
	_base_x = position.x
	_burst_wait = _burst_period
	_sweep_wait = _sweep_period
	z_index = 5


func is_telegraphing() -> bool:
	return _telegraph != ATK_NONE


func _process(delta: float) -> void:
	if dead:
		return
	_t += delta
	if _flash > 0.0:
		_flash -= delta

	if _is_boss:
		_process_boss(delta)
	else:
		position.y += speed * delta
		if _amp > 0.0:
			position.x = _base_x + sin(_t * _freq) * _amp
		if position.y > 1450.0:
			_despawn()

	queue_redraw()


func _process_boss(delta: float) -> void:
	# Descend, then patrol sideways inside the top band.
	if position.y < 250.0:
		position.y += speed * delta
	else:
		position.x += speed * 0.9 * _drift_dir * delta
		if position.x < 140.0:
			position.x = 140.0
			_drift_dir = 1.0
		elif position.x > 580.0:
			position.x = 580.0
			_drift_dir = -1.0

	# A telegraph in progress must resolve before any new attack starts.
	if _telegraph != ATK_NONE:
		_telegraph_t -= delta
		if _telegraph_t <= 0.0:
			_fire(_telegraph)
			_telegraph = ATK_NONE
		return

	_burst_wait -= delta
	_sweep_wait -= delta

	if _sweep_wait <= 0.0 and _sweep_wait <= _burst_wait:
		_sweep_wait = _sweep_period
		_begin_telegraph(ATK_SWEEP, 0.85)
	elif _burst_wait <= 0.0:
		_burst_wait = _burst_period
		_begin_telegraph(ATK_FAN, 0.6)


func _begin_telegraph(atk: String, duration: float) -> void:
	_telegraph = atk
	_telegraph_t = duration
	_telegraph_dur = duration


func _fire(atk: String) -> void:
	# The enemy lives under Game/Field, so the battle API is on the grandparent.
	var battlefield := _battlefield()
	if battlefield == null:
		return
	if atk == ATK_FAN:
		for i in _burst_count:
			var t := float(i) / maxf(1.0, _burst_count - 1)
			var angle := deg_to_rad(lerpf(55.0, 125.0, t))
			battlefield.spawn_enemy_bullet(
				global_position, Vector2.RIGHT.rotated(angle) * 340.0, 12)
	else:
		# Sweep: a row of shots falling across the boss's width.
		for i in 5:
			var offset := Vector2(lerpf(-170.0, 170.0, i / 4.0), 0.0)
			battlefield.spawn_enemy_bullet(
				global_position + offset, Vector2(0, 1) * 300.0, 10)


## Walks up to the node that exposes spawn_enemy_bullet (the Game node).
func _battlefield() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("spawn_enemy_bullet"):
			return n
		n = n.get_parent()
	return null


func take_damage(amount: int) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.12
	if hp <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	died.emit(self, score_value)
	queue_free()


func _despawn() -> void:
	dead = true
	queue_free()


func _draw() -> void:
	var col := Color(0.95, 0.45, 0.35)
	match kind:
		KIND_FALLER:
			col = Color(0.95, 0.45, 0.35)
		KIND_WEAVER:
			col = Color(0.55, 0.85, 0.95)
		KIND_BRUTE:
			col = Color(0.75, 0.55, 0.95)
		KIND_BOSS:
			col = Color(0.98, 0.30, 0.45)
	if _flash > 0.0:
		col = col.lerp(Color(1, 1, 1), 0.55)

	match kind:
		KIND_FALLER:
			# Teardrop pointing at the player: reads as "falling".
			var pts := PackedVector2Array([
				Vector2(0, radius * 1.15),
				Vector2(-radius, -radius * 0.6),
				Vector2(0, -radius),
				Vector2(radius, -radius * 0.6),
			])
			draw_colored_polygon(pts, col)
			draw_polyline(pts, col.darkened(0.4), 3.0)
		KIND_WEAVER:
			# Diamond: wide and fast-looking.
			var pts := PackedVector2Array([
				Vector2(0, -radius), Vector2(radius, 0),
				Vector2(0, radius), Vector2(-radius, 0),
			])
			draw_colored_polygon(pts, col)
			draw_polyline(pts, col.darkened(0.4), 3.0)
		KIND_BRUTE:
			# Heavy square with corner bolts.
			draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), col, true)
			draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0),
				col.darkened(0.45), false, 5.0)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					draw_circle(Vector2(sx * radius * 0.62, sy * radius * 0.62),
						radius * 0.13, col.darkened(0.5))
		KIND_BOSS:
			var r := radius
			draw_rect(Rect2(-r, -r * 0.85, r * 2.0, r * 1.7), col, true)
			draw_rect(Rect2(-r, -r * 0.85, r * 2.0, r * 1.7), col.darkened(0.4), false, 5.0)
			# Eye slit brightens while charging an attack.
			var eye := Color(1, 0.9, 0.4) if _telegraph != ATK_NONE else Color(0.12, 0.1, 0.18)
			draw_rect(Rect2(-r * 0.62, -r * 0.22, r * 1.24, r * 0.34), eye, true)
			# Horns distinguish it from a brute.
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r, -r * 0.85), Vector2(-r * 0.72, -r * 1.25), Vector2(-r * 0.45, -r * 0.85),
			]), col.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([
				Vector2(r, -r * 0.85), Vector2(r * 0.72, -r * 1.25), Vector2(r * 0.45, -r * 0.85),
			]), col.darkened(0.25))

	# Health ring for anything damaged but alive.
	if hp < max_hp and hp > 0:
		var t := 1.0 - float(hp) / float(maxf(1, max_hp))
		draw_arc(Vector2.ZERO, radius + 7.0, -PI / 2, -PI / 2 + TAU * t, 28,
			Color(1, 1, 1, 0.7), 3.0)

	# Telegraph ring: shrinks toward the body as the attack lands, making timing readable.
	if _telegraph != ATK_NONE and _telegraph_dur > 0.0:
		var p := 1.0 - (_telegraph_t / _telegraph_dur)
		draw_arc(Vector2.ZERO, radius + 26.0 * (1.0 - p), 0.0, TAU, 40,
			Color(1.0, 0.85, 0.3, 0.9), 5.0)
