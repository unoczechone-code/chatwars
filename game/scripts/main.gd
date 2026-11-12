# main.gd — spike scene: title, counter button, version label.
extends Control

@onready var _counter_label: Label = $Center/Layout/CounterLabel
@onready var _title_label: Label = $Center/Layout/TitleLabel
@onready var _hit_button: Button = $Center/Layout/HitButton
@onready var _lang_button: Button = $Center/Layout/LangButton
@onready var _version_label: Label = $Center/Layout/VersionLabel


func _ready() -> void:
	_hit_button.pressed.connect(_on_hit)
	_lang_button.pressed.connect(_on_toggle_locale)
	_apply_locale()
	_refresh()


func _refresh() -> void:
	_counter_label.text = tr("COUNTER_LABEL") % SaveManager.get_counter()
	_version_label.text = "v%s · Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.1.0"),
		Engine.get_version_info().get("string", "?"),
	]
	_lang_button.text = tr("LANG_SWITCH")


func _on_hit() -> void:
	SaveManager.bump_counter()
	_refresh()


func _on_toggle_locale() -> void:
	var cur := TranslationServer.get_locale()
	var next_locale := "ru" if cur.begins_with("en") else "en"
	TranslationServer.set_locale(next_locale)
	SaveManager.set_locale(next_locale)
	SaveManager.save_game()
	_apply_locale()
	_refresh()


func _apply_locale() -> void:
	_title_label.text = tr("GAME_TITLE")
