@tool
# A barracks for exactly one troop type. Holds one squad at a fixed rally point
# (nearest path tile) and respawns fallen members for free after a cooldown.
class_name BarracksData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var faction_id: String = ""
@export var cost: int = 10
@export var max_hp: int = 900
@export var unit: UnitData
@export var squad_size: int = 2
@export var respawn_time: float = 12.0
@export var color: Color = Color(0.55, 0.70, 0.85)
## Per-troop-type skin later; one placeholder for all for now.
@export var texture: Texture2D
## Upgrade steps bought in the match; upgrades[0] is level 2.
@export var upgrades: Array[BarracksLevel] = []
