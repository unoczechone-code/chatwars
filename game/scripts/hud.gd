# Hud — timer, HP bar, score, wave, AoE button with cooldown, pause button.
extends Control

@onready var _wave: Label = $Top/Rows/WaveLabel
@onready var _timer: Label = $Top/Rows/TimerLabel
@onready var _score: Label = $Top/Rows/ScoreLabel
@onready var _hp_bar: ProgressBar = $Top/Rows/HpBar
@onready var _hp_text: Label = $Top/Rows/HpText
@onready var _aoe: Button = $Bottom/AoeButton
@onready var _pause: Button = $Top/PauseButton
@onready var _paused_panel: Panel = $PausedPanel

signal pause_pressed

var game: Game

var _aoe_cd := 0.0


func _ready() -> void:
	_aoe.pressed.connect(_on_aoe)
	_pause.pressed.connect(func() -> void: pause_pressed.emit())
	_paused_panel.visible = false
	var paused_label := _paused_panel.get_node_or_null("PausedLabel")
	if paused_label != null:
		(paused_label as Label).text = tr("PAUSED")


func bind(g: Game) -> void:
	game = g
	g.stats_changed.connect(_refresh)
	_aoe_cd = 0.0
	_refresh()


func set_paused_visible(v: bool) -> void:
	_paused_panel.visible = v


func _process(delta: float) -> void:
	if game == null or game.state == null:
		return
	if _aoe_cd > 0.0:
		_aoe_cd = maxf(0.0, _aoe_cd - delta)
		_aoe.text = "%s (%.1f)" % [tr("BTN_AOE"), _aoe_cd]
		_aoe.disabled = true
	else:
		_aoe.text = tr("BTN_AOE")
		_aoe.disabled = game.state.finished or game.is_paused()
	_refresh()


func _refresh() -> void:
	if game == null or game.state == null:
		return
	var s := game.state
	_wave.text = tr("WAVE") % s.wave
	var left := maxf(0.0, game.balance.run_duration - s.time)
	_timer.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_score.text = tr("SCORE_SHORT") % s.score
	_hp_bar.max_value = maxi(1, s.max_hp)
	_hp_bar.value = s.hp
	_hp_text.text = "%d / %d" % [s.hp, s.max_hp]


func _on_aoe() -> void:
	if game == null or game.state == null or _aoe_cd > 0.0:
		return
	_aoe_cd = game.state.aoe_cooldown()
	game.do_aoe()
