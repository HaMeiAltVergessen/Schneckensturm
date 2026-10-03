# Visual side of a match: map, y-sorted entities and camera. Observes a MatchSim
# (signals + per-frame state) and never changes rules itself.
class_name MatchWorld
extends Node2D

const RING_HERO := Color(0.95, 0.75, 0.30)
const RING_TROOP := Color(0.55, 0.80, 1.00)
const RING_ENEMY := Color(0.85, 0.25, 0.30)
const RING_BOSS := Color(0.75, 0.20, 0.85)

var sim: MatchSim
var map: MapView
var entities: Node2D
var camera: MatchCamera
var popups := true
var unit_visuals: Dictionary = {}       # SimUnit -> UnitVisual
var building_visuals: Dictionary = {}   # SimBuilding -> BuildingVisual
var dahlias: Array[DahliaVisual] = []


func start(p_sim: MatchSim) -> void:
	sim = p_sim
	map = MapView.new()
	add_child(map)
	map.build(sim.layout)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	camera = MatchCamera.new()
	add_child(camera)
	camera.make_current()
	camera.frame(map.world_rect(), Settings.camera_zoom)
	sim.unit_spawned.connect(_on_unit_spawned)
	sim.unit_removed.connect(_on_unit_removed)
	sim.unit_attacked.connect(_on_attacked)
	sim.building_added.connect(_on_building_added)
	sim.building_removed.connect(_on_building_removed)
	sim.building_upgraded.connect(_on_building_upgraded)
	sim.ability_used.connect(_on_ability_used)
	sim.lives_changed.connect(_on_lives_changed)
	_place_dahlias()


# One dahlia at every distinct path end (paths that meet share it).
func _place_dahlias() -> void:
	var ends := {}
	for p in sim.layout.paths:
		if not p.cells.is_empty():
			ends[p.cells[p.cells.size() - 1]] = true
	for c in ends:
		var d := DahliaVisual.new()
		d.max_petals = sim.max_lives
		d.petals = sim.lives
		d.position = map.grid.to_world(Vector2(c))
		entities.add_child(d)
		dahlias.append(d)


func _on_lives_changed(lives: int) -> void:
	for d in dahlias:
		d.set_petals(lives, sim.max_lives)


func _process(_delta: float) -> void:
	if sim == null:
		return
	for u in unit_visuals:
		var v: UnitVisual = unit_visuals[u]
		if not is_instance_valid(v):
			continue
		var target := map.grid.to_world(u.pos)
		var dx := target.x - v.position.x
		v.moving = v.position.distance_squared_to(target) > 0.01
		if v.moving:
			v.set_facing(dx)
		v.position = target
		v.set_hp(u.hp_ratio())
		if u.kind == SimUnit.Kind.HERO:
			v.set_charge(_hero_charge(u))
	for b in building_visuals:
		var bv: BuildingVisual = building_visuals[b]
		if is_instance_valid(bv):
			bv.set_state(b.hp / b.max_hp, b.charge if b.ability() != null else -1.0)


func _hero_charge(u: SimUnit) -> float:
	var slot: Dictionary = sim.heroes.get(u.hero_id, {})
	var abilities: Array = slot.get("abilities", [])
	if abilities.is_empty():
		return -1.0
	var cd: float = slot["ability_cd"][0]
	return 1.0 - cd / maxf(0.01, abilities[0].cooldown)


func screen_to_world(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p


func cell_at_screen(p: Vector2) -> Vector2i:
	return map.grid.to_cell(screen_to_world(p))


func visual_of(obj: Object) -> Node2D:
	if obj is SimUnit:
		return unit_visuals.get(obj)
	return building_visuals.get(obj)


func _on_unit_spawned(u: SimUnit) -> void:
	var v := UnitVisual.new()
	var tex: Texture2D = u.data.token
	var frames: SpriteFrames = u.data.sprite_frames
	var ring := RING_ENEMY
	var mult := 1.0
	match u.kind:
		SimUnit.Kind.HERO:
			ring = RING_HERO
			mult = 1.15
		SimUnit.Kind.TROOP, SimUnit.Kind.SUMMON:
			ring = RING_TROOP
			mult = 0.8
		_:
			var ud: UnitData = u.data
			ring = RING_BOSS if ud.is_boss else RING_ENEMY
			mult = ud.visual_scale
	v.setup(tex, frames, ring, mult)
	v.position = map.grid.to_world(u.pos)
	entities.add_child(v)
	unit_visuals[u] = v
	v.modulate.a = 0.0
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.2)


