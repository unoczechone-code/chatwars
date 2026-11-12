# Gameplay test: drives the real Game scene headless and asserts the MVP rules.
extends SceneTree

var _fail: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  "), msg)
	if not cond:
		_fail.append(msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== MVP gameplay test ===")

	var sm: Node = root.get_node_or_null("SaveManager")
	_check(sm != null, "SaveManager autoload present")
	if sm == null:
		quit(1)
		return

	var scene: PackedScene = load("res://scenes/game.tscn")
	_check(scene != null, "game.tscn loads")
	if scene == null:
		quit(1)
		return

	var g: Node = scene.instantiate()
	root.add_child(g)
	await process_frame

	_check(g.state != null, "run state created")
	_check(g.balance.run_duration == 180.0, "run is 180s")
	_check(g.balance.wave_duration == 60.0, "wave is 60s")
	_check(g.state.wave == 1, "starts on wave 1")
	_check(g.player != null, "player spawned")

	# Wave boundaries are pure clock math — verify the mapping directly.
	_check(g.state.wave_for_time(0.0) == 1, "t=0 -> wave 1")
	_check(g.state.wave_for_time(59.9) == 1, "t=59.9 -> wave 1")
	_check(g.state.wave_for_time(60.0) == 2, "t=60 -> wave 2")
	_check(g.state.wave_for_time(120.0) == 3, "t=120 -> wave 3")

	# Upgrade availability respects stack limits and excludes maxed entries.
	_check(g.state.available_upgrades().size() == 6, "6 upgrades available at start")
	for i in g.balance.max_stack_speed:
		g.state.add_upgrade("speed")
	_check(not g.state.available_upgrades().has("speed"), "maxed upgrade excluded from pool")
	_check(g.state.available_upgrades().size() == 5, "pool shrinks to 5 after maxing speed")

	# Damage/HP effects actually change numbers.
	var dmg_before: int = g.state.damage()
	g.state.add_upgrade("damage")
	_check(g.state.damage() > dmg_before, "damage upgrade raises damage")

	# Spawn one of each enemy kind and confirm they take damage and die with score.
	for kind in ["faller", "weaver", "brute"]:
		var e = load("res://scripts/enemy.gd").new()
		e.setup({"kind": kind, "hp": 10, "speed": 0.0, "damage": 1, "score": 7, "radius": 20.0})
		e.position = Vector2(360, 500)
		g._field.add_child(e)
		e.died.connect(g._on_enemy_died)
		await process_frame
		e.take_damage(5)
		_check(e.hp == 5, "%s takes damage" % kind)
		e.take_damage(100)
		# The node frees itself on death; read the flag captured before that.
		var was_dead: bool = e.dead
		await process_frame
		_check(was_dead, "%s dies at 0 hp" % kind)

	_check(g.state.score >= 21, "kills awarded score (got %d)" % g.state.score)

	# Boss spawns at 120s and killing it ends the run as a win.
	g.start_run(55)
	await physics_frame
	var won := [false]
	g.run_finished.connect(func(w: bool, _s: int, _t: float) -> void:
		won[0] = w
	)
	g.state.time = 119.9
	g._paused = false
	g._upgrade_times.clear()
	await physics_frame
	_check(g.state.boss_spawned == false, "boss not yet at 119.9s")

	g.state.time = 120.0
	await physics_frame
	await physics_frame
	_check(g.state.boss_spawned, "boss spawns at 120s")

	if g._boss != null:
		g._boss.take_damage(100000)
	await physics_frame
	_check(won[0], "killing the boss wins the run")

	# Timer expiry loses the run.
	g.start_run(1234)
	await physics_frame
	g._upgrade_times.clear()
	var lost := [false]
	g.run_finished.connect(func(w: bool, _s: int, _t: float) -> void:
		if not w:
			lost[0] = true
	)
	g.state.time = 180.0
	await physics_frame
	await physics_frame
	await physics_frame
	_check(lost[0], "timer expiry ends the run as a loss")

	# AoE damages enemies in radius only.
	g.start_run(99)
	await physics_frame
	var near = load("res://scripts/enemy.gd").new()
	near.setup({"kind": "brute", "hp": 500, "speed": 0.0, "damage": 1, "score": 1, "radius": 20.0})
	near.position = g.player.position + Vector2(40, 0)
	g._field.add_child(near)
	var far = load("res://scripts/enemy.gd").new()
	far.setup({"kind": "brute", "hp": 500, "speed": 0.0, "damage": 1, "score": 1, "radius": 20.0})
	far.position = g.player.position + Vector2(900, 0)
	g._field.add_child(far)
	await physics_frame
	g.do_aoe()
	_check(near.hp < 500, "AoE damages enemy inside radius")
	_check(far.hp == 500, "AoE does not damage enemy outside radius")

	# Restart leaves no stale enemies behind.
	var before := get_nodes_in_group("enemies").size()
	g.start_run(7)
	await physics_frame
	await physics_frame
	_check(get_nodes_in_group("enemies").size() <= 2,
		"restart clears old enemies (before=%d after=%d)" % [before,
			get_nodes_in_group("enemies").size()])

	print("=== RESULT: %d failure(s) ===" % _fail.size())
	quit(0 if _fail.is_empty() else 1)
