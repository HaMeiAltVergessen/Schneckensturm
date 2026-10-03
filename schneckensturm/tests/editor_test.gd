# Editor plugin (M5) without the editor UI: builds the dock for a layout and a
# waveset, paints a small map through the painter and checks the result validates.
extends TestSuite

const Dock := preload("res://addons/talathon_editor/talathon_dock.gd")
const Painter := preload("res://addons/talathon_editor/map_painter.gd")


func _run() -> void:
	tag = "EDITOR"
	var dock = Dock.new()
	dock.size = Vector2(1200, 320)
	add_child(dock)
	await get_tree().process_frame
	dock.edit(ContentDB.layouts["layout_gar_l1"].duplicate(true))
	await get_tree().process_frame
	expect(dock._painter != null, "painter built for a MapLayout")
	dock.edit(ContentDB.get_waveset("gar_l2").duplicate(true))
	await get_tree().process_frame
	expect(dock._timeline != null, "timeline built for a WaveSet")
	expect("✔" in dock._status.text or "⚠" in dock._status.text, "shipped waveset shows no errors")

	# Paint a map from scratch.
	var l := MapLayout.new()
	l.id = "painted"
	l.size = Vector2i(6, 4)
	var p = Painter.new()
	p.size = Vector2(600, 300)
	add_child(p)
	p.set_layout(l)
	p.tool = Painter.Tool.PATH
	p._apply(Vector2i(0, 1), false)
	p._apply(Vector2i(3, 1), false)        # straight run fills (1,1),(2,1)
	p._apply(Vector2i(3, 2), false)
	p._apply(Vector2i(5, 2), false)
	expect_eq(l.paths[0].cells.size(), 7, "path painted with gap fill")
	p._apply(Vector2i(5, 2), false)        # clicking the last tile removes it
	expect_eq(l.paths[0].cells.size(), 6, "last path tile removed")
	p._apply(Vector2i(5, 2), false)
	p.tool = Painter.Tool.DEPLOY_PATH
	p._apply(Vector2i(2, 1), false)
	p.tool = Painter.Tool.DEPLOY_EDGE
	p._apply(Vector2i(2, 0), false)
	p._apply(Vector2i(4, 3), false)
	p.tool = Painter.Tool.BUILD
	p._apply(Vector2i(4, 3), false)        # re-marking moves the tile to build slots
	expect(Vector2i(4, 3) in l.build_slots and Vector2i(4, 3) not in l.deploy_edge_cells, "markings are exclusive")
	var r := MapValidator.validate_layout(l)
	expect(r["errors"].is_empty(), "painted layout valid: %s" % str(r["errors"]))
	p._apply(Vector2i(3, 1), true)         # right click on the path cuts it
	expect_eq(l.paths[0].cells.size(), 3, "erasing a path tile cuts the path there")
	# Painter picking math round-trips.
	p._fit()
	for c in [Vector2i(0, 0), Vector2i(5, 3), Vector2i(2, 1)]:
		expect_eq(p.cell_at(p.cell_center(Vector2(c))), c, "painter cell_at %s" % str(c))
	dock.queue_free()
	p.queue_free()
