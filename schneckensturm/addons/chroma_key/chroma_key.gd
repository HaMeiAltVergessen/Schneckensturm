@tool
# Background removal for AI-generated sprites on a flat key colour (magenta,
# cyan, green screen …) plus the usual post-steps: trim, fit, cover.
# Pure image logic, no project dependencies — usable from the editor dialog,
# the headless CLI (cli.gd) or any game/tool script:
#     var img := Image.load_from_file("raw.png")
#     var out := ChromaKey.fit(ChromaKey.trim(ChromaKey.key(img)), Vector2i(512, 512))
#     out.save_png("sprite.png")
class_name ChromaKey
extends RefCounted

enum Anchor { CENTER, BOTTOM }

## Fully transparent below this distance to the key colour (0..1, RGB distance / sqrt(3)).
const DEFAULT_TOLERANCE := 0.22
## Width of the soft band above the tolerance, where alpha ramps up to opaque.
const DEFAULT_FEATHER := 0.14


## Median colour of the image border — the background a generator was asked for.
static func detect_key(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var rs: Array[float] = []
	var gs: Array[float] = []
	var bs: Array[float] = []
	var step := maxi(1, (w + h) / 400)
	for x in range(0, w, step):
		for y in [0, h - 1]:
			var c := img.get_pixel(x, y)
			rs.append(c.r); gs.append(c.g); bs.append(c.b)
	for y in range(0, h, step):
		for x in [0, w - 1]:
			var c := img.get_pixel(x, y)
			rs.append(c.r); gs.append(c.g); bs.append(c.b)
	rs.sort(); gs.sort(); bs.sort()
	var m := rs.size() / 2
	return Color(rs[m], gs[m], bs[m])


## Removes the background. Only pixels connected to the image border are keyed
## (flood fill), so key-coloured details *inside* the subject survive.
## `holes` = also key enclosed background (gap between bow and string, between
## branches): every pixel within half the `tolerance` seeds the fill as well.
## `key_color` with alpha 0 = auto-detect from the border.
## Returns a new RGBA8 image; the input stays untouched.
static func key(src: Image, key_color := Color(0, 0, 0, 0), tolerance := DEFAULT_TOLERANCE,
		feather := DEFAULT_FEATHER, despill := true, holes := false) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if key_color.a == 0.0:
		key_color = detect_key(img)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var n := w * h
	var kr := key_color.r * 255.0
	var kg := key_color.g * 255.0
	var kb := key_color.b * 255.0
	var norm := 1.0 / (255.0 * sqrt(3.0))
	var limit := tolerance + feather

	# Distance of every pixel to the key colour.
	var dist := PackedFloat32Array()
	dist.resize(n)
	for i in n:
		var o := i * 4
		var dr := data[o] - kr
		var dg := data[o + 1] - kg
		var db := data[o + 2] - kb
		dist[i] = sqrt(dr * dr + dg * dg + db * db) * norm

	# Flood fill from the border through everything within tolerance + feather.
	var bg := PackedByteArray()
	bg.resize(n)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	if holes:
		for i in n:
			if dist[i] < tolerance * 0.5:
				stack.append(i)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if bg[i] == 1 or dist[i] >= limit:
			continue
		bg[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)

	for i in n:
		var o := i * 4
		if bg[i] == 1:
			var a := clampf((dist[i] - tolerance) / maxf(feather, 0.0001), 0.0, 1.0)
			if despill and a > 0.0:
				# Un-mix the key colour out of the semi-transparent edge pixel.
				data[o] = int(clampf(kr + (data[o] - kr) / a, 0.0, 255.0))
				data[o + 1] = int(clampf(kg + (data[o + 1] - kg) / a, 0.0, 255.0))
				data[o + 2] = int(clampf(kb + (data[o + 2] - kb) / a, 0.0, 255.0))
			data[o + 3] = int(round(a * float(data[o + 3])))
		elif despill and _touches(bg, i, w, h):
			_desaturate_spill(data, o, dist[i], limit)

	var out := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	# Bleed edge colours into transparent pixels so later scaling has no key-coloured halo.
	out.fix_alpha_edges()
	return out


## Crops to the visible content plus `margin` px. `rect` overrides the measured
## area (use union_rect() to crop a set of images identically).
static func trim(img: Image, margin := 8, rect := Rect2i()) -> Image:
	var r := rect if rect.has_area() else img.get_used_rect()
	if not r.has_area():
		return img.duplicate() as Image
	r = r.grow(margin).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)


## Union of the visible areas of several same-sized images (animation frames,
## upgrade stages …) so they can be trimmed with the same frame.
static func union_rect(images: Array[Image]) -> Rect2i:
	var u := Rect2i()
	for img in images:
		var r := img.get_used_rect()
		if r.has_area():
			u = r if not u.has_area() else u.merge(r)
	return u


## Scales the image to fit inside `size` (keeping aspect) and places it on a
## transparent canvas of exactly that size — centred or standing on the bottom edge.
static func fit(img: Image, size: Vector2i, anchor := Anchor.CENTER) -> Image:
	var s := minf(float(size.x) / img.get_width(), float(size.y) / img.get_height())
	var scaled := img.duplicate() as Image
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(maxi(1, int(round(img.get_width() * s))), maxi(1, int(round(img.get_height() * s))), Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var pos := Vector2i((size.x - scaled.get_width()) / 2, (size.y - scaled.get_height()) / 2)
	if anchor == Anchor.BOTTOM:
		pos.y = size.y - scaled.get_height()
	canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), pos)
	return canvas


## Scales to fill `size` completely and crops the overflow (backgrounds).
static func cover(img: Image, size: Vector2i) -> Image:
	var s := maxf(float(size.x) / img.get_width(), float(size.y) / img.get_height())
	var scaled := img.duplicate() as Image
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(maxi(size.x, int(ceil(img.get_width() * s))), maxi(size.y, int(ceil(img.get_height() * s))), Image.INTERPOLATE_LANCZOS)
	var off := (scaled.get_size() - size) / 2
	return scaled.get_region(Rect2i(off, size))


static func _touches(bg: PackedByteArray, i: int, w: int, h: int) -> bool:
	var x := i % w
	var y := i / w
	return (x > 0 and bg[i - 1] == 1) or (x < w - 1 and bg[i + 1] == 1) \
		or (y > 0 and bg[i - w] == 1) or (y < h - 1 and bg[i + w] == 1)


# Opaque pixel right at the cut line: pull it towards grey the closer it is to the key.
static func _desaturate_spill(data: PackedByteArray, o: int, d: float, limit: float) -> void:
	var s := clampf(1.0 - (d - limit) / maxf(limit, 0.0001), 0.0, 1.0) * 0.8
	if s <= 0.0:
		return
	var l := 0.299 * data[o] + 0.587 * data[o + 1] + 0.114 * data[o + 2]
	for c in 3:
		data[o + c] = int(lerpf(data[o + c], l, s))
