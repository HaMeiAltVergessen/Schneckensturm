# save -> wipe -> load round-trip of the story progress (writes a scratch file)
# plus the linear unlock rules.
extends TestSuite


func _run() -> void:
	tag = "SAVE"
	GameState.start_new_game()
	var maps := GameState.maps()
	expect_eq(maps.size(), 3, "three levels in story order")
	expect(GameState.is_map_unlocked(maps[0]), "level 1 open")
	expect(not GameState.is_map_unlocked(maps[1]), "level 2 locked at start")
	expect(GameState.current_map() == maps[0], "story starts at level 1")
	expect(GameState.mark_cleared(maps[0]), "first clear counts")
	expect(not GameState.mark_cleared(maps[0]), "second clear does not")
	expect(GameState.is_map_unlocked(maps[1]), "level 2 opens after level 1")
	expect(GameState.next_map(maps[0]) == maps[1], "next map")
	expect(GameState.next_map(maps[2]) == null, "finale has no next map")
	GameState.mark_dialog_seen("gar_intro")
	var before := SaveManager.to_dict()
	SaveManager.save_game()

	GameState.reset()
	expect(not GameState.has_game(), "wiped")
	expect(SaveManager.load_game(), "load_game returned false")
	var after := SaveManager.to_dict()
	for k in before:
		expect_eq(JSON.stringify(after[k]), JSON.stringify(before[k]), "field '%s' survives round-trip" % k)
	expect(GameState.is_cleared(maps[0].id), "progress restored")
	expect(GameState.has_seen("gar_intro"), "seen dialogs restored")
	expect(GameState.current_map() == maps[1], "continue at level 2")

	for m in maps:
		GameState.mark_cleared(m)
	expect(GameState.story_complete(), "story complete after the finale")

	# Future-proofing: an unversioned dict still loads (migration hook).
	var legacy := before.duplicate(true)
	legacy.erase("version")
	expect(SaveManager.from_dict(legacy), "unversioned save loads")
