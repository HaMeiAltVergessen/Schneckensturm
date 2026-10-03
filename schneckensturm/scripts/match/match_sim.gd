# Headless match simulation: economy, waves, deploy/retreat, blocking, targeting,
# towers, barracks, abilities, leaks and win/loss. Visuals (scenes/match) only
# observe its signals and read its state, so every rule is testable without a scene.
class_name MatchSim
extends RefCounted

signal unit_spawned(u: SimUnit)
## reason: "died", "leaked", "retreated", "expired"
signal unit_removed(u: SimUnit, reason: String)
## attacker: SimUnit or SimBuilding; target: SimUnit or SimBuilding.
signal unit_attacked(attacker: Object, target: Object, amount: float, is_heal: bool)
signal building_added(b: SimBuilding)
signal building_removed(b: SimBuilding)
signal building_upgraded(b: SimBuilding)
signal wave_started(index: int)
signal ability_used(source: Object, ability: AbilityData, at: Vector2)
signal lives_changed(lives: int)
## A boss enemy entered the map (HUD shows its HP bar).
signal boss_spawned(u: SimUnit)
signal hero_healed(id: String, amount: int)
signal ended(victory: bool)

enum Phase { PREP, RUNNING, ENDED }
enum DeployError { OK, UNKNOWN, FALLEN, ALREADY_DEPLOYED, COOLDOWN, LIMIT, COST, TILE_KIND, OCCUPIED, ENDED, NOT_ALLOWED, MAX_LEVEL, FULL_HP }

const BLOCK_CONTACT := 0.5
## Spacing (path distance) at which enemies line up behind a held line.
const QUEUE_GAP := 0.5
const TROOP_OFFSETS := [Vector2(0.0, 0.0), Vector2(0.22, -0.22), Vector2(-0.22, 0.22), Vector2(0.22, 0.22)]

var ws: WaveSet
var layout: MapLayout
var rules: TargetRuleSet
var balance: BalanceConfig

var phase: int = Phase.PREP
var time := 0.0
var resource := 0.0
## Resource per second (level value x balance).
var regen := 1.0
var lives := 3
var max_lives := 3
## "" while running; "leaks" or "hero_fell" after a defeat.
var defeat_reason := ""
var won := false
var prep_left := 0.0
## Index of the last started wave (-1 = none yet).
var wave_index := -1
var next_wave_timer := 0.0
var kills := 0
var leaks := 0
var auto_tower_abilities := false

var units: Array[SimUnit] = []
var buildings: Array[SimBuilding] = []
## hero_id -> { data, stats, hp, max_hp, unit, cooldown_left, abilities, ability_cd }
var heroes: Dictionary = {}
## Building ids the player may build (empty = everything of the faction allowed).
var allowed_buildings: Array[String] = []

var _spawn_queue: Array = []   # [{ "t": float, "unit": UnitData, "path": int }]
var _uid := 0


# hero_entries: [{ "id", "data": HeroData, "stats": Dictionary, "hp": int, "abilities": Array }]
# p_balance: global knobs (data/rules/balance.tres); null = neutral.
func setup(p_ws: WaveSet, hero_entries: Array, p_rules: TargetRuleSet = null, p_balance: BalanceConfig = null) -> void:
	ws = p_ws
	layout = ws.layout
	rules = p_rules if p_rules != null else TargetRuleSet.make_default()
	balance = p_balance if p_balance != null else BalanceConfig.new()
	resource = float(ws.start_resource) * balance.start_resource_mult
	regen = ws.resource_regen * balance.regen_mult
	lives = balance.petals if balance.petals > 0 else ws.lives
	max_lives = lives
	prep_left = ws.prep_time
	for e in hero_entries:
		var stats: Dictionary = (e["stats"] as Dictionary).duplicate()
		stats["attack"] = int(round(float(stats["attack"]) * balance.hero_attack_mult))
		var abilities: Array = e.get("abilities", [])
		var cds: Array[float] = []
		for a in abilities:
			cds.append(ability_cooldown(a) * 0.5)
		heroes[e["id"]] = {
			"data": e["data"], "stats": stats, "max_hp": int(stats["max_hp"]),
			"hp": clampi(int(e.get("hp", stats["max_hp"])), 0, int(stats["max_hp"])),
			"unit": null, "cooldown_left": 0.0, "abilities": abilities, "ability_cd": cds,
		}


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
func step(dt: float) -> void:
	if phase == Phase.ENDED or dt <= 0.0:
		return
	time += dt
	resource = minf(float(ws.resource_cap), resource + regen * dt)
	_tick_waves(dt)
	_tick_spawns()
	_tick_heroes(dt)
	_tick_buildings(dt)
	_tick_units(dt)
	_cleanup()
	_check_end()


