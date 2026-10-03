@tool
# A faction: campaign (acts), buildings and colours. The snails are enemy-only (playable == false).
class_name FactionData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var playable: bool = true
@export var color: Color = Color(0.8, 0.8, 0.8)
@export var acts: Array[ActData] = []
@export var towers: Array[TowerData] = []
@export var barracks: Array[BarracksData] = []


func act(number: int) -> ActData:
	for a in acts:
		if a.act_number == number:
			return a
	return null


# Every level of the campaign in story order.
func all_maps() -> Array[WaveSet]:
	var out: Array[WaveSet] = []
	for a in acts:
		out.append_array(a.maps)
	return out


func buildings() -> Array:
	var out: Array = []
	out.append_array(towers)
	out.append_array(barracks)
	return out
