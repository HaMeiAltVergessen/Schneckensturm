@tool
# Team-neutral unit record: the same data drives enemies (walk the path) and own
# troops (hold a rally point). Behaviour is decided by the side at spawn time.
class_name UnitData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var faction_id: String = ""
## Enums.TargetClass — row in the target-rule matrix.
@export var target_class: int = Enums.TargetClass.MELEE
@export var max_hp: int = 300
@export var attack: int = 40
@export var defense: int = 10
## Seconds between attacks.
@export var attack_interval: float = 1.2
## Tiles per second along the path (enemies only).
@export var move_speed: float = 1.0
## Attack reach in tiles (grid distance).
@export var attack_range: float = 0.8
## Ranged attackers may hit flyers; melee cannot.
@export var is_ranged: bool = false
## Capacity this unit uses up on a blocker.
@export var block_weight: int = 1
## Capacity when this unit is an own troop standing on the path.
@export var block_capacity: int = 1
## true = enemies beyond the capacity queue up instead of walking past (heroes do this).
@export var holds_line: bool = false
## Lives lost when this enemy leaks.
@export var leak_damage: int = 1
## Match resource granted on kill (enemy only).
@export var bounty: int = 1
@export var is_boss: bool = false
## Visual size multiplier of the token.
@export var visual_scale: float = 1.0
@export var token: Texture2D
## Optional real animation; replaces the tweened token when set.
@export var sprite_frames: SpriteFrames

@export_group("Brood")
## Boss mechanic: while crawling this unit lays `brood_count` of these every `brood_interval` s.
@export var brood_unit: UnitData
@export var brood_interval: float = 0.0
@export var brood_count: int = 1