func resource_int() -> int:
	return int(floor(resource))


func alive_enemies() -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u in units:
		if u.alive and u.side == Enums.Side.ENEMY:
			out.append(u)
	return out


func alive_defenders() -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u in units:
		if u.alive and u.is_player():
			out.append(u)
	return out


func total_waves() -> int:
	return ws.waves.size()


# ---------------------------------------------------------------------------
# Waves
# ---------------------------------------------------------------------------
func call_next_wave() -> bool:
	if phase == Phase.ENDED:
		return false
	if phase == Phase.PREP:
		_start_wave(0)
		return true
	if wave_index + 1 < total_waves():
		_start_wave(wave_index + 1)
		return true
	return false


func _tick_waves(dt: float) -> void:
	if phase == Phase.PREP:
		prep_left -= dt
		if prep_left <= 0.0:
			_start_wave(0)
		return
	if wave_index + 1 < total_waves():
		next_wave_timer -= dt
		if next_wave_timer <= 0.0:
			_start_wave(wave_index + 1)


func _start_wave(i: int) -> void:
	phase = Phase.RUNNING
	prep_left = 0.0
	wave_index = i
	if i >= total_waves():
		return
	var wave: WaveData = ws.waves[i]
	for g in wave.groups:
		if g.unit == null:
			continue
		for k in g.count:
			_spawn_queue.append({ "t": time + g.delay + g.interval * k, "unit": g.unit, "path": g.path_index })
	_spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	next_wave_timer = wave.duration() + wave.next_delay
	wave_started.emit(i)


func _tick_spawns() -> void:
	while not _spawn_queue.is_empty() and _spawn_queue[0]["t"] <= time:
		var s: Dictionary = _spawn_queue.pop_front()
		spawn_enemy(s["unit"], s["path"])


func spawn_enemy(data: UnitData, path_index := 0) -> SimUnit:
	if layout.paths.is_empty():
		return null
	var u := _make_unit(data, SimUnit.Kind.ENEMY, Enums.Side.ENEMY, 1.0)
	u.max_hp *= balance.enemy_hp_mult
	u.hp = u.max_hp
	u.path = layout.paths[clampi(path_index, 0, layout.paths.size() - 1)]
	u.progress = 0.0
	u.pos = Vector2(u.path.cells[0]) if not u.path.cells.is_empty() else Vector2.ZERO
	u.move_speed = data.move_speed * balance.enemy_speed_mult
	u.leak_damage = data.leak_damage
	u.bounty = data.bounty
	u.brood_left = data.brood_interval
	_add_unit(u)
	if data.is_boss:
		boss_spawned.emit(u)
	return u


# ---------------------------------------------------------------------------
# Heroes: deploy / retreat / abilities
# ---------------------------------------------------------------------------
func hero_limit() -> int:
	return ws.hero_limit()


func deployed_hero_count() -> int:
	var n := 0
	for id in heroes:
		if heroes[id]["unit"] != null:
			n += 1
	return n


func hero_cost(id: String) -> int:
	return (heroes[id]["data"] as HeroData).deploy_cost if heroes.has(id) else 0


