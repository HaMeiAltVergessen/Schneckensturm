# Renders a MapLayout: iso TileMapLayer for the ground + an overlay layer for
# path arrows, spawn/exit markers and cell highlights (deploy targets, ranges).
class_name MapView
extends Node2D

const PLACEHOLDER_TILESET := "res://assets/tiles/placeholder_iso_tileset.tres"
## Atlas column per Enums.TileKind (placeholder tileset layout).
const KIND_ATLAS := {
	Enums.TileKind.GROUND: 0, Enums.TileKind.PATH: 1, Enums.TileKind.DEPLOY_PATH: 2,
	Enums.TileKind.DEPLOY_EDGE: 3, Enums.TileKind.BUILD_SLOT: 4, Enums.TileKind.BLOCKED: 5,
}

var layout: MapLayout
var grid: IsoGrid
var ground: TileMapLayer
var overlay: MapOverlay


func build(p_layout: MapLayout) -> void:
	layout = p_layout
	ground = TileMapLayer.new()
	ground.tile_set = layout.tileset if layout.tileset != null else load(PLACEHOLDER_TILESET)
	add_child(ground)
	for x in layout.size.x:
		for y in layout.size.y:
			var c := Vector2i(x, y)
			ground.set_cell(c, 0, Vector2i(KIND_ATLAS.get(layout.kind_at(c), 0), 0))
	grid = IsoGrid.from_tilemap(ground)
	overlay = MapOverlay.new()
	overlay.view = self
	add_child(overlay)


# World-space bounds of the whole map (for camera limits).
func world_rect() -> Rect2:
	var r := Rect2(grid.to_world(Vector2.ZERO), Vector2.ZERO)
	for c in [Vector2(-0.5, -0.5), Vector2(layout.size.x - 0.5, -0.5), Vector2(-0.5, layout.size.y - 0.5), Vector2(layout.size) - Vector2(0.5, 0.5)]:
		r = r.expand(grid.to_world(c))
	return r


func highlight(cells: Dictionary) -> void:
	overlay.highlights = cells
	overlay.queue_redraw()


func clear_highlight() -> void:
	highlight({})
