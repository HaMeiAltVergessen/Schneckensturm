# ChromaKey (addons/chroma_key) and IsoTiles (tools/iso_tiles.gd): background keying
# keeps enclosed key-coloured holes, soft edges carry no key-colour fringe, fit/cover
# produce the requested canvas, the iso atlas has transparent corners.
extends TestSuite


func _run() -> void:
	tag = "CHROMA_KEY"
	var key_col := Color(1, 0, 1)
	# 64×64 magenta canvas, an orange disc (r 20) with a magenta "hole" (r 4) in its middle.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(key_col)
	for y in 64:
		for x in 64:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(32, 32))
			if d <= 4.0:
				continue
			if d <= 20.0:
				img.set_pixel(x, y, Color(0.95, 0.55, 0.15))
			elif d <= 21.0:
				img.set_pixel(x, y, Color(0.95, 0.55, 0.15).lerp(key_col, 0.5))   # anti-aliased rim

	expect(ChromaKey.detect_key(img).is_equal_approx(key_col), "auto-detects the border colour")
	var out := ChromaKey.key(img)
	expect_eq(out.get_pixel(0, 0).a, 0.0, "corner is transparent")
	expect_eq(out.get_pixel(32, 32).a, 1.0, "enclosed key-coloured hole is kept (flood fill from border)")
	expect_eq(out.get_pixel(32, 20).a, 1.0, "subject stays opaque")
	var fringe := 0
	for y in 64:
		for x in 64:
			var c := out.get_pixel(x, y)
			var outside_hole := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(32, 32)) > 5.0
			if outside_hole and c.a > 0.05 and c.r > 0.8 and c.b > 0.6 and c.g < 0.3:
				fringe += 1
	expect_eq(fringe, 0, "no magenta fringe left on visible pixels")
	var rim := out.get_pixel(32, 32 - 21)
	expect(rim.a > 0.0 and rim.a < 1.0, "anti-aliased rim becomes semi-transparent (a=%.2f)" % rim.a)

	var trimmed := ChromaKey.trim(out, 2)
	expect(trimmed.get_width() <= 48 and trimmed.get_width() >= 42, "trim crops to the disc + margin (w=%d)" % trimmed.get_width())
	var fitted := ChromaKey.fit(trimmed, Vector2i(100, 200), ChromaKey.Anchor.BOTTOM)
	expect_eq(fitted.get_size(), Vector2i(100, 200), "fit returns the canvas size")
	expect_eq(fitted.get_pixel(50, 10).a, 0.0, "bottom anchor leaves the top empty")
	expect(fitted.get_pixel(50, 195).a > 0.9 or fitted.get_pixel(50, 190).a > 0.9, "bottom anchor puts the subject on the floor")
	expect_eq(ChromaKey.cover(img, Vector2i(120, 30)).get_size(), Vector2i(120, 30), "cover returns the exact size")

	var a := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	a.fill_rect(Rect2i(1, 1, 2, 2), Color.WHITE)
	var b := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	b.fill_rect(Rect2i(6, 5, 3, 3), Color.WHITE)
	expect_eq(ChromaKey.union_rect([a, b] as Array[Image]), Rect2i(1, 1, 8, 7), "union_rect spans all stages")

	# Iso atlas: 6 diamonds, transparent outside, opaque in the middle.
	var tex := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	tex.fill(Color(0.4, 0.3, 0.2))
	var atlas := IsoTiles.build_atlas({"ground": tex, "path": tex})
	expect_eq(atlas.get_size(), Vector2i(768, 64), "atlas has 6 tiles of 128×64")
	expect_eq(atlas.get_pixel(2, 2).a, 0.0, "diamond corner is transparent")
	expect_eq(atlas.get_pixel(64, 32).a, 1.0, "diamond centre is opaque")
	expect(atlas.get_pixel(5 * 128 + 64, 32).r < 0.3, "missing 'blocked' falls back to darkened ground")
	var ts := IsoTiles.build_tileset(ImageTexture.create_from_image(atlas))
	expect_eq((ts.get_source(0) as TileSetAtlasSource).get_tiles_count(), 6, "tileset has 6 tiles")
