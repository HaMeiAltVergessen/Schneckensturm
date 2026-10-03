@tool
# `count` units of one type, spawned `interval` seconds apart after `delay`.
class_name SpawnGroup
extends Resource

@export var unit: UnitData
@export var count: int = 5
@export var interval: float = 1.5
## Seconds after the wave start before the first unit.
@export var delay: float = 0.0
## Index into MapLayout.paths.
@export var path_index: int = 0


func duration() -> float:
	return delay + interval * float(maxi(0, count - 1))
