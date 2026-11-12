# Enemy — one node type for all kinds, configured from data. Drawn procedurally
# so the MVP needs no art pipeline; swap in sprites later behind the same API.
extends Area2D
class_name Enemy

signal died(enemy: Enemy, score_value: int)

const KIND_FALLER := "faller"
const KIND_WEAVER := "weaver"
const KIND_BRUTE := "brute"
const KIND_BOSS := "boss"

var kind := KIND_FALLER
var hp := 1
var max_hp := 1
var speed := 100.0
var contact_damage := 5
var score_value := 10
var radius := 26.0

var _t := 0.0
var _base_x := 0.0
var _amp := 0.0
var _freq := 1.0
var _is_boss := false

# Boss attack timers.
var _burst_t := 0.0
var _sweep_t := 0.0
var _boss_burst_count := 7

var dead := false


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
	_boss_burst_count = int(cfg.get("burst_count", 7))
	_base_x = position.x
	_burst_t = float(cfg.get("burst_interval", 2.6))
	_sweep_t = float(cfg.get("sweep_interval", 6.5))


func _ready() -> void:
	add_to_group("enemies")
	z_index = 5


func _process(delta: float) -> void:
	if dead:
		return
	_t += delta

	if _is_boss:
		# Boss descends to a holding line then drifts side to side.
		if position.y < 240.0:
			position.y += speed * delta
		else:
			_base_x += speed * 0.8 * delta
			position.x = _base_x
		_burst_t -= delta
		_sweep_t -= delta
		if _burst_t <= 0.0:
			_burst_t = float(_burst_interval_cfg())
			_emit_burst()
		if _sweep_t <= 0.0:
			_sweep_t = float(_sweep_interval_cfg())
			_emit_sweep()
	else:
		position.y += speed * delta
		if _amp > 0.0:
			position.x = _base_x + sin(_t * _freq) * _amp

	queue_redraw()

	# Left the playfield bottom.
	if position.y > 1450.0:
		_despawn()


var _burst_interval := 2.6
var _sweep_interval := 6.5


func _burst_interval_cfg() -> float:
	return _burst_interval


func _sweep_interval_cfg() -> float:
	return _sweep_interval


func _emit_burst() -> void:
	# Radial telegraph-then-fire is represented by a downward fan of projectiles.
	var battlefield := get_parent()
	if battlefield == null:
		return
	for i in _boss_burst_count:
		var angle := deg_to_rad(lerpf(60.0, 120.0, float(i) / maxf(1.0, _boss_burst_count - 1)))
		battlefield.spawn_enemy_bullet(global_position, Vector2.RIGHT.rotated(angle) * 320.0, 12)


func _emit_sweep() -> void:
	var battlefield := get_parent()
	if battlefield == null:
		return
	for i in 5:
		var offset := Vector2(lerpf(-160.0, 160.0, i / 4.0), 0.0)
		battlefield.spawn_enemy_bullet(global_position + offset, Vector2(0, 1) * 260.0, 10)


func take_damage(amount: int) -> void:
	if dead:
		return
	hp -= amount
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

	if _is_boss:
		# Boxy boss silhouette with an eye slit.
		var r := radius
		draw_rect(Rect2(-r, -r * 0.9, r * 2.0, r * 1.8), col, true)
		draw_rect(Rect2(-r, -r * 0.9, r * 2.0, r * 1.8), col.darkened(0.35), false, 4.0)
		draw_rect(Rect2(-r * 0.6, -r * 0.25, r * 1.2, r * 0.35), Color(0.1, 0.1, 0.16), true)
	else:
		draw_circle(Vector2.ZERO, radius, col)
		draw_circle(Vector2.ZERO, radius, col.darkened(0.35), false, 3.0)
		# Two eyes so the direction reads clearly.
		draw_circle(Vector2(-radius * 0.3, -radius * 0.15), radius * 0.16, Color(0.1, 0.1, 0.16))
		draw_circle(Vector2(radius * 0.3, -radius * 0.15), radius * 0.16, Color(0.1, 0.1, 0.16))

	# Damage feedback: brighten with missing HP.
	if hp < max_hp:
		var t := 1.0 - float(hp) / float(maxf(1, max_hp))
		draw_arc(Vector2.ZERO, radius + 6.0, -PI / 2, -PI / 2 + TAU * t, 24,
			Color(1, 1, 1, 0.75), 3.0)
