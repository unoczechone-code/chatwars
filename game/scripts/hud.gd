# Hud — the in-run overlay: timer, HP, score, objective, AoE charge, pause.
extends Control

@onready var _wave: Label = $Top/Rows/WaveLabel
@onready var _timer: Label = $Top/Rows/TimerLabel
@onready var _objective: Label = $Top/Rows/ObjectiveLabel
@onready var _score: Label = $Top/Rows/ScoreLabel
@onready var _hp_bar: ProgressBar = $Top/Rows/HpBar
@onready var _hp_text: Label = $Top/Rows/HpText
@onready var _aoe: Button = $Bottom/AoeButton
@onready var _aoe_bar: ProgressBar = $Bottom/AoeBar
@onready var _pause: Button = $Top/PauseButton
@onready var _boss_wrap: Control = $BossBar
@onready var _boss_bar: ProgressBar = $BossBar/Bar
@onready var _boss_label: Label = $BossBar/Label
@onready var _paused_panel: Panel = $PausedPanel

signal pause_pressed

var game: Game

var _aoe_cd := 0.0


func _ready() -> void:
	_aoe.pressed.connect(_on_aoe)
	_pause.pressed.connect(func() -> void: pause_pressed.emit())
	_pause.text = tr("BTN_PAUSE")
	_paused_panel.visible = false
	_boss_wrap.visible = false
	var paused_label := _paused_panel.get_node_or_null("PausedLabel")
	if paused_label != null:
		(paused_label as Label).text = tr("PAUSED")
	_objective.text = tr("OBJECTIVE")
	_boss_label.text = tr("BOSS")


func bind(g: Game) -> void:
	game = g
	g.stats_changed.connect(_refresh)
	_aoe_cd = 0.0
	_refresh()


func set_paused_visible(v: bool) -> void:
	_paused_panel.visible = v
	if not v:
		_aoe_cd = _aoe_cd  # keep the charge; pausing must not refund or reset it


func _process(delta: float) -> void:
	if game == null or game.state == null:
		return

	if _aoe_cd > 0.0 and not game.is_paused():
		_aoe_cd = maxf(0.0, _aoe_cd - delta)

	var total := game.state.aoe_cooldown()
	_aoe_bar.max_value = maxf(0.001, total)
	_aoe_bar.value = total - _aoe_cd
	_aoe.disabled = _aoe_cd > 0.0 or game.state.finished or game.is_paused()
	_aoe.text = tr("BTN_AOE") if _aoe_cd <= 0.0 else "%.1f" % _aoe_cd

	_refresh_boss()
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

	# The objective is spelled out on screen, and switches once the boss is up.
	if s.boss_spawned:
		_objective.text = tr("OBJECTIVE_BOSS")
	else:
		_objective.text = tr("OBJECTIVE") % int(maxf(0.0, game.balance.boss_spawn_time - s.time))


func _refresh_boss() -> void:
	if game == null or game._boss == null:
		_boss_wrap.visible = false
		return
	_boss_wrap.visible = true
	_boss_bar.max_value = maxi(1, game._boss.max_hp)
	_boss_bar.value = maxi(0, game._boss.hp)


func _on_aoe() -> void:
	if game == null or game.state == null or _aoe_cd > 0.0:
		return
	_aoe_cd = game.state.aoe_cooldown()
	game.do_aoe()
