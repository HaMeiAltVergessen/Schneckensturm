@tool
# A playable level: layout + waves + match economy + story dialogs. Belongs to a campaign act.
class_name WaveSet
extends Resource

@export var id: String = ""
@export var name_key: String = ""
## Player campaign faction.
@export var faction_id: String = "garden"
@export var enemy_faction_id: String = "snails"
@export var act: int = 1
@export var layout: MapLayout
@export var waves: Array[WaveData] = []
## -1 = use layout.hero_limit.
@export var hero_limit_override: int = -1
@export var is_boss: bool = false
@export var music_key: String = "battle"
## Played once before the level starts.
@export var pre_dialog: DialogData
## Played once after the first victory, before the story continues.
@export var post_dialog: DialogData

@export_group("Match economy")
@export var start_resource: int = 10
## Resource per second.
@export var resource_regen: float = 1.0
@export var resource_cap: int = 99
## Multiplier on UnitData.bounty.
@export var kill_bonus_mult: float = 1.0
## Dahlia petals: lost when snails reach the dahlia.
@export var lives: int = 10
@export var prep_time: float = 60.0
@export_range(0.0, 1.0) var retreat_refund_ratio: float = 0.35
## Match resource per missing hero HP when healing a hero in the match.
@export var heal_cost_per_hp: float = 0.02


func hero_limit() -> int:
	if hero_limit_override > 0:
		return hero_limit_override
	return layout.hero_limit if layout != null else 4