func can_deploy_hero(id: String, c: Vector2i) -> int:
	if phase == Phase.ENDED:
		return DeployError.ENDED
	if not heroes.has(id):
		return DeployError.UNKNOWN
	var slot: Dictionary = heroes[id]
	var h: HeroData = slot["data"]
	if slot["hp"] <= 0:
		return DeployError.FALLEN
	if slot["unit"] != null:
		return DeployError.ALREADY_DEPLOYED
	if slot["cooldown_left"] > 0.0:
		return DeployError.COOLDOWN
	if deployed_hero_count() >= hero_limit():
		return DeployError.LIMIT
	var kind := layout.kind_at(c)
	var need := Enums.TileKind.DEPLOY_PATH if h.placement == Enums.Placement.PATH else Enums.TileKind.DEPLOY_EDGE
	if kind != need:
		return DeployError.TILE_KIND
	if hero_at(c) != null:
		return DeployError.OCCUPIED
	if resource_int() < h.deploy_cost:
		return DeployError.COST
	return DeployError.OK


func deploy_hero(id: String, c: Vector2i) -> SimUnit:
	if can_deploy_hero(id, c) != DeployError.OK:
		return null
	var slot: Dictionary = heroes[id]
	var h: HeroData = slot["data"]
	var st: Dictionary = slot["stats"]
	resource -= h.deploy_cost
	var u := SimUnit.new()
	u.kind = SimUnit.Kind.HERO
	u.side = Enums.Side.PLAYER
	u.data = h
	u.hero_id = id
	u.max_hp = float(st["max_hp"])
	u.hp = float(slot["hp"])
	u.attack = float(st["attack"])
	u.defense = float(st["defense"])
	u.attack_interval = float(st["attack_interval"])
	u.range_pattern = h.range_pattern
	u.is_ranged = h.placement == Enums.Placement.EDGE
	u.heals = h.heals
	u.priority = h.target_priority
	u.block_capacity = int(st["block"]) if h.placement == Enums.Placement.PATH else 0
	u.holds_line = h.holds_line and u.block_capacity > 0
	u.cell = c
	u.pos = Vector2(c)
	slot["unit"] = u
	_add_unit(u)
	return u


func hero_at(c: Vector2i) -> SimUnit:
	for id in heroes:
		var u: SimUnit = heroes[id]["unit"]
		if u != null and u.cell == c:
			return u
	return null


# Pull a hero back: keeps HP, refunds part of the cost, starts the redeploy cooldown.
func retreat(u: SimUnit) -> int:
	if u == null or not u.alive or u.kind != SimUnit.Kind.HERO or phase == Phase.ENDED:
		return 0
	var slot: Dictionary = heroes[u.hero_id]
	var h: HeroData = slot["data"]
	var refund := int(floor(h.deploy_cost * ws.retreat_refund_ratio))
	resource = minf(float(ws.resource_cap), resource + refund)
	slot["hp"] = int(ceil(u.hp))
	slot["cooldown_left"] = h.redeploy_cooldown
	_remove(u, "retreated")
	return refund


func hero_ability_ready(id: String, index := 0) -> bool:
	if not heroes.has(id):
		return false
	var slot: Dictionary = heroes[id]
	return slot["unit"] != null and index < slot["abilities"].size() and slot["ability_cd"][index] <= 0.0


func trigger_hero_ability(id: String, index := 0) -> bool:
	if phase == Phase.ENDED or not hero_ability_ready(id, index):
		return false
	var slot: Dictionary = heroes[id]
	var u: SimUnit = slot["unit"]
	var ab: AbilityData = slot["abilities"][index]
	slot["ability_cd"][index] = ability_cooldown(ab)
	var target := Targeting.defender_target(u, alive_enemies(), rules)
	_apply_ability(u, ab, u.pos, u.effective_attack(), target)
	return true