func _on_unit_removed(u: SimUnit, reason: String) -> void:
	var v: UnitVisual = unit_visuals.get(u)
	unit_visuals.erase(u)
	if is_instance_valid(v):
		v.die(reason)
	if reason == "died" and u.side == Enums.Side.ENEMY:
		AudioManager.play_sfx("enemy_death", 0.1)


func _on_attacked(attacker: Object, target: Object, amount: float, is_heal: bool) -> void:
	var av := visual_of(attacker)
	var tv := visual_of(target)
	if av is UnitVisual and tv != null and not is_heal:
		av.lunge(tv.global_position)
	if tv is UnitVisual:
		if is_heal:
			tv.flash(Color(0.6, 1.6, 0.7))
		else:
			tv.flash()
	elif tv is BuildingVisual and not is_heal:
		tv.flash()
	if popups and tv != null and amount >= 1.0:
		var col := Color(0.5, 1.0, 0.55) if is_heal else (Color(1.0, 0.45, 0.4) if target is SimUnit and target.is_player() else Color(1, 1, 1))
		FX.popup(entities, tv.global_position + Vector2(randf_range(-10, 10), -70), ("+" if is_heal else "") + str(int(round(amount))), col)


func _on_building_added(b: SimBuilding) -> void:
	var bv := BuildingVisual.new()
	bv.setup(b.data, b.is_tower)
	bv.max_level = b.max_level()
	bv.position = map.grid.to_world(Vector2(b.cell))
	entities.add_child(bv)
	building_visuals[b] = bv
	bv.scale = Vector2(1.0, 0.2)
	bv.create_tween().tween_property(bv, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_building_upgraded(b: SimBuilding) -> void:
	var bv: BuildingVisual = building_visuals.get(b)
	if is_instance_valid(bv):
		bv.set_level(b.level, b.max_level(), b.level_texture())
	AudioManager.play_sfx("level_up")


func _on_building_removed(b: SimBuilding) -> void:
	var bv: BuildingVisual = building_visuals.get(b)
	building_visuals.erase(b)
	if is_instance_valid(bv):
		bv.die()


func _on_ability_used(_source: Object, ab: AbilityData, at: Vector2) -> void:
	if ab.kind == Enums.AbilityKind.STRIKE_ALL:
		_strike_all_fx()
		return
	var fx := AbilityFx.new()
	fx.radius_px = maxf(0.6, ab.radius) * float(IsoGrid.TILE_SIZE.x) * 0.5
	fx.color = _ability_color(ab.kind)
	fx.position = map.grid.to_world(at)
	add_child(fx)
	AudioManager.play_sfx("heal" if ab.kind == Enums.AbilityKind.HEAL else ("summon" if ab.kind == Enums.AbilityKind.SUMMON else "attack"))


# "Leinen los": a burst on every snail plus a short full-screen flash.
func _strike_all_fx() -> void:
	for e in sim.alive_enemies():
		var fx := AbilityFx.new()
		fx.radius_px = 48.0
		fx.color = Color(1.0, 0.85, 0.4)
		fx.position = map.grid.to_world(e.pos)
		add_child(fx)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.75, 0.55)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
	AudioManager.play_sfx("attack")


func _ability_color(kind: int) -> Color:
	match kind:
		Enums.AbilityKind.HEAL: return Color(0.5, 1.0, 0.6)
		Enums.AbilityKind.BUFF_ATTACK: return Color(1.0, 0.85, 0.35)
		Enums.AbilityKind.STUN: return Color(0.6, 0.8, 1.0)
		Enums.AbilityKind.SUMMON: return Color(0.8, 0.9, 1.0)
	return Color(1.0, 0.5, 0.3)
