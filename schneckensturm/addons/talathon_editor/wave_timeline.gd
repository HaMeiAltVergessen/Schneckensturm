@tool
# Preview of a WaveSet without starting the game: one row per wave, one bar per
# spawn group (start = delay, length = spawn duration, ticks = single spawns).
extends Control

var waveset: WaveSet


func _ready() -> void:
	custom_minimum_size = Vector2(0, 160)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.09))
	if waveset == null or waveset.waves.is_empty():
		return
	var font := get_theme_default_font()
	var longest := 1.0
	for w in waveset.waves:
		if w != null:
			longest = maxf(longest, w.duration() + 1.0)
	var label_w := 70.0
	var row_h := minf(28.0, (size.y - 20.0) / waveset.waves.size())
	var scale := (size.x - label_w - 10.0) / longest
	for wi in waveset.waves.size():
		var w: WaveData = waveset.waves[wi]
		var y := 10.0 + wi * row_h
		draw_string(font, Vector2(6, y + row_h * 0.7), "W%d (%d)" % [wi + 1, w.unit_count() if w != null else 0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.85))
		if w == null:
			continue
		var gh := (row_h - 4.0) / maxf(1.0, w.groups.size())
		for gi in w.groups.size():
			var g: SpawnGroup = w.groups[gi]
			if g == null:
				continue
			var col := _color_for(g.unit)
			var x0 := label_w + g.delay * scale
			var gy := y + 2.0 + gi * gh
			draw_rect(Rect2(x0, gy, maxf(3.0, g.interval * maxf(0, g.count - 1) * scale), gh - 1.0), Color(col, 0.45))
			for k in g.count:
				var x := x0 + g.interval * k * scale
				draw_line(Vector2(x, gy), Vector2(x, gy + gh - 1.0), col, 2.0)
	# seconds axis
	var step := 5.0 if longest < 40.0 else 10.0
	var t := 0.0
	while t <= longest:
		var x := label_w + t * scale
		draw_line(Vector2(x, size.y - 8), Vector2(x, size.y - 2), Color(0.5, 0.5, 0.55), 1.0)
		t += step


func _color_for(u: UnitData) -> Color:
	if u == null:
		return Color(0.5, 0.5, 0.5)
	match u.target_class:
		Enums.TargetClass.RANGED: return Color(0.95, 0.75, 0.3)
		Enums.TargetClass.FLYER: return Color(0.5, 0.8, 1.0)
		Enums.TargetClass.ASSASSIN: return Color(0.8, 0.4, 1.0)
		Enums.TargetClass.SIEGE: return Color(0.6, 0.6, 0.6)
	return Color(1.0, 0.4, 0.35) if not u.is_boss else Color(1.0, 0.2, 0.8)
