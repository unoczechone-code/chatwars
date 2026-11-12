# Bullet — used for both player shots and enemy shots. Behaviour is set at spawn
# time; the node frees itself on hit, timeout, or leaving the playfield.
extends Area2D
class_name Bullet

signal hit()

var velocity := Vector2.ZERO
var damage := 10
var lifetime := 2.0
var radius := 7.0
var friendly := true
var color := Color(0.45, 0.85, 1.0)

var _age := 0.0
var _spent := false


func setup(p_pos: Vector2, p_vel: Vector2, p_damage: int, p_friendly: bool, p_radius := 7.0) -> void:
	position = p_pos
	velocity = p_vel
	damage = p_damage
	friendly = p_friendly
	radius = p_radius
	color = Color(0.45, 0.85, 1.0) if friendly else Color(1.0, 0.55, 0.4)


func _ready() -> void:
	add_to_group("bullets")
	z_index = 6


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	position += velocity * delta

	if _age > lifetime or position.y < -80.0 or position.y > 1400.0 \
			or position.x < -80.0 or position.x > 800.0:
		queue_free()
		return

	if not friendly:
		return

	# Player bullets hit the nearest overlapping enemy.
	var best: Enemy = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy.dead:
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < pow(radius + enemy.radius, 2) and d < best_d:
			best_d = d
			best = enemy
	if best != null:
		best.take_damage(damage)
		_spent = true
		hit.emit()
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1, 1, 1, 0.85))
