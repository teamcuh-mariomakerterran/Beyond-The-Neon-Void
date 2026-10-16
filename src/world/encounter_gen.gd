class_name EncounterGen
extends RefCounted
## Rolled encounters for explore regions: a random battle map, a random
## formation from the region's enemy pool on that map's enemy spawns, levels
## from the region's range (optionally following the party, clamped), and
## rewards that scale with it. The result is a MissionResource injected for
## this session only (never written to data/). Same seed, same fight: a threat
## keeps its formation until it respawns.
##
## Region "encounter" → "generate":
##   name         shown on the briefing ("Doctrine Patrol")
##   maps         battle map ids to pick from
##   pool         enemy ids, or [{id, weight}] (weight default 1)
##   count        [min, max] enemies (clamped to the map's enemy spawns)
##   level        [min, max] for this zone
##   scale        true: follow the party's average level, clamped to `level`
##   fixed_level  > 0: every enemy at exactly this level (late game, secrets)
##   boss         optional enemy id always added (first spawn)
##   coins_per_level, xp_per_level, chips   rewards (per enemy level, summed)

const DEFAULT_COINS := 12
const DEFAULT_XP := 9


static func has_generator(region: Dictionary) -> bool:
	var g: Variant = (region.get("encounter", {}) as Dictionary).get("generate")
	return g is Dictionary and not (g.get("maps", []) as Array).is_empty() and not (g.get("pool", []) as Array).is_empty()


## The party's average level (1 with nobody in it).
static func party_level() -> int:
	var members := GameManager.get_party_members()
	if members.is_empty():
		return 1
	var total := 0
	for c: CharacterData in members:
		total += c.get_stats().level
	return maxi(roundi(float(total) / members.size()), 1)


## The level an enemy rolls in this zone.
static func roll_level(g: Dictionary, rng: RandomNumberGenerator, party: int) -> int:
	if int(g.get("fixed_level", 0)) > 0:
		return int(g["fixed_level"])
	var lv: Array = g.get("level", [1, 3])
	var lo := int(lv[0])
	var hi := int(lv[1]) if lv.size() > 1 else lo
	if bool(g.get("scale", false)):
		# Around the party (−1 … +1), never outside the zone's range.
		return clampi(party + rng.randi_range(-1, 1), lo, hi)
	return rng.randi_range(lo, hi)


static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for p: Variant in pool:
		total += float(p.get("weight", 1.0)) if p is Dictionary else 1.0
	var roll := rng.randf() * total
	for p2: Variant in pool:
		var w := float(p2.get("weight", 1.0)) if p2 is Dictionary else 1.0
		roll -= w
		if roll <= 0.0:
			return str(p2.get("id", "")) if p2 is Dictionary else str(p2)
	var last: Variant = pool[pool.size() - 1]
	return str(last.get("id", "")) if last is Dictionary else str(last)


## Builds the mission entry (a Dictionary like data/missions.json) for one roll.
static func make_entry(id: String, g: Dictionary, seed_value: int, party: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if party < 0:
		party = party_level()
	var maps: Array = g["maps"]
	var map_id := str(maps[rng.randi() % maps.size()])
	var spawns: Array = (ContentDB.get_map(map_id).get("spawns", {}) as Dictionary).get("enemy", []).duplicate()
	# Shuffle the spawn order with the same stream (Fisher-Yates).
	for i in range(spawns.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = spawns[i]
		spawns[i] = spawns[j]
		spawns[j] = tmp
	var cnt: Array = g.get("count", [2, 3])
	var n := rng.randi_range(int(cnt[0]), int(cnt[1]) if cnt.size() > 1 else int(cnt[0]))
	var enemies: Array = []
	var levels := 0
	var boss := str(g.get("boss", ""))
	if boss != "" and not spawns.is_empty():
		var bl := roll_level(g, rng, party) + 1
		enemies.append({"character_id": boss, "cell": spawns.pop_front(), "level": bl})
		levels += bl
	while enemies.size() < n and not spawns.is_empty():
		var lv := roll_level(g, rng, party)
		enemies.append({"character_id": _pick(g["pool"], rng), "cell": spawns.pop_front(), "level": lv})
		levels += lv
	var avg := roundi(float(levels) / maxf(enemies.size(), 1))
	var nm := str(g.get("name", "Hostiles"))
	return {"id": id, "display_name": nm, "chapter": 1, "map_id": map_id, "music_id": "",
		"briefing": "%s: %d hostile%s, around level %d. They've seen you." % [nm, enemies.size(), "" if enemies.size() == 1 else "s", avg],
		"max_party_size": 5, "enemies": enemies, "win_condition": "defeat_all",
		"soul_coin_reward": int(g.get("coins_per_level", DEFAULT_COINS)) * levels,
		"xp_reward": int(g.get("xp_per_level", DEFAULT_XP)) * levels,
		"microchip_reward": int(g.get("chips", 0)), "loot_table_id": str(g.get("loot_table_id", "")), "story_flags_on_win": []}


## Rolls and registers the fight for a region's threat; returns its mission id.
static func build(map_id: String, region: Dictionary, index: int, seed_value: int) -> String:
	var id := "gen_%s_%s_%d" % [map_id, str(region.get("id", "")), index]
	ContentDB.inject("missions", make_entry(id, region["encounter"]["generate"], seed_value), false)
	return id
