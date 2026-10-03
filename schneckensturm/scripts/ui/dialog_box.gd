# Reusable dialog widget. Renders a DialogData line by line and emits `finished`
# when the last line is confirmed or the player skips. Used both as the body of
# the standalone dialog scene and as an in-battle overlay.
class_name DialogBox
extends Control

signal finished
## Emitted whenever a line is shown (the dialog scene swaps its background on it).
signal line_shown(line: DialogLine)

var _dialog: DialogData
var _index := 0

var _portrait: TextureRect
var _speaker: Label
var _text: Label
var _next_button: Button


func _ready() -> void:
	UITheme.fill(self)

	# Anchor the box to the lower part of the screen.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.stylebox(UITheme.PANEL, UITheme.ACCENT, 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -250
	panel.offset_left = 160
	panel.offset_right = -160
	panel.offset_bottom = -24
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	var m := UITheme.margin(18)
	m.add_child(vb)
	panel.add_child(m)

	# Portrait + speaker name row.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(104, 104)
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_portrait)
	_speaker = UITheme.label("", 22, UITheme.ACCENT)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speaker.autowrap_mode = TextServer.AUTOWRAP_OFF  # name on one line; never wrap to a vertical column
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_speaker)
	vb.add_child(head)

	_text = UITheme.label("", 18, UITheme.TEXT, true)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_text)

	# Buttons: Skip (left) + Next (right).
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	var skip := UITheme.button(tr("UI_DIALOG_SKIP"), 20)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_finish)
	_next_button = UITheme.button(tr("UI_DIALOG_NEXT"), 20, "")  # advance sound played in _advance
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(_advance)
	controls.add_child(skip)
	controls.add_child(_next_button)
	vb.add_child(controls)

	if _dialog != null:
		_show_line()


func play(dialog: DialogData) -> void:
	_dialog = dialog
	_index = 0
	if is_node_ready():
		_show_line()


func _show_line() -> void:
	if _dialog == null or _index >= _dialog.lines.size():
		_finish()
		return
	var line := _dialog.lines[_index]
	_speaker.text = tr(line.speaker_name_key)
	_text.text = tr(line.text_key)
	_portrait.texture = line.portrait
	_portrait.visible = line.portrait != null
	line_shown.emit(line)


func _advance() -> void:
	AudioManager.play_sfx("dialog_advance")
	_index += 1
	if _index >= _dialog.lines.size():
		_finish()
	else:
		_show_line()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _finish() -> void:
	finished.emit()
