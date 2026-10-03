# Statische Tween-Helfer für Kampf-„Juice": Zahlen-Popups, Flash, Scale-Punch,
# Lunge und Tod-Fade. Reine Code-Effekte (keine Assets); laufen auch headless.
class_name FX
extends RefCounted

const POPUP_RISE := 48.0
const POPUP_TIME := 0.6
const FLASH_TIME := 0.25
const PUNCH_TIME := 0.18
const LUNGE_TIME := 0.16
const DEAD_ALPHA := 0.45


# Aufsteigende, ausblendende Schadens-/Heilzahl an Bildschirmposition `at`.
static func popup(parent: CanvasItem, at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 100
	parent.add_child(l)
	l.global_position = at - Vector2(16, 8)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - POPUP_RISE, POPUP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, POPUP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


# Kurzes Aufleuchten in `color`, dann zurück zu Weiß.
static func flash(c: CanvasItem, color: Color) -> void:
	c.modulate = color
	c.create_tween().tween_property(c, "modulate", Color.WHITE, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Kurzer Scale-Stoß aus der Mitte (überschreibt kein Container-Layout).
static func punch(c: Control, amount := 1.12) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(amount, amount), PUNCH_TIME * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, PUNCH_TIME * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Kurzer Versatz Richtung `offset` und zurück (Angriffs-Lunge).
static func lunge(c: Control, offset: Vector2) -> void:
	var start := c.position
	var tw := c.create_tween()
	tw.tween_property(c, "position", start + offset, LUNGE_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", start, LUNGE_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Sanftes Abdunkeln eines gefallenen Combatant-Panels.
static func death_fade(c: Control) -> void:
	c.create_tween().tween_property(c, "modulate:a", DEAD_ALPHA, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
