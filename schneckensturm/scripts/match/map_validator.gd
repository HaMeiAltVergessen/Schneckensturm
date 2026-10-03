@tool
# Checks MapLayouts and WaveSets for mistakes before they reach a match. Used by
# the editor plugin (M5) and tests. Returns { "errors": [String], "warnings": [String] }.
# Messages are German on purpose: they are for the map author in the editor.
class_name MapValidator

## Recommended wave counts per act (warning only).
const WAVE_TARGETS := { 1: Vector2i(5, 7), 2: Vector2i(7, 9), 3: Vector2i(9, 12) }
## A build slot farther than this from every path tile is probably useless.
const SLOT_REACH := 3.5
const EDGE_REACH := 2.0


static func validate_layout(l: MapLayout) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if l == null:
		errors.append("Kein Layout.")
		return { "errors": errors, "warnings": warnings }
	if l.size.x < 2 or l.size.y < 2:
		errors.append("Kartengröße zu klein (%s)." % str(l.size))
	if l.hero_limit < 1:
		errors.append("hero_limit muss mindestens 1 sein.")
	if l.paths.is_empty():
		errors.append("Keine Pfade definiert.")
	var path_cells := {}
	for pi in l.paths.size():
		var p: MapPath = l.paths[pi]
		if p == null or p.cells.size() < 2:
			errors.append("Pfad %d hat weniger als 2 Felder." % pi)
			continue
		var seen := {}
		for i in p.cells.size():
			var c: Vector2i = p.cells[i]
			path_cells[c] = true
			if not _in_bounds(l, c):
				errors.append("Pfad %d: Feld %s liegt außerhalb der Karte." % [pi, str(c)])
			if c in l.blocked_cells:
				errors.append("Pfad %d: Feld %s ist blockiert." % [pi, str(c)])
			if seen.has(c):
				warnings.append("Pfad %d betritt Feld %s mehrfach (Schleife)." % [pi, str(c)])
			seen[c] = true
			if i > 0:
				var d: Vector2i = c - p.cells[i - 1]
				if absi(d.x) + absi(d.y) != 1:
					errors.append("Pfad %d: Schritt %s → %s ist kein Nachbarfeld entlang der Iso-Diagonalen." % [pi, str(p.cells[i - 1]), str(c)])
	if l.deploy_path_cells.is_empty():
		warnings.append("Keine Pfad-Felder: Nahkampf-Helden können nirgends stehen.")
	if l.deploy_edge_cells.is_empty():
		warnings.append("Keine Rand-Felder: Fernkampf-Helden können nirgends stehen.")
	for c in l.deploy_path_cells:
		if not path_cells.has(c):
			errors.append("Pfad-Feld %s liegt auf keinem Pfad." % str(c))
	var used := {}
	for group in [["Rand-Feld", l.deploy_edge_cells], ["Bau-Slot", l.build_slots], ["Blockiertes Feld", l.blocked_cells]]:
		for c in group[1]:
			if not _in_bounds(l, c):
				errors.append("%s %s liegt außerhalb der Karte." % [group[0], str(c)])
			if path_cells.has(c) and group[0] != "Blockiertes Feld":
				errors.append("%s %s liegt auf einem Pfad." % [group[0], str(c)])
			if used.has(c):
				errors.append("Feld %s ist doppelt belegt (%s und %s)." % [str(c), used[c], group[0]])
			used[c] = group[0]
	for c in l.build_slots:
		if _nearest_path_dist(path_cells, c) > SLOT_REACH:
			warnings.append("Bau-Slot %s ist weit von jedem Pfad entfernt (Türme erreichen nichts)." % str(c))
	for c in l.deploy_edge_cells:
		if _nearest_path_dist(path_cells, c) > EDGE_REACH:
			warnings.append("Rand-Feld %s liegt nicht am Pfad." % str(c))
	return { "errors": errors, "warnings": warnings }


static func validate_waveset(ws: WaveSet) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if ws == null:
		errors.append("Kein WaveSet.")
		return { "errors": errors, "warnings": warnings }
	if ws.id == "":
		errors.append("WaveSet hat keine id.")
	if ws.layout == null:
		errors.append("WaveSet hat kein Layout.")
	else:
		var lr := validate_layout(ws.layout)
		errors.append_array(lr["errors"])
		warnings.append_array(lr["warnings"])
	if ws.waves.is_empty():
		errors.append("Keine Wellen.")
	var n_paths := ws.layout.paths.size() if ws.layout != null else 0
	for wi in ws.waves.size():
		var w: WaveData = ws.waves[wi]
		if w == null or w.groups.is_empty():
			errors.append("Welle %d hat keine Gruppen." % (wi + 1))
			continue
		for gi in w.groups.size():
			var g: SpawnGroup = w.groups[gi]
			var where := "Welle %d, Gruppe %d" % [wi + 1, gi + 1]
			if g == null or g.unit == null:
				errors.append("%s: kein Gegnertyp." % where)
				continue
			if g.count < 1:
				errors.append("%s: Anzahl muss mindestens 1 sein." % where)
			if g.path_index < 0 or g.path_index >= n_paths:
				errors.append("%s: Pfad %d existiert nicht." % [where, g.path_index])
			if g.unit.faction_id == ws.faction_id:
				warnings.append("%s: %s gehört zur Spielerfraktion." % [where, g.unit.id])
	var target: Vector2i = WAVE_TARGETS.get(ws.act, Vector2i.ZERO)
	if target != Vector2i.ZERO and (ws.waves.size() < target.x or ws.waves.size() > target.y):
		warnings.append("%d Wellen – Richtwert für Akt %d sind %d–%d." % [ws.waves.size(), ws.act, target.x, target.y])
	if ws.start_resource < 8:
		warnings.append("Startguthaben %d ist knapp (günstigster Held kostet meist ≥ 9)." % ws.start_resource)
	if ws.lives < 1:
		errors.append("Leben müssen mindestens 1 sein.")
	return { "errors": errors, "warnings": warnings }


static func _in_bounds(l: MapLayout, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < l.size.x and c.y < l.size.y


static func _nearest_path_dist(path_cells: Dictionary, c: Vector2i) -> float:
	var best := INF
	for p in path_cells:
		best = minf(best, Vector2(p - c).length())
	return best
