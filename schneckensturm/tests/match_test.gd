# Headless rules test for MatchSim: target-rule matrix, blocking, targeting per
# class, leaks/lives, retreat + HP persistence, economy, towers, barracks, summons.
extends TestSuite

const DT := 0.05

var _sims: Array[MatchSim] = []


func _run() -> void:
	tag = "MATCH"
	_test_rule_matrix()
	_test_blocking_capacity()
	_test_flyer_ignores_block()
	_test_enemy_targeting()
	_test_melee_cannot_hit_flyer()
	_test_leaks_and_defeat()
	_test_retreat_keeps_hp()
	_test_deploy_rules()
	_test_kill_bonus_and_regen()
	_test_waves_and_victory()
	_test_barracks_respawn()
	_test_tower_ability()
	_test_summon_blocks()
	_test_queue_behind_hero()
	_test_queue_releases_on_death()
	_test_troops_let_surplus_pass()
	_test_tower_upgrade()
	_test_barracks_upgrade()
	_test_iso_grid()
	_test_strike_all()
	_test_essential_hero_defeat()
	_test_heal_hero()
	_test_brood()
	_test_boss_leak_ends_match()
	_test_balance_config()
	_test_give_up_is_defeat()
	for s in _sims:
		s.dispose()


# --- builders ---------------------------------------------------------------
func _layout() -> MapLayout:
	var l := MapLayout.new()
	l.size = Vector2i(12, 5)
	var p := MapPath.new()
	for x in 12:
		p.cells.append(Vector2i(x, 2))
	l.paths.append(p)
	l.deploy_path_cells = [Vector2i(5, 2), Vector2i(8, 2)] as Array[Vector2i]
	l.deploy_edge_cells = [Vector2i(5, 1), Vector2i(5, 3), Vector2i(9, 1)] as Array[Vector2i]
	l.build_slots = [Vector2i(3, 1), Vector2i(7, 3)] as Array[Vector2i]
	l.hero_limit = 2
	return l


func _ws(waves: Array[WaveData] = []) -> WaveSet:
	var w := WaveSet.new()
	w.id = "test"
	w.layout = _layout()
	w.waves = waves
	w.prep_time = 100000.0   # tests drive waves explicitly
	w.start_resource = 50
	w.lives = 3
	return w


func _unit(tc: int, hp := 300, atk := 50, speed := 1.0, reach := 0.8, ranged := false) -> UnitData:
	var u := UnitData.new()
	u.id = "u_%d" % tc
	u.target_class = tc
	u.max_hp = hp
	u.attack = atk
	u.defense = 0
	u.move_speed = speed
	u.attack_range = reach
	u.is_ranged = ranged
	u.bounty = 2
	return u


func _hero(id: String, placement: int, block := 2, atk := 100, hp := 1000) -> Dictionary:
	var h := HeroData.new()
	h.id = id
	h.placement = placement
	h.block = block
	h.attack = atk
	h.max_hp = hp
	h.defense = 0
	h.deploy_cost = 10
	h.redeploy_cooldown = 20.0
	if placement == Enums.Placement.EDGE:
		h.range_pattern = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 2), Vector2i(1, 2), Vector2i(-1, 2)] as Array[Vector2i]
	var stats := h.match_stats()
	return { "id": id, "data": h, "stats": stats, "hp": stats["max_hp"], "abilities": [] }


func _sim(ws: WaveSet, heroes: Array = []) -> MatchSim:
	var s := MatchSim.new()
	s.setup(ws, heroes)
	_sims.append(s)
	return s


func _run_for(s: MatchSim, seconds: float) -> void:
	var t := 0.0
	while t < seconds and s.phase != MatchSim.Phase.ENDED:
		s.step(DT)
		t += DT


