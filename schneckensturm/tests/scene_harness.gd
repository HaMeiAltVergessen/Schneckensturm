# Instantiates every scene registered in SceneRouter in a real tree (autoloads
# present) to catch _ready / UI-build errors. Scenes that need hand-over state
# (match, dialog) get it prepared here. Also checks the story routing.
extends TestSuite


func _run() -> void:
	tag = "HARNESS"
	GameState.start_new_game()
	var ws := ContentDB.get_waveset("gar_l1")
	for key in SceneRouter.SCENES:
		if key == "boot":
			continue   # boot immediately routes to the menu
		GameState.pending_waveset = ws
		GameState.pending_dialog = ws.pre_dialog if key == "dialog" else null
		await _try_scene(SceneRouter.SCENES[key], key)
	# Level select and credits with everything cleared (credits button, ✓ marks).
	for m in GameState.maps():
		GameState.mark_cleared(m)
	await _try_scene(SceneRouter.SCENES["level_select"], "level_select (all cleared)")
	await _test_dialog_backgrounds()
	_test_story_dialogs()


# Lines with a background picture swap it (cross-fade), lines without keep it.
func _test_dialog_backgrounds() -> void:
	var tex := ImageTexture.create_from_image(Image.create(16, 9, false, Image.FORMAT_RGBA8))
	var d := DialogData.new()
	d.id = "harness_bg"
	for i in 2:
		var l := DialogLine.new()
		l.speaker_name_key = "DIALOG_SPEAKER_NARRATOR"
		l.text_key = "DIALOG_GAR_INTRO_1"
		l.background = tex if i == 0 else null
		d.lines.append(l)
	GameState.pending_dialog = d
	var inst: Control = load(SceneRouter.SCENES["dialog"]).instantiate()
	add_child(inst)
	await get_tree().process_frame
	expect(inst._bg.texture == tex, "dialog shows the line's background")
	for c in inst.get_children():
		if c is DialogBox:
			c._advance()
	expect(inst._bg.texture == tex, "a line without background keeps the previous one")
	inst.queue_free()
	GameState.pending_dialog = null
	await get_tree().process_frame


# Every level except the first has a post-dialog chain that ends in the credits.
func _test_story_dialogs() -> void:
	var maps := GameState.maps()
	expect(maps[0].pre_dialog != null, "level 1 has the intro")
	for m in maps:
		expect(m.post_dialog != null, "%s has a post dialog" % m.id)
	expect(maps[maps.size() - 1].is_boss, "the finale is the boss level")


func _try_scene(path: String, key: String) -> void:
	if not ResourceLoader.exists(path):
		expect(false, "scene missing: %s (%s)" % [key, path])
		return
	var ps: PackedScene = load(path)
	if ps == null:
		expect(false, "load failed: %s" % key)
		return
	var inst := ps.instantiate()
	add_child(inst)
	for i in 3:
		await get_tree().process_frame
	inst.queue_free()
	await get_tree().process_frame
	print("  scene ok: ", key)