# Hero ability cooldown after the balance multiplier.
func ability_cooldown(ab: AbilityData) -> float:
	return ab.cooldown * (balance.hero_ability_cooldown_mult if balance != null else 1.0)


# Current / max HP of a hero, deployed or not.
func hero_hp(id: String) -> float:
	var slot: Dictionary = heroes[id]
	var u: SimUnit = slot["unit"]
	return u.hp if u != null else float(slot["hp"])


func heal_cost(id: String) -> int:
	if not heroes.has(id):
		return 0
	var missing := float(heroes[id]["max_hp"]) - hero_hp(id)
	return int(ceil(maxf(0.0, missing) * ws.heal_cost_per_hp))


func can_heal_hero(id: String) -> int:
	if phase == Phase.ENDED:
		return DeployError.ENDED
	if not heroes.has(id):
		return DeployError.UNKNOWN
	if hero_hp(id) >= float(heroes[id]["max_hp"]):
		return DeployError.FULL_HP
	if resource_int() < heal_cost(id):
		return DeployError.COST
	return DeployError.OK


# Buys a full heal for the match resource (deployed or waiting hero).
func heal_hero(id: String) -> bool:
	if can_heal_hero(id) != DeployError.OK:
		return false
	resource -= heal_cost(id)
	var slot: Dictionary = heroes[id]
	var u: SimUnit = slot["unit"]
	var amount := int(ceil(float(slot["max_hp"]) - hero_hp(id)))
	if u != null:
		_heal(u, u, float(amount))
	else:
		slot["hp"] = slot["max_hp"]
	hero_healed.emit(id, amount)
	return true


func _tick_heroes(dt: float) -> void:
	for id in heroes:
		var slot: Dictionary = heroes[id]
		slot["cooldown_left"] = maxf(0.0, slot["cooldown_left"] - dt)
		var cds: Array = slot["ability_cd"]
		for i in cds.size():
			cds[i] = maxf(0.0, cds[i] - dt)


# ---------------------------------------------------------------------------
# Buildings: towers + barracks
# ---------------------------------------------------------------------------
func building_cost(data: Resource) -> int:
	return int(data.cost)


func can_build(data: Resource, c: Vector2i) -> int:
	if phase == Phase.ENDED:
		return DeployError.ENDED
	if data == null:
		return DeployError.UNKNOWN
	if not allowed_buildings.is_empty() and data.id not in allowed_buildings:
		return DeployError.NOT_ALLOWED
	if layout.kind_at(c) != Enums.TileKind.BUILD_SLOT:
		return DeployError.TILE_KIND
	if building_at(c) != null:
		return DeployError.OCCUPIED
	if resource_int() < building_cost(data):
		return DeployError.COST
	return DeployError.OK


func build(data: Resource, c: Vector2i) -> SimBuilding:
	if can_build(data, c) != DeployError.OK:
		return null
	resource -= building_cost(data)
	var b := SimBuilding.new()
	_uid += 1
	b.uid = _uid
	b.data = data
	b.is_tower = data is TowerData
	b.cell = c
	b.max_hp = float(data.max_hp)
	b.hp = b.max_hp
	buildings.append(b)
	building_added.emit(b)
	if b.is_tower:
		b.attack_mult = balance.tower_attack_mult
	else:
		b.rally = layout.nearest_path_cell(c)
		b.troop_mult = balance.troop_mult
		for i in (data as BarracksData).squad_size:
			_spawn_troop(b, i)
	return b


func building_at(c: Vector2i) -> SimBuilding:
	for b in buildings:
		if b.alive and b.cell == c:
			return b
	return null


func upgrade_cost(b: SimBuilding) -> int:
	var up := b.next_upgrade() if b != null else null
	return int(up.cost) if up != null else 0


func can_upgrade(b: SimBuilding) -> int:
	if phase == Phase.ENDED:
		return DeployError.ENDED
	if b == null or not b.alive:
		return DeployError.UNKNOWN
	if b.next_upgrade() == null:
		return DeployError.MAX_LEVEL
	if resource_int() < upgrade_cost(b):
		return DeployError.COST
	return DeployError.OK


