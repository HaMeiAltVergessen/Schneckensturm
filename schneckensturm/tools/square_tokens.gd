# Crops every PNG under res://assets/units/ to a centred square (top-biased for
# portrait images, where the face sits high) and scales it to 256 px, so the
# round token mask fits. Safe to re-run: square 256 px images are skipped.
#   godot --headless --path . --script res://tools/square_tokens.gd
extends SceneTree

const SIZE := 256


func _initialize() -> void:
	var n := 0
	for path in _pngs("res://assets/units"):
		var abs_path := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_path)
		if img == null:
			continue
		var w := img.get_width()
		var h := img.get_height()
		if w == SIZE and h == SIZE:
			continue
		var side := mini(w, h)
		var x := (w - side) / 2
		var y := 0 if h > w else (h - side) / 2
		var sq := img.get_region(Rect2i(x, y, side, side))
		sq.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		sq.save_png(abs_path)
		n += 1
	print("SQUARED %d images" % n)
	quit(0)


func _pngs(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_pngs(dir.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(dir.path_join(f))
	return out
