extends SceneTree
## Balance sheet from the REAL DamageCalculator (no re-implemented formulas to drift).
##   godot --headless --path <repo> -s <abs>/forecast_matrix.gd -- [options]
##     --level=6                      attacker level (party template "rook" re-classed)
##     --classes=chrome_warrior,...   attacker classes (default: ClassLibrary.CLASS_ORDER)
##     --defenders=doctrine_warden,…  defender character ids (default: every mission enemy)
##     --abilities=innate|basic|all   which attacker abilities (default innate = basic + class innates)
##     --angle=front|side|back        defender facing relative to attacker (default front)
##     --out=C:/temp/forecast.csv     CSV path (default: print to stdout)
## Flat ground, no cover, adjacent (range ignored). Columns: hit, dmg, crit, hits_to_kill, expected_dmg.
func _initialize() -> void:
	await process_frame
	var body: GDScript = load(get_script().resource_path.get_base_dir().path_join("forecast_matrix_body.gd"))
	if body == null or not body.can_instantiate():
		printerr("forecast_matrix: body does not compile")
		quit(2)
		return
	quit(await body.new().run(self, OS.get_cmdline_user_args()))
