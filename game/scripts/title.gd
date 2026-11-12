# Title screen.
extends Control

signal start_pressed
signal settings_pressed

@onready var _title: Label = $Center/Layout/Title
@onready var _best: Label = $Center/Layout/Best
@onready var _start: Button = $Center/Layout/StartButton
@onready var _settings: Button = $Center/Layout/SettingsButton


func _ready() -> void:
	_start.pressed.connect(func() -> void: start_pressed.emit())
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_title.text = tr("GAME_TITLE")
	_start.text = tr("BTN_START")
	_settings.text = tr("BTN_SETTINGS")
	_best.text = tr("BEST_SCORE") % SaveManager.get_best_score()
