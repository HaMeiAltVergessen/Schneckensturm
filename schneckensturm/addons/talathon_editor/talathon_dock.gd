@tool
# Bottom panel of the Talathon editor. Shows the map painter for a MapLayout or
# the wave editor for a WaveSet, plus validation, save and quick test.
extends VBoxContainer

const Painter := preload("res://addons/talathon_editor/map_painter.gd")
const Timeline := preload("res://addons/talathon_editor/wave_timeline.gd")
const QUICKTEST_CFG := "user://quicktest.cfg"
const MATCH_SCENE := "res://scenes/match/match.tscn"

var undo_redo: EditorUndoRedoManager
var _res: Resource
var _body: Control
var _status: RichTextLabel
var _title: Label
var _painter: Control
var _timeline: Control
var _before: Dictionary = {}
var _hover_label: Label


func _ready() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	_title = Label.new()
	_title.text = "Talathon Editor – MapLayout oder WaveSet im Dateisystem auswählen"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	for spec in [["Validieren", _validate], ["Speichern", _save], ["Schnelltest ▶", _quicktest]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		top.add_child(b)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_stretch_ratio = 2.5
	split.add_child(_body)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size = Vector2(320, 0)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_status)


func edit(obj: Object) -> void:
	_res = obj
	for ch in _body.get_children():
		ch.queue_free()
	_painter = null
	_timeline = null
	if obj is MapLayout:
		_title.text = "MapLayout: %s  (%s)" % [obj.id, obj.resource_path]
		_build_layout_ui(obj)
	elif obj is WaveSet:
		_title.text = "WaveSet: %s  (%s)" % [obj.id, obj.resource_path]
		_build_waveset_ui(obj)
	_validate()


# ---------------------------------------------------------------------------
# MapLayout
# ---------------------------------------------------------------------------
func _build_layout_ui(l: MapLayout) -> void:
	var tools := HBoxContainer.new()
	_body.add_child(tools)
	var group := ButtonGroup.new()
	var names := ["Pfad", "Pfad-Feld", "Rand-Feld", "Bau-Slot", "Blockiert", "Radierer"]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == 0
		var t := i
		b.pressed.connect(func(): _painter.tool = t)
		tools.add_child(b)
	tools.add_child(VSeparator.new())
	tools.add_child(_label("Pfad #"))
	var pidx := SpinBox.new()
	pidx.min_value = 0
	pidx.max_value = 7
	pidx.value_changed.connect(func(v):
		_painter.path_index = int(v)
		_painter.queue_redraw())
	tools.add_child(pidx)
	tools.add_child(VSeparator.new())
	tools.add_child(_label("Größe"))
	for axis in [0, 1]:
		var s := SpinBox.new()
		s.min_value = 4
		s.max_value = 40
		s.value = l.size[axis]
		var ax: int = axis
		s.value_changed.connect(func(v):
			var before := _snapshot(l)
			var sz := l.size
			sz[ax] = int(v)
			l.size = sz
			_commit(l, before, "Kartengröße"))
		tools.add_child(s)
	tools.add_child(_label("Helden-Limit"))
	var hl := SpinBox.new()
	hl.min_value = 1
	hl.max_value = 12
	hl.value = l.hero_limit
	hl.value_changed.connect(func(v):
		var before := _snapshot(l)
		l.hero_limit = int(v)
		_commit(l, before, "Helden-Limit"))
	tools.add_child(hl)
	_hover_label = _label("")
	tools.add_child(_hover_label)

	_painter = Painter.new()
	_painter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_painter.custom_minimum_size = Vector2(0, 220)
	_body.add_child(_painter)
	_painter.set_layout(l)
	_painter.stroke_started.connect(func(): _before = _snapshot(l))
	_painter.stroke_finished.connect(func(): _commit(l, _before, "Karte malen"))
	_painter.hovered.connect(func(c): _hover_label.text = "  Feld %s" % str(c))
	_body.add_child(_label("Linksklick malt · Rechtsklick radiert · Pfad: Nachbarfeld anklicken verlängert, letztes Feld erneut anklicken entfernt es"))


