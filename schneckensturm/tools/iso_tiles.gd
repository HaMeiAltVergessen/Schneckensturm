# Turns square, seamless top-down textures (what an image generator can make)
# into the 2:1 iso tile atlas MapView expects: one diamond per Enums.TileKind
# in MapView.KIND_ATLAS order. Used by tools/process_art.gd (atlas PNG) and
# tools/link_art.gd (TileSet resource).
class_name IsoTiles
extends RefCounted

const TILE := Vector2i(128, 64)
## Atlas column → [texture role, rim colour or transparent]. Column order = MapView.KIND_ATLAS.
const COLUMNS := [
	["ground", Color(0, 0, 0, 0)],               # 0 ground
	["path", Color(0, 0, 0, 0)],                 # 1 path
	["path", Color(0.95, 0.78, 0.30)],           # 2 deploy path (gold rim)
	["ground", Color(0.40, 0.65, 0.95)],         # 3 deploy edge (blue rim, Christina)
	["ground", Color(0.95, 0.95, 0.98)],         # 4 build slot (white rim)
	["blocked", Color(0, 0, 0, 0)],              # 5 blocked
]


## Atlas (TILE.x * 6 × TILE.y) from the role textures. Missing "blocked" = darkened ground.
static func build_atlas(textures: Dictionary) -> Image:
	var atlas := Image.create(TILE.x * COLUMNS.size(), TILE.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for i in COLUMNS.size():
		var role: String = COLUMNS[i][0]
		var src: Image = textures.get(role)
		var dim := 1.0
		if src == null and role == "blocked":
			src = textures.get("ground")
			dim = 0.45
		if src == null:
			continue
		var tile := diamond(src, COLUMNS[i][1], dim)
		atlas.blit_rect(tile, Rect2i(Vector2i.ZERO, TILE), Vector2i(i * TILE.x, 0))
	return atlas


## Maps a square texture onto one iso diamond: the square's corners land on the
## diamond's top/right/bottom/left points, so a seamless texture tiles seamlessly.
static func diamond(src: Image, rim := Color(0, 0, 0, 0), dim := 1.0) -> Image:
	var tex := src.duplicate() as Image
	if tex.is_compressed():
		tex.decompress()
	tex.convert(Image.FORMAT_RGBA8)
	# Pre-shrink so the per-pixel lookup below is effectively antialiased.
	var side := int(ceil(TILE.x * 1.42))
	tex.resize(side, side, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(TILE.x, TILE.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var hw := TILE.x / 2.0
	var hh := TILE.y / 2.0
	for y in TILE.y:
		for x in TILE.x:
			var dx := (x + 0.5 - hw) / hw
			var dy := (y + 0.5 - hh) / hh
			var d := absf(dx) + absf(dy)
			if d > 1.0:
				continue
			var u := clampf((dx + dy) * 0.5 + 0.5, 0.0, 0.9999)
			var v := clampf((dy - dx) * 0.5 + 0.5, 0.0, 0.9999)
			var c := tex.get_pixel(int(u * side), int(v * side))
			c = Color(c.r * dim, c.g * dim, c.b * dim, 1.0)
			if rim.a > 0.0 and d > 0.88:
				c = c.lerp(rim, 0.85)
			elif d > 0.97:
				c = c.darkened(0.25)   # thin seam so cells stay readable
			out.set_pixel(x, y, c)
	return out


## TileSet over an imported atlas PNG (same layout as the placeholder tileset).
static func build_tileset(atlas: Texture2D) -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = TILE
	var src := TileSetAtlasSource.new()
	src.texture = atlas
	src.texture_region_size = TILE
	for i in COLUMNS.size():
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	return ts
