# Autoload: the persistent story progress (cleared levels, seen dialogs) plus
# transient hand-over fields between scenes. Persisted by SaveManager.
extends Node

const FACTION := "garden"

# --- Persistent -------------------------------------------------------------
var faction_id: String = ""
## WaveSet ids won at least once.
var cleared: Array[String] = []
var seen_dialogs: Array[String] = []

# --- Transient (scene hand-over) ---------------------------------------------
var pending_waveset: WaveSet = null
var pending_dialog: DialogData = null


func reset() -> void:
	faction_id = ""
	cleared = [] as Array[String]
	seen_dialogs = [] as Array[String]
	pending_waveset = null
	pending_dialog = null


func start_new_game(fid := FACTION) -> void:
	reset()
	faction_id = fid


func has_game() -> bool:
	return faction_id != ""


func faction() -> FactionData:
	return ContentDB.get_faction(faction_id if faction_id != "" else FACTION)


func has_seen(dialog_id: String) -> bool:
	return dialog_id in seen_dialogs


func mark_dialog_seen(dialog_id: String) -> void:
	if dialog_id != "" and dialog_id not in seen_dialogs:
		seen_dialogs.append(dialog_id)


# ---------------------------------------------------------------------------
# Story progress (linear: each level unlocks the next)
# ---------------------------------------------------------------------------
func maps() -> Array[WaveSet]:
	var f := faction()
	return f.all_maps() if f != null else [] as Array[WaveSet]


func is_cleared(ws_id: String) -> bool:
	return ws_id in cleared


func mark_cleared(ws: WaveSet) -> bool:
	if ws == null or is_cleared(ws.id):
		return false
	cleared.append(ws.id)
	return true


func is_map_unlocked(ws: WaveSet) -> bool:
	var list := maps()
	var idx := list.find(ws)
	return idx <= 0 or is_cleared(list[idx - 1].id)


# The level after `ws` in story order, or null after the finale.
func next_map(ws: WaveSet) -> WaveSet:
	var list := maps()
	var idx := list.find(ws)
	return list[idx + 1] if idx >= 0 and idx + 1 < list.size() else null


# First level not won yet (the finale once everything is cleared).
func current_map() -> WaveSet:
	var list := maps()
	for ws in list:
		if not is_cleared(ws.id):
			return ws
	return list[list.size() - 1] if not list.is_empty() else null


func story_complete() -> bool:
	var list := maps()
	return not list.is_empty() and is_cleared(list[list.size() - 1].id)
