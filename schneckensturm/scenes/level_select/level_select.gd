# Level select: the three levels in story order (cleared / open / locked) + credits once won.
extends Control


func _ready() -> void:
	var vb := UITheme.screen(self, 16, "menu_bg")
	vb.add_child(UITheme.header(tr("UI_LEVEL_SELECT")))
	var row := UITheme.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(row)
	var list := GameState.maps()
	for i in list.size():
		row.add_child(_level_button(list[i], i + 1))
	if GameState.story_complete():
		var credits := UITheme.button(tr("UI_CREDITS"), 22)
		credits.custom_minimum_size = Vector2(320, 56)
		credits.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		credits.pressed.connect(func(): SceneRouter.goto("credits"))
		vb.add_child(credits)


func _level_button(ws: WaveSet, n: int) -> Button:
	var open := GameState.is_map_unlocked(ws)
	var text := "%s\n%s" % [tr("UI_LEVEL_N") % n, tr(ws.name_key)]
	if GameState.is_cleared(ws.id):
		text += "\n✓"
	elif not open:
		text += "\n" + tr("UI_LOCK_PREVIOUS")
	if ws.is_boss:
		text = "★ " + text
	var b := UITheme.button(text, 22, "ui_confirm")
	b.custom_minimum_size = Vector2(300, 220)
	b.disabled = not open
	b.pressed.connect(func(): SceneRouter.goto_match(ws))
	return b
