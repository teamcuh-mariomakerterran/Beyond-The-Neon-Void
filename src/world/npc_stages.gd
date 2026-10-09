class_name NpcStages
extends RefCounted
## Runs an NPC's interaction stages (fields under "Interaction stages" on
## NPCResource). An interaction anchor of kind "npc" — or talking to the NPC
## on an explore map — calls run(). Progress lives in story flags:
##   npc:<id>:met    first talk done        npc:<id>:gift   item handed over
##   npc:<id>:fetch  {item: delivered}      npc:<id>:fetched  fetch finished
##   npc:<id>:repeat index of the next repeat line

static func flag(npc: NPCResource, what: String) -> String:
	return "npc:%s:%s" % [npc.id, what]


static func has_stages(npc: NPCResource) -> bool:
	return not npc.intro_lines.is_empty() or not npc.repeat_lines.is_empty() or npc.give_item_id != "" \
		or npc.after_talk != "none" or not npc.closing_lines.is_empty() or not npc.evidence_talk.is_empty()


## Plays the whole visit. `host` is the scene (for cutscenes / toasts).
static func run(npc: NPCResource, host: Node) -> void:
	var box := UIManager.get_dialogue_box()
	if not has_stages(npc):
		box.play_npc(npc)
		await box.finished
		return
	var first := not GameManager.check_story_flag(flag(npc, "met"))
	if first:
		if npc.intro_lines.is_empty() and not npc.dialog.is_empty():
			box.play_npc(npc)
			await box.finished
		else:
			await _say(box, npc, npc.intro_lines)
		GameManager.set_story_flag(flag(npc, "met"))
		if npc.give_item_id != "" and not GameManager.check_story_flag(flag(npc, "gift")):
			GameManager.give_item(npc.give_item_id, maxi(npc.give_item_qty, 1))
			GameManager.set_story_flag(flag(npc, "gift"))
			var it := ContentDB.get_item(npc.give_item_id)
			_toast(host, "RECEIVED: %s%s" % [it.display_name if it else npc.give_item_id, ("  ×%d" % npc.give_item_qty) if npc.give_item_qty > 1 else ""])
	# Evidence you've found cracks the propaganda: new talk first.
	var ev_heard: int = await Evidence.play_ready(npc, host)
	var lines: Array[String] = []
	var after := ""  # battle / cutscene start after the closing lines
	match npc.after_talk:
		"shop":
			if npc.vendor_id != "" and ContentDB.vendors.has(npc.vendor_id):
				await ShopPopup.open(host, npc.vendor_id)
		"quest":
			lines = quest_step(npc.offer_quest_id, host)
		"chain":
			if chain_ready(npc):
				lines = quest_step(npc.chain_quest_id, host)
			else:
				lines = npc.chain_locked_lines.duplicate()
				if lines.is_empty():
					lines = ["Not yet. Come back when you've got what I need: %s." % ", ".join(chain_missing(npc))]
		"fetch":
			var r := fetch_turn_in(npc)
			lines = r["lines"]
			for t: String in r["toasts"]:
				_toast(host, t)
		"battle":
			if npc.fight_mission_id != "" and ContentDB.get_mission(npc.fight_mission_id):
				after = "battle"
		"cutscene":
			if npc.stage_cutscene != "":
				after = "cutscene"
	# Nothing new to say? The repeat lines (cycled) fill the visit.
	if not first and ev_heard == 0 and lines.is_empty() and after == "" and npc.after_talk in ["none", "quest", "chain", "fetch"] and not npc.repeat_lines.is_empty():
		var i := int(GameManager.story_flags.get(flag(npc, "repeat"), 0))
		lines = [npc.repeat_lines[i % npc.repeat_lines.size()]]
		GameManager.story_flags[flag(npc, "repeat")] = i + 1
	await _say(box, npc, lines)
	await _say(box, npc, npc.closing_lines)
	match after:
		"battle":
			CampaignManager.start_mission(npc.fight_mission_id)
		"cutscene":
			if FileAccess.file_exists(npc.stage_cutscene):
				var player := CutscenePlayer.play(host.get_tree().root, npc.stage_cutscene, {"NPC": npc.display_name})
				if player:
					await player.finished


static func _say(box: DialogueBox, npc: NPCResource, lines: Array) -> void:
	if lines.is_empty():
		return
	for l: Variant in lines:
		box.say(npc.display_name, str(l))
	await box.finished


static func _toast(host: Node, text: String) -> void:
	if host and host.has_method("ix_toast"):
		host.ix_toast(text, NeonTheme.AMBER)
	else:
		EventBus.log_message.emit(text)


# --- Quests & chains -------------------------------------------------------------

