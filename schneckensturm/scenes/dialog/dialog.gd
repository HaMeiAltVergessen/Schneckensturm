# Standalone story dialog screen. Reads GameState.pending_dialog, plays it, then
# hands back to SceneRouter, which continues the story (level, credits, menu).
extends Control


func _ready() -> void:
	var dialog: DialogData = GameState.pending_dialog
	if dialog == null:
		SceneRouter.goto("main_menu")
		return

	UITheme.fill(self)
	add_child(UITheme.background())

	var box := DialogBox.new()
	add_child(box)
	box.finished.connect(_on_finished.bind(dialog))
	box.play(dialog)


func _on_finished(dialog: DialogData) -> void:
	GameState.mark_dialog_seen(dialog.id)
	SaveManager.save_game()
	GameState.pending_dialog = null
	SceneRouter.dialog_finished()
