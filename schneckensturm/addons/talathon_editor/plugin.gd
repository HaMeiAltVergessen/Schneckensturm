@tool
# Registers the "Talathon" bottom panel. Selecting a MapLayout or WaveSet in the
# FileSystem / Inspector opens it there (see docs/EDITOR.md).
extends EditorPlugin

const Dock := preload("res://addons/talathon_editor/talathon_dock.gd")

var _dock: Control
var _button: Button


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.undo_redo = get_undo_redo()
	_dock.custom_minimum_size = Vector2(0, 320)
	_button = add_control_to_bottom_panel(_dock, "Talathon")


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null


func _handles(object: Object) -> bool:
	return object is MapLayout or object is WaveSet


func _edit(object: Object) -> void:
	if _dock != null and object != null:
		_dock.edit(object)


func _make_visible(visible: bool) -> void:
	if visible and _dock != null:
		make_bottom_panel_item_visible(_dock)
