@tool
# A sequence of dialog lines. Played by DialogBox (standalone scene or in-battle overlay).
class_name DialogData
extends Resource

@export var id: String = ""                  # unique id, used for "already seen" tracking
@export var lines: Array[DialogLine] = []