# --- tests ------------------------------------------------------------------
func _test_rule_matrix() -> void:
	expect(TargetRuleSet.make_default().missing_classes().is_empty(), "default rule set incomplete")
	expect(ContentDB.target_rules.missing_classes().is_empty(), "data/rules/target_rules.tres incomplete: %s" % str(ContentDB.target_rules.missing_classes()))
	var seen := {}
	for r in ContentDB.target_rules.rules:
		expect(not seen.has(r.target_class), "duplicate rule for class %d" % r.target_class)
		seen[r.target_class] = true
	var flyer := ContentDB.target_rules.rule_for(Enums.TargetClass.FLYER)
	expect(flyer != null and not flyer.can_be_blocked and not flyer.hittable_by_melee, "flyer rule wrong")


func _test_blocking_capacity() -> void:
	var s := _sim(_ws(), [_hero("w", Enums.Placement.PATH, 2, 0)])
	var hero := s.deploy_hero("w", Vector2i(5, 2))
	expect(hero != null, "melee hero deploy failed")
	var imp := _unit(Enums.TargetClass.MELEE, 300, 0)
	for i in 3:
		var e := s.spawn_enemy(imp)
		e.progress = 4.4 - i * 0.3
		e.pos = MatchSim.path_point(e.path, e.progress)
	_run_for(s, 1.5)
	expect_eq(hero.blocking.size(), 2, "hero with block 2 should hold two enemies")
	_run_for(s, 8.0)
	expect_eq(s.leaks, 0, "nobody walks past a living hero")
	expect_eq(hero.blocking.size(), 2, "blocked enemies stay blocked")
	var queued := s.alive_enemies().filter(func(e): return e.queued_at == hero)
	expect_eq(queued.size(), 1, "third enemy waits in the queue")
	s.retreat(hero)
	var freed := 0
	for e in s.alive_enemies():
		if e.blocked_by == null and e.queued_at == null:
			freed += 1
	expect_eq(freed, 3, "retreat must release blocked and queued enemies")
	_run_for(s, 10.0)
	expect_eq(s.leaks, 3, "released enemies walk on")


func _test_flyer_ignores_block() -> void:
	var s := _sim(_ws(), [_hero("w", Enums.Placement.PATH, 3, 0)])
	var hero := s.deploy_hero("w", Vector2i(5, 2))
	var e := s.spawn_enemy(_unit(Enums.TargetClass.FLYER))
	e.progress = 4.8
	_run_for(s, 0.5)
	expect(e.blocked_by == null and hero.blocking.is_empty(), "flyer must not be blocked")


func _test_enemy_targeting() -> void:
	var rules := TargetRuleSet.make_default()
	var blocker := SimUnit.new()
	blocker.side = Enums.Side.PLAYER
	blocker.pos = Vector2(5, 2)
	blocker.block_capacity = 1
	var edge := SimUnit.new()
	edge.side = Enums.Side.PLAYER
	edge.pos = Vector2(5, 1)
	var bld := SimBuilding.new()
	bld.cell = Vector2i(4, 1)

	var melee := _enemy_at(Enums.TargetClass.MELEE, Vector2(5, 2), 0.8)
	expect(Targeting.enemy_target(melee, rules, [blocker, edge], [bld]) == null, "unblocked melee must not attack")
	melee.blocked_by = blocker
	expect(Targeting.enemy_target(melee, rules, [blocker, edge], [bld]) == blocker, "blocked melee attacks its blocker")

	var ranged := _enemy_at(Enums.TargetClass.RANGED, Vector2(5, 2.4), 2.5)
	expect(Targeting.enemy_target(ranged, rules, [edge], []) == edge, "ranged attacks any defender in range")

	var assassin := _enemy_at(Enums.TargetClass.ASSASSIN, Vector2(5, 1.6), 1.2)
	blocker.blocking.append(melee)
	expect(Targeting.enemy_target(assassin, rules, [blocker, edge], []) == edge, "assassin prefers unprotected (non-blocking) targets")

	var siege := _enemy_at(Enums.TargetClass.SIEGE, Vector2(4, 2), 1.5)
	expect(Targeting.enemy_target(siege, rules, [blocker, edge], [bld]) == bld, "siege attacks buildings first")
	blocker.blocking.clear()
	melee.blocked_by = null


