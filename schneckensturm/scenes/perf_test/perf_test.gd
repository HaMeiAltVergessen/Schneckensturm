# Performance measurement (M1/M3): streams N enemies over the longest layout,
# optionally with a defended line (heroes, barracks, towers) so blocking and
# combat cost is included. Shows FPS, unit count and sim time per frame.
extends Node2D

const LAYOUT := "layout_gar_l3"

var _sim: MatchSim
var _world: MatchWorld
var _target := 60
var _label: Label
var _sim_ms := 0.0
var _defended := false
var _enemy: UnitData


func _ready() -> void:
	_enemy = ContentDB.get_unit("sna_slug")
	_start()
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := UITheme.hbox(10)
	bar.position = Vector2(12, 12)
	layer.add_child(bar)
	_label = UITheme.label("", 20)
	_label.custom_minimum_size = Vector2(460, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var panel := UITheme.panel(Color(0, 0, 0, 0.6))
	panel.add_child(_label)
	bar.add_child(panel)
	for spec in [["-50", -50], ["-10", -10], ["+10", 10], ["+50", 50]]:
		var b := UITheme.button(spec[0], 20)
		b.custom_minimum_size = Vector2(70, 48)
		var d: int = spec[1]
		b.pressed.connect(func(): _target = clampi(_target + d, 0, 1000))
		bar.add_child(b)
	var def := UITheme.button(tr("UI_PERF_DEFENDED"), 20)
	def.toggle_mode = true
	def.toggled.connect(func(v):
		_defended = v
		_restart())
	bar.add_child(def)
	var back := UITheme.button(tr("UI_BACK"), 20)
	back.pressed.connect(func(): SceneRouter.goto("main_menu"))
	bar.add_child(back)


func _start() -> void:
	var ws := WaveSet.new()
	ws.id = "perf"
	ws.layout = ContentDB.layouts[LAYOUT]
	ws.lives = 1000000
	ws.prep_time = 1.0e9
	ws.start_resource = 999
	ws.resource_cap = 999
	var heroes := []
	if _defended:
		for h in ContentDB.heroes_of("garden"):
			var e := h.match_entry()
			e["stats"]["max_hp"] = 999999
			e["hp"] = 999999
			e["abilities"] = []
			heroes.append(e)
	_sim = MatchSim.new()
	_sim.setup(ws, heroes)
	_world = MatchWorld.new()
	_world.popups = false
	add_child(_world)
	_world.start(_sim)
	if _defended:
		var l: MapLayout = ws.layout
		_sim.deploy_hero("gar_christina", l.deploy_edge_cells[1])
		for i in l.build_slots.size():
			var data: Resource = ContentDB.barracks["gar_rose_bush"] if i % 2 == 0 else ContentDB.towers["gar_rosehip"]
			_sim.build(data, l.build_slots[i])


func _restart() -> void:
	_sim.dispose()
	_world.queue_free()
	_start()


func _process(delta: float) -> void:
	var enemies := _sim.alive_enemies().size()
	# keep the enemy count at the target: spawn a few per frame along both ends
	var spawn := mini(_target - enemies, 4)
	for i in maxi(0, spawn):
		var u := _sim.spawn_enemy(_enemy)
		if u != null:
			u.progress = randf() * 3.0
			u.pos = MatchSim.path_point(u.path, u.progress)
	var t0 := Time.get_ticks_usec()
	_sim.step(delta)
	_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	_label.text = "FPS %d   %s %d/%d   sim %.2f ms   %s" % [Engine.get_frames_per_second(), tr("UI_UNITS"),
		_sim.units.size(), _target, _sim_ms, OS.get_name()]


func _exit_tree() -> void:
	if _sim != null:
		_sim.dispose()
