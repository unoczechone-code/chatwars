# SaveManager — versioned JSON save with atomic write and backup.
extends Node

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.json.tmp"
const BAK_PATH := "user://save.json.bak"
const CORRUPT_PATH := "user://save.corrupt.json"
const SAVE_VERSION := 1

var _data: Dictionary = {}


func _ready() -> void:
	load_game()


func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"counter": 0,
		"best_score": 0,
		"total_wins": 0,
		"settings": {
			"locale": "en",
			"music": true,
			"sfx": true,
			"haptics": true,
		},
	}


func _sanitize(raw: Variant) -> Dictionary:
	var out := _defaults()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw
	if d.get("version") is int and int(d["version"]) > 0:
		out["version"] = SAVE_VERSION
	out["counter"] = _clampi(d.get("counter"), 0, 1_000_000_000)
	out["best_score"] = _clampi(d.get("best_score"), 0, 1_000_000_000)
	out["total_wins"] = _clampi(d.get("total_wins"), 0, 1_000_000_000)
	var s: Variant = d.get("settings")
	if typeof(s) == TYPE_DICTIONARY:
		var sd: Dictionary = s
		var loc: Variant = sd.get("locale")
		if typeof(loc) == TYPE_STRING and (loc as String) in ["ru", "en"]:
			out["settings"]["locale"] = loc
		for k in ["music", "sfx", "haptics"]:
			out["settings"][k] = bool(sd.get(k, true))
	return out


func _clampi(v: Variant, lo: int, hi: int) -> int:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return clampi(int(v), lo, hi)
	return 0


## Reads the save file, quarantining a corrupt one instead of silently wiping it.
func load_game() -> void:
	_data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("SaveManager: cannot open save: %s" % FileAccess.get_open_error())
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_quarantine_corrupt()
		return
	_data = _sanitize(parsed)


func _quarantine_corrupt() -> void:
	push_warning("SaveManager: corrupt save quarantined to %s" % CORRUPT_PATH)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
		ProjectSettings.globalize_path(CORRUPT_PATH))


## Atomic write: tmp -> backup -> replace. Returns true on success.
func save_game() -> bool:
	var tmp := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_error("SaveManager: cannot open temp for write: %s" % FileAccess.get_open_error())
		return false
	tmp.store_string(JSON.stringify(_data, "\t"))
	tmp.flush()
	tmp.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: cannot open user:// dir")
		return false
	if dir.file_exists("save.json"):
		if dir.file_exists("save.json.bak"):
			dir.remove("save.json.bak")
		var mv := dir.rename("save.json", "save.json.bak")
		if mv != OK:
			push_warning("SaveManager: backup rename failed: %d" % mv)
	var err := dir.rename("save.json.tmp", "save.json")
	if err != OK:
		push_error("SaveManager: commit rename failed: %d" % err)
		return false
	return true


func get_counter() -> int:
	return int(_data.get("counter", 0))
func set_counter(v: int) -> void:
	_data["counter"] = maxi(v, 0)


func get_settings() -> Dictionary:
	return _data.get("settings", {})


func set_locale(loc: String) -> void:
	if loc not in ["ru", "en"]:
		return
	_data["settings"]["locale"] = loc
	TranslationServer.set_locale(loc)


func apply_saved_locale() -> void:
	set_locale(String(_data.get("settings", {}).get("locale", "en")))


func bump_counter() -> int:
	var v := get_counter() + 1
	set_counter(v)
	save_game()
	return v
