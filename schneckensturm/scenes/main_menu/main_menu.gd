# Title screen: continue (level select) / new game (intro + level 1) / settings.
extends Control


func _ready() -> void:
	var vb := UITheme.screen(self, 16, "menu_bg")
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(UITheme.title(tr("UI_TITLE")))
	vb.add_child(UITheme.label(tr("UI_SUBTITLE"), 22, UITheme.MUTED))

	var col := UITheme.vbox(12)
	col.custom_minimum_size = Vector2(420, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(col)

	if GameState.has_game():
		var cont := UITheme.button(tr("UI_CONTINUE"), 26, "ui_confirm")
		cont.pressed.connect(func(): SceneRouter.goto("level_select"))
		col.add_child(cont)
	var new_game := UITheme.button(tr("UI_NEW_GAME"), 26, "ui_confirm")
	new_game.pressed.connect(_on_new_game)
	col.add_child(new_game)
	var settings := UITheme.button(tr("UI_SETTINGS"), 24)
	settings.pressed.connect(func(): SceneRouter.goto("settings"))
	col.add_child(settings)


func _on_new_game() -> void:
	GameState.start_new_game()
	SaveManager.save_game()
	var first := GameState.current_map()
	if first != null:
		SceneRouter.goto_match(first)
