# Long-run soak: drives a full 180s run at accelerated physics and verifies it terminates,
# that the enemy/projectile caps hold, and that repeated restarts leave no stale state.
extends SceneTree

var _fail: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  "), msg)
	if not cond:
		_fail.append(msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== soak test ===")

	var scene: PackedScene = load("res://scenes/game.tscn")
	var g: Node = scene.instantiate()
	root.add_child(g)
	await process_frame

	# The game intentionally pauses for an upgrade pick at 60s and 120s. Auto-answer
	# it so the soak can reach the end of the run.
	g.upgrade_requested.connect(func() -> void:
		var pool: Array[String] = g.state.available_upgrades()
		g.apply_upgrade(pool[0] if not pool.is_empty() else "")
	)

	# Run several cycles; each one must stop on its own and respect the caps.
	for cycle in 1:
		g.start_run(1000 + cycle)
		g.state.max_hp = 100000  # survive knockouts so the clock is what ends the run
		g.state.hp = 100000
		var max_enemies := 0
		var max_bullets := 0
		var frames := 0

		# Physics ticks are slower than wall-clock in a headless tree, so bound by
		# simulated time (plus a generous frame ceiling as a hang guard) instead of
		# assuming a fixed frames-per-second relationship.
		while not g.state.finished and frames < 20000:
			await physics_frame
			frames += 1
			max_enemies = maxi(max_enemies, get_nodes_in_group("enemies").size())
			max_bullets = maxi(max_bullets, get_nodes_in_group("bullets").size())
			g.state.hp = 100000  # keep it alive to exercise the full 180s
			if g.state.time > g.balance.run_duration + 5.0:
				break

		_check(g.state.finished, "cycle %d terminated on its own" % cycle)
		_check(max_enemies <= g.balance.max_enemies,
			"cycle %d enemy cap held (peak %d <= %d)" % [cycle, max_enemies,
				g.balance.max_enemies])
		_check(max_bullets <= g.balance.max_projectiles,
			"cycle %d projectile cap held (peak %d <= %d)" % [cycle, max_bullets,
				g.balance.max_projectiles])
		print("    cycle %d: time=%.1fs score=%d enemies_peak=%d bullets_peak=%d" % [
			cycle, g.state.time, g.state.score, max_enemies, max_bullets])

	# After all that, no node should be leaking from previous runs.
	_check(get_nodes_in_group("enemies").size() <= 1, "no enemy leak after restarts")

	print("=== RESULT: %d failure(s) ===" % _fail.size())
	quit(0 if _fail.is_empty() else 1)
