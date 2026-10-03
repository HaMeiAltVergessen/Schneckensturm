# Static helpers to build the placeholder UI consistently in code.
class_name UITheme
extends RefCounted

const BG := Color(0.08, 0.07, 0.10)
const PANEL := Color(0.16, 0.15, 0.20)
const ACCENT := Color(0.86, 0.62, 0.28)
const TEXT := Color(0.92, 0.90, 0.94)
const MUTED := Color(0.62, 0.60, 0.66)
const GOOD := Color(0.45, 0.80, 0.45)
const BAD := Color(0.90, 0.35, 0.32)


static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func background(color := BG) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# wrap: word-wrap for flowing text; needs a container that gives the label a width.
static func label(text: String, size := 24, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String) -> Label:
	return label(text, 40, ACCENT)


# click_sound: AudioManager-Kurzname, der beim Drücken abgespielt wird.
# "" unterdrückt den Klick (z. B. wenn der Handler bereits einen Sound spielt).
static func button(text: String, size := 24, click_sound := "ui_click") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 52)
	if click_sound != "":
		b.pressed.connect(func(): AudioManager.play_sfx(click_sound))
	return b


static func stylebox(bg: Color, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	return sb


static func margin(all := 24) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all)
	m.add_theme_constant_override("margin_bottom", all)
	return m


static func panel(bg := PANEL, border := Color.TRANSPARENT, border_width := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stylebox(bg, border, border_width))
	return p


static func hbox(sep := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func vbox(sep := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


# Screen header: back button (to scene `back_key`, "" = none) + title.
static func header(title_text: String, back_key := "main_menu") -> HBoxContainer:
	var row := hbox(16)
	if back_key != "":
		var back := button(TranslationServer.translate("UI_BACK"), 22)
		back.custom_minimum_size = Vector2(140, 48)
		back.pressed.connect(func(): SceneRouter.goto(back_key))
		row.add_child(back)
	var t := label(title_text, 32, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	return row


# Standard full-screen scaffold: background + margin + vbox. Returns the vbox.
static func screen(root: Control, sep := 12) -> VBoxContainer:
	fill(root)
	root.add_child(background())
	var m := margin(20)
	fill(m)
	root.add_child(m)
	var vb := vbox(sep)
	m.add_child(vb)
	return vb


# Card-like toggle button: clear selected state (accent border) and a fixed-size icon.
static func style_toggle(b: Button, icon_px := 64) -> void:
	b.add_theme_stylebox_override("normal", stylebox(Color(0.13, 0.12, 0.17), Color(0.25, 0.24, 0.30), 2))
	b.add_theme_stylebox_override("hover", stylebox(Color(0.17, 0.16, 0.22), Color(0.40, 0.38, 0.46), 2))
	b.add_theme_stylebox_override("pressed", stylebox(Color(0.22, 0.18, 0.12), ACCENT, 3))
	b.add_theme_stylebox_override("hover_pressed", stylebox(Color(0.26, 0.21, 0.14), ACCENT, 3))
	b.add_theme_stylebox_override("disabled", stylebox(Color(0.09, 0.09, 0.11), Color(0.2, 0.2, 0.2), 2))
	b.add_theme_constant_override("icon_max_width", icon_px)
	b.expand_icon = false
