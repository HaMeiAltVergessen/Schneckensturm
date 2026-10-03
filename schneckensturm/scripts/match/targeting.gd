# Pure target selection: the target-rule matrix for enemies and the priority
# rules for own heroes/troops/towers. No engine state -> headless-testable.
class_name Targeting


static func damage(attack: float, defense: float) -> float:
	# Arknights-style floor: at least 5 % of the attack always gets through.
	return maxf(attack * 0.05, attack - defense)


# Is `p` (grid pos) within reach of `u`? Heroes use their tile pattern.
static func in_reach(u: SimUnit, p: Vector2) -> bool:
	if not u.range_pattern.is_empty():
		var c := Vector2i(roundi(p.x), roundi(p.y))
		return (c - u.cell) in u.range_pattern or u.pos.distance_to(p) <= 0.5
	return u.pos.distance_to(p) <= u.attack_range + 0.001


# May defender `u` (or a tower when is_tower) hit enemy `e` at all?
static func can_hit(attacker_ranged: bool, e: SimUnit, rules: TargetRuleSet) -> bool:
	var r := rules.rule_for(e.target_class)
	return attacker_ranged or r == null or r.hittable_by_melee


# Who does enemy `e` attack right now? Returns a SimUnit, a SimBuilding or null.
static func enemy_target(e: SimUnit, rules: TargetRuleSet, defenders: Array, buildings: Array) -> Object:
	var rule := rules.rule_for(e.target_class)
	var mode: int = rule.attack_mode if rule != null else Enums.AttackMode.BLOCKER_ONLY
	var blocker := e.blocked_by if e.blocked_by != null and e.blocked_by.alive else null
	match mode:
		Enums.AttackMode.BLOCKER_ONLY:
			return blocker
		Enums.AttackMode.ANY_IN_RANGE:
			if blocker != null:
				return blocker
			return _nearest_unit(e, defenders, false)
		Enums.AttackMode.UNPROTECTED_FIRST:
			if blocker != null:
				return blocker
			var soft := _nearest_unit(e, defenders, true)
			return soft if soft != null else _nearest_unit(e, defenders, false)
		Enums.AttackMode.BUILDINGS_FIRST:
			var b := _nearest_building(e, buildings)
			if b != null:
				return b
			return blocker
	return blocker


# Target for an own hero/troop (damage dealers). `enemies`: all alive enemies.
static func defender_target(u: SimUnit, enemies: Array, rules: TargetRuleSet) -> SimUnit:
	var cands: Array[SimUnit] = []
	for e in enemies:
		if e.alive and can_hit(u.is_ranged, e, rules) and in_reach(u, e.pos):
			cands.append(e)
	return pick_by_priority(cands, u.priority, u.blocking)


# Tower target inside a radius.
static func tower_target(pos: Vector2, reach: float, hits_flyers: bool, priority: int, enemies: Array) -> SimUnit:
	var cands: Array[SimUnit] = []
	for e in enemies:
		if not e.alive or pos.distance_to(e.pos) > reach + 0.001:
			continue
		if e.target_class == Enums.TargetClass.FLYER and not hits_flyers:
			continue
		cands.append(e)
	return pick_by_priority(cands, priority, [])


static func pick_by_priority(cands: Array[SimUnit], priority: int, blocked: Array) -> SimUnit:
	if cands.is_empty():
		return null
	if priority == Enums.TargetPriority.BLOCKED_THEN_FIRST:
		var held: Array[SimUnit] = []
		for c in cands:
			if c in blocked:
				held.append(c)
		if not held.is_empty():
			return _best(held, Enums.TargetPriority.FIRST)
		return _best(cands, Enums.TargetPriority.FIRST)
	return _best(cands, priority)


static func _best(cands: Array[SimUnit], priority: int) -> SimUnit:
	var best: SimUnit = cands[0]
	for c in cands:
		match priority:
			Enums.TargetPriority.STRONGEST:
				if c.hp > best.hp:
					best = c
			Enums.TargetPriority.WEAKEST:
				if c.hp < best.hp:
					best = c
			_:
				if c.remaining_distance() < best.remaining_distance():
					best = c
	return best


# Heal target for supports: most wounded ally (lowest HP ratio) in reach.
static func heal_target(u: SimUnit, allies: Array) -> SimUnit:
	var best: SimUnit = null
	for a in allies:
		if not a.alive or a.hp >= a.max_hp or not in_reach(u, a.pos):
			continue
		if best == null or a.hp_ratio() < best.hp_ratio():
			best = a
	return best


static func _nearest_unit(e: SimUnit, defenders: Array, unprotected_only: bool) -> SimUnit:
	var best: SimUnit = null
	var best_d := INF
	for d in defenders:
		if not d.alive:
			continue
		if unprotected_only and not d.blocking.is_empty():
			continue
		var dist: float = e.pos.distance_to(d.pos)
		if dist <= e.attack_range + 0.001 and dist < best_d:
			best_d = dist
			best = d
	return best


static func _nearest_building(e: SimUnit, buildings: Array) -> SimBuilding:
	var best: SimBuilding = null
	var best_d := INF
	for b in buildings:
		if not b.alive:
			continue
		var dist: float = e.pos.distance_to(b.pos())
		if dist <= e.attack_range + 0.001 and dist < best_d:
			best_d = dist
			best = b
	return best
