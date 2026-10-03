# MapValidator: all shipped content is error-free; typical authoring mistakes are caught.
extends TestSuite


func _run() -> void:
	tag = "VALIDATOR"
	for id in ContentDB.wavesets:
		var r := MapValidator.validate_waveset(ContentDB.wavesets[id])
		expect(r["errors"].is_empty(), "%s has errors: %s" % [id, str(r["errors"])])
		for w in r["warnings"]:
			print("  warning %s: %s" % [id, w])
	for id in ContentDB.layouts:
		expect(MapValidator.validate_layout(ContentDB.layouts[id])["errors"].is_empty(), "layout %s has errors" % id)

	var l := MapLayout.new()
	l.size = Vector2i(6, 6)
	var p := MapPath.new()
	p.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1)] as Array[Vector2i]   # diagonal step
	l.paths.append(p)
	l.deploy_path_cells = [Vector2i(4, 4)] as Array[Vector2i]                         # not on a path
	l.deploy_edge_cells = [Vector2i(1, 0)] as Array[Vector2i]                         # on the path
	l.build_slots = [Vector2i(9, 9)] as Array[Vector2i]                               # out of bounds
	var e: Array = MapValidator.validate_layout(l)["errors"]
	expect(_has(e, "Iso-Diagonalen"), "diagonal step detected")
	expect(_has(e, "liegt auf keinem Pfad"), "deploy path cell off-path detected")
	expect(_has(e, "Rand-Feld (1, 0) liegt auf einem Pfad"), "edge cell on path detected")
	expect(_has(e, "außerhalb"), "out-of-bounds slot detected")

	var ws := WaveSet.new()
	ws.id = "t"
	ws.act = 1
	var good := MapLayout.new()
	good.size = Vector2i(5, 3)
	var gp := MapPath.new()
	gp.cells = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i]
	good.paths.append(gp)
	ws.layout = good
	var w := WaveData.new()
	var g := SpawnGroup.new()
	g.unit = ContentDB.get_unit("sna_slug")
	g.path_index = 3
	w.groups.append(g)
	ws.waves = [w] as Array[WaveData]
	var r2 := MapValidator.validate_waveset(ws)
	expect(_has(r2["errors"], "Pfad 3 existiert nicht"), "invalid path index detected")
	expect(_has(r2["warnings"], "Richtwert für Akt 1"), "wave count warning for act 1")


func _has(list: Array, needle: String) -> bool:
	for s in list:
		if needle in s:
			return true
	return false
