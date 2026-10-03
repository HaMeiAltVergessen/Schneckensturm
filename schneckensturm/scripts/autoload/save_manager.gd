# Autoload: persists GameState to user://savegame.json as versioned JSON.
# Every format change bumps VERSION and adds a step to _migrate().
extends Node

const SAVE_PATH := "user://savegame.json"
const VERSION := 1

## Tests point this at a scratch file so a real savegame is never touched.
var save_path: String = SAVE_PATH


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"faction_id": GameState.faction_id,
		"cleared": GameState.cleared,
		"seen_dialogs": GameState.seen_dialogs,
	}


func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Could not open save file for writing.")
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return from_dict(parsed)


func from_dict(d: Dictionary) -> bool:
	d = _migrate(d)
	GameState.reset()
	GameState.faction_id = str(d.get("faction_id", ""))
	GameState.cleared = _to_string_array(d.get("cleared", []))
	GameState.seen_dialogs = _to_string_array(d.get("seen_dialogs", []))
	return GameState.faction_id != ""


# Upgrades older save dictionaries step by step to VERSION.
func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	# if v < 2: d = _v1_to_v2(d); v = 2   <- future steps go here
	d["version"] = v
	return d


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _to_string_array(arr) -> Array[String]:
	var out: Array[String] = []
	if arr is Array:
		for v in arr:
			out.append(str(v))
	return out
