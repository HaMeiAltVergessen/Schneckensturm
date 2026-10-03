# The dahlia at the end of the snail path. Shows the remaining petals (= lives):
# with real art it switches between the stage textures (assets/garden/dahlia_<n>.png,
# 0 = untouched … 3 = nearly eaten), otherwise it draws a procedural flower whose
# petals disappear one by one.
class_name DahliaVisual
extends Node2D

const STAGE_PATH := "res://assets/garden/dahlia_%d.png"
const STAGES := 4
const PETAL_COLOR := Color(0.93, 0.36, 0.55)
const PETAL_DARK := Color(0.72, 0.18, 0.38)
const CENTER_COLOR := Color(0.98, 0.80, 0.30)
const STEM_COLOR := Color(0.28, 0.55, 0.25)

var max_petals := 10
var petals := 10
var _stages: Array[Texture2D] = []
var _sprite: Sprite2D
var _shake := 0.0


func _ready() -> void:
	for i in STAGES:
		var p := STAGE_PATH % i
		if ResourceLoader.exists(p):
			_stages.append(load(p))
	if _stages.size() == STAGES:
		_sprite = Sprite2D.new()
		_sprite.offset = Vector2(0, -_stages[0].get_height() * 0.5 + 16)
		add_child(_sprite)
	_refresh()


func set_petals(n: int, max_n: int) -> void:
	var lost := n < petals
	petals = maxi(0, n)
	max_petals = maxi(1, max_n)
	_refresh()
	if lost:
		_nibble()


func _refresh() -> void:
	if _sprite != null:
		var ratio := float(petals) / float(max_petals)
		var stage := clampi(int(floor((1.0 - ratio) * STAGES)), 0, STAGES - 1)
		_sprite.texture = _stages[stage]
	queue_redraw()


# Little shake + red flash when a snail takes a bite.
func _nibble() -> void:
	modulate = Color(1.6, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.35)
	_shake = 0.3
	set_process(true)


func _process(delta: float) -> void:
	if _shake <= 0.0:
		rotation = 0.0
		set_process(false)
		return
	_shake -= delta
	rotation = sin(_shake * 60.0) * 0.08


func _draw() -> void:
	if _sprite != null:
		return
	# stem and leaves
	draw_line(Vector2(0, 10), Vector2(0, -60), STEM_COLOR, 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(-26, -34), Vector2(-6, -12)]), STEM_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -32), Vector2(24, -46), Vector2(6, -24)]), STEM_COLOR)
	# petals: one per remaining life, evenly spaced around the head
	var head := Vector2(0, -78)
	var shown := clampi(petals, 0, max_petals)
	for i in max_petals:
		var a := TAU * float(i) / float(max_petals) - PI * 0.5
		var tip := head + Vector2(cos(a), sin(a)) * 34.0
		var side := Vector2(-sin(a), cos(a)) * 9.0
		var base := head + Vector2(cos(a), sin(a)) * 8.0
		var poly := PackedVector2Array([base + side * 0.6, tip + side * 0.4, tip + Vector2(cos(a), sin(a)) * 5.0, tip - side * 0.4, base - side * 0.6])
		if i < shown:
			draw_colored_polygon(poly, PETAL_COLOR if i % 2 == 0 else PETAL_DARK)
		else:
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.3, 0.2, 0.25, 0.35), 1.5)
	draw_circle(head, 11.0, CENTER_COLOR)
