@tool
# Editor dialog: pick images, tune tolerance/feather/size with a live before/after
# preview, then write the keyed PNGs (next to the source as <name>_keyed.png or
# into a chosen output folder).
extends AcceptDialog

var _files: PackedStringArray = []
var _preview_src: Image
var _before: TextureRect
var _after: TextureRect
var _list: Label
var _out_dir: LineEdit
var _key: ColorPickerButton
var _auto_key: CheckBox
var _tol: SpinBox
var _feather: SpinBox
var _size: SpinBox
var _anchor: OptionButton
var _trim: CheckBox
var _shared: CheckBox
var _holes: CheckBox
var _picker: FileDialog
var _dir_picker: FileDialog


func _init() -> void:
	title = "Chroma Key – Hintergrund entfernen"
	ok_button_text = "Freistellen & speichern"
	min_size = Vector2i(900, 560)
	confirmed.connect(_run)

	var root := VBoxContainer.new()
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var pick := Button.new()
	pick.text = "Bilder wählen…"
	pick.pressed.connect(func(): _picker.popup_centered_ratio(0.7))
	top.add_child(pick)
	_list = Label.new()
	_list.text = "keine Bilder gewählt"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.clip_text = true
	top.add_child(_list)

	var opts := GridContainer.new()
	opts.columns = 6
	root.add_child(opts)
	_auto_key = _check(opts, "Keyfarbe automatisch", true)
	_key = ColorPickerButton.new()
	_key.color = Color.MAGENTA
	_key.custom_minimum_size = Vector2(60, 0)
	_key.color_changed.connect(func(_c): _refresh())
	opts.add_child(_label("Keyfarbe"))
	opts.add_child(_key)
	opts.add_child(Control.new())
	_tol = _spin(opts, "Toleranz", 0.0, 1.0, 0.01, ChromaKey.DEFAULT_TOLERANCE)
	_feather = _spin(opts, "Weiche Kante", 0.0, 0.5, 0.01, ChromaKey.DEFAULT_FEATHER)
	_size = _spin(opts, "Zielgröße px (0 = aus)", 0, 4096, 1, 512)
	opts.add_child(_label("Ausrichtung"))
	_anchor = OptionButton.new()
	_anchor.add_item("mittig", ChromaKey.Anchor.CENTER)
	_anchor.add_item("Fußpunkt unten", ChromaKey.Anchor.BOTTOM)
	_anchor.item_selected.connect(func(_i): _refresh())
	opts.add_child(_anchor)
	_trim = _check(opts, "Zuschneiden", true)
	_shared = _check(opts, "gleicher Ausschnitt für alle", false)
	_holes = _check(opts, "eingeschlossene Flächen auch", false)

	var out_row := HBoxContainer.new()
	root.add_child(out_row)
	out_row.add_child(_label("Ausgabe-Ordner (leer = neben Quelle, *_keyed.png):"))
	_out_dir = LineEdit.new()
	_out_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out_row.add_child(_out_dir)
	var dir_btn := Button.new()
	dir_btn.text = "…"
	dir_btn.pressed.connect(func(): _dir_picker.popup_centered_ratio(0.6))
	out_row.add_child(dir_btn)

	var previews := HBoxContainer.new()
	previews.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(previews)
	_before = _preview(previews)
	_after = _preview(previews)

	_picker = FileDialog.new()
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Bilder"])
	_picker.files_selected.connect(_on_files)
	add_child(_picker)
	_dir_picker = FileDialog.new()
	_dir_picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dir_picker.access = FileDialog.ACCESS_FILESYSTEM
	_dir_picker.dir_selected.connect(func(d): _out_dir.text = d)
	add_child(_dir_picker)


func _on_files(paths: PackedStringArray) -> void:
	_files = paths
	_list.text = "%d Bild(er): %s" % [paths.size(), ", ".join(Array(paths).map(func(p): return p.get_file()))]
	_preview_src = Image.load_from_file(paths[0]) if paths.size() > 0 else null
	if _preview_src != null and maxi(_preview_src.get_width(), _preview_src.get_height()) > 384:
		# keying runs in GDScript – preview on a smaller copy so the sliders stay responsive
		var s := 384.0 / maxi(_preview_src.get_width(), _preview_src.get_height())
		_preview_src.resize(int(_preview_src.get_width() * s), int(_preview_src.get_height() * s), Image.INTERPOLATE_BILINEAR)
	_refresh()


func _refresh() -> void:
	if _preview_src == null:
		return
	_before.texture = ImageTexture.create_from_image(_preview_src)
	_after.texture = ImageTexture.create_from_image(_keyed_preview(_preview_src))


func _keyed_preview(img: Image) -> Image:
	var key_col := Color(0, 0, 0, 0) if _auto_key.button_pressed else _key.color
	var out := ChromaKey.key(img, key_col, _tol.value, _feather.value, true, _holes.button_pressed)
	if _trim.button_pressed:
		out = ChromaKey.trim(out, 8)
	if _size.value > 0:
		out = ChromaKey.fit(out, Vector2i(int(_size.value), int(_size.value)), _anchor.get_selected_id())
	return out


func _run() -> void:
	var key_col := Color(0, 0, 0, 0) if _auto_key.button_pressed else _key.color
	var keyed: Array[Image] = []
	for p in _files:
		keyed.append(ChromaKey.key(Image.load_from_file(p), key_col, _tol.value, _feather.value, true, _holes.button_pressed))
	var shared := ChromaKey.union_rect(keyed) if _shared.button_pressed else Rect2i()
	for i in _files.size():
		var out := keyed[i]
		if _trim.button_pressed:
			out = ChromaKey.trim(out, 8)
		if _size.value > 0:
			out = ChromaKey.fit(out, Vector2i(int(_size.value), int(_size.value)), _anchor.get_selected_id())
		var src := _files[i]
		var dir := _out_dir.text.strip_edges()
		var dest := src.get_basename() + "_keyed.png" if dir == "" else ProjectSettings.globalize_path(dir).path_join(src.get_file().get_basename() + ".png")
		out.save_png(dest)
		print("Chroma Key: ", dest)
	EditorInterface.get_resource_filesystem().scan()


func _preview(parent: Control) -> TextureRect:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.35, 0.38)   # neutral grey shows leftover fringes
	panel.add_theme_stylebox_override("panel", sb)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(400, 360)
	panel.add_child(t)
	parent.add_child(panel)
	return t


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _spin(parent: Control, text: String, lo: float, hi: float, step: float, value: float) -> SpinBox:
	parent.add_child(_label(text))
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.value_changed.connect(func(_v): _refresh())
	parent.add_child(s)
	return s


func _check(parent: Control, text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(func(_b): _refresh())
	parent.add_child(c)
	return c
