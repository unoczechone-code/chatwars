# main.gd — app root. Owns screen switching; every screen is a scene it swaps in.
extends Control

const TitleScene := preload("res://scenes/title.tscn")
const GameScene := preload("res://scenes/game.tscn")
const UpgradeScene := preload("res://scenes/upgrade_pick.tscn")
const ResultScene := preload("res://scenes/result.tscn")
const SettingsScene := preload("res://scenes/settings.tscn")

var _current: Node = null
# The live run is kept aside (detached, not freed) while the upgrade pick is shown,
# so the run's clock, enemies and stack state survive the round trip.
var _held_game: Node = null


func _ready() -> void:
	SaveManager.apply_saved_locale()
	show_title()


func _detach_current() -> void:
	if _current == null:
		return
	var old := _current
	_current = null
	remove_child(old)
	old.queue_free()


func _swap(scene: PackedScene) -> Node:
	_detach_current()
	var inst := scene.instantiate()
	add_child(inst)
	_current = inst
	return inst


func show_title() -> void:
	_held_game = null
	var t := _swap(TitleScene)
	t.start_pressed.connect(start_game)
	t.settings_pressed.connect(show_settings)


func start_game() -> void:
	if _held_game != null:
		var stale := _held_game
		_held_game = null
		stale.queue_free()
	var g := _swap(GameScene) as Game
	g.run_finished.connect(_on_run_finished)
	g.upgrade_requested.connect(_on_upgrade_requested)


func _on_upgrade_requested() -> void:
	var g := _current as Game
	if g == null:
		return
	# Hold the run aside instead of destroying it, then show the pick screen.
	remove_child(g)
	_held_game = g
	_current = null

	var pick := _swap(UpgradeScene)
	pick.setup(g.state.available_upgrades())
	pick.chosen.connect(func(id: String) -> void:
		var resumed := _held_game
		_held_game = null
		_detach_current()
		if resumed == null:
			show_title()
			return
		add_child(resumed)
		_current = resumed
		resumed.apply_upgrade(id)
	)


func _on_run_finished(won: bool, score: int, time: float) -> void:
	SaveManager.record_run(won, score)
	_held_game = null
	var r := _swap(ResultScene)
	r.setup(won, score, time, SaveManager.get_best_score(), SaveManager.get_total_wins())
	r.retry_pressed.connect(start_game)
	r.menu_pressed.connect(show_title)


func show_settings() -> void:
	var s := _swap(SettingsScene)
	s.back_pressed.connect(show_title)
