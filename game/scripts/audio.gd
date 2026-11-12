# Audio — owns SFX playback and haptics, both gated by the saved settings.
# One player per sound keeps rapid fire from cutting itself off.
extends Node

const SOUNDS := {
	"shoot": "res://audio/shoot.wav",
	"hit": "res://audio/hit.wav",
	"kill": "res://audio/kill.wav",
	"hurt": "res://audio/hurt.wav",
	"aoe": "res://audio/aoe.wav",
	"upgrade": "res://audio/upgrade.wav",
}

const VOICES_PER_SOUND := 4

var _streams: Dictionary = {}
var _players: Dictionary = {}
var _next: Dictionary = {}


func _ready() -> void:
	for id in SOUNDS.keys():
		var stream: AudioStream = load(SOUNDS[id])
		if stream == null:
			push_warning("Audio: missing stream for %s" % id)
			continue
		_streams[id] = stream
		var bank: Array[AudioStreamPlayer] = []
		for i in VOICES_PER_SOUND:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "Master"
			p.volume_db = -6.0
			add_child(p)
			bank.append(p)
		_players[id] = bank
		_next[id] = 0


func _sfx_enabled() -> bool:
	return bool(SaveManager.get_settings().get("sfx", true))


func _haptics_enabled() -> bool:
	return bool(SaveManager.get_settings().get("haptics", true))


func play(id: String, volume_db: float = -6.0) -> void:
	if not _sfx_enabled():
		return
	var bank: Array = _players.get(id, [])
	if bank.is_empty():
		return
	var idx: int = _next.get(id, 0)
	var player: AudioStreamPlayer = bank[idx % bank.size()]
	_next[id] = (idx + 1) % bank.size()
	player.volume_db = volume_db
	player.play()


## Short haptic pulse. No-ops on platforms without handheld vibration support.
func haptic(kind: String = "light") -> void:
	if not _haptics_enabled():
		return
	var ms := 25
	var amp := 0.5
	match kind:
		"medium":
			ms = 45
			amp = 0.75
		"heavy":
			ms = 80
			amp = 1.0
	Input.vibrate_handheld(ms, amp)
