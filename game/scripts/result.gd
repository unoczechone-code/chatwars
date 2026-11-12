# Result screen — win/lose, score, best, retry, menu.
extends Control

signal retry_pressed
signal menu_pressed

@onready var _headline: Label = $Center/Layout/Headline
@onready var _score: Label = $Center/Layout/Score
@onready var _best: Label = $Center/Layout/Best
@onready var _time: Label = $Center/Layout/Time
@onready var _retry: Button = $Center/Layout/RetryButton
@onready var _menu: Button = $Center/Layout/MenuButton


func _ready() -> void:
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_menu.pressed.connect(func() -> void: menu_pressed.emit())
	_retry.text = tr("BTN_RETRY")
	_menu.text = tr("BTN_MENU")


func setup(won: bool, score: int, time: float, best: int, wins: int) -> void:
	_headline.text = tr("RESULT_WIN") if won else tr("RESULT_LOSE")
	_headline.add_theme_color_override("font_color",
		Color(0.45, 0.9, 0.6) if won else Color(0.95, 0.45, 0.45))
	_score.text = tr("SCORE") % score
	_best.text = tr("BEST_SCORE") % best
	_time.text = tr("SURVIVED") % int(time)
	if won:
		_time.text += "  ·  " + (tr("WINS") % wins)
