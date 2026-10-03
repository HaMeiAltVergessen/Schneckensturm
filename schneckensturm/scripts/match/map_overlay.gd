# Drawn above the ground tiles: path direction chevrons, spawn/exit markers and
# highlighted cells ({ Vector2i: Color }).
class_name MapOverlay
extends Node2D

var view: MapView
var highlights: Dictionary = {}


func _draw() -> void:
	if view == null or view.layout == null:
		return
	var g := view.grid
	for p in view.layout.paths:
		for i in range(0, p.cells.size() - 1):
			if i % 2 == 1:
				continue
			var a := g.to_world(Vector2(p.cells[i]))
			var b := g.to_world(Vector2(p.cells[i + 1]))
			var dir := (b - a).normalized()
			var mid := a.lerp(b, 0.5)
			var side := Vector2(-dir.y, dir.x) * 7.0
			draw_polyline(PackedVector2Array([mid - dir * 7.0 + side, mid + dir * 5.0, mid - dir * 7.0 - side]), Color(0, 0, 0, 0.25), 3.0)
		if not p.cells.is_empty():
			_marker(g.to_world(Vector2(p.cells[0])), Color(0.85, 0.25, 0.30))
			_marker(g.to_world(Vector2(p.cells[p.cells.size() - 1])), Color(0.30, 0.55, 0.95))
	for c in highlights:
		var col: Color = highlights[c]
		draw_colored_polygon(g.cell_polygon(c), col)
		var poly := g.cell_polygon(c)
		poly.append(poly[0])
		draw_polyline(poly, Color(col.r, col.g, col.b, minf(1.0, col.a * 2.5)), 2.0)


func _marker(at: Vector2, col: Color) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, col, 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
