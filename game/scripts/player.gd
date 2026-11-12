# Player — drag to move inside the lower third, auto-attacks the nearest enemy.
extends Area2D
class_name Player

signal hp_changed(hp: int, max_hp: int)
signal hurt()

const RADIUS := 30.0

var state: RunState
var bounds := Rect2(40, 800, 640, 420)  # move zone in viewport coords

var _attack_t := 0.0
var _invuln := 0.0
var _drag_offset := Vector2.ZERO
var _dragging := false
var _flash := 0.0

var battlefield: Node = null


func _ready() -> void:
	add_to_group("player")
	z_index = 7


## Convert a screen-space point into the play field, clamping to the move zone.
func _set_target(screen_pos: Vector2) -> void:
	position = Vector2(
		clampf(screen_pos.x, bounds.position.x, bounds.end.x),
		clampf(screen_pos.y, bounds.position.y, bounds.end.y)
	)


func _unhandled_input(event: InputEvent) -> void:
	if state == null or state.finished:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_dragging = true
			_drag_offset = position - _to_field(e.position)
		else:
			_dragging = false
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _dragging:
			_set_target(_to_field(e.position) + _drag_offset)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_dragging = mb.pressed
		if mb.pressed:
			_set_target(_to_field(mb.position))
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_set_target(_to_field(mm.position))


## Map a raw input position to field coordinates, accounting for stretch/canvas transform.
func _to_field(raw: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return raw
	var xf := vp.get_canvas_transform()
	return xf.affine_inverse() * raw


func _physics_process(delta: float) -> void:
	if state == null or state.finished:
		return

	if _invuln > 0.0:
		_invuln -= delta
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()

	_attack_t -= delta
	if _attack_t <= 0.0:
		var target := _nearest_enemy()
		if target != null:
			_attack_t = state.attack_interval()
			_fire_at(target)

	# Contact damage.
	if _invuln <= 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			var enemy := e as Enemy
			if enemy == null or enemy.dead:
				continue
			if global_position.distance_to(enemy.global_position) < RADIUS + enemy.radius * 0.8:
				_hurt(enemy.contact_damage)
				break


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy.dead:
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _fire_at(target: Enemy) -> void:
	if battlefield == null:
		return
	var dir := (target.global_position - global_position).normalized()
	battlefield.spawn_player_bullet(global_position, dir * 1150.0, state.damage())


func _hurt(amount: int) -> void:
	if _invuln > 0.0 or state.finished:
		return
	_invuln = 0.35
	_flash = 0.18
	state.take_damage(amount)
	hp_changed.emit(state.hp, state.max_hp)
	hurt.emit()
	queue_redraw()


func _draw() -> void:
	var body := Color(0.93, 0.95, 0.99) if _flash <= 0.0 else Color(1.0, 0.45, 0.45)
	# Porcelain robot: round head, boxy body.
	draw_circle(Vector2(0, -12), RADIUS * 0.62, body)
	draw_rect(Rect2(-RADIUS * 0.62, -2, RADIUS * 1.24, RADIUS * 0.95), body, true)
	draw_circle(Vector2(0, -12), RADIUS * 0.62, Color(0.5, 0.58, 0.72), false, 2.5)
	# Eyes
	draw_circle(Vector2(-8, -16), 4.5, Color(0.1, 0.13, 0.22))
	draw_circle(Vector2(8, -16), 4.5, Color(0.1, 0.13, 0.22))
	# Chest light shows invulnerability state.
	var chest := Color(0.25, 0.56, 0.83) if _invuln <= 0.0 else Color(1, 1, 1, 0.6)
	draw_rect(Rect2(-9, 6, 18, 14), chest, true)
