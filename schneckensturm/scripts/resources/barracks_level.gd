@tool
# One upgrade step of a barracks (level 2, 3, ...). Level 1 is the BarracksData itself.
class_name BarracksLevel
extends Resource

## Match resource paid for this upgrade.
@export var cost: int = 10
## Multiplier on troop HP and attack at this level (relative to level 1).
@export var troop_mult: float = 1.3
## Optional skin for this level (falls back to the previous level's look).
@export var texture: Texture2D
