extends RefCounted
## Template body: autoloads are available. Return 0 = pass.
var _fails := 0

func run(tree: SceneTree, args: PackedStringArray) -> int:
	check(ContentDB.validate().is_empty(), "ContentDB.validate() clean")
	check(ContentDB.get_mission("m01_the_brew_plan") != null, "m01 exists")
	await tree.process_frame
	print("%s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	return 0 if _fails == 0 else 1

func check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)