# Buys the next level. Barracks troops scale up at once (HP ratio kept).
func upgrade(b: SimBuilding) -> bool:
	if can_upgrade(b) != DeployError.OK:
		return false
	resource -= upgrade_cost(b)
	var old_mult := b.level_troop_mult()
	b.level += 1
	if not b.is_tower:
		var f := b.level_troop_mult() / old_mult
		for u in b.squad:
			u.max_hp *= f
			u.hp *= f
			u.attack *= f
	building_upgraded.emit(b)
	return true


func trigger_tower_ability(b: SimBuilding) -> bool:
	if phase == Phase.ENDED or b == null or not b.alive or not b.ability_ready():
		return false
	var t: TowerData = b.data
	var target := Targeting.tower_target(b.pos(), t.attack_range, t.can_hit_flyers, t.target_priority, alive_enemies())
	b.charge = 0.0
	var center := target.pos if target != null else b.pos()
	_apply_ability(b, t.ability, center, b.attack(), target)
	return true


func _spawn_troop(b: SimBuilding, slot_index: int) -> SimUnit:
	var bd: BarracksData = b.data
	if bd.unit == null:
		return null
	var u := _make_unit(bd.unit, SimUnit.Kind.TROOP, Enums.Side.PLAYER, b.troop_mult * b.level_troop_mult())
	u.home = b
	u.cell = b.rally
	u.pos = Vector2(b.rally) + TROOP_OFFSETS[slot_index % TROOP_OFFSETS.size()]
	b.squad.append(u)
	_add_unit(u)
	return u


func _tick_buildings(dt: float) -> void:
	var enemies := alive_enemies()
	for b in buildings:
		if not b.alive:
			continue
		if b.is_tower:
			var t: TowerData = b.data
			if t.ability != null and t.ability.cooldown > 0.0:
				b.charge = minf(1.0, b.charge + dt / t.ability.cooldown)
				if auto_tower_abilities and b.charge >= 1.0 and not enemies.is_empty():
					trigger_tower_ability(b)
			b.cooldown -= dt
			if b.cooldown > 0.0:
				continue
			var target := Targeting.tower_target(b.pos(), t.attack_range, t.can_hit_flyers, t.target_priority, enemies)
			if target == null:
				continue
			b.cooldown = b.attack_interval()
			b.last_target = target
			_hit(b, target, b.attack())
			if t.splash_radius > 0.0:
				for e in enemies:
					if e != target and e.alive and e.pos.distance_to(target.pos) <= t.splash_radius:
						_hit(b, e, b.attack() * 0.5)
		else:
			var bd: BarracksData = b.data
			for i in range(b.respawn.size() - 1, -1, -1):
				b.respawn[i] -= dt
				if b.respawn[i] <= 0.0:
					b.respawn.remove_at(i)
					_spawn_troop(b, b.squad.size())
			# keep respawn bookkeeping bounded to the squad size
			while b.squad.size() + b.respawn.size() > bd.squad_size and not b.respawn.is_empty():
				b.respawn.pop_back()


