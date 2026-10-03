@tool
# The target-rule matrix as data. Must contain exactly one rule per Enums.TargetClass
# (enforced by tests/match_test).
class_name TargetRuleSet
extends Resource

@export var rules: Array[TargetRule] = []


func rule_for(target_class: int) -> TargetRule:
	for r in rules:
		if r.target_class == target_class:
			return r
	return null


func missing_classes() -> Array[int]:
	var out: Array[int] = []
	for c in Enums.TargetClass.values():
		if rule_for(c) == null:
			out.append(c)
	return out


# Built-in defaults; data/rules/target_rules.tres is generated from this.
static func make_default() -> TargetRuleSet:
	var s := TargetRuleSet.new()
	s.rules.append(_rule(Enums.TargetClass.MELEE, true, Enums.AttackMode.BLOCKER_ONLY, true, true))
	s.rules.append(_rule(Enums.TargetClass.RANGED, true, Enums.AttackMode.ANY_IN_RANGE, true, true))
	s.rules.append(_rule(Enums.TargetClass.FLYER, false, Enums.AttackMode.ANY_IN_RANGE, false, false))
	s.rules.append(_rule(Enums.TargetClass.ASSASSIN, true, Enums.AttackMode.UNPROTECTED_FIRST, true, true))
	s.rules.append(_rule(Enums.TargetClass.SIEGE, true, Enums.AttackMode.BUILDINGS_FIRST, true, true))
	return s


static func _rule(c: int, blockable: bool, mode: int, stops: bool, melee_hittable: bool) -> TargetRule:
	var r := TargetRule.new()
	r.target_class = c
	r.can_be_blocked = blockable
	r.attack_mode = mode
	r.stops_to_attack = stops
	r.hittable_by_melee = melee_hittable
	return r
