# Standalone story dialog screen. Reads GameState.pending_dialog, plays it, then
# hands back to SceneRouter, which continues the story (level, credits, menu).
# Lines may carry a background picture (DialogLine.background); it stays until
# a later line brings a new one and cross-fades on change.
extends Control

const FADE := 0.6

var _bg: TextureRect
var _bg_old: TextureRect


func _ready() -> void:
	var dialog: DialogData = GameState.pending_dialog
	if dialog == null:
		SceneRouter.goto("main_menu")
		return

	UITheme.fill(self)
	add_child(UITheme.background())
	_bg_old = _picture()
	_bg = _picture()

	var box := DialogBox.new()
	add_child(box)
	box.finished.connect(_on_finished.bind(dialog))
	box.line_shown.connect(_on_line)
	box.play(dialog)


func _on_line(line: DialogLine) -> void:
	if line.background == null or line.background == _bg.texture:
		return
	_bg_old.texture = _bg.texture
	_bg_old.modulate.a = 1.0
	_bg.texture = line.background
	_bg.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_bg, "modulate:a", 1.0, FADE)
	tw.tween_property(_bg_old, "modulate:a", 0.0, FADE)


func _picture() -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.fill(r)
	add_child(r)
	return r


func _on_finished(dialog: DialogData) -> void:
	GameState.mark_dialog_seen(dialog.id)
	SaveManager.save_game()
	GameState.pending_dialog = null
	SceneRouter.dialog_finished()
