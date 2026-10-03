# Ending: the birthday greeting, slowly fading in line by line, then back to the menu.
extends Control

const LINE_KEYS := ["CREDITS_LINE_1", "CREDITS_LINE_2", "CREDITS_LINE_3", "CREDITS_LINE_4"]


func _ready() -> void:
	UITheme.fill(self)
	add_child(UITheme.background(Color(0.10, 0.05, 0.10)))
	var bg := UITheme.backdrop("credits_bg", 0.5)
	if bg != null:
		add_child(bg)
	var m := UITheme.margin(40)
	UITheme.fill(m)
	add_child(m)
	var vb := UITheme.vbox(22)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(vb)

	var title := UITheme.title(tr("CREDITS_TITLE"))
	vb.add_child(title)
	var lines: Array[Control] = [title]
	for key in LINE_KEYS:
		var l := UITheme.label(tr(key), 26, UITheme.TEXT, true)
		vb.add_child(l)
		lines.append(l)
	var back := UITheme.button(tr("UI_TO_MENU"), 22, "ui_confirm")
	back.custom_minimum_size = Vector2(320, 56)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): SceneRouter.goto("main_menu"))
	vb.add_child(back)
	lines.append(back)

	AudioManager.play_sfx("victory")
	var tw := create_tween()
	for c in lines:
		c.modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 1.2)
		tw.tween_interval(0.6)
