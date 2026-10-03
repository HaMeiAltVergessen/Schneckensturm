@tool
# Grid <-> world conversion for the 2:1 isometric map (tile 128×64, diamond-down).
# Grid coordinates are floats so units can stand between tile centres; the
# mapping is affine: world = origin + x * axis_x + y * axis_y.
class_name IsoGrid
extends RefCounted

const TILE_SIZE := Vector2i(128, 64)

var origin := Vector2.ZERO
var axis_x := Vector2(TILE_SIZE.x * 0.5, TILE_SIZE.y * 0.5)
var axis_y := Vector2(-TILE_SIZE.x * 0.5, TILE_SIZE.y * 0.5)


# Matches a TileMapLayer exactly (uses its cell centres).
static func from_tilemap(tm: TileMapLayer) -> IsoGrid:
	var g := IsoGrid.new()
	g.origin = tm.map_to_local(Vector2i.ZERO)
	g.axis_x = tm.map_to_local(Vector2i(1, 0)) - g.origin
	g.axis_y = tm.map_to_local(Vector2i(0, 1)) - g.origin
	g.origin = tm.to_global(g.origin) if tm.is_inside_tree() else g.origin + tm.position
	return g


func to_world(grid: Vector2) -> Vector2:
	return origin + axis_x * grid.x + axis_y * grid.y


func to_grid(world: Vector2) -> Vector2:
	var p := world - origin
	var det := axis_x.x * axis_y.y - axis_y.x * axis_x.y
	return Vector2((p.x * axis_y.y - axis_y.x * p.y) / det, (axis_x.x * p.y - p.x * axis_x.y) / det)


func to_cell(world: Vector2) -> Vector2i:
	var g := to_grid(world)
	return Vector2i(roundi(g.x), roundi(g.y))


# Screen-space diamond corners of a cell (for highlights).
func cell_polygon(c: Vector2i) -> PackedVector2Array:
	var center := to_world(Vector2(c))
	var hx := (axis_x + axis_y) * 0.5
	var hy := (axis_x - axis_y) * 0.5
	return PackedVector2Array([center - hx, center + hy, center + hx, center - hy])
