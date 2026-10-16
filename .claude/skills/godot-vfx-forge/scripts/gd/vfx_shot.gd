extends SceneTree
## Render ONE VFX effect frozen at several moments to a PNG strip, on a dark iso floor with
## caster/target dummies. For iterating on a look without booting a battle.
##   godot --path <repo> --rendering-method gl_compatibility -s <abs>/vfx_shot.gd -- --effect=plasma_explosion
##     [--def=C:/temp/my_fx.json]   candidate effect def (or {"effects":{id:def}}), injected in memory only
##     [--times=0.05,0.12,0.25,0.5] [--to=120,-36] [--targets=-20,-26;56,26] [--color=#ff2e88*1.6]
##     [--scale=1.2] [--seed=7] [--ability=<ability id>]  (--ability resolves the effect via
##     VFX.plan_for_ability like a battle: travel+impact shown side by side)  --out=C:/temp/fx.png
## Needs a display (xvfb-run -a on Linux). vfx.json on disk is never modified.
func _initialize() -> void:
	await process_frame
	var body: GDScript = load(get_script().resource_path.get_base_dir().path_join("vfx_shot_body.gd"))
	if body == null or not body.can_instantiate():
		printerr("vfx_shot: body does not compile")
		quit(2)
		return
	quit(await body.new().run(self, OS.get_cmdline_user_args()))