func _enemy_at(tc: int, p: Vector2, reach: float) -> SimUnit:
	var e := SimUnit.new()
	e.side = Enums.Side.ENEMY
	e.target_class = tc
	e.pos = p
	e.attack_range = reach
	return e


func _test_melee_cannot_hit_flyer() -> void:
	var s := _sim(_ws(), [_hero("w", Enums.Placement.PATH, 2, 100), _hero("a", Enums.Placement.EDGE, 0, 100)])
	var melee := s.deploy_hero("w", Vector2i(5, 2))
	var flyer := s.spawn_enemy(_unit(Enums.TargetClass.FLYER, 5000, 0, 0.0))
	flyer.progress = 5.0
	flyer.pos = Vector2(5, 2)
	expect(Targeting.defender_target(melee, s.alive_enemies(), s.rules) == null, "melee hero must not target a flyer")
	var archer := s.deploy_hero("a", Vector2i(5, 1))
	expect(Targeting.defender_target(archer, s.alive_enemies(), s.rules) == flyer, "ranged hero must target the flyer")


func _test_leaks_and_defeat() -> void:
	var wave := WaveData.new()
	var g := SpawnGroup.new()
	g.unit = _unit(Enums.TargetClass.MELEE, 100, 0, 4.0)
	g.count = 3
	g.interval = 0.2
	wave.groups.append(g)
	var s := _sim(_ws([wave] as Array[WaveData]))
	s.call_next_wave()
	var result := [null]
	s.ended.connect(func(v): result[0] = v)
	_run_for(s, 10.0)
	expect_eq(s.leaks, 3, "three leaks expected")
	expect_eq(s.lives, 0, "lives should drop to 0")
	expect(result[0] == false, "three leaks must end in defeat")


func _test_retreat_keeps_hp() -> void:
	var s := _sim(_ws(), [_hero("w", Enums.Placement.PATH, 2, 0, 1000)])
	var r0 := s.resource
	var hero := s.deploy_hero("w", Vector2i(5, 2))
	expect(is_equal_approx(s.resource, r0 - 10.0), "deploy should cost 10")
	hero.hp = 420.0
	var before := s.resource
	var refund := s.retreat(hero)
	expect_eq(refund, 3, "35 % of 10 rounds down to 3")
	expect(is_equal_approx(s.resource, before + 3.0), "refund added to resource")
	expect_eq(s.heroes["w"]["hp"], 420, "hero HP kept after retreat")
	expect_eq(s.can_deploy_hero("w", Vector2i(5, 2)), MatchSim.DeployError.COOLDOWN, "redeploy cooldown active")
	_run_for(s, 20.1)
	var again := s.deploy_hero("w", Vector2i(5, 2))
	expect(again != null and is_equal_approx(again.hp, 420.0), "redeployed hero keeps damaged HP")
	expect_eq(s.result()["hero_hp"]["w"], 420, "result reports live HP")
	again.hp = 0.0
	s._kill(again)
	expect_eq(s.can_deploy_hero("w", Vector2i(5, 2)), MatchSim.DeployError.FALLEN, "fallen hero cannot redeploy")
	expect_eq(s.result()["hero_hp"]["w"], 0, "fallen hero reports 0 HP")


func _test_deploy_rules() -> void:
	var ws := _ws()
	var s := _sim(ws, [_hero("w", Enums.Placement.PATH), _hero("a", Enums.Placement.EDGE, 0), _hero("x", Enums.Placement.PATH)])
	expect_eq(s.can_deploy_hero("w", Vector2i(5, 1)), MatchSim.DeployError.TILE_KIND, "path hero on edge tile")
	expect_eq(s.can_deploy_hero("a", Vector2i(5, 2)), MatchSim.DeployError.TILE_KIND, "edge hero on path tile")
	expect_eq(s.can_deploy_hero("w", Vector2i(0, 0)), MatchSim.DeployError.TILE_KIND, "plain ground not deployable")
	s.deploy_hero("w", Vector2i(5, 2))
	expect_eq(s.can_deploy_hero("x", Vector2i(5, 2)), MatchSim.DeployError.OCCUPIED, "tile occupied")
	s.deploy_hero("a", Vector2i(5, 1))
	expect_eq(s.can_deploy_hero("x", Vector2i(8, 2)), MatchSim.DeployError.LIMIT, "hero_limit 2 enforced")
	s.resource = 0.0
	s.retreat(s.heroes["a"]["unit"])
	s.resource = 0.0
	expect_eq(s.can_deploy_hero("x", Vector2i(8, 2)), MatchSim.DeployError.COST, "not enough resource")


