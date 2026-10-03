# Hooks the real art from res://assets/garden/ into the existing content .tres files
# (token/portrait/texture fields only — balance values stay untouched). Run after
# adding images and importing them once:
#   godot --headless --path . --import
#   godot --headless --path . --script res://tools/link_art.gd
# File names: see ASSETS.md (<id>.png, <building id>_2.png / _3.png per upgrade level).
extends SceneTree

const ART := "res://assets/garden/%s.png"

var linked := 0


func _initialize() -> void:
	for path in _list("res://data/heroes"):
		var h: HeroData = load(path)
		if _link(h, "token", h.id):
			h.portrait = h.token
			_save(h, path)
	for path in _list("res://data/units"):
		var u: UnitData = load(path)
		if _link(u, "token", u.id):
			_save(u, path)
	for dir in ["res://data/towers", "res://data/barracks"]:
		for path in _list(dir):
			var b: Resource = load(path)
			var changed := _link(b, "texture", b.id)
			for i in b.upgrades.size():
				changed = _link(b.upgrades[i], "texture", "%s_%d" % [b.id, i + 2]) or changed
			if changed:
				_save(b, path)
	for path in _list("res://data/dialogs"):
		var d: DialogData = load(path)
		var changed := false
		for line in d.lines:
			var who := _speaker_art(line.speaker_name_key)
			if who != "":
				changed = _link(line, "portrait", who) or changed
		if changed:
			_save(d, path)
	print("LINK_ART_DONE linked=%d" % linked)
	quit(0)


# Dialog portraits follow the speaker (Christina / the queen / Mama).
func _speaker_art(key: String) -> String:
	match key:
		"HERO_GAR_CHRISTINA_NAME": return "gar_christina"
		"UNIT_SNA_QUEEN_NAME": return "sna_queen"
		"DIALOG_SPEAKER_MOM": return "mom"
	return ""


func _link(res: Resource, field: String, id: String) -> bool:
	var p := ART % id
	if not ResourceLoader.exists(p):
		return false
	var tex: Texture2D = load(p)
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
