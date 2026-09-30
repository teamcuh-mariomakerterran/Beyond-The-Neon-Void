extends SceneTree
## Loads every script under res://src and res://tests so parse/compile errors
## surface in CI:  godot --headless --path . -s res://tests/compile_all.gd


func _initialize() -> void:
	var failures := 0
	var files := _collect("res://src") + _collect("res://scenes")
	for path in files:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			failures += 1
			printerr("FAILED: ", path)
		elif res is GDScript and not (res as GDScript).can_instantiate() and not (res as GDScript).is_abstract():
			failures += 1
			printerr("CANNOT INSTANTIATE: ", path)
	print("compile_all: %d files, %d failures" % [files.size(), failures])
	quit(1 if failures > 0 else 0)


func _collect(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_collect(dir.path_join(d)))
	return out
