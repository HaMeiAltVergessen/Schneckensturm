# Every translation key referenced by .tres content (and every Enums key helper)
# must resolve in every shipped locale (German) — no raw keys visible in-game.
extends TestSuite

var _missing: Array[String] = []


func _run() -> void:
	tag = "CONTENT_LOC"
	for locale in Settings.LOCALES:
		TranslationServer.set_locale(locale)
		for h in ContentDB.heroes.values():
			_check(h.name_key, "hero %s" % h.id)
		for u in ContentDB.units.values():
			_check(u.name_key, "unit %s" % u.id)
		for t in ContentDB.towers.values():
			_check(t.name_key, "tower %s" % t.id)
		for b in ContentDB.barracks.values():
			_check(b.name_key, "barracks %s" % b.id)
		for a in ContentDB.abilities.values():
			_check(a.name_key, "ability %s name" % a.id)
			_check(a.desc_key, "ability %s desc" % a.id)
		for l in ContentDB.layouts.values():
			_check(l.name_key, "layout %s" % l.id)
		for w in ContentDB.wavesets.values():
			_check(w.name_key, "waveset %s" % w.id)
			for wave in w.waves:
				_check(wave.announce_key, "waveset %s announce" % w.id)
			_check_dialog(w.pre_dialog)
			_check_dialog(w.post_dialog)
		for f in ContentDB.factions.values():
			_check(f.name_key, "faction %s" % f.id)
			for a in f.acts:
				_check(a.name_key, "act %s" % a.id)
		for d in ContentDB.dialogs.values():
			_check_dialog(d)
		for t in Enums.HeroTier.values():
			_check(Enums.tier_name_key(t), "tier")
		for c in Enums.HeroClass.values():
			_check(Enums.class_name_key(c), "class")
		for c in Enums.TargetClass.values():
			_check(Enums.target_class_key(c), "target class")
		for key in _code_keys():
			_check(key, "code")
	TranslationServer.set_locale(Settings.locale)
	for m in _missing:
		printerr("  MISSING: ", m)
	expect(_missing.is_empty(), "%d missing translation keys" % _missing.size())


# Every literal key in tr("…") / translate("…") across scenes/ and scripts/.
func _code_keys() -> Array[String]:
	var re := RegEx.create_from_string("(?:tr|translate)\\(\"([A-Z][A-Z0-9_]+)\"\\)")
	var out: Array[String] = []
	for dir in ["res://scenes", "res://scripts", "res://addons"]:
		for path in _gd_files(dir):
			var text := FileAccess.get_file_as_string(path)
			for m in re.search_all(text):
				var k := m.get_string(1)
				if k not in out:
					out.append(k)
	return out


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


func _check_dialog(d: DialogData) -> void:
	if d == null:
		return
	for line in d.lines:
		_check(line.speaker_name_key, "dialog %s speaker" % d.id)
		_check(line.text_key, "dialog %s text" % d.id)


func _check(key: String, where: String) -> void:
	if key == "":
		return
	if TranslationServer.translate(key) == key:
		var entry := "%s [%s] (%s)" % [key, TranslationServer.get_locale(), where]
		if entry not in _missing:
			_missing.append(entry)