# ---------------------------------------------------------------------------
# Units: blocking, movement, attacks
# ---------------------------------------------------------------------------
func _tick_units(dt: float) -> void:
	for u in units:
		if not u.alive:
			continue
		u.stun_left = maxf(0.0, u.stun_left - dt)
		if u.buff_left > 0.0:
			u.buff_left -= dt
			if u.buff_left <= 0.0:
				u.buff_mult = 1.0
		if u.lifetime > 0.0:
			u.lifetime -= dt
			if u.lifetime <= 0.0:
				_remove(u, "expired")
		u.cooldown = maxf(0.0, u.cooldown - dt)
	_tick_brood(dt)

	_assign_blocks()

	var defenders := alive_defenders()
	var live_buildings: Array[SimBuilding] = []
	for b in buildings:
		if b.alive:
			live_buildings.append(b)
	var enemies := alive_enemies()

	for e in enemies:
		if not e.alive or e.stun_left > 0.0:
			continue
		var rule := rules.rule_for(e.target_class)
		var target := Targeting.enemy_target(e, rules, defenders, live_buildings)
		var stop := e.blocked_by != null or e.queued_at != null or (target != null and rule != null and rule.stops_to_attack)
		if not stop:
			_move(e, dt)
			if not e.alive:
				continue
		if target != null and e.cooldown <= 0.0:
			e.cooldown = e.attack_interval
			e.last_target = target
			_hit(e, target, e.effective_attack())

	for u in defenders:
		if not u.alive or u.stun_left > 0.0 or u.cooldown > 0.0:
			continue
		if u.heals:
			var ally := Targeting.heal_target(u, alive_defenders())
			if ally != null:
				u.cooldown = u.attack_interval
				u.last_target = ally
				_heal(u, ally, u.effective_attack())
			continue
		var t := Targeting.defender_target(u, alive_enemies(), rules)
		if t != null:
			u.cooldown = u.attack_interval
			u.last_target = t
			_hit(u, t, u.effective_attack())


# Brood layers (the snail queen) drop small snails at their own spot on the path.
func _tick_brood(dt: float) -> void:
	var drops: Array[SimUnit] = []
	for u in units:
		if not u.alive or u.side != Enums.Side.ENEMY:
			continue
		var ud: UnitData = u.data
		if ud.brood_unit == null or ud.brood_interval <= 0.0:
			continue
		u.brood_left -= dt
		if u.brood_left <= 0.0:
			u.brood_left += ud.brood_interval
			drops.append(u)
	for mother in drops:
		var ud: UnitData = mother.data
		for i in ud.brood_count:
			var b := spawn_enemy(ud.brood_unit, layout.paths.find(mother.path))
			if b == null:
				continue
			b.progress = maxf(0.0, mother.progress - 0.15 * (i + 1))
			b.pos = path_point(b.path, b.progress)


# Blocking + queueing. A blocker with free capacity stops enemies in contact.
# A full line-holder (hero) lets nobody past: enemies in contact, and enemies
# closing up behind them on the same path, wait in a queue until it dies,
# retreats or frees capacity. Other blockers let the surplus walk past.
func _assign_blocks() -> void:
	var blockers: Array[SimUnit] = []
	for u in units:
		if u.alive and u.can_block():
			blockers.append(u)
	var enemies: Array[SimUnit] = []
	for e in units:
		if not e.alive or e.side != Enums.Side.ENEMY:
			continue
		if e.queued_at != null and (not e.queued_at.alive or e.queued_at.free_capacity() >= e.block_weight):
			e.queued_at = null
		if e.blocked_by == null:
			enemies.append(e)
	if blockers.is_empty():
		return
	# front-most first: it takes a freed slot, and queues chain backwards in one pass
	enemies.sort_custom(func(a: SimUnit, b: SimUnit): return a.progress > b.progress)
	for e in enemies:
		var rule := rules.rule_for(e.target_class)
		if rule != null and not rule.can_be_blocked:
			continue
		var holder: SimUnit = null
		for b in blockers:
			if b.pos.distance_to(e.pos) > BLOCK_CONTACT:
				continue
			if b.free_capacity() >= e.block_weight:
				e.queued_at = null
				e.blocked_by = b
				b.blocking.append(e)
				break
			if b.holds_line and holder == null:
				holder = b
		if e.blocked_by != null or e.queued_at != null:
			continue
		if holder == null:
			holder = _line_ahead(e)
		e.queued_at = holder