func _test_kill_bonus_and_regen() -> void:
	var ws := _ws()
	ws.start_resource = 0
	ws.resource_regen = 2.0
	var s := MatchSim.new()
	s.setup(ws, [])
	s.step(1.0)
	expect(is_equal_approx(s.resource, 2.0), "regen 2/s")
	var e := s.spawn_enemy(_unit(Enums.TargetClass.MELEE, 10))
	e.hp = 0.0
	s._kill(e)
	expect(is_equal_approx(s.resource, 4.0), "kill bonus = bounty 2")
	ws.resource_cap = 5
	s.step(10.0)
	expect(is_equal_approx(s.resource, 5.0), "resource capped")


func _test_waves_and_victory() -> void:
	var waves: Array[WaveData] = []
	for i in 2:
		var w := WaveData.new()
		var g := SpawnGroup.new()
		g.unit = _unit(Enums.TargetClass.MELEE, 50, 0, 1.0)
		g.count = 2
		g.interval = 0.5
		w.groups.append(g)
		w.next_delay = 3.0
		waves.append(w)
	var ws := _ws(waves)
	ws.prep_time = 5.0
	var s := _sim(ws, [_hero("w", Enums.Placement.PATH, 3, 400)])
	expect_eq(s.phase, MatchSim.Phase.PREP, "starts in prep")
	s.step(1.0)
	s.deploy_hero("w", Vector2i(5, 2))
	var started: Array[int] = []
	s.wave_started.connect(func(i): started.append(i))
	_run_for(s, 4.5)
	expect_eq(started, [0] as Array[int], "wave 0 after 5 s prep")
	expect(s.call_next_wave(), "calling the next wave early works")
	expect_eq(s.wave_index, 1, "second wave started early")
	var won := [false]
	s.ended.connect(func(v): won[0] = v)
	_run_for(s, 30.0)
	expect(won[0], "defended map must be won")
	expect_eq(s.kills, 4, "all four enemies killed")
	expect(s.result()["victory"], "result victory flag")


func _test_barracks_respawn() -> void:
	var s := _sim(_ws())
	var troop := _unit(Enums.TargetClass.MELEE, 200, 20)
	var bd := BarracksData.new()
	bd.id = "b"
	bd.unit = troop
	bd.squad_size = 2
	bd.respawn_time = 3.0
	bd.cost = 10
	var b := s.build(bd, Vector2i(3, 1))
	expect(b != null, "barracks built")
	expect_eq(b.rally, Vector2i(3, 2), "rally point is the nearest path tile")
	expect_eq(b.squad.size(), 2, "squad spawned")
	var t: SimUnit = b.squad[0]
	t.hp = 0.0
	s._kill(t)
	expect_eq(b.squad.size(), 1, "one troop down")
	_run_for(s, 3.2)
	expect_eq(b.squad.size(), 2, "free respawn after cooldown")
	expect_eq(s.can_build(bd, Vector2i(3, 1)), MatchSim.DeployError.OCCUPIED, "slot occupied")
	expect_eq(s.can_build(bd, Vector2i(5, 2)), MatchSim.DeployError.TILE_KIND, "only on build slots")


