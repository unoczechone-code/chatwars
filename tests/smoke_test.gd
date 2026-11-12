# Headless smoke test: runs inside the real project, exercises save + scene + locale.
extends SceneTree

var _failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		_failures.append(msg)


func _init() -> void:
	print("=== ChatWars headless smoke test ===")
	print("Godot: ", Engine.get_version_info().get("string", "?"))
	print("Renderer: ", ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))
	print("Current locale: ", TranslationServer.get_locale())

	# 1. Autoload present
	var sm: Node = root.get_node_or_null("SaveManager")
	if sm == null:
		# --script builds a bare SceneTree with no autoloads; instantiate manually so
		# the same code path is exercised. The real game uses the autoload normally.
		print("  NOTE  no autoload under --script; instantiating SaveManager manually")
		var script_res: Script = load("res://scripts/save_manager.gd")
		sm = script_res.new()
		sm.name = "SaveManager"
		root.add_child(sm)
	_check(sm != null, "SaveManager autoload exists")
	if sm == null:
		print("\nFATAL: no SaveManager, aborting")
		quit(1)
		return

	# 2. Clean slate: remove any prior save so the test is deterministic
	for p in ["user://save.json", "user://save.json.bak", "user://save.corrupt.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	# 3. Counter starts at 0 and increments
	_check(sm.get_counter() == 0, "fresh counter is 0")
	var v1: int = sm.bump_counter()
	var v2: int = sm.bump_counter()
	_check(v1 == 1 and v2 == 2, "bump_counter -> 1 then 2 (got %d, %d)" % [v1, v2])

	# 4. Save file exists and is valid JSON
	_check(FileAccess.file_exists("user://save.json"), "save.json written")
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	_check(typeof(parsed) == TYPE_DICTIONARY, "save.json parses as dict")
	_check(typeof(parsed) == TYPE_DICTIONARY and int((parsed as Dictionary).get("counter", -1)) == 2,
		"persisted counter == 2")

	# 5. Reload from disk (simulates app restart) and confirm the counter is restored
	sm.load_game()
	_check(sm.get_counter() == 2, "counter restored after reload (got %d)" % sm.get_counter())

	# 6. Locale switch persists
	sm.set_locale("ru")
	sm.save_game()
	sm.load_game()
	_check(String(sm.get_settings().get("locale", "")) == "ru", "locale 'ru' persisted")

	# 7. Corrupt-save recovery: write garbage, reload, must not crash and must quarantine
	var bad := FileAccess.open("user://save.json", FileAccess.WRITE)
	bad.store_string("{ this is not json ]]")
	bad.close()
	sm.load_game()
	_check(sm.get_counter() == 0, "corrupt save fell back to defaults")
	_check(FileAccess.file_exists("user://save.corrupt.json"), "corrupt save quarantined")

	# 8. Scene instantiates and its labels resolve
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "main.tscn loads")
	if scene != null:
		var inst: Node = scene.instantiate()
		root.add_child(inst)
		await process_frame
		var lbl: Node = inst.get_node_or_null("Center/Layout/CounterLabel")
		_check(lbl != null, "CounterLabel found")
		if lbl != null:
			_check((lbl as Label).text.length() > 0, "CounterLabel has text: '%s'" % (lbl as Label).text)
		var btn: Node = inst.get_node_or_null("Center/Layout/HitButton")
		_check(btn != null and (btn as Button).custom_minimum_size.x >= 44,
			"HitButton meets >=44px touch target")

	# 9. Translation actually resolves in both locales
	TranslationServer.set_locale("ru")
	var ru_title := tr("GAME_TITLE")
	TranslationServer.set_locale("en")
	var en_title := tr("GAME_TITLE")
	_check(ru_title != "GAME_TITLE", "ru translation resolves ('%s')" % ru_title)
	_check(en_title != "GAME_TITLE", "en translation resolves ('%s')" % en_title)
	_check(ru_title != en_title, "ru and en differ")

	print("=== RESULT: %d failure(s) ===" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
