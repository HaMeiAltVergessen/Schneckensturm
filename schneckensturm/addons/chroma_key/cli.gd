# Headless batch keying. Every .png/.jpg/.webp in --in is keyed and written as PNG to --out.
#   godot --headless --path . --script res://addons/chroma_key/cli.gd -- \
#       --in art_raw/figures --out res://assets/sprites --size 512 [--anchor bottom]
# Options:
#   --size N | WxH     fit onto a canvas of that size (omit = keep trimmed size)
#   --anchor center|bottom
#   --key #ff00ff      key colour (default: auto-detect from the border)
#   --tolerance 0.22   --feather 0.14   --margin 8
#   --no-trim          keep the original framing   --shared-trim  crop all files with one frame
#   --cover WxH        no keying, scale+crop to fill (backgrounds)
extends SceneTree


func _initialize() -> void:
	var opt := _parse(OS.get_cmdline_user_args())
	if not opt.has("in") or not opt.has("out"):
		printerr("usage: --in <dir> --out <dir> [--size N|WxH] [--anchor center|bottom] [--key #rrggbb] [--cover WxH]")
		quit(1)
		return
	var in_dir := _abs(opt["in"])
	var out_dir := _abs(opt["out"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var files := _images(in_dir)
	var imgs: Array[Image] = []
	for f in files:
		imgs.append(Image.load_from_file(in_dir.path_join(f)))

	var cover := _size(str(opt.get("cover", "")))
	if cover == Vector2i.ZERO:
		var key_col := Color(opt["key"]) if opt.has("key") else Color(0, 0, 0, 0)
		var tol := float(opt.get("tolerance", ChromaKey.DEFAULT_TOLERANCE))
		var fea := float(opt.get("feather", ChromaKey.DEFAULT_FEATHER))
		for i in imgs.size():
			imgs[i] = ChromaKey.key(imgs[i], key_col, tol, fea)
	var shared := ChromaKey.union_rect(imgs) if opt.has("shared-trim") else Rect2i()
	var size := _size(str(opt.get("size", "")))
	var anchor := ChromaKey.Anchor.BOTTOM if str(opt.get("anchor", "")) == "bottom" else ChromaKey.Anchor.CENTER
	for i in imgs.size():
		var img := imgs[i]
		if cover != Vector2i.ZERO:
			img = ChromaKey.cover(img, cover)
		else:
			if not opt.has("no-trim"):
				img = ChromaKey.trim(img, int(opt.get("margin", 8)), shared)
			if size != Vector2i.ZERO:
				img = ChromaKey.fit(img, size, anchor)
		var out := out_dir.path_join(files[i].get_basename() + ".png")
		img.save_png(out)
		print("keyed ", out)
	print("CHROMA_KEY_DONE files=%d" % files.size())
	quit(0)


static func _parse(args: PackedStringArray) -> Dictionary:
	var d := {}
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--"):
			var k := a.substr(2)
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				d[k] = args[i + 1]
				i += 1
			else:
				d[k] = true
		i += 1
	return d


static func _abs(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	if p.is_relative_path():
		return ProjectSettings.globalize_path("res://").path_join(p)
	return p


static func _size(s: String) -> Vector2i:
	if s == "":
		return Vector2i.ZERO
	var p := s.to_lower().split("x")
	return Vector2i(int(p[0]), int(p[1] if p.size() > 1 else p[0]))


static func _images(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			out.append(f)
	out.sort()
	return out
