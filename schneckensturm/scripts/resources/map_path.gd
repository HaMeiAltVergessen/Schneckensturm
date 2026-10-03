@tool
# One enemy route as a chain of tile coordinates: first = spawn, last = exit.
# Consecutive cells must be orthogonal neighbours (iso diagonals on screen).
class_name MapPath
extends Resource

@export var cells: Array[Vector2i] = []


func length() -> float:
	return float(maxi(0, cells.size() - 1))