## Offer / remind / turn in. Returns what the NPC says ([] = nothing new).
static func quest_step(quest_id: String, host: Node = null) -> Array[String]:
	var out: Array[String] = []
	var q := ContentDB.get_quest(quest_id)
	if q == null:
		return out
	match QuestManager.get_state(quest_id):
		QuestManager.COMPLETE:
			return out
		QuestManager.ACTIVE:
			if QuestManager.try_complete(quest_id):
				_toast(host, "QUEST COMPLETE: " + q.display_name.to_upper())
				out.append("That's everything. Here — you earned it.")
			else:
				out.append("Still waiting on that job: %s." % q.display_name)
		_:
			var why := QuestManager.accept(quest_id)
			if why == "":
				_toast(host, "NEW QUEST: " + q.display_name.to_upper())
				out.append(q.description if q.description != "" else "I've got work for you: %s." % q.display_name)
			else:
				out.append(why)
	return out


static func chain_ready(npc: NPCResource) -> bool:
	return chain_missing(npc).is_empty()


## Requirements not met yet, in readable form.
static func chain_missing(npc: NPCResource) -> Array[String]:
	var out: Array[String] = []
	for req: String in npc.chain_requires:
		var bits := req.split(":")
		match bits[0]:
			"quest":
				if QuestManager.get_state(bits[1]) != QuestManager.COMPLETE:
					var q := ContentDB.get_quest(bits[1])
					out.append(q.display_name if q else bits[1])
			"mission":
				if not CampaignManager.is_completed(bits[1]):
					var m := ContentDB.get_mission(bits[1])
					out.append(m.display_name if m else bits[1])
			"item":
				var need := int(bits[2]) if bits.size() > 2 else 1
				if GameManager.get_stack_count(bits[1]) < need:
					var it := ContentDB.get_item(bits[1])
					out.append("%s ×%d" % [it.display_name if it else bits[1], need])
			_:
				if not GameManager.check_story_flag(req):
					out.append(req.replace("_", " "))
	return out


# --- Fetch quests ----------------------------------------------------------------

## Hands over whatever the player carries toward the fetch list and pays out.
## Returns {lines, toasts, delivered: {item: n}, done}.
static func fetch_turn_in(npc: NPCResource) -> Dictionary:
	var res := {"lines": [] as Array[String], "toasts": [] as Array[String], "delivered": {}, "done": false}
	if npc.fetch_items.is_empty():
		return res
	if GameManager.check_story_flag(flag(npc, "fetched")):
		res["done"] = true
		return res
	var got: Dictionary = GameManager.story_flags.get(flag(npc, "fetch"), {})
	got = got.duplicate()
	var any := false
	for item: String in npc.fetch_items:
		var want := int(npc.fetch_items[item]) - int(got.get(item, 0))
		var have := GameManager.get_stack_count(item)
		var give := mini(want, have)
		if give > 0:
			GameManager.remove_stack_item(item, give)
			got[item] = int(got.get(item, 0)) + give
			res["delivered"][item] = give
			any = true
	GameManager.story_flags[flag(npc, "fetch")] = got
	var left := fetch_left(npc)
	if any:
		_pay(npc.fetch_reward_coins_each, 0, npc.fetch_reward_items_each, res["toasts"])
	if left.is_empty():
		GameManager.set_story_flag(flag(npc, "fetched"))
		_pay(npc.fetch_reward_coins_done, npc.fetch_reward_chips_done, npc.fetch_reward_items_done, res["toasts"])
		res["done"] = true
		res["lines"].append("That's all of it. Pleasure doing business.")
	elif any:
		res["lines"].append("Good. Still need: %s." % ", ".join(left))
	else:
		res["lines"].append("Bring me %s." % ", ".join(left))
	return res


## Still wanted, e.g. ["Scrap Plate ×2"].
static func fetch_left(npc: NPCResource) -> Array[String]:
	var out: Array[String] = []
	var got: Dictionary = GameManager.story_flags.get(flag(npc, "fetch"), {})
	for item: String in npc.fetch_items:
		var n := int(npc.fetch_items[item]) - int(got.get(item, 0))
		if n > 0:
			var it := ContentDB.get_item(item)
			out.append("%s ×%d" % [it.display_name if it else item, n])
	return out


static func _pay(coins: int, chips: int, items: Dictionary, toasts: Array) -> void:
	if coins > 0:
		GameManager.add_soul_coins(coins)
		toasts.append("+%d SOUL COINS" % coins)
	if chips > 0:
		GameManager.add_microchips(chips)
		toasts.append("+%d MICROCHIPS" % chips)
	for id: String in items:
		GameManager.give_item(id, int(items[id]))
		var it := ContentDB.get_item(id)
		toasts.append("RECEIVED: %s ×%d" % [it.display_name if it else id, int(items[id])])
