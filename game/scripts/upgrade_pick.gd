# UpgradePick — choose 1 of up to 3. Pauses the run; no auto-pick timer.
extends Control

signal chosen(id: String)

const DESCRIPTIONS := {
	"damage": "UPG_DAMAGE",
	"rate": "UPG_RATE",
	"hp": "UPG_HP",
	"speed": "UPG_SPEED",
	"aoe": "UPG_AOE",
	"cd": "UPG_CD",
}

@onready var _headline: Label = $Center/Layout/Headline
@onready var _buttons: VBoxContainer = $Center/Layout/Buttons


func _ready() -> void:
	_headline.text = tr("UPGRADE_PICK")


func setup(available: Array[String]) -> void:
	_headline.text = tr("UPGRADE_PICK")

	for c in _buttons.get_children():
		c.queue_free()

	if available.is_empty():
		# Pool exhausted: offer a plain continue so the run can never deadlock.
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 88)
		b.text = tr("BTN_CONTINUE")
		b.pressed.connect(func() -> void: chosen.emit(""))
		_buttons.add_child(b)
		return

	var ids := available.duplicate()
	ids.shuffle()
	for id in ids.slice(0, 3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(520, 88)
		btn.text = tr(DESCRIPTIONS.get(id, "UPG_DAMAGE"))
		btn.add_theme_font_size_override("font_size", 30)
		var pick_id: String = id
		btn.pressed.connect(func() -> void: chosen.emit(pick_id))
		_buttons.add_child(btn)
