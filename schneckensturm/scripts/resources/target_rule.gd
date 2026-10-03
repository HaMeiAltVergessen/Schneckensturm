@tool
# One row of the target-rule matrix: how a target class behaves in combat.
class_name TargetRule
extends Resource

## Enums.TargetClass this row describes.
@export var target_class: int = Enums.TargetClass.MELEE
## Can a blocker stop this unit?
@export var can_be_blocked: bool = true
## Enums.AttackMode — who this unit attacks.
@export var attack_mode: int = Enums.AttackMode.BLOCKER_ONLY
## Stops walking while it has a target in range (blocked units always stop).
@export var stops_to_attack: bool = true
## Can melee defenders hit this unit? (false for flyers)
@export var hittable_by_melee: bool = true
