# Raw generator images (art_raw/<category>/<name>.png) → game-ready assets.
# Keys out the flat background (addons/chroma_key), trims, scales, builds the
# iso tile atlases and app icons. Only changed files are processed (--all forces).
#   godot --headless --path . --script res://tools/process_art.gd [-- --all]
# Normally run through tools/art.sh (process → import → link_art). See ASSETS.md.
extends SceneTree

const RAW := "res://art_raw"
## category → [output dir, canvas size, anchor]. Keyed + trimmed + fitted.
const SPRITES := {
	"figures": ["res://assets/garden", Vector2i(512, 512), ChromaKey.Anchor.CENTER],
	"portraits": ["res://assets/garden", Vector2i(512, 512), ChromaKey.Anchor.BOTTOM],
	"buildings": ["res://assets/garden", Vector2i(256, 320), ChromaKey.Anchor.BOTTOM],
	"dahlia": ["res://assets/garden", Vector2i(256, 384), ChromaKey.Anchor.BOTTOM],
	"icons": ["res://assets/ui", Vector2i(128, 128), ChromaKey.Anchor.CENTER],
}
## Groups whose enclosed background must go too (bow string, branches, hail).
## Not global: keying holes would also eat pinkish lips or pale eye whites.
const HOLES := ["gar_christina", "gar_rosehip", "icon_rosehip_hail"]
const BACKGROUND_SIZE := Vector2i(1920, 1080)
const APP_DIR := "res://assets/app"
const TILE_NAME := "tile_l%d_%s"     # tile_l1_ground / _path / _blocked
const TILE_ATLAS := "res://assets/tiles/gar_l%d_tiles.png"
const LEVELS := 3

var force := false
var written := 0


func _initialize() -> void:
	force = "--all" in OS.get_cmdline_user_args()
	for cat in SPRITES:
		_sprites(cat, SPRITES[cat][0], SPRITES[cat][1], SPRITES[cat][2])
	_backgrounds()
	_tiles()
	_app_icon()
	print("PROCESS_ART_DONE written=%d" % written)
	quit(0)


# Files of one category, grouped by name without a trailing stage number
# (gar_rose_bush, gar_rose_bush_2 … / dahlia_0 … dahlia_3): a group shares one
# crop frame so stages keep their relative size and position.
func _sprites(cat: String, out_dir: String, size: Vector2i, anchor: int) -> void:
	var groups := {}
	for f in _images(cat):
		var base := f.get_basename()
		var g := base
		var re := RegEx.create_from_string("^(.*)_\\d+$")
		var m := re.search(base)
		if m != null:
			g = m.get_string(1)
		if not groups.has(g):
			groups[g] = []
		groups[g].append(f)
	for g in groups:
		var files: Array = groups[g]
		if not force and files.all(func(f): return not _stale(cat, f, _out(out_dir, f, "png"))):
			continue
		var keyed: Array[Image] = []
		for f in files:
			keyed.append(ChromaKey.key(_load(cat, f), Color(0, 0, 0, 0), ChromaKey.DEFAULT_TOLERANCE,
					ChromaKey.DEFAULT_FEATHER, true, g in HOLES))
		var frame := ChromaKey.union_rect(keyed)
		for i in files.size():
			var img := ChromaKey.fit(ChromaKey.trim(keyed[i], 8, frame), size, anchor)
			_save_png(img, _out(out_dir, files[i], "png"))


# Full-screen pictures: no keying, scaled to cover 1920×1080, stored as JPG (small APK).
func _backgrounds() -> void:
	for f in _images("backgrounds"):
		var out := _out("res://assets/ui", f, "jpg")
		if force or _stale("backgrounds", f, out):
			var img := ChromaKey.cover(_load("backgrounds", f), BACKGROUND_SIZE)
			img.convert(Image.FORMAT_RGB8)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
			img.save_jpg(ProjectSettings.globalize_path(out), 0.9)
			_wrote(out)


# One iso atlas per level from tile_l<n>_ground / _path / _blocked.
func _tiles() -> void:
	for n in range(1, LEVELS + 1):
		var tex := {}
		var stale := force
		var out := TILE_ATLAS % n
		for role in ["ground", "path", "blocked"]:
			var f := _find("tiles", TILE_NAME % [n, role])
			if f != "":
				tex[role] = _load("tiles", f)
				stale = stale or _stale("tiles", f, out)
		if not tex.has("ground") or not tex.has("path") or not stale:
			continue
		_save_png(IsoTiles.build_atlas(tex), out)


# app_icon (square, no keying) → project icon + Android launcher icons.
func _app_icon() -> void:
	var f := _find("app", "app_icon")
	if f == "" or not (force or _stale("app", f, APP_DIR + "/icon.png")):
		return
	var src := _load("app", f)
	for s in [[256, "icon.png"], [192, "icon_192.png"], [432, "icon_432.png"]]:
		var img := ChromaKey.cover(src, Vector2i(s[0], s[0]))
		_save_png(img, APP_DIR.path_join(s[1]))
	# Adaptive-icon background: the picture blurred to soft colour fields.
	var bg := ChromaKey.cover(src, Vector2i(6, 6))
	bg.resize(432, 432, Image.INTERPOLATE_CUBIC)
	_save_png(bg, APP_DIR.path_join("icon_bg_432.png"))


# ---------------------------------------------------------------------------
func _images(cat: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := ProjectSettings.globalize_path(RAW.path_join(cat))
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			out.append(f)
	out.sort()
	return out


func _find(cat: String, base: String) -> String:
	for f in _images(cat):
		if f.get_basename() == base:
			return f
	return ""


func _load(cat: String, f: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(RAW.path_join(cat).path_join(f)))


func _out(dir: String, f: String, ext: String) -> String:
	return dir.path_join(f.get_basename() + "." + ext)


func _stale(cat: String, f: String, out: String) -> bool:
	var o := ProjectSettings.globalize_path(out)
	if not FileAccess.file_exists(o):
		return true
	var r := ProjectSettings.globalize_path(RAW.path_join(cat).path_join(f))
	return FileAccess.get_modified_time(r) > FileAccess.get_modified_time(o)


func _save_png(img: Image, out: String) -> void:
	var full := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	img.save_png(full)
	_wrote(out)


func _wrote(out: String) -> void:
	written += 1
	print("  wrote ", out)