func _test_tower_ability() -> void:
	var s := _sim(_ws())
	var ab := AbilityData.new()
	ab.kind = Enums.AbilityKind.STUN
	ab.radius = 2.0
	ab.duration = 2.0
	ab.cooldown = 1.0
	var td := TowerData.new()
	td.id = "t"
	td.cost = 5
	td.attack = 1
	td.attack_range = 3.0
	td.ability = ab
	var b := s.build(td, Vector2i(7, 3))
	var e := s.spawn_enemy(_unit(Enums.TargetClass.MELEE, 100000, 0, 0.5))
	e.progress = 7.0
	e.pos = Vector2(7, 2)
	expect(not s.trigger_tower_ability(b), "ability not ready at start")
	_run_for(s, 1.05)
	expect(b.ability_ready(), "charged after cooldown")
	expect(s.trigger_tower_ability(b), "manual trigger works")
	expect(e.stun_left > 0.0 and b.charge == 0.0, "stun applied, charge reset")
	s.auto_tower_abilities = true
	_run_for(s, 1.1)
	expect(b.charge < 1.0, "auto mode fires by itself")


func _test_summon_blocks() -> void:
	var ws := _ws()
	var summon := _unit(Enums.TargetClass.MELEE, 100, 10)
	var ab := AbilityData.new()
	ab.kind = Enums.AbilityKind.SUMMON
	ab.summon_unit = summon
	ab.summon_count = 2
	ab.duration = 5.0
	ab.cooldown = 10.0
	var entry := _hero("c", Enums.Placement.EDGE, 0, 10)
	entry["abilities"] = [ab]
	var s := _sim(ws, [entry])
	s.deploy_hero("c", Vector2i(9, 1))
	s.heroes["c"]["ability_cd"][0] = 0.0
	expect(s.trigger_hero_ability("c"), "summon ability fires")
	var summons := s.alive_defenders().filter(func(u): return u.kind == SimUnit.Kind.SUMMON)
	expect_eq(summons.size(), 2, "two summons")
	expect(summons[0].can_block(), "summons count as blockers")
	_run_for(s, 5.1)
	expect_eq(s.alive_defenders().filter(func(u): return u.kind == SimUnit.Kind.SUMMON).size(), 0, "summons expire")


func _test_iso_grid() -> void:
	var g := IsoGrid.new()
	for p in [Vector2(0, 0), Vector2(3, 5), Vector2(2.5, -1.25)]:
		expect(g.to_grid(g.to_world(p)).distance_to(p) < 0.001, "iso round trip %s" % str(p))
	expect_eq(g.to_world(Vector2(1, 0)), Vector2(64, 32), "x axis goes down-right")
	expect_eq(g.to_cell(g.to_world(Vector2(4, 7))), Vector2i(4, 7), "to_cell")

func _line_up(s: MatchSim, data: UnitData, n: int, front: float, gap := 0.3) -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for i in n:
		var e := s.spawn_enemy(data)
		e.progress = front - i * gap
		e.pos = MatchSim.path_point(e.path, e.progress)
		out.append(e)
	return out


func _test_queue_behind_hero() -> void:
	var s := _sim(_ws(), [_hero("w", Enums.Placement.PATH, 1, 0, 100000)])
	var hero := s.deploy_hero("w", Vector2i(5, 2))
	var line := _line_up(s, _unit(Enums.TargetClass.MELEE, 300, 10), 3, 4.4, 0.6)
	var flyer := s.spawn_enemy(_unit(Enums.TargetClass.FLYER, 300, 0))
	flyer.progress = 6.0
	_run_for(s, 6.0)
	expect_eq(hero.blocking.size(), 1, "block 1 holds exactly one enemy")
	expect(line[1].queued_at == hero and line[2].queued_at == hero, "the others queue behind the hero")
	expect(line[1].progress > line[2].progress + 0.2, "queue keeps its spacing instead of stacking")
	expect(line[1].progress < hero.pos.x, "queued enemies stay in front of the hero")
	expect_eq(s.leaks, 1, "only the flyer passes")
	expect(not flyer.alive, "flyer leaked")
	expect(hero.hp >= hero.max_hp - 10.0 * 6.0 / 1.0 - 1.0, "queued melee enemies do not attack")
	# blocked enemy dies -> front-most queued one takes the slot
	line[0].hp = 0.0
	s._kill(line[0])
	_run_for(s, 1.5)
	expect(line[1].blocked_by == hero, "front-most queued enemy moves up into the block")
	expect(line[2].queued_at == hero, "the rest keeps waiting")