# The line-holder whose queue `e` runs into: a held or waiting enemy just ahead on the same path.
func _line_ahead(e: SimUnit) -> SimUnit:
	if e.path == null:
		return null
	for f in units:
		if f == e or not f.alive or f.side != Enums.Side.ENEMY or f.path != e.path:
			continue
		var gap := f.progress - e.progress
		if gap < 0.0 or gap >= QUEUE_GAP:
			continue
		var holder: SimUnit = f.queued_at if f.queued_at != null else f.blocked_by
		if holder != null and holder.holds_line and holder.free_capacity() < e.block_weight:
			return holder
	return null


func _move(e: SimUnit, dt: float) -> void:
	if e.path == null or e.path.cells.size() < 2:
		return
	e.progress += e.move_speed * dt
	if e.progress >= e.path.length():
		leaks += 1
		lives = maxi(0, lives - e.leak_damage)
		lives_changed.emit(lives)
		_remove(e, "leaked")
		return
	e.pos = path_point(e.path, e.progress)


static func path_point(p: MapPath, d: float) -> Vector2:
	var i := clampi(int(floor(d)), 0, p.cells.size() - 2)
	var t := clampf(d - float(i), 0.0, 1.0)
	return Vector2(p.cells[i]).lerp(Vector2(p.cells[i + 1]), t)


func _hit(attacker: Object, target: Object, atk: float) -> void:
	if target == null or not target.alive:
		return
	var amount := Targeting.damage(atk, float(target.defense) if target is SimUnit else 0.0)
	target.hp -= amount
	unit_attacked.emit(attacker, target, amount, false)
	if target.hp <= 0.0:
		if target is SimUnit:
			_kill(target)
		else:
			_destroy_building(target)


func _heal(source: Object, target: SimUnit, amount: float) -> void:
	var healed := minf(amount, target.max_hp - target.hp)
	if healed <= 0.0:
		return
	target.hp += healed
	unit_attacked.emit(source, target, healed, true)


func _kill(u: SimUnit) -> void:
	if not u.alive:
		return
	if u.side == Enums.Side.ENEMY:
		kills += 1
		resource = minf(float(ws.resource_cap), resource + u.bounty * ws.kill_bonus_mult)
	elif u.kind == SimUnit.Kind.HERO:
		heroes[u.hero_id]["hp"] = 0
		if (u.data as HeroData).essential and defeat_reason == "":
			defeat_reason = "hero_fell"
	_remove(u, "died")


func _destroy_building(b: SimBuilding) -> void:
	if not b.alive:
		return
	b.alive = false
	b.respawn.clear()
	building_removed.emit(b)


func _remove(u: SimUnit, reason: String) -> void:
	if not u.alive:
		return
	u.alive = false
	for e in u.blocking:
		if e.blocked_by == u:
			e.blocked_by = null
	u.blocking.clear()
	if u.blocked_by != null:
		u.blocked_by.blocking.erase(u)
		u.blocked_by = null
	u.queued_at = null
	if u.holds_line:
		for e in units:
			if e.queued_at == u:
				e.queued_at = null
	if u.kind == SimUnit.Kind.HERO:
		heroes[u.hero_id]["unit"] = null
	if u.home != null:
		u.home.squad.erase(u)
		if u.home.alive and reason == "died":
			u.home.respawn.append((u.home.data as BarracksData).respawn_time)
	unit_removed.emit(u, reason)


func _cleanup() -> void:
	for i in range(units.size() - 1, -1, -1):
		if not units[i].alive:
			units.remove_at(i)
	for i in range(buildings.size() - 1, -1, -1):
		if not buildings[i].alive:
			buildings.remove_at(i)


func _check_end() -> void:
	if phase == Phase.ENDED:
		return
	if defeat_reason == "hero_fell":
		_end(false)
		return
	if lives <= 0:
		defeat_reason = "leaks"
		_end(false)
		return
	if phase == Phase.RUNNING and wave_index >= total_waves() - 1 and _spawn_queue.is_empty() and alive_enemies().is_empty():
		_end(true)


