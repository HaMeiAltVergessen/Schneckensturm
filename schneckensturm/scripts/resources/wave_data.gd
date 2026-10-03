@tool
# One wave: parallel spawn groups. The next wave starts automatically
# `next_delay` seconds after this wave's last spawn (or earlier when called).
class_name WaveData
extends Resource

@export var groups: Array[SpawnGroup] = []
@export var next_delay: float = 20.0
## Optional announcement text key (e.g. boss incoming).
@export var announce_key: String = ""


func duration() -> float:
	var d := 0.0
	for g in groups:
		d = maxf(d, g.duration())
	return d


func unit_count() -> int:
	var n := 0
	for g in groups:
		n += g.count
	return n