func _test_queue_releases_on_death() -> void:
	var s := _sim(_ws(), [_hero("w", Enums.Placement.PATH, 1, 0, 1000)])
	var hero := s.deploy_hero("w", Vector2i(5, 2))
	var line := _line_up(s, _unit(Enums.TargetClass.MELEE, 300, 0), 3, 4.4, 0.6)
	_run_for(s, 4.0)
	expect_eq(s.leaks, 0, "held while alive")
	hero.hp = 0.0
	s._kill(hero)
	_run_for(s, 12.0)
	expect_eq(s.leaks, 3, "queue walks on once the hero is dead")
	expect(line.all(func(e): return e.queued_at == null), "queue references cleared")


func _test_troops_let_surplus_pass() -> void:
	var s := _sim(_ws())
	var troop := _unit(Enums.TargetClass.MELEE, 100000, 0)
	troop.block_capacity = 1
	var bd := BarracksData.new()
	bd.id = "b"
	bd.unit = troop
	bd.squad_size = 1
	bd.cost = 5
	var b := s.build(bd, Vector2i(7, 3))
	expect(not b.squad[0].holds_line, "troops do not hold the line by default")
	_line_up(s, _unit(Enums.TargetClass.MELEE, 300, 0), 2, 6.0, 0.6)
	_run_for(s, 12.0)
	expect_eq(s.leaks, 1, "a troop with block 1 lets the surplus walk past")


func _test_tower_upgrade() -> void:
	var s := _sim(_ws())
	var ab := AbilityData.new()
	ab.kind = Enums.AbilityKind.STRIKE
	ab.power = 1.0
	ab.cooldown = 1.0
	var td := TowerData.new()
	td.id = "t"
	td.cost = 5
	td.attack = 100
	td.attack_interval = 1.0
	td.attack_range = 3.0
	td.ability = ab
	for pair in [[10, 150, 0.8], [20, 200, 0.6]]:
		var lv := TowerLevel.new()
		lv.cost = pair[0]
		lv.attack = pair[1]
		lv.attack_interval = pair[2]
		td.upgrades.append(lv)
	var b := s.build(td, Vector2i(7, 3))
	expect_eq(b.level, 1, "built at level 1")
	expect_eq(b.max_level(), 3, "two upgrades = three levels")
	s.resource = 15.0
	expect(s.upgrade(b), "upgrade to level 2")
	expect_eq(s.resource_int(), 5, "upgrade cost paid")
	expect(b.level == 2 and b.attack() == 150.0 and is_equal_approx(b.attack_interval(), 0.8), "level 2 stats")
	expect_eq(s.can_upgrade(b), MatchSim.DeployError.COST, "not enough resource for level 3")
	s.resource = 30.0
	expect(s.upgrade(b), "upgrade to level 3")
	expect_eq(s.can_upgrade(b), MatchSim.DeployError.MAX_LEVEL, "maxed at level 3")
	var e := s.spawn_enemy(_unit(Enums.TargetClass.MELEE, 100000, 0, 0.0))
	e.progress = 7.0
	e.pos = Vector2(7, 2)
	b.charge = 1.0
	b.cooldown = 99.0
	var before := e.hp
	s.trigger_tower_ability(b)
	expect_eq(before - e.hp, 200.0, "tower ability uses the upgraded attack")
	b.cooldown = 0.0
	s.step(0.01)
	expect(is_equal_approx(b.cooldown, 0.6), "upgraded attack interval used")


