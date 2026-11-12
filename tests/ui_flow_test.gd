# UI flow test — exercises every screen transition on the real Main scene.
extends SceneTree

var _fail: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  "), msg)
	if not cond:
		_fail.append(msg)


func _init() -> void:
	# Defer so autoloads exist before any UI script is compiled/instantiated.
	call_deferred("_run")


func _run() -> void:
	print("=== UI flow test ===")
	_check(root.get_node_or_null("SaveManager") != null, "SaveManager autoload present")

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_check(main_scene != null, "main.tscn loads")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	_check(main._current != null and main._current.name == "Title", "starts on the title screen")

	main.start_game()
	await process_frame
	await process_frame
	_check(main._current != null and main._current.name == "Game", "title -> game")

	var g: Node = main._current
	_check(g.state != null, "game has state")

	var game_id := g.get_instance_id()
	main._on_upgrade_requested()
	await process_frame
	await process_frame
	_check(main._current.name == "UpgradePick", "upgrade prompt replaces the game screen")

	var pick: Node = main._current
	var buttons: Node = pick.get_node("Center/Layout/Buttons")
	_check(buttons.get_child_count() > 0, "upgrade screen offers choices")

	var first: Button = buttons.get_child(0)
	first.pressed.emit()
	await process_frame
	await process_frame
	_check(main._current.name == "Game", "choosing an upgrade returns to the game")
	_check(main._current.get_instance_id() == game_id,
		"the SAME game instance is restored (run state preserved)")
	_check(not main._current.is_paused(), "game resumes unpaused after the pick")

	main._on_run_finished(true, 1234, 180.0)
	await process_frame
	await process_frame
	_check(main._current.name == "Result", "game -> result")
	var res: Node = main._current
	var headline: Label = res.get_node("Center/Layout/Headline")
	var score_lbl: Label = res.get_node("Center/Layout/Score")
	_check(headline.text.length() > 0, "result headline filled ('%s')" % headline.text)
	_check(score_lbl.text.contains("1234"), "result shows the score ('%s')" % score_lbl.text)

	main.start_game()
	await process_frame
	await process_frame
	_check(main._current.name == "Game", "result -> retry restarts into a game")
	_check(main._current.state.time < 1.0, "retry starts a fresh clock")

	main.show_settings()
	await process_frame
	await process_frame
	_check(main._current.name == "Settings", "settings screen opens")
	var settings: Node = main._current
	var lang: Button = settings.get_node("Center/Layout/LangButton")
	_check(lang.text.length() > 0, "language button labelled ('%s')" % lang.text)

	var before_locale := TranslationServer.get_locale()
	settings._toggle_language()
	await process_frame
	_check(TranslationServer.get_locale() != before_locale,
		"language toggle changes locale (%s -> %s)" % [before_locale,
			TranslationServer.get_locale()])

	settings.back_pressed.emit()
	await process_frame
	await process_frame
	_check(main._current.name == "Title", "settings -> title")

	print("=== RESULT: %d failure(s) ===" % _fail.size())
	quit(0 if _fail.is_empty() else 1)
