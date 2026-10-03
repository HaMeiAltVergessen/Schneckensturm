@tool
# An active ability, shared by heroes (cooldown) and towers (charge time).
# All effects are data: kind + power + radius + duration (+ summon fields).
class_name AbilityData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
## Enums.AbilityKind
@export var kind: int = Enums.AbilityKind.STRIKE
## STRIKE/HEAL: multiplier of the user's attack. BUFF_ATTACK: +fraction (0.5 = +50 %).
@export var power: float = 2.0
## Area in tiles around the user (STRIKE with 0 hits only the current target).
@export var radius: float = 1.5
## Seconds (buff, stun, summon lifetime).
@export var duration: float = 5.0
## Hero cooldown / tower charge time in seconds.
@export var cooldown: float = 20.0
@export var summon_unit: UnitData
@export var summon_count: int = 0