func _test_barracks_upgrade() -> void:
	var s := _sim(_ws())
	var bd := BarracksData.new()
	bd.id = "b"
	bd.unit = _unit(Enums.TargetClass.MELEE, 200, 20)
	bd.squad_size = 2
	bd.respawn_time = 1.0
	bd.cost = 5
	var lv := BarracksLevel.new()
	lv.cost = 5
	lv.troop_mult = 1.5
	bd.upgrades.append(lv)
	var b := s.build(bd, Vector2i(3, 1))
	var t: SimUnit = b.squad[0]
	t.hp = 100.0
	expect(s.upgrade(b), "barracks upgrade")
	expect(t.max_hp == 300.0 and t.hp == 150.0 and t.attack == 30.0, "existing troops scale, HP ratio kept")
	s._kill(t)
	_run_for(s, 1.1)
	var fresh: SimUnit = b.squad[b.squad.size() - 1]
	expect(fresh != t and fresh.max_hp == 300.0, "respawned troops use the upgraded level")


# --- Schneckensturm mechanics -------------------------------------------------
func _ability(kind: int, power: float, radius := 0.0, cooldown := 10.0) -> AbilityData:
	var ab := AbilityData.new()
	ab.kind = kind
	ab.power = power
	ab.radius = radius
	ab.cooldown = cooldown
	return ab


func _test_strike_all() -> void:
	var entry := _hero("c", Enums.Placement.EDGE, 0, 100)
	entry["abilities"] = [_ability(Enums.AbilityKind.STRIKE_ALL, 3.0)]
	var s := _sim(_ws(), [entry])
	s.deploy_hero("c", Vector2i(5, 1))
	var far: Array[SimUnit] = []
	for p in [0.0, 5.0, 10.0]:
		var e := s.spawn_enemy(_unit(Enums.TargetClass.MELEE, 1000, 0, 0.0))
		e.progress = p
		e.pos = MatchSim.path_point(e.path, p)
		far.append(e)
	expect(not s.trigger_hero_ability("c"), "ability starts on half cooldown")
	_run_for(s, 5.0)
	var before := far.map(func(e): return e.hp)
	expect(s.trigger_hero_ability("c"), "Leinen los ready after half cooldown")
	for i in far.size():
		expect(far[i].hp <= before[i] - 299.0, "STRIKE_ALL hits snail %d anywhere on the map" % i)


func _test_essential_hero_defeat() -> void:
	var entry := _hero("c", Enums.Placement.EDGE, 0, 0, 100)
	entry["data"].essential = true
	var s := _sim(_ws(), [entry])
	var hero := s.deploy_hero("c", Vector2i(5, 1))
	var result := [null]
	s.ended.connect(func(v): result[0] = v)
	var spit := _unit(Enums.TargetClass.RANGED, 100000, 500, 0.0, 3.0, true)
	var e := s.spawn_enemy(spit)
	e.progress = 5.0
	e.pos = MatchSim.path_point(e.path, 5.0)
	_run_for(s, 3.0)
	expect(not hero.alive, "Christina fell to the spitter")
	expect(result[0] == false, "an essential hero falling ends the match")
	expect_eq(s.result()["reason"], "hero_fell", "defeat reason recorded")
	expect(s.lives > 0, "petals were not the cause")


func _test_heal_hero() -> void:
	var s := _sim(_ws(), [_hero("c", Enums.Placement.EDGE, 0, 0, 1000)])
	s.ws.heal_cost_per_hp = 0.05
	var hero := s.deploy_hero("c", Vector2i(5, 1))
	expect_eq(s.can_heal_hero("c"), MatchSim.DeployError.FULL_HP, "nothing to heal at full HP")
	hero.hp = 600.0
	expect_eq(s.heal_cost("c"), 20, "400 missing HP x 0.05 = 20")
	s.resource = 10.0
	expect_eq(s.can_heal_hero("c"), MatchSim.DeployError.COST, "heal needs resource")
	s.resource = 30.0
	expect(s.heal_hero("c"), "heal bought")
	expect(is_equal_approx(hero.hp, 1000.0), "back to full HP")
	expect(is_equal_approx(s.resource, 10.0), "heal cost paid")
	s.retreat(hero)
	s.heroes["c"]["hp"] = 500
	s.resource = 50.0
	expect(s.heal_hero("c"), "a retreated hero can be healed too")
	expect_eq(s.heroes["c"]["hp"], 1000, "slot HP restored")


