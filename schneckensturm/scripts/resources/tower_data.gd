@tool
# A tower built on a build slot. Attacks from range, charges an ability over time.
class_name TowerData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var faction_id: String = ""
@export var cost: int = 12
## Building HP (siege enemies attack buildings).
@export var max_hp: int = 800
@export var attack: int = 50
@export var attack_interval: float = 1.0
@export var attack_range: float = 3.0
## Area damage radius around the target (0 = single target).
@export var splash_radius: float = 0.0
@export var can_hit_flyers: bool = true
## Enums.TargetPriority
@export var target_priority: int = Enums.TargetPriority.FIRST
@export var ability: AbilityData
@export var color: Color = Color(0.85, 0.80, 0.55)
@export var texture: Texture2D
## Upgrade steps bought in the match; upgrades[0] is level 2.
@export var upgrades: Array[TowerLevel] = []
