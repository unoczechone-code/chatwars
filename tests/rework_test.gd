# Verifies the behaviours added in the rework: boss telegraphs, auto-pause on
# interruption, AoE cooldown, and that audio/haptics respect the settings toggles.
extends SceneTree

var _fail: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  "), msg)
	if not cond:
		_fail.append(msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== rework behaviour test ===")

	var sm: Node = root.get_node_or_null("SaveManager")
	var audio: Node = root.get_node_or_null("Audio")
	_check(sm != null, "SaveManager autoload present")
	_check(audio != null, "Audio autoload present")
	if sm == null or audio == null:
		quit(1)
		return

	# --- Audio respects the settings toggles -----------------------------
	_check(audio._sfx_enabled(), "sfx enabled by default")
	sm.set_setting("sfx", false)
	_check(not audio._sfx_enabled(), "sfx disabled by setting")
	sm.set_setting("sfx", true)

	_check(audio._haptics_enabled(), "haptics enabled by default")
	sm.set_setting("haptics", false)
	_check(not audio._haptics_enabled(), "haptics disabled by setting")
	sm.set_setting("haptics", true)

	var missing: Array[String] = []
	for id in audio.SOUNDS.keys():
		if not audio._streams.has(id):
			missing.append(id)
	_check(missing.is_empty(), "all 6 SFX loaded (missing: %s)" % str(missing))
	_check(audio.SOUNDS.size() >= 4, "at least 4 distinct SFX (got %d)" % audio.SOUNDS.size())

	# --- Boss telegraphs --------------------------------------------------
	var g: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	await physics_frame
	await physics_frame

	g.state.time = 120.5
	g._upgrade_times.clear()
	g.state.hp = 100000
	await physics_frame
	await physics_frame
	await physics_frame
	_check(g.state.boss_spawned, "boss spawned past 120s")

	var boss = g._boss
	_check(boss != null, "boss node exists")
	if boss != null:
		_check(not boss.is_telegraphing(), "boss starts without a telegraph")
		# Force the fan attack to charge, then confirm the warning phase exists
		# and that the shots only appear once it resolves.
		var bullets_before := get_nodes_in_group("bullets").size()
		boss._burst_wait = 0.0
		boss._process(0.02)
		_check(boss.is_telegraphing(), "boss enters a telegraph before firing")
		_check(get_nodes_in_group("bullets").size() == bullets_before,
			"no bullets during the warning phase")

		# Advance past the warning; shots must now exist.
		for i in 80:
			boss._process(0.02)
			if not boss.is_telegraphing():
				break
		_check(not boss.is_telegraphing(), "telegraph resolved")
		_check(get_nodes_in_group("bullets").size() > bullets_before,
			"bullets fired after the telegraph")

	# --- Auto-pause on interruption --------------------------------------
	g.start_run(31)
	await physics_frame
	_check(not g.is_paused(), "fresh run is unpaused")
	var t_before: float = g.state.time
	g._auto_pause_for_interruption()
	_check(g.is_paused(), "interruption pauses the run")
	# While paused the clock must not advance.
	for i in 20:
		await physics_frame
	_check(is_equal_approx(g.state.time, t_before), "clock frozen while auto-paused")
	_check(g._auto_paused, "auto-pause flag recorded")
	# The player must resume deliberately.
	g.toggle_pause()
	_check(not g.is_paused(), "toggling pause resumes the run")

	# --- AoE cooldown ------------------------------------------------------
	g.start_run(77)
	await physics_frame
	var cd_before: float = g.state.aoe_cooldown()
	g.state.add_upgrade("cd")
	_check(g.state.aoe_cooldown() < cd_before, "cooldown upgrade shortens AoE cooldown")
	var rad_before: float = g.state.aoe_radius()
	g.state.add_upgrade("aoe")
	_check(g.state.aoe_radius() > rad_before, "aoe upgrade widens the radius")

	# --- Objective text switches once the boss is up ----------------------
	var hud = g.get_node("Hud")
	hud._refresh()
	_check(hud._objective.text.length() > 0, "objective line populated")

	print("=== RESULT: %d failure(s) ===" % _fail.size())
	quit(0 if _fail.is_empty() else 1)
