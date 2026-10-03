# Expanding, fading iso ring marking an ability's area. Frees itself.
class_name AbilityFx
extends Node2D

const TIME := 0.45

var radius_px := 64.0
var color := Color.WHITE
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= TIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / TIME
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	var c := Color(color.r, color.g, color.b, (1.0 - k) * 0.35)
	draw_circle(Vector2.ZERO, radius_px * (0.4 + 0.6 * k), c)
	draw_arc(Vector2.ZERO, radius_px * (0.4 + 0.6 * k), 0.0, TAU, 48, Color(color.r, color.g, color.b, 1.0 - k), 4.0)
