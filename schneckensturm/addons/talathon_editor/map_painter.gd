@tool
# Iso grid canvas for painting a MapLayout: paths (per index), path/edge deploy
# tiles, build slots, blocked tiles, eraser. Emits stroke_started/stroke_finished
# so the dock can record undo snapshots.
extends Control

signal stroke_started
signal stroke_finished
signal hovered(cell: Vector2i)

enum Tool { PATH, DEPLOY_PATH, DEPLOY_EDGE, BUILD, BLOCKED, ERASE }

const COLORS := {
	Enums.TileKind.GROUND: Color(0.23, 0.30, 0.22),
	Enums.TileKind.PATH: Color(0.62, 0.52, 0.36),
	Enums.TileKind.DEPLOY_PATH: Color(0.95, 0.78, 0.30),
	Enums.TileKind.DEPLOY_EDGE: Color(0.40, 0.65, 0.95),
	Enums.TileKind.BUILD_SLOT: Color(0.92, 0.92, 0.95),
	Enums.TileKind.BLOCKED: Color(0.10, 0.09, 0.11),
}
const PATH_COLORS := [Color(1.0, 0.45, 0.35), Color(0.45, 0.85, 1.0), Color(0.75, 1.0, 0.45), Color(1.0, 0.6, 1.0)]

var layout: MapLayout
var tool: int = Tool.PATH
var path_index := 0

var _tw := 32.0
var _origin := Vector2.ZERO
var _painting := false
var _hover := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func set_layout(l: MapLayout) -> void:
	layout = l
	queue_redraw()


# --- geometry -------------------------------------------------------------
func _fit() -> void:
	if layout == null:
		return
	var n := float(layout.size.x + layout.size.y)
	_tw = minf(2.0 * size.x / n, 4.0 * size.y / n) * 0.95
	var th := _tw * 0.5
	var total := Vector2(n * _tw * 0.5, n * th * 0.5)
	_origin = Vector2((size.x - total.x) * 0.5 + layout.size.y * _tw * 0.5, (size.y - total.y) * 0.5 + th * 0.5)


func cell_center(c: Vector2) -> Vector2:
	return _origin + Vector2((c.x - c.y) * _tw * 0.5, (c.x + c.y) * _tw * 0.25)


func cell_at(p: Vector2) -> Vector2i:
	var d := p - _origin
	var a := d.x / (_tw * 0.5)
	var b := d.y / (_tw * 0.25)
	return Vector2i(roundi((a + b) * 0.5), roundi((b - a) * 0.5))


func _diamond(c: Vector2i) -> PackedVector2Array:
	var m := cell_center(Vector2(c))
	var hx := _tw * 0.5
	var hy := _tw * 0.25
	return PackedVector2Array([m + Vector2(0, -hy), m + Vector2(hx, 0), m + Vector2(0, hy), m + Vector2(-hx, 0)])


