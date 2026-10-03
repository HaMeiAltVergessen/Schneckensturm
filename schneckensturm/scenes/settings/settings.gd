# Settings: volumes, UI scale, tower-ability automation.
extends Control


func _ready() -> void:
	var vb := UITheme.screen(self, 14)
	vb.add_child(UITheme.header(tr("UI_SETTINGS"), "main_menu"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(grid)

	for bus in Settings.AUDIO_BUSES:
		grid.add_child(_row_label(tr("UI_VOLUME_" + bus.to_upper())))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Settings.get_volume(bus)
		s.custom_minimum_size = Vector2(360, 40)
		s.value_changed.connect(func(v): Settings.set_volume(bus, v))
		grid.add_child(s)

	grid.add_child(_row_label(tr("UI_UI_SCALE")))
	var scale_opt := OptionButton.new()
	for p in Settings.SCALE_PRESETS:
		scale_opt.add_item("%d %%" % int(p * 100))
	scale_opt.selected = Settings.SCALE_PRESETS.find(Settings.window_scale)
	scale_opt.item_selected.connect(func(i): Settings.set_scale(Settings.SCALE_PRESETS[i]))
	grid.add_child(scale_opt)

	grid.add_child(_row_label(tr("UI_AUTO_TOWER_ABILITIES")))
	var auto := CheckButton.new()
	auto.button_pressed = Settings.auto_tower_abilities
	auto.toggled.connect(func(v): Settings.set_auto_tower_abilities(v))
	grid.add_child(auto)


func _row_label(text: String) -> Label:
	var l := UITheme.label(text, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
