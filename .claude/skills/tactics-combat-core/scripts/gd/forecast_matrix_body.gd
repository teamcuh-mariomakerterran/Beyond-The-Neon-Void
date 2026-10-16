extends RefCounted

func run(tree: SceneTree, args: PackedStringArray) -> int:
	var o := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			o[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var level := int(o.get("level", "6"))
	var classes: Array = str(o["classes"]).split(",", false) if o.has("classes") else Array(ClassLibrary.CLASS_ORDER)
	var defenders: Array = []
	if o.has("defenders"):
		defenders = str(o["defenders"]).split(",", false)
	else:
		for m: MissionResource in ContentDB.get_all("missions"):
			for e: Dictionary in m.enemies:
				var key := "%s@%d" % [e["character_id"], int(e.get("level", 1))]
				if not defenders.has(key):
					defenders.append(key)
	var mode := str(o.get("abilities", "innate"))
	var angle := str(o.get("angle", "front"))
	GameManager.new_game()
	var template: CharacterData = GameManager.get_character("rook")
	var rows: PackedStringArray = ["attacker_class,level,ability,defender,def_level,hit,damage,crit,hits_to_kill,expected_damage"]
	for cid: String in classes:
		if ClassLibrary.get_class_res(cid) == null:
			printerr("unknown class ", cid)
			continue
		var ch: CharacterData = template.duplicate(true)
		ch.class_id = cid
		ch.secondary_class_id = ""
		var att := Unit.new()
		att.setup(ch, Unit.Team.PLAYER, level)
		att.cell = Vector2i(0, 0)
		var abilities: Array[Ability] = []
		for ab in att.job_handler.get_ability_list():
			if ab == null or not (ab.kind in [Ability.Kind.ATTACK, Ability.Kind.MAGIC]):
				continue
			if mode == "basic" and ab.id != "basic_attack":
				continue
			abilities.append(ab)
		if mode == "all":
			for aid in att.class_res().learnable_ability_ids:
				var la := ContentDB.get_ability(aid)
				if la and la.kind in [Ability.Kind.ATTACK, Ability.Kind.MAGIC] and not abilities.has(la):
					abilities.append(la)
		for dkey: String in defenders:
			var parts := dkey.split("@")
			var dd := ContentDB.get_character(parts[0])
			if dd == null:
				printerr("unknown defender ", parts[0])
				continue
			var dlv := int(parts[1]) if parts.size() > 1 else level
			var dfn := Unit.new()
			dfn.setup(dd, Unit.Team.ENEMY, dlv)
			dfn.cell = Vector2i(1, 0)
			dfn.facing = {"front": Vector2i(-1, 0), "back": Vector2i(1, 0), "side": Vector2i(0, 1)}.get(angle, Vector2i(-1, 0))
			for ab in abilities:
				var f := DamageCalculator.forecast(att, dfn, ab, null)
				var dmg := int(f["damage"])
				var htk := ceili(float(dfn.current_hp) / maxf(dmg, 1)) if dmg > 0 else -1
				var exp_dmg := float(f["hit"]) * dmg * (1.0 + float(f["crit"]) * (DamageCalculator.CRIT_MULT - 1.0))
				rows.append("%s,%d,%s,%s,%d,%.2f,%d,%.2f,%d,%.1f" % [cid, level, ab.id, parts[0], dlv, f["hit"], dmg, f["crit"], htk, exp_dmg])
			dfn.free()
		att.free()
	var csv := "\n".join(rows)
	if o.has("out"):
		var fa := FileAccess.open(str(o["out"]), FileAccess.WRITE)
		fa.store_string(csv + "\n")
		print("forecast_matrix: %d rows -> %s" % [rows.size() - 1, o["out"]])
	else:
		print(csv)
	await tree.process_frame
	return 0