func _snapshot(l: MapLayout) -> Dictionary:
	var paths := []
	for p in l.paths:
		paths.append(p.cells.duplicate() if p != null else [])
	return { "size": l.size, "hero_limit": l.hero_limit, "paths": paths,
		"deploy_path_cells": l.deploy_path_cells.duplicate(), "deploy_edge_cells": l.deploy_edge_cells.duplicate(),
		"build_slots": l.build_slots.duplicate(), "blocked_cells": l.blocked_cells.duplicate() }


func _restore(l: MapLayout, s: Dictionary) -> void:
	l.size = s["size"]
	l.hero_limit = s["hero_limit"]
	var paths: Array[MapPath] = []
	for cells in s["paths"]:
		var p := MapPath.new()
		for c in cells:
			p.cells.append(c)
		paths.append(p)
	l.paths = paths
	for k in ["deploy_path_cells", "deploy_edge_cells", "build_slots", "blocked_cells"]:
		var arr: Array[Vector2i] = []
		for c in s[k]:
			arr.append(c)
		l.set(k, arr)
	l.emit_changed()
	if _painter != null and is_instance_valid(_painter):
		_painter.queue_redraw()
	_validate()


func _commit(l: MapLayout, before: Dictionary, name: String) -> void:
	var after := _snapshot(l)
	if undo_redo != null:
		undo_redo.create_action(name)
		undo_redo.add_do_method(self, "_restore", l, after)
		undo_redo.add_undo_method(self, "_restore", l, before)
		undo_redo.commit_action(false)
	l.emit_changed()
	if _painter != null:
		_painter.queue_redraw()
	_validate()


# ---------------------------------------------------------------------------
# WaveSet
# ---------------------------------------------------------------------------
func _build_waveset_ui(ws: WaveSet) -> void:
	var row := HBoxContainer.new()
	_body.add_child(row)
	row.add_child(_label("Akt"))
	var act := SpinBox.new()
	act.min_value = 1
	act.max_value = 3
	act.value = ws.act
	act.value_changed.connect(func(v):
		ws.act = int(v)
		_changed())
	row.add_child(act)
	var add := Button.new()
	add.text = "+ Welle"
	add.pressed.connect(func():
		var w := WaveData.new()
		w.groups.append(_new_group(ws))
		ws.waves.append(w)
		_changed(true))
	row.add_child(add)
	row.add_child(_label("   Wirtschaft, Belohnungen und Layout stehen im Inspector."))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(560, 200)
	split.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var units := _enemy_units(ws)
	for wi in ws.waves.size():
		list.add_child(_wave_box(ws, wi, units))
	_timeline = Timeline.new()
	_timeline.waveset = ws
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_timeline)


