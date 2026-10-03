# Runtime state of one unit inside MatchSim (hero, troop, summon or enemy).
# Pure data + tiny helpers; all rules live in MatchSim so they stay testable.
class_name SimUnit
extends RefCounted

enum Kind { HERO, TROOP, SUMMON, ENEMY }

var uid := 0
var kind: int = Kind.ENEMY
var side: int = Enums.Side.ENEMY
## HeroData for heroes, UnitData otherwise.
var data: Resource
var hero_id := ""
var target_class: int = Enums.TargetClass.MELEE

var max_hp := 100.0
var hp := 100.0
var attack := 10.0
var defense := 0.0
var attack_interval := 1.0
var attack_range := 0.8
## Heroes: reach as tile offsets; empty = use attack_range.
var range_pattern: Array[Vector2i] = []
var is_ranged := false
var heals := false
var priority: int = Enums.TargetPriority.BLOCKED_THEN_FIRST

var block_capacity := 0
var block_weight := 1
var blocking: Array[SimUnit] = []
var blocked_by: SimUnit = null
## Heroes: enemies beyond the capacity queue up instead of walking past.
var holds_line := false
## Enemy waiting in the queue behind this full line-holder.
var queued_at: SimUnit = null

## Grid-space position (float); `cell` is the home tile for defenders.
var pos := Vector2.ZERO
var cell := Vector2i.ZERO
var path: MapPath
var progress := 0.0
var move_speed := 1.0

var cooldown := 0.0
var alive := true
var stun_left := 0.0
var buff_mult := 1.0
var buff_left := 0.0
## Seconds left for summons (-1 = permanent).
var lifetime := -1.0
## Seconds until the next brood (enemies with UnitData.brood_unit).
var brood_left := 0.0
var leak_damage := 1
var bounty := 0
## Barracks this troop belongs to.
var home: SimBuilding = null
## Last thing this unit attacked (for visuals).
var last_target: Object = null


func is_player() -> bool:
	return side == Enums.Side.PLAYER


func can_block() -> bool:
	return is_player() and block_capacity > 0


func used_capacity() -> int:
	var n := 0
	for e in blocking:
		n += e.block_weight
	return n


func free_capacity() -> int:
	return block_capacity - used_capacity()


func remaining_distance() -> float:
	return path.length() - progress if path != null else 0.0


func effective_attack() -> float:
	return attack * buff_mult


func hp_ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0
