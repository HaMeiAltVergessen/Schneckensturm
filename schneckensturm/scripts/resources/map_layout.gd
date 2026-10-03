@tool
# Faction-neutral level geometry, shared by all campaigns (reskinned via tileset).
# Waves, rewards and enemy faction live in WaveSet.
class_name MapLayout
extends Resource

@export var id: String = ""
@export var name_key: String = ""
## Ground area in tiles (cells 0..size-1).
@export var size: Vector2i = Vector2i(14, 10)
@export var paths: Array[MapPath] = []
## Path tiles where PATH heroes may stand (and block).
@export var deploy_path_cells: Array[Vector2i] = []
## Edge tiles for EDGE heroes (never block).
@export var deploy_edge_cells: Array[Vector2i] = []
## Tower / barracks slots.
@export var build_slots: Array[Vector2i] = []
## Decoration / obstacles (not walkable, not deployable).
@export var blocked_cells: Array[Vector2i] = []
## Max heroes on this map (WaveSet may override).
@export var hero_limit: int = 4
## Optional tileset for reskins; null = placeholder tileset.
@export var tileset: TileSet
## Optional battle background (screen-fixed behind the map); null = plain color.
@export var background: Texture2D


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func is_path_cell(c: Vector2i) -> bool:
	for p in paths:
		if c in p.cells:
			return true
	return false


func all_path_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in paths:
		for c in p.cells:
			if c not in out:
				out.append(c)
	return out


# The dominant use of a tile (deploy/build markings win over plain path).
func kind_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return Enums.TileKind.NONE
	if c in build_slots:
		return Enums.TileKind.BUILD_SLOT
	if c in deploy_path_cells:
		return Enums.TileKind.DEPLOY_PATH
	if c in deploy_edge_cells:
		return Enums.TileKind.DEPLOY_EDGE
	if c in blocked_cells:
		return Enums.TileKind.BLOCKED
	if is_path_cell(c):
		return Enums.TileKind.PATH
	return Enums.TileKind.GROUND


# Nearest path tile to `c` (barracks rally point). Ties: first found.
func nearest_path_cell(c: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for p in all_path_cells():
		var d := Vector2(p - c).length()
		if d < best_d:
			best_d = d
			best = p
	return best
