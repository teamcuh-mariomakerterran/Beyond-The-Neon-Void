extends RefCounted
## Body of scan_tiles.gd (loaded at runtime so it may use autoloads/class names).


func run(args: PackedStringArray) -> void:
	var root: String = args[0] if args.size() > 0 else TileIndex.ROOT
	var index := TileIndex.scan(root)
	var animated := 0
	for e: Dictionary in index.values():
		if e.get("frames", []).size() > 1:
			animated += 1
	var path := TileIndex.save(index)
	print("tiles: %d entries (%d animated) -> %s" % [index.size(), animated, path])
