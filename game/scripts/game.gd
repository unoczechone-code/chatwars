# Game — one run from start to finish. Owns the clock, waves, spawning, and the
# win/lose decision. Everything is rebuilt per run; nothing survives a restart.
extends Node2D
class_name Game

signal run_finished(won: bool, score: int, time: float)
signal upgrade_requested
signal stats_changed

const EnemyScript := preload("res://scripts/enemy.gd")
const BulletScript := preload("res://scripts/bullet.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BalanceScript := preload("res://scripts/balance.gd")
const RunStateScript := preload("res://scripts/run_state.gd")

var balance: Balance
var state: RunState
var player: Player

var _rng := RandomNumberGenerator.new()
var _spawn_t := 0.0
var _upgrade_times: Array[float] = []
var _paused := false
var _boss: Enemy = null

@onready var _field: Node2D = $Field


func _ready() -> void:
	balance = BalanceScript.new()
	_rng.randomize()
	start_run()
	var hud := $Hud
	if hud != null:
		hud.bind(self)
		hud.pause_pressed.connect(toggle_pause)


func toggle_pause() -> void:
	if state == null or state.finished:
		return
	_paused = not _paused
	var hud := $Hud
	if hud != null:
		hud.set_paused_visible(_paused)


func start_run(seed_value: int = 0) -> void:
	for c in _field.get_children():
		c.queue_free()
	_boss = null
	_paused = false
	_upgrade_times = balance.upgrade_times.duplicate()
	_spawn_t = 0.0

	if seed_value != 0:
		_rng.seed = seed_value

	state = RunStateScript.new(balance)

	# A run must always start unpaused, even if the previous one ended while the
	# upgrade prompt or pause overlay had the clock stopped.
	_paused = false
	var hud_node := get_node_or_null("Hud")
	if hud_node != null:
		hud_node.set_paused_visible(false)

	player = PlayerScript.new()
	player.state = state
	player.battlefield = self
	player.position = Vector2(360, 1080)
	_field.add_child(player)
	player.hp_changed.connect(_on_player_hp_changed)

	stats_changed.emit()


func set_paused(v: bool) -> void:
	_paused = v


func is_paused() -> bool:
	return _paused


func spawn_player_bullet(pos: Vector2, vel: Vector2, dmg: int) -> void:
	if _count_group("bullets") >= balance.max_projectiles:
		return
	var b := BulletScript.new()
	b.setup(pos, vel, dmg, true)
	_field.add_child(b)


func spawn_enemy_bullet(pos: Vector2, vel: Vector2, dmg: int) -> void:
	if _count_group("bullets") >= balance.max_projectiles:
		return
	var b := BulletScript.new()
	b.setup(pos, vel, dmg, false, 9.0)
	_field.add_child(b)


func _count_group(name: String) -> int:
	return get_tree().get_nodes_in_group(name).size()


func _physics_process(delta: float) -> void:
	if state == null or state.finished or _paused:
		return

	state.time += delta
	var new_wave := state.wave_for_time(state.time)
	if new_wave != state.wave:
		state.wave = new_wave
		stats_changed.emit()

	# Boss appears once, at the start of the third wave. This is checked before the
	# upgrade prompt so a pending upgrade can never suppress the boss spawn.
	if not state.boss_spawned and state.time >= balance.boss_spawn_time:
		_spawn_boss()

	# Scheduled upgrade picks pause the run.
	if not _upgrade_times.is_empty() and state.time >= _upgrade_times[0]:
		_upgrade_times.remove_at(0)
		_paused = true
		upgrade_requested.emit()
		return

	_spawn_t -= delta
	if _spawn_t <= 0.0 and not state.boss_spawned:
		_spawn_t = _current_spawn_interval()
		_spawn_enemy()

	_check_end()


func _current_spawn_interval() -> float:
	var t := clampf(state.time / balance.run_duration, 0.0, 1.0)
	return lerpf(balance.spawn_interval_start, balance.spawn_interval_end, t)


func _spawn_enemy() -> void:
	if _count_group("enemies") >= balance.max_enemies:
		return

	var roll := _rng.randf()
	var cfg := {
		"kind": Enemy.KIND_FALLER,
		"hp": balance.faller_hp,
		"speed": balance.faller_speed,
		"damage": balance.faller_damage,
		"score": balance.faller_score,
		"radius": 26.0,
	}

	if state.wave >= 2 and roll < 0.35:
		cfg = {
			"kind": Enemy.KIND_WEAVER,
			"hp": balance.weaver_hp,
			"speed": balance.weaver_speed,
			"damage": balance.weaver_damage,
			"score": balance.weaver_score,
			"radius": 22.0,
			"amplitude": balance.weaver_amplitude,
			"frequency": balance.weaver_frequency,
		}
	elif state.wave >= 3 and roll > 0.72:
		cfg = {
			"kind": Enemy.KIND_BRUTE,
			"hp": balance.brute_hp,
			"speed": balance.brute_speed,
			"damage": balance.brute_damage,
			"score": balance.brute_score,
			"radius": 38.0,
		}

	var x := _rng.randf_range(60.0, 660.0)
	var e: Enemy = EnemyScript.new()
	e.setup(cfg)
	e.position = Vector2(x, -60.0)
	e.died.connect(_on_enemy_died)
	_field.add_child(e)


func _spawn_boss() -> void:
	state.boss_spawned = true
	state.boss_alive = true
	var cfg := {
		"kind": Enemy.KIND_BOSS,
		"hp": balance.boss_hp,
		"speed": balance.boss_speed,
		"damage": balance.boss_damage,
		"score": balance.boss_score,
		"radius": 90.0,
		"burst_count": balance.boss_burst_count,
		"burst_interval": balance.boss_burst_interval,
		"sweep_interval": balance.boss_sweep_interval,
	}
	_boss = EnemyScript.new()
	_boss.setup(cfg)
	_boss.position = Vector2(360, -120.0)
	_boss.died.connect(_on_enemy_died)
	_field.add_child(_boss)


func _on_enemy_died(enemy: Enemy, score_value: int) -> void:
	state.score += score_value
	if enemy == _boss:
		state.boss_alive = false
		_boss = null
		_finish(true)
	stats_changed.emit()


func _on_player_hp_changed(_hp: int, _max_hp: int) -> void:
	stats_changed.emit()


func _check_end() -> void:
	if state.finished:
		return
	if state.hp <= 0:
		_finish(false)
	elif state.time >= balance.run_duration:
		_finish(false)


func _finish(won: bool) -> void:
	if state.finished:
		return
	state.finished = true
	_paused = true
	run_finished.emit(won, state.score, state.time)


## Called by the UI after an upgrade is chosen; resumes the clock.
func apply_upgrade(id: String) -> void:
	if state != null and id != "":
		state.add_upgrade(id)
	_paused = false
	stats_changed.emit()


## One-shot AoE around the player. Single explicit button, no charges.
func do_aoe() -> void:
	if state == null or state.finished or _paused or player == null:
		return
	var radius := state.aoe_radius()
	var dmg := state.aoe_damage()
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy.dead:
			continue
		if player.global_position.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(dmg)
	_aoe_flash(player.global_position, radius)


func _aoe_flash(pos: Vector2, radius: float) -> void:
	var ring := _Ring.new()
	ring.position = pos
	ring.radius = radius
	_field.add_child(ring)


# Short-lived expanding ring drawn at the AoE origin.
class _Ring extends Node2D:
	var radius := 100.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.35:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - _t / 0.35, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.4, 0.8, 1.0, a * 0.8), 6.0)
