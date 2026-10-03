# Placeholder display for towers and barracks: an extruded iso block in the
# building colour (or its texture when one is set), HP bar and ability charge.
class_name BuildingVisual
extends Node2D

const HALF := Vector2(52, 26)   # footprint half-diagonals (slightly inside the tile)

var color := Color(0.8, 0.8, 0.8)
var height := 46.0
var hp_ratio := 1.0
## 0..1 ability charge, < 0 = none.
var charge := -1.0
var selected := false
var is_tower := true
var _texture: Texture2D
var level := 1
var max_level := 1


func setup(data: Resource, tower: bool) -> void:
	is_tower = tower
	color = data.color
	height = 64.0 if tower else 40.0
	_texture = data.texture
	queue_redraw()


func set_state(hp: float, ch: float) -> void:
	if not is_equal_approx(hp, hp_ratio) or not is_equal_approx(ch, charge):
		hp_ratio = hp
		charge = ch
		queue_redraw()


# Level pips + optional per-level skin, with a short pulse.
func set_level(lv: int, max_lv: int, tex: Texture2D) -> void:
	level = lv
	max_level = max_lv
	_texture = tex
	queue_redraw()
	scale = Vector2(1.15, 0.85)
	modulate = Color(1.5, 1.4, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color.WHITE, 0.35)


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func flash() -> void:
	modulate = Color(1.7, 0.6, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func die() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_property(self, "scale", Vector2(1.1, 0.3), 0.4)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var top := Vector2(0, -height)
	var n := Vector2(0, -HALF.y)
	var e := Vector2(HALF.x, 0)
	var s := Vector2(0, HALF.y)
	var w := Vector2(-HALF.x, 0)
	if _texture != null:
		var sz := Vector2(HALF.x * 2.0, HALF.x * 2.0 * _texture.get_height() / maxf(1.0, _texture.get_width()))
		draw_texture_rect(_texture, Rect2(Vector2(-sz.x * 0.5, HALF.y - sz.y), sz), false)
	else:
		# left + right faces, then the lid
		draw_colored_polygon(PackedVector2Array([w, s, s + top, w + top]), color.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([s, e, e + top, s + top]), color.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([n + top, e + top, s + top, w + top]), color)
		if is_tower:
			draw_circle(top + Vector2(0, -10), 9.0, color.lightened(0.35))
		else:
			draw_rect(Rect2(top + Vector2(-9, -16), Vector2(18, 14)), color.lightened(0.3))
	if max_level > 1:
		var pip_y := 4.0
		for i in max_level:
			var px := (float(i) - float(max_level - 1) * 0.5) * 14.0
			draw_circle(Vector2(px, pip_y), 5.0, Color(0, 0, 0, 0.6))
			draw_circle(Vector2(px, pip_y), 3.8, Color(1.0, 0.85, 0.3) if i < level else Color(0.35, 0.35, 0.4))
	if selected:
		draw_polyline(PackedVector2Array([n, e, s, w, n]), Color.WHITE, 3.0)
	if hp_ratio < 0.999:
		var y := -height - 30.0
		draw_rect(Rect2(-29, y - 1, 58, 8), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-28, y, 56 * hp_ratio, 6), Color(0.35, 0.85, 0.35))
	if charge >= 0.0:
		var c := top + Vector2(0, -10)
		draw_arc(c, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(charge, 0.0, 1.0), 32,
			Color(1.0, 0.9, 0.4) if charge >= 1.0 else Color(0.55, 0.85, 1.0), 4.0)
