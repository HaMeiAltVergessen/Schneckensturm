# Pan/zoom camera for the iso map, driven only by InputRouter gestures
# (touch drag / pinch, mouse drag / wheel). Keeps the view inside the map bounds.
class_name MatchCamera
extends Camera2D

const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0

var bounds := Rect2()
## Screen space covered by HUD bars (px); the map is framed in the area between.
var hud_top := 60.0
var hud_bottom := 132.0


func _ready() -> void:
	InputRouter.dragged.connect(_on_drag)
	InputRouter.zoomed.connect(_on_zoom)


func frame(rect: Rect2, initial_zoom := 1.0) -> void:
	var vp := get_viewport_rect().size
	var usable := Vector2(vp.x, maxf(100.0, vp.y - hud_top - hud_bottom))
	# fit the whole map on first view, never closer than the preferred zoom
	var fit := minf(usable.x / maxf(1.0, rect.size.x + 96.0), usable.y / maxf(1.0, rect.size.y + 96.0))
	var z := clampf(minf(fit, initial_zoom), MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	# allow scrolling the map edges out from under the HUD bars
	bounds = Rect2(rect.position - Vector2(96.0, 96.0 + hud_top / z), rect.size + Vector2(192.0, 192.0 + (hud_top + hud_bottom) / z))
	position = rect.get_center() + Vector2(0.0, (hud_bottom - hud_top) * 0.5 / z)
	_clamp()


func _on_drag(relative: Vector2) -> void:
	position -= relative / zoom.x
	_clamp()


func _on_zoom(factor: float, screen_center: Vector2) -> void:
	var before := _screen_to_world(screen_center)
	var z := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	# keep the point under the fingers/cursor fixed
	position += before - _screen_to_world(screen_center)
	_clamp()


func _screen_to_world(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return position + (p - vp * 0.5) / zoom.x


func _clamp() -> void:
	if bounds.size == Vector2.ZERO:
		return
	var half := get_viewport_rect().size * 0.5 / zoom.x
	var lo := bounds.position + half
	var hi := bounds.end - half
	position.x = clampf(position.x, minf(lo.x, bounds.get_center().x), maxf(hi.x, bounds.get_center().x))
	position.y = clampf(position.y, minf(lo.y, bounds.get_center().y), maxf(hi.y, bounds.get_center().y))