# --- drawing --------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.09))
	if layout == null:
		return
	_fit()
	for x in layout.size.x:
		for y in layout.size.y:
			var c := Vector2i(x, y)
			var poly := _diamond(c)
			draw_colored_polygon(poly, COLORS.get(_kind(c), COLORS[Enums.TileKind.GROUND]))
			poly.append(poly[0])
			draw_polyline(poly, Color(0, 0, 0, 0.35), 1.0)
	var font := get_theme_default_font()
	for pi in layout.paths.size():
		var p: MapPath = layout.paths[pi]
		if p == null:
			continue
		var col: Color = PATH_COLORS[pi % PATH_COLORS.size()]
		var pts := PackedVector2Array()
		for c in p.cells:
			pts.append(cell_center(Vector2(c)) + Vector2(0, pi * 3.0))
		if pts.size() >= 2:
			draw_polyline(pts, col, 3.0 if pi == path_index else 1.5)
		if not pts.is_empty():
			draw_circle(pts[0], _tw * 0.14, col)
			draw_arc(pts[pts.size() - 1], _tw * 0.16, 0.0, TAU, 16, col, 2.0)
			draw_string(font, pts[0] + Vector2(-4, -_tw * 0.18), str(pi), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	if _hover.x >= 0 and _in_bounds(_hover):
		var poly := _diamond(_hover)
		poly.append(poly[0])
		draw_polyline(poly, Color.WHITE, 2.0)


func _kind(c: Vector2i) -> int:
	if c in layout.build_slots:
		return Enums.TileKind.BUILD_SLOT
	if c in layout.deploy_path_cells:
		return Enums.TileKind.DEPLOY_PATH
	if c in layout.deploy_edge_cells:
		return Enums.TileKind.DEPLOY_EDGE
	if c in layout.blocked_cells:
		return Enums.TileKind.BLOCKED
	for p in layout.paths:
		if p != null and c in p.cells:
			return Enums.TileKind.PATH
	return Enums.TileKind.GROUND


func _in_bounds(c: Vector2i) -> bool:
	return layout != null and c.x >= 0 and c.y >= 0 and c.x < layout.size.x and c.y < layout.size.y


# --- input ----------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if layout == null:
		return
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != _hover:
			_hover = c
			hovered.emit(c)
			queue_redraw()
		if _painting and tool != Tool.PATH:
			_apply(c, false)
	elif event is InputEventMouseButton and event.pressed:
		var c := cell_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			stroke_started.emit()
			_painting = event.button_index == MOUSE_BUTTON_LEFT and tool != Tool.PATH
			_apply(c, event.button_index == MOUSE_BUTTON_RIGHT)
			if not _painting:
				stroke_finished.emit()
			accept_event()
	elif event is InputEventMouseButton and not event.pressed and _painting:
		_painting = false
		stroke_finished.emit()


func _apply(c: Vector2i, erase: bool) -> void:
	if not _in_bounds(c):
		return
	if erase or tool == Tool.ERASE:
		_erase(c)
	else:
		match tool:
			Tool.PATH: _path_click(c)
			Tool.DEPLOY_PATH: _toggle_only(c, layout.deploy_path_cells)
			Tool.DEPLOY_EDGE: _toggle_only(c, layout.deploy_edge_cells)
			Tool.BUILD: _toggle_only(c, layout.build_slots)
			Tool.BLOCKED: _toggle_only(c, layout.blocked_cells)
	layout.emit_changed()
	queue_redraw()


# Adds `c` to one marking list (removing it from the others). Painting never toggles off.
func _toggle_only(c: Vector2i, target: Array[Vector2i]) -> void:
	for list in [layout.deploy_path_cells, layout.deploy_edge_cells, layout.build_slots, layout.blocked_cells]:
		if list != target:
			list.erase(c)
	if c not in target:
		target.append(c)


# Path tool: extend the current path by a neighbouring tile; clicking its last
# tile again removes it. A new path starts anywhere.
func _path_click(c: Vector2i) -> void:
	while layout.paths.size() <= path_index:
		layout.paths.append(MapPath.new())
	var p: MapPath = layout.paths[path_index]
	if p == null:
		p = MapPath.new()
		layout.paths[path_index] = p
	if p.cells.is_empty():
		p.cells.append(c)
		return
	var last: Vector2i = p.cells[p.cells.size() - 1]
	if c == last:
		p.cells.remove_at(p.cells.size() - 1)
		return
	var d := c - last
	if absi(d.x) + absi(d.y) == 1:
		p.cells.append(c)
	elif d.x == 0 or d.y == 0:
		# straight run: fill the gap along the iso diagonal
		var step := Vector2i(signi(d.x), signi(d.y))
		while last != c:
			last += step
			p.cells.append(last)


# Eraser: clears markings; on a path it cuts the path from that tile onward.
func _erase(c: Vector2i) -> void:
	for list in [layout.deploy_path_cells, layout.deploy_edge_cells, layout.build_slots, layout.blocked_cells]:
		list.erase(c)
	for p in layout.paths:
		if p == null:
			continue
		var i := p.cells.find(c)
		if i >= 0:
			p.cells.resize(i)