func _test_brood() -> void:
	var s := _sim(_ws())
	var brood := _unit(Enums.TargetClass.MELEE, 50, 0, 0.0)
	brood.id = "brood"
	var queen := _unit(Enums.TargetClass.MELEE, 100000, 0, 0.5)
	queen.id = "queen"
	queen.is_boss = true
	queen.brood_unit = brood
	queen.brood_interval = 2.0
	queen.brood_count = 2
	var bosses := []
	s.boss_spawned.connect(func(u): bosses.append(u))
	var q := s.spawn_enemy(queen)
	expect_eq(bosses.size(), 1, "boss_spawned fires for the queen")
	_run_for(s, 4.1)
	var kids := s.alive_enemies().filter(func(e): return e.data == brood)
	expect_eq(kids.size(), 4, "two broods of two after 4 s")
	for k in kids:
		expect(k.progress <= q.progress and k.path == q.path, "brood is laid behind the queen")


func _test_boss_leak_ends_match() -> void:
	var s := _sim(_ws())
	var queen := _unit(Enums.TargetClass.MELEE, 100000, 0, 4.0)
	queen.leak_damage = 99
	var result := [null]
	s.ended.connect(func(v): result[0] = v)
	s.spawn_enemy(queen)
	_run_for(s, 5.0)
	expect_eq(s.lives, 0, "the queen eats every petal")
	expect(result[0] == false, "queen reaching the dahlia is an instant defeat")


func _test_balance_config() -> void:
	var bal := BalanceConfig.new()
	bal.enemy_hp_mult = 2.0
	bal.enemy_speed_mult = 0.5
	bal.start_resource_mult = 2.0
	bal.regen_mult = 3.0
	bal.petals = 7
	bal.hero_attack_mult = 1.5
	bal.hero_ability_cooldown_mult = 0.5
	bal.tower_attack_mult = 2.0
	bal.troop_mult = 1.5
	var entry := _hero("c", Enums.Placement.EDGE, 0, 100)
	entry["abilities"] = [_ability(Enums.AbilityKind.STRIKE_ALL, 1.0, 0.0, 20.0)]
	var s := MatchSim.new()
	s.setup(_ws(), [entry], null, bal)
	_sims.append(s)
	expect(is_equal_approx(s.resource, 100.0), "start resource x2")
	expect(is_equal_approx(s.regen, 3.0), "regen x3")
	expect_eq(s.lives, 7, "petal override")
	expect_eq(s.max_lives, 7, "max petals follow the override")
	expect_eq(int(s.heroes["c"]["stats"]["attack"]), 150, "hero attack x1.5")
	expect(is_equal_approx(s.heroes["c"]["ability_cd"][0], 5.0), "ability cooldown x0.5 (starts half charged)")
	expect_eq(int(entry["stats"]["attack"]), 100, "caller's stats are not modified")
	var e := s.spawn_enemy(_unit(Enums.TargetClass.MELEE, 300, 0, 1.0))
	expect(is_equal_approx(e.max_hp, 600.0) and is_equal_approx(e.hp, 600.0), "enemy HP x2")
	expect(is_equal_approx(e.move_speed, 0.5), "enemy speed x0.5")
	var td := TowerData.new()
	td.id = "t"
	td.cost = 1
	td.attack = 40
	var t := s.build(td, Vector2i(3, 1))
	expect(is_equal_approx(t.attack(), 80.0), "tower attack x2")
	var bd := BarracksData.new()
	bd.id = "b"
	bd.cost = 1
	bd.squad_size = 1
	bd.unit = _unit(Enums.TargetClass.MELEE, 200, 10, 0.0)
	var b := s.build(bd, Vector2i(7, 3))
	expect(is_equal_approx(b.squad[0].max_hp, 300.0), "troop HP x1.5")


func _test_give_up_is_defeat() -> void:
	var s := _sim(_ws())
	s._end(false)
	var r := s.result()
	expect(not r["victory"], "giving up is never a victory")
	expect_eq(r["reason"], "gave_up", "give-up reason")
