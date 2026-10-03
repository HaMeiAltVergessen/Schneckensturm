@tool
# One upgrade step of a tower (level 2, 3, ...). Level 1 is the TowerData itself.
class_name TowerLevel
extends Resource

## Match resource paid for this upgrade.
@export var cost: int = 10
@export var attack: int = 60
@export var attack_interval: float = 1.0
## Optional skin for this level (falls back to the previous level's look).
@export var texture: Texture2D
