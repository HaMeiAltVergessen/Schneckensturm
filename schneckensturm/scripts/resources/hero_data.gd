@tool
# A hero template. Heroes start every level with full HP (no persistence between levels).
class_name HeroData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var faction_id: String = ""
## Enums.HeroTier
@export var tier: int = Enums.HeroTier.CHAMPION
## Enums.HeroClass
@export var hero_class: int = Enums.HeroClass.MELEE
## Enums.Placement — path tiles (blocks there) or edge tiles (never blocks).
@export var placement: int = Enums.Placement.PATH
@export var max_hp: int = 1000
@export var attack: int = 80
@export var defense: int = 40
@export var attack_interval: float = 1.2
## How many enemy weight units this hero holds. 0 = never blocks.
@export var block: int = 2
## While alive nobody walks past: enemies beyond the block capacity queue up behind.
@export var holds_line: bool = true
## Attack reach as tile offsets from the hero's own tile.
@export var range_pattern: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Supports with heals == true use `attack` as healing on allies instead of damage.
@export var heals: bool = false
## Enums.TargetPriority
@export var target_priority: int = Enums.TargetPriority.BLOCKED_THEN_FIRST
@export var deploy_cost: int = 10
@export var redeploy_cooldown: float = 20.0
@export var ability: AbilityData
## The match is lost when this hero falls (Christina).
@export var essential: bool = false

@export_group("Visuals")
@export var token: Texture2D
@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames


func blocks() -> bool:
	return placement == Enums.Placement.PATH and block > 0


# Match stats (MatchSim hero entry). `atk_mult` comes from the balance config.
func match_stats(atk_mult := 1.0) -> Dictionary:
	return {
		"max_hp": max_hp,
		"attack": int(round(attack * atk_mult)),
		"defense": defense,
		"attack_interval": attack_interval,
		"block": block,
	}


# Hero entry as MatchSim.setup expects it.
func match_entry(atk_mult := 1.0) -> Dictionary:
	var st := match_stats(atk_mult)
	return { "id": id, "data": self, "stats": st, "hp": st["max_hp"], "abilities": [ability] if ability != null else [] }
