# Hooks the real art into the existing content .tres files (texture fields only —
# balance values stay untouched). Run after adding images and importing them once;
# tools/art.sh does process_art → import → this in one go.
#   godot --headless --path . --script res://tools/link_art.gd
# File names: see ASSETS.md.
#   assets/garden/<id>.png            hero/unit token, building level 1
#   assets/garden/<id>_portrait.png   dialog portrait (fallback: token)
#   assets/garden/<building>_2/_3.png building upgrade levels
#   assets/ui/icon_<ability id>.png   ability button icon
#   assets/ui/bg_<dialog id>.jpg      dialog background from line 1, bg_<dialog id>_<n> from line n
#   assets/ui/bg_battle_gar_l<n>.jpg  battle background of level n
#   assets/tiles/gar_l<n>_tiles.png   level tileset (built by process_art)
#   assets/app/icon*.png              project + Android launcher icons
extends SceneTree

const ART := "res://assets/garden/%s.png"
const UI := "res://assets/ui/%s"
const TILE_ATLAS := "res://assets/tiles/gar_l%d_tiles.png"
const TILESET := "res://assets/tiles/gar_l%d_tileset.tres"
const LAYOUT := "res://data/maps/layout_gar_l%d.tres"
const APP := "res://assets/app/%s"

var linked := 0


func _initialize() -> void:
	for path in _list("res://data/heroes"):
		var h: HeroData = load(path)
		var changed := _link(h, "token", ART % h.id)
		changed = _link(h, "portrait", _portrait(h.id)) or changed
		if changed:
			_save(h, path)
	for path in _list("res://data/units"):
		var u: UnitData = load(path)
		if _link(u, "token", ART % u.id):
			_save(u, path)
	for dir in ["res://data/towers", "res://data/barracks"]:
		for path in _list(dir):
			var b: Resource = load(path)
			var changed := _link(b, "texture", ART % b.id)
			for i in b.upgrades.size():
				changed = _link(b.upgrades[i], "texture", ART % ("%s_%d" % [b.id, i + 2])) or changed
			if changed:
				_save(b, path)
	for path in _list("res://data/abilities"):
		var a: AbilityData = load(path)
		if _link(a, "icon", UI % ("icon_%s.png" % a.id)):
			_save(a, path)
	for path in _list("res://data/dialogs"):
		var d: DialogData = load(path)
		var changed := false
		for n in d.lines.size():
			var line: DialogLine = d.lines[n]
			var who := _speaker_art(line.speaker_name_key)
			if who != "":
				changed = _link(line, "portrait", _portrait(who)) or changed
			var bg := _background("bg_%s_%d" % [d.id, n + 1])
			if bg == "" and n == 0:
				bg = _background("bg_%s" % d.id)
			changed = _link(line, "background", bg) or changed
		if changed:
			_save(d, path)
	_tilesets()
	_battle_backgrounds()
	_app_icon()
	print("LINK_ART_DONE linked=%d" % linked)
	quit(0)


# Dialog portraits follow the speaker (Christina / the queen / Mama).
func _speaker_art(key: String) -> String:
	match key:
		"HERO_GAR_CHRISTINA_NAME": return "gar_christina"
		"UNIT_SNA_QUEEN_NAME": return "sna_queen"
		"DIALOG_SPEAKER_MOM": return "mom"
	return ""


# Dedicated bust if there is one, else the full-body token.
func _portrait(id: String) -> String:
	var p := ART % (id + "_portrait")
	return p if ResourceLoader.exists(p) else ART % id


func _background(name: String) -> String:
	for ext in ["jpg", "png"]:
		var p := UI % ("%s.%s" % [name, ext])
		if ResourceLoader.exists(p):
			return p
	return ""


func _tilesets() -> void:
	for n in range(1, 4):
		var atlas := TILE_ATLAS % n
		if not ResourceLoader.exists(atlas):
			continue
		var ts := IsoTiles.build_tileset(load(atlas))
		_save(ts, TILESET % n)
		var layout: MapLayout = load(LAYOUT % n)
		layout.tileset = load(TILESET % n)
		_save(layout, LAYOUT % n)
		linked += 1


func _battle_backgrounds() -> void:
	for n in range(1, 4):
		var layout: MapLayout = load(LAYOUT % n)
		if _link(layout, "background", _background("bg_battle_gar_l%d" % n)):
			_save(layout, LAYOUT % n)


# Project icon (window/taskbar, Windows .exe) + Android launcher icons.
func _app_icon() -> void:
	if not ResourceLoader.exists(APP % "icon.png"):
		return
	if ProjectSettings.get_setting("application/config/icon") != APP % "icon.png":
		ProjectSettings.set_setting("application/config/icon", APP % "icon.png")
		ProjectSettings.save()
		linked += 1
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		return
	for section in cfg.get_sections():
		if section.ends_with(".options") and cfg.has_section_key(section, "launcher_icons/main_192x192"):
			cfg.set_value(section, "launcher_icons/main_192x192", APP % "icon_192.png")
			cfg.set_value(section, "launcher_icons/adaptive_foreground_432x432", APP % "icon_432.png")
			cfg.set_value(section, "launcher_icons/adaptive_background_432x432", APP % "icon_bg_432.png")
	cfg.save("res://export_presets.cfg")


func _link(res: Resource, field: String, path: String) -> bool:
	if path == "" or not ResourceLoader.exists(path):
		return false
	var tex: Texture2D = load(path)
	if res.get(field) == tex:
		return false
	res.set(field, tex)
	linked += 1
	return true


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s: %d" % [path, err])


func _list(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	return out
