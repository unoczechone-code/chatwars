# Settings + Credits: language, audio/haptics toggles, credits.
extends Control

signal back_pressed

@onready var _headline: Label = $Center/Layout/Headline
@onready var _lang: Button = $Center/Layout/LangButton
@onready var _music: CheckButton = $Center/Layout/MusicButton
@onready var _sfx: CheckButton = $Center/Layout/SfxButton
@onready var _haptics: CheckButton = $Center/Layout/HapticsButton
@onready var _credits: Label = $Center/Layout/Credits
@onready var _back: Button = $Center/Layout/BackButton


func _ready() -> void:
	var s := SaveManager.get_settings()
	_headline.text = tr("BTN_SETTINGS")
	_lang.text = tr("BTN_LANGUAGE")
	_music.text = tr("SET_MUSIC")
	_sfx.text = tr("SET_SFX")
	_haptics.text = tr("SET_HAPTICS")
	_credits.text = tr("CREDITS_TEXT")
	_back.text = tr("BTN_BACK")

	_music.button_pressed = bool(s.get("music", true))
	_sfx.button_pressed = bool(s.get("sfx", true))
	_haptics.button_pressed = bool(s.get("haptics", true))

	_lang.pressed.connect(_toggle_language)
	_music.toggled.connect(func(v: bool) -> void: _set_setting("music", v))
	_sfx.toggled.connect(func(v: bool) -> void: _set_setting("sfx", v))
	_haptics.toggled.connect(func(v: bool) -> void: _set_setting("haptics", v))
	_back.pressed.connect(func() -> void: back_pressed.emit())


func _toggle_language() -> void:
	var cur := TranslationServer.get_locale()
	var next_locale := "ru" if cur.begins_with("en") else "en"
	SaveManager.set_locale(next_locale)
	SaveManager.save_game()
	_headline.text = tr("BTN_SETTINGS")
	_lang.text = tr("BTN_LANGUAGE")
	_music.text = tr("SET_MUSIC")
	_sfx.text = tr("SET_SFX")
	_haptics.text = tr("SET_HAPTICS")
	_credits.text = tr("CREDITS_TEXT")
	_back.text = tr("BTN_BACK")


func _set_setting(key: String, value: bool) -> void:
	SaveManager.set_setting(key, value)
	SaveManager.save_game()
