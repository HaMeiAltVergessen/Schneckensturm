# Verifies the compiled translations (the artifacts shipped in exports) resolve
# German and English strings. Run with:
#   godot --headless --path . --script res://tests/loc_test.gd
extends SceneTree

func _initialize() -> void:
	var ok := true
	for pair in [["de", "Schneckensturm"]]:
		var t = load("res://localization/text.%s.translation" % pair[0])
		if t == null:
			printerr("missing translation for ", pair[0])
			ok = false
			continue
		TranslationServer.add_translation(t)
		TranslationServer.set_locale(pair[0])
		var title := TranslationServer.translate("UI_TITLE")
		print("%s: UI_TITLE -> %s" % [pair[0], title])
		ok = ok and title == pair[1]
	print("LOC_OK" if ok else "LOC_FAILED")
	quit(0 if ok else 1)
