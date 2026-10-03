# Base for headless test scenes: autoloads are present, failures are counted,
# the process exits with the failure count. Subclasses implement _run() and
# set `tag` (printed as "<tag>_OK" / "<tag>_FAILED").
class_name TestSuite
extends Node

var tag := "TEST"
var failures := 0


func _ready() -> void:
	# Never touch a real savegame from tests.
	SaveManager.save_path = "user://test_savegame.json"
	await get_tree().process_frame
	await _run()
	SaveManager.delete_save()
	if failures == 0:
		print("%s_OK" % tag)
	else:
		printerr("%s_FAILED: %d" % [tag, failures])
	get_tree().quit(failures)


func _run() -> void:
	pass


func expect(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("  CHECK FAILED: ", msg)


func expect_eq(a, b, msg: String) -> void:
	if a != b:
		failures += 1
		printerr("  CHECK FAILED: %s (got %s, expected %s)" % [msg, str(a), str(b)])
