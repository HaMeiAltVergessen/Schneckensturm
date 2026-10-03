@tool
# One act of a faction campaign (Schneckensturm has a single act with three levels).
class_name ActData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var act_number: int = 1
@export var maps: Array[WaveSet] = []
