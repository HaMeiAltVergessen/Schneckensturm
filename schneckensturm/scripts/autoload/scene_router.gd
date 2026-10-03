# Autoload: centralized scene transitions by key, with a soft fade between scenes.
extends Node

const SCENES := {
	"boot": "res://scenes/boot/boot.tscn",
	"main_menu": "res://scenes/main_menu/main_menu.tscn",
	"level_select": "res://scenes/level_select/level_select.tscn",
	"match": "res://scenes/match/match.tscn",
	"settings": "res://scenes/settings/settings.tscn",
	"dialog": "res://scenes/dialog/dialog.tscn",
	"credits": "res://scenes/credits/credits.tscn",
	"perf_test": "res://scenes/perf_test/perf_test.tscn",
}

const FADE_TIME := 0.22

# Background music per scene. "match" picks its own track per WaveSet,
# "dialog" keeps whatever is playing.
const _SCENE_MUSIC := {
	"boot": "main_theme",
	"main_menu": "main_theme",
	"level_select": "main_theme",
	"settings": "main_theme",
	"credits": "main_theme",
}

# Fade overlay lives on the autoload so it survives change_scene_to_file.
var _fade_rect: ColorRect
var _transitioning := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)


func goto(key: String) -> void:
	if not SCENES.has(key):
		push_error("Unknown scene key: %s" % key)
		return
	if _transitioning:
		return
	AudioManager.play_sfx("scene_transition")
	AudioManager.play_music(_SCENE_MUSIC.get(key, ""))
	_change(SCENES[key])


# ---------------------------------------------------------------------------
# Story flow: menu -> [pre dialog] -> level -> [post dialog] -> next level ... -> credits
# ---------------------------------------------------------------------------
# Enter a level; its pre-dialog plays first the first time.
func goto_match(ws: WaveSet) -> void:
	GameState.pending_waveset = ws
	if ws.pre_dialog != null and not GameState.has_seen(ws.pre_dialog.id):
		play_dialog(ws.pre_dialog, "match")
		return
	goto("match")


# After a won level: post-dialog (once), then the next level or the credits.
func continue_story(ws: WaveSet) -> void:
	var next := GameState.next_map(ws)
	if ws.post_dialog != null and not GameState.has_seen(ws.post_dialog.id):
		GameState.pending_waveset = next
		play_dialog(ws.post_dialog, "match" if next != null else "credits")
		return
	if next != null:
		goto_match(next)
	else:
		goto("credits")


## Scene key the dialog scene continues to.
var dialog_next: String = "main_menu"


func play_dialog(d: DialogData, next_key: String) -> void:
	GameState.pending_dialog = d
	dialog_next = next_key
	goto("dialog")


# Called by the dialog scene when its dialog is over.
func dialog_finished() -> void:
	var ws := GameState.pending_waveset
	if dialog_next == "match" and ws != null:
		goto_match(ws)   # plays the next level's own pre-dialog if still unseen
	else:
		goto(dialog_next)


func _change(path: String) -> void:
	_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false


func _fade(target_alpha: float) -> void:
	var tw := _fade_rect.create_tween()
	tw.tween_property(_fade_rect, "modulate:a", target_alpha, FADE_TIME)
	await tw.finished
