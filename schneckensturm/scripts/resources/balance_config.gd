@tool
# Global balancing knobs (data/rules/balance.tres). MatchSim applies them on top of
# the per-level values, so the whole game gets easier/harder from one place.
class_name BalanceConfig
extends Resource

## 1.2 = every snail has 20 % more HP.
@export_range(0.1, 5.0, 0.05) var enemy_hp_mult: float = 1.0
## 1.2 = every snail crawls 20 % faster.
@export_range(0.1, 3.0, 0.05) var enemy_speed_mult: float = 1.0
## Multiplier on each level's start resource.
@export_range(0.1, 5.0, 0.05) var start_resource_mult: float = 1.0
## Multiplier on each level's resource regeneration per second.
@export_range(0.1, 5.0, 0.05) var regen_mult: float = 1.0
## Dahlia petals per level; 0 = use the level's own `lives`.
@export_range(0, 50) var petals: int = 0
## Multiplier on hero attack (Christina).
@export_range(0.1, 5.0, 0.05) var hero_attack_mult: float = 1.0
## Multiplier on hero ability cooldowns ("Leinen los"); 0.8 = 20 % more often.
@export_range(0.1, 5.0, 0.05) var hero_ability_cooldown_mult: float = 1.0
## Multiplier on tower attack (rosehips).
@export_range(0.1, 5.0, 0.05) var tower_attack_mult: float = 1.0
## Multiplier on troop HP and attack (roses).
@export_range(0.1, 5.0, 0.05) var troop_mult: float = 1.0
