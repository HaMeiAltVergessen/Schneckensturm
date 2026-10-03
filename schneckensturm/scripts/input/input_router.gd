# Autoload: one place that turns raw touch/mouse input into gestures, so gameplay
# code never polls devices itself. Only *unhandled* input is routed — UI controls
# consume their own clicks first.
#   Touch: tap, long-press, one-finger drag (pan), two-finger pinch (zoom)
#   Mouse: left click = tap (via touch emulation), right click = long-press,
#          wheel = zoom, middle/left drag = pan
extends Node

signal tapped(screen_pos: Vector2)
signal long_pressed(screen_pos: Vector2)
signal dragged(relative: Vector2)
signal zoomed(factor: float, screen_center: Vector2)

const LONG_PRESS_TIME := 0.45
const DRAG_THRESHOLD := 12.0
const WHEEL_ZOOM := 1.1

var _touches: Dictionary = {}     # index -> current position
var _start_pos := Vector2.ZERO
var _press_time := 0.0
var _dragging := false
var _long_fired := false
var _pinch_dist := 0.0
var _middle_drag := false


func _process(delta: float) -> void:
	if _touches.size() != 1 or _dragging or _long_fired:
		return
	_press_time += delta
	if _press_time >= LONG_PRESS_TIME:
		_long_fired = true
		long_pressed.emit(_start_pos)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _middle_drag:
		dragged.emit(event.relative)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_start_pos = e.position
			_press_time = 0.0
			_dragging = false
			_long_fired = false
		elif _touches.size() == 2:
			_dragging = true   # a pinch never ends as a tap
			_pinch_dist = _touch_distance()
		return
	var was_single := _touches.size() == 1
	_touches.erase(e.index)
	if was_single and not _dragging and not _long_fired:
		tapped.emit(e.position)
	if _touches.is_empty():
		_dragging = false


func _on_drag(e: InputEventScreenDrag) -> void:
	_touches[e.index] = e.position
	if _touches.size() >= 2:
		var d := _touch_distance()
		if _pinch_dist > 0.0 and d > 0.0:
			zoomed.emit(d / _pinch_dist, _touch_center())
		_pinch_dist = d
		return
	if not _dragging and e.position.distance_to(_start_pos) > DRAG_THRESHOLD:
		_dragging = true
	if _dragging:
		dragged.emit(e.relative)


func _on_mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_RIGHT:
			if e.pressed:
				long_pressed.emit(e.position)
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				zoomed.emit(WHEEL_ZOOM, e.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				zoomed.emit(1.0 / WHEEL_ZOOM, e.position)
		MOUSE_BUTTON_MIDDLE:
			_middle_drag = e.pressed


func _touch_distance() -> float:
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1]) if pts.size() >= 2 else 0.0


func _touch_center() -> Vector2:
	var pts := _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5 if pts.size() >= 2 else Vector2.ZERO
