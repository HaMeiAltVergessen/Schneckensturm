# Runtime state of a tower or barracks inside MatchSim.
class_name SimBuilding
extends RefCounted

var uid := 0
## TowerData or BarracksData.
var data: Resource
var is_tower := true
var cell := Vector2i.ZERO
var max_hp := 100.0
var hp := 100.0
var alive := true
## 1 = as built; each bought upgrade adds one.
var level := 1

# Tower
var cooldown := 0.0
## Ability charge 0..1.
var charge := 0.0
var last_target: Object = null

# Barracks
var rally := Vector2i.ZERO
var squad: Array[SimUnit] = []
## One countdown per fallen squad member.
var respawn: Array[float] = []
var troop_mult := 1.0
## Tower damage multiplier (balance config).
var attack_mult := 1.0


func pos() -> Vector2:
	return Vector2(cell)


func ability() -> AbilityData:
	return data.ability if is_tower else null


func ability_ready() -> bool:
	return is_tower and data.ability != null and charge >= 1.0


func max_level() -> int:
	return 1 + data.upgrades.size()


## Upgrade data for the next level, or null when maxed.
func next_upgrade() -> Resource:
	return data.upgrades[level - 1] if level < max_level() else null


func _current_level() -> Resource:
	return data.upgrades[level - 2] if level >= 2 else null


func attack() -> float:
	var lv := _current_level()
	return float(lv.attack if lv != null else data.attack) * attack_mult


func attack_interval() -> float:
	var lv := _current_level()
	return lv.attack_interval if lv != null else data.attack_interval


## Barracks: troop stat multiplier of the current level (1.0 at level 1).
func level_troop_mult() -> float:
	var lv := _current_level()
	return lv.troop_mult if lv != null and not is_tower else 1.0


## Skin of the highest level at or below the current one that has a texture.
func level_texture() -> Texture2D:
	for i in range(level - 2, -1, -1):
		if data.upgrades[i].texture != null:
			return data.upgrades[i].texture
	return data.texture