func _wave_box(ws: WaveSet, wi: int, units: Array) -> Control:
	var w: WaveData = ws.waves[wi]
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(_label("Welle %d" % (wi + 1)))
	head.add_child(_label("Pause danach (s)"))
	head.add_child(_spin(w.next_delay, 0, 120, 1, func(v): w.next_delay = v))
	var ann := LineEdit.new()
	ann.placeholder_text = "Ansage-Key (optional)"
	ann.text = w.announce_key
	ann.custom_minimum_size = Vector2(170, 0)
	ann.text_changed.connect(func(t):
		w.announce_key = t
		_changed())
	head.add_child(ann)
	var addg := Button.new()
	addg.text = "+ Gruppe"
	addg.pressed.connect(func():
		w.groups.append(_new_group(ws))
		_changed(true))
	head.add_child(addg)
	var del := Button.new()
	del.text = "Welle löschen"
	del.pressed.connect(func():
		ws.waves.remove_at(wi)
		_changed(true))
	head.add_child(del)
	for gi in w.groups.size():
		var g: SpawnGroup = w.groups[gi]
		var r := HBoxContainer.new()
		box.add_child(r)
		r.add_child(_label("   "))
		var opt := OptionButton.new()
		for i in units.size():
			opt.add_item(units[i].id)
			if units[i] == g.unit or (g.unit != null and units[i].resource_path == g.unit.resource_path):
				opt.selected = i
		opt.item_selected.connect(func(i):
			g.unit = units[i]
			_changed())
		r.add_child(opt)
		r.add_child(_label("Anzahl"))
		r.add_child(_spin(g.count, 1, 99, 1, func(v): g.count = int(v)))
		r.add_child(_label("Abstand"))
		r.add_child(_spin(g.interval, 0.1, 20, 0.1, func(v): g.interval = v))
		r.add_child(_label("Start"))
		r.add_child(_spin(g.delay, 0, 60, 0.5, func(v): g.delay = v))
		r.add_child(_label("Pfad"))
		r.add_child(_spin(g.path_index, 0, 7, 1, func(v): g.path_index = int(v)))
		var x := Button.new()
		x.text = "✕"
		x.pressed.connect(func():
			w.groups.remove_at(gi)
			_changed(true))
		r.add_child(x)
	box.add_child(HSeparator.new())
	return box


func _new_group(ws: WaveSet) -> SpawnGroup:
	var g := SpawnGroup.new()
	var units := _enemy_units(ws)
	g.unit = units[0] if not units.is_empty() else null
	return g


# Enemy units first (not of the player faction), then the rest.
func _enemy_units(ws: WaveSet) -> Array:
	var enemies := []
	var others := []
	for path in _list_tres("res://data/units"):
		var u = load(path)
		if u is UnitData:
			(others if u.faction_id == ws.faction_id else enemies).append(u)
	return enemies + others


func _list_tres(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	return out


func _changed(rebuild := false) -> void:
	_res.emit_changed()
	if rebuild:
		edit(_res)
		return
	if _timeline != null:
		_timeline.queue_redraw()
	_validate()


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
func _validate() -> void:
	if _res == null:
		_status.text = ""
		return
	var r: Dictionary = MapValidator.validate_layout(_res) if _res is MapLayout else MapValidator.validate_waveset(_res)
	var t := ""
	if r["errors"].is_empty() and r["warnings"].is_empty():
		t = "[color=#7c7]✔ Keine Probleme gefunden.[/color]"
	for e in r["errors"]:
		t += "[color=#f77]✖ %s[/color]\n" % e
	for w in r["warnings"]:
		t += "[color=#fc6]⚠ %s[/color]\n" % w
	_status.text = t


func _save() -> void:
	if _res == null or _res.resource_path == "" or _res.resource_path.contains("::"):
		push_warning("Talathon Editor: Ressource hat keinen eigenen Dateipfad – bitte über das Dateisystem speichern.")
		return
	var err := ResourceSaver.save(_res, _res.resource_path)
	_title.text = ("Gespeichert: " if err == OK else "Fehler beim Speichern: ") + _res.resource_path


func _quicktest() -> void:
	var ws: WaveSet = _res if _res is WaveSet else _waveset_for_layout(_res)
	if ws == null:
		push_warning("Talathon Editor: Kein WaveSet für dieses Layout gefunden.")
		return
	_save()
	var cfg := ConfigFile.new()
	cfg.set_value("quicktest", "waveset", ws.resource_path)
	cfg.save(QUICKTEST_CFG)
	EditorInterface.play_custom_scene(MATCH_SCENE)


func _waveset_for_layout(l: Resource) -> WaveSet:
	if not (l is MapLayout):
		return null
	for path in _list_tres("res://data/waves"):
		var ws = load(path)
		if ws is WaveSet and ws.layout != null and ws.layout.resource_path == l.resource_path:
			return ws
	return null


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _spin(value: float, lo: float, hi: float, step: float, setter: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(80, 0)
	s.value_changed.connect(func(v):
		setter.call(v)
		_changed())
	return s
