# Entry scene: loads the savegame (if any), then shows the menu.
extends Control


func _ready() -> void:
	UITheme.fill(self)
	add_child(UITheme.background())
	var l := UITheme.title(tr("UI_TITLE"))
	UITheme.fill(l)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	SaveManager.load_game()
	await get_tree().process_frame
	SceneRouter.goto("main_menu")
