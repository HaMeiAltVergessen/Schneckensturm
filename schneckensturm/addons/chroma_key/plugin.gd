@tool
# Adds "Project → Tools → Chroma Key…" (background removal for sprites on a flat key colour).
extends EditorPlugin

const KeyDialog := preload("res://addons/chroma_key/key_dialog.gd")
const MENU := "Chroma Key (Freistellen)…"

var _dialog: Window


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _open)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func _open() -> void:
	if _dialog == null:
		_dialog = KeyDialog.new()
		EditorInterface.get_base_control().add_child(_dialog)
	_dialog.popup_centered(Vector2i(980, 640))
