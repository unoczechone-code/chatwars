# Smoke test: save persistence, corruption recovery, localisation, and touch targets.
# Scene-level checks target the real game screens.
extends SceneTree

var _failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  "), msg)
	if not cond:
		_failures.append(msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ChatWars smoke test ===")
	print("Godot: ", Engine.get_version_info().get("string", "?"))
	print("Renderer: ", ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))

	var sm: Node = root.get_node_or_null("SaveManager")
	_check(sm != null, "SaveManager autoload exists")
	if sm == null:
		print("\nFATAL: no SaveManager")
		quit(1)
		return

	# Deterministic start: wipe any save left by a previous test run, then reload it
	# into the same manager so no in-memory state carries over.
	for p in ["user://save.json", "user://save.json.bak", "user://save.corrupt.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	sm.load_game()

	_check(sm.get_counter() == 0, "fresh counter is 0")
	_check(sm.bump_counter() == 1, "bump_counter -> 1")
	_check(sm.bump_counter() == 2, "bump_counter -> 2")

	_check(FileAccess.file_exists("user://save.json"), "save.json written")
	sm.load_game()
	_check(sm.get_counter() == 2, "counter restored after reload")

	# Run results feed best score and win count.
	sm.record_run(false, 500)
	_check(sm.get_best_score() == 500, "best score recorded on a loss")
	_check(sm.get_total_wins() == 0, "a loss does not count as a win")
	sm.record_run(true, 300)
	_check(sm.get_best_score() == 500, "lower score does not replace the best")
	_check(sm.get_total_wins() == 1, "a win increments the win counter")

	# Settings round trip.
	sm.set_locale("ru")
	sm.set_setting("music", false)
	sm.save_game()
	sm.load_game()
	_check(String(sm.get_settings().get("locale", "")) == "ru", "locale persisted")
	_check(sm.get_settings().get("music") == false, "music setting persisted")

	# Corrupt save must not crash and must be quarantined.
	var bad := FileAccess.open("user://save.json", FileAccess.WRITE)
	bad.store_string("{ not json ]]")
	bad.close()
	sm.load_game()
	_check(sm.get_counter() == 0, "corrupt save falls back to defaults")
	_check(FileAccess.file_exists("user://save.corrupt.json"), "corrupt save quarantined")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.corrupt.json"))

	# Every screen loads, and its static buttons meet the 44pt touch minimum.
	var screens := ["title", "game", "upgrade_pick", "result", "settings"]
	for name in screens:
		var path := "res://scenes/%s.tscn" % name
		var packed: PackedScene = load(path)
		_check(packed != null, "%s loads" % name)
		if packed == null:
			continue
		var inst: Node = packed.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		for b in _all_buttons(inst):
			var btn := b as Button
			var h := maxf(btn.custom_minimum_size.y, btn.size.y)
			_check(h >= 44.0, "%s: button '%s' >= 44pt (%.0f)" % [name, btn.text, h])
		inst.queue_free()
		await process_frame

	# Translation resolves in both locales.
	TranslationServer.set_locale("ru")
	var ru := TranslationServer.translate("GAME_TITLE")
	TranslationServer.set_locale("en")
	var en := TranslationServer.translate("GAME_TITLE")
	_check(ru != "" and ru != "GAME_TITLE", "ru translates the title ('%s')" % ru)
	_check(en != "" and en != "GAME_TITLE", "en translates the title ('%s')" % en)
	_check(ru != en, "ru and en differ")

	for key in ["BTN_START", "RESULT_WIN", "UPG_DAMAGE", "PAUSED"]:
		_check(TranslationServer.translate(key) != key, "key %s translated" % key)

	print("=== RESULT: %d failure(s) ===" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _all_buttons(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_buttons(c))
	return out
