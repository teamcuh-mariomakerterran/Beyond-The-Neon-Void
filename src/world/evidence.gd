class_name Evidence
extends RefCounted
## Evidence against the Doctrine's story (data/evidence.json). Finding a piece
## sets the story flag "evidence:<id>". NPCs react through their
## `evidence_talk` entries (NPCResource): once you hold enough (or the right
## pieces), a new conversation unlocks: new lines, maybe an item, a quest,
## a flag. A reason to walk back to early areas and the regulars' stools.
##   evidence_talk entry: {"needs": 2, "evidence": ["casualty_ledger"],
##     "lines": ["..."], "sets_flag": "", "give_item_id": "", "quest_id": ""}

const PREFIX := "evidence:"


static func info(id: String) -> Dictionary:
	var d: Variant = ContentDB.evidence.get(id)
	return d if d is Dictionary else {"title": id.replace("_", " ").capitalize(), "description": "", "source": ""}


static func has(id: String) -> bool:
	return GameManager.check_story_flag(PREFIX + id)


## Ids of every piece found, in data order.
static func found() -> Array[String]:
	var out: Array[String] = []
	for id: String in ContentDB.evidence:
		if not id.begins_with("_") and has(id):
			out.append(id)
	return out


static func count() -> int:
	return found().size()


## Finds a piece. Returns false if it was already in the file.
static func give(id: String) -> bool:
	if id == "" or has(id):
		return false
	GameManager.set_story_flag(PREFIX + id)
	EventBus.log_message.emit("Evidence: " + str(info(id)["title"]))
	return true


static func _heard_flag(npc: NPCResource, i: int) -> String:
	return "npc:%s:ev%d" % [npc.id, i]


static func entry_ready(e: Dictionary) -> bool:
	if count() < int(e.get("needs", 0)):
		return false
	for id: Variant in e.get("evidence", []):
		if not has(str(id)):
			return false
	return true


## Indexes of evidence talks this NPC has ready and you haven't heard.
static func ready_talks(npc: NPCResource) -> Array[int]:
	var out: Array[int] = []
	if npc == null:
		return out
	for i in npc.evidence_talk.size():
		if not GameManager.check_story_flag(_heard_flag(npc, i)) and entry_ready(npc.evidence_talk[i]):
			out.append(i)
	return out


## Plays every ready evidence talk (lines, then rewards). Returns how many.
static func play_ready(npc: NPCResource, host: Node = null) -> int:
	var idx := ready_talks(npc)
	if idx.is_empty():
		return 0
	var box := UIManager.get_dialogue_box()
	for i in idx:
		var e: Dictionary = npc.evidence_talk[i]
		for l: Variant in e.get("lines", []):
			box.say(npc.display_name, str(l))
		await box.finished
		reward(npc, i, host)
	return idx.size()


## Marks a talk heard and pays it out (separate so tests can call it).
static func reward(npc: NPCResource, i: int, host: Node = null) -> void:
	var e: Dictionary = npc.evidence_talk[i]
	GameManager.set_story_flag(_heard_flag(npc, i))
	if str(e.get("sets_flag", "")) != "":
		GameManager.set_story_flag(str(e["sets_flag"]))
	var item := str(e.get("give_item_id", ""))
	if item != "":
		GameManager.give_item(item)
		var it := ContentDB.get_item(item)
		_toast(host, "RECEIVED: " + (it.display_name if it else item))
	var q := str(e.get("quest_id", ""))
	if q != "" and QuestManager.accept(q) == "":
		var qr := ContentDB.get_quest(q)
		_toast(host, "NEW QUEST: " + (qr.display_name.to_upper() if qr else q))


static func _toast(host: Node, text: String) -> void:
	if host and host.has_method("ix_toast"):
		host.ix_toast(text, NeonTheme.AMBER)
	elif host and host.has_method("_toast"):
		host.call("_toast", text)
	else:
		EventBus.log_message.emit(text)