func _end(victory: bool) -> void:
	phase = Phase.ENDED
	won = victory
	if not victory and defeat_reason == "":
		defeat_reason = "gave_up"
	ended.emit(victory)


# Outcome + HP of every hero after the match (deployed heroes keep their live HP).
func result() -> Dictionary:
	var hp := {}
	for id in heroes:
		var slot: Dictionary = heroes[id]
		var u: SimUnit = slot["unit"]
		hp[id] = int(ceil(u.hp)) if u != null and u.alive else int(slot["hp"])
	return { "victory": won, "hero_hp": hp,
		"kills": kills, "leaks": leaks, "reason": defeat_reason }


# Breaks the reference cycles (blocker <-> blocked, barracks <-> squad) so the
# RefCounted state is freed. Call when the match scene is left.
func dispose() -> void:
	for u in units:
		u.blocking.clear()
		u.blocked_by = null
		u.queued_at = null
		u.home = null
		u.last_target = null
	for b in buildings:
		b.squad.clear()
		b.last_target = null
	for id in heroes:
		heroes[id]["unit"] = null
	units.clear()
	buildings.clear()
	_spawn_queue.clear()


# ---------------------------------------------------------------------------
# Abilities
# ---------------------------------------------------------------------------
func _apply_ability(source: Object, ab: AbilityData, center: Vector2, atk: float, target: SimUnit) -> void:
	ability_used.emit(source, ab, center)
	match ab.kind:
		Enums.AbilityKind.STRIKE:
			if ab.radius <= 0.0:
				if target != null:
					_hit(source, target, atk * ab.power)
			else:
				for e in alive_enemies():
					if e.pos.distance_to(center) <= ab.radius:
						_hit(source, e, atk * ab.power)
		Enums.AbilityKind.STRIKE_ALL:
			for e in alive_enemies():
				_hit(source, e, atk * ab.power)
		Enums.AbilityKind.HEAL:
			for a in alive_defenders():
				if a.pos.distance_to(center) <= ab.radius:
					_heal(source, a, atk * ab.power)
		Enums.AbilityKind.BUFF_ATTACK:
			for a in alive_defenders():
				if a.pos.distance_to(center) <= ab.radius:
					a.buff_mult = 1.0 + ab.power
					a.buff_left = ab.duration
		Enums.AbilityKind.STUN:
			for e in alive_enemies():
				if e.pos.distance_to(center) <= ab.radius:
					e.stun_left = maxf(e.stun_left, ab.duration)
		Enums.AbilityKind.SUMMON:
			if ab.summon_unit == null:
				return
			var from := Vector2i(roundi(center.x), roundi(center.y))
			var rally := layout.nearest_path_cell(from)
			for i in ab.summon_count:
				var s := _make_unit(ab.summon_unit, SimUnit.Kind.SUMMON, Enums.Side.PLAYER, 1.0)
				s.cell = rally
				s.pos = Vector2(rally) + TROOP_OFFSETS[i % TROOP_OFFSETS.size()]
				s.lifetime = ab.duration
				_add_unit(s)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _make_unit(data: UnitData, kind: int, side: int, mult: float) -> SimUnit:
	var u := SimUnit.new()
	u.kind = kind
	u.side = side
	u.data = data
	u.target_class = data.target_class
	u.max_hp = float(data.max_hp) * mult
	u.hp = u.max_hp
	u.attack = float(data.attack) * mult
	u.defense = float(data.defense)
	u.attack_interval = data.attack_interval
	u.attack_range = data.attack_range
	u.is_ranged = data.is_ranged
	u.block_weight = data.block_weight
	u.block_capacity = data.block_capacity if side == Enums.Side.PLAYER else 0
	u.holds_line = data.holds_line and side == Enums.Side.PLAYER
	u.priority = Enums.TargetPriority.BLOCKED_THEN_FIRST
	return u


func _add_unit(u: SimUnit) -> void:
	_uid += 1
	u.uid = _uid
	units.append(u)
	unit_spawned.emit(u)
