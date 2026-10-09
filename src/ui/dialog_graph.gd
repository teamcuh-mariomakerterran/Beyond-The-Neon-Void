class_name DialogGraph
extends RefCounted
## Pure walk over an NPCResource dialog graph — no UI, so it's testable
## headlessly. DialogueBox drives one of these.
##
## Node: {"id", "text", "speaker"?, "voice_path"?, "requires_flag"?, "sets_flag"?,
##        "next"?, "choices"?: [{"text", "next", "correct"?, "sets_flag"?}]}
## - A node whose requires_flag isn't set is skipped by following its "next".
##   "requires_evidence": N skips it until N pieces of evidence are found.
## - Entering a node sets its sets_flag.
## - A choice with a "correct" key feeds GameManager.record_hub_visit(correct),
##   which drives the Drunken Oracle's five-in-a-row secret unlock.
## - An empty / missing "next" ends the conversation.

const MAX_SKIPS := 64

var nodes: Array[Dictionary] = []
## The node on screen, or {} once the conversation is over.
var current: Dictionary = {}
## Ids entered this conversation, in order (handy for tests / analytics).
var visited: Array[String] = []


func _init(p_nodes: Array[Dictionary] = []) -> void:
	nodes = p_nodes


func find(node_id: String) -> Dictionary:
	for n: Dictionary in nodes:
		if str(n.get("id", "")) == node_id:
			return n
	return {}


## Starts at start_id (or the first node). Returns the first shown node.
func start(start_id: String = "") -> Dictionary:
	visited.clear()
	if start_id == "" and not nodes.is_empty():
		start_id = str(nodes[0].get("id", ""))
	return _goto(start_id)


func is_finished() -> bool:
	return current.is_empty()


func has_choices() -> bool:
	return not current.get("choices", []).is_empty()


func get_choices() -> Array:
	return current.get("choices", [])


## Moves past a node without choices.
func advance() -> Dictionary:
	if current.is_empty() or has_choices():
		return current
	return _goto(str(current.get("next", "")))


## Picks a choice on the current node.
func choose(index: int) -> Dictionary:
	var choices := get_choices()
	if index < 0 or index >= choices.size():
		return current
	var ch: Dictionary = choices[index]
	var flag := str(ch.get("sets_flag", ""))
	if flag != "":
		GameManager.set_story_flag(flag)
	if ch.has("correct"):
		GameManager.record_hub_visit(bool(ch["correct"]))
	return _goto(str(ch.get("next", "")))


func _goto(node_id: String) -> Dictionary:
	current = {}
	for _i in MAX_SKIPS:
		if node_id == "":
			return current
		var n := find(node_id)
		if n.is_empty():
			return current
		var req := str(n.get("requires_flag", ""))
		var ev := int(n.get("requires_evidence", 0))
		if (req != "" and not GameManager.check_story_flag(req)) or (ev > 0 and Evidence.count() < ev):
			node_id = str(n.get("next", ""))
			continue
		current = n
		visited.append(node_id)
		var flag := str(n.get("sets_flag", ""))
		if flag != "":
			GameManager.set_story_flag(flag)
		return current
	push_warning("DialogGraph: gave up after %d skipped nodes" % MAX_SKIPS)
	return current
