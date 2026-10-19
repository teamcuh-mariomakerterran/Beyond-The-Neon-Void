class_name DialogTools
extends RefCounted
## Helpers behind Neon Forge ▸ DIALOG (and the voice lookup DialogueBox uses).
## Pure functions over an NPC's dialog array (see DialogGraph for the node
## format), so the editor logic is testable headlessly.
##
## Voice naming: a node with no voice_path plays
##   res://assets/voice/dialog/<npc_id>_<node_id>.ogg   (.wav / .mp3 also work)
## so exported recordings named that way are picked up with no wiring.
## The editor keeps each node's graph position in "pos": [x, y]; the game ignores it.

const VOICE_DIR := "res://assets/voice/dialog"


static func voice_path(npc_id: String, node_id: String) -> String:
	return VOICE_DIR.path_join("%s_%s.ogg" % [npc_id, node_id])


## The voice file a node plays, or "" if there's no recording yet.
static func voice_for(npc_id: String, node: Dictionary) -> String:
	var own := str(node.get("voice_path", ""))
	if own != "":
		return Barks.voice_file(own)
	return Barks.voice_file(voice_path(npc_id, str(node.get("id", ""))))


static func ids(nodes: Array) -> Array[String]:
	var out: Array[String] = []
	for n: Dictionary in nodes:
		out.append(str(n.get("id", "")))
	return out


## A fresh id ("line", "line_2", …) not used by any node.
static func new_id(nodes: Array, base: String = "line") -> String:
	var used := ids(nodes)
	if not base in used:
		return base
	var i := 2
	while "%s_%d" % [base, i] in used:
		i += 1
	return "%s_%d" % [base, i]


## Renames a node and every next / choice that points at it. False if taken.
static func rename(nodes: Array, old_id: String, new_name: String) -> bool:
	if new_name == "" or new_name == old_id or new_name in ids(nodes):
		return false
	for n: Dictionary in nodes:
		if str(n.get("id", "")) == old_id:
			n["id"] = new_name
		if str(n.get("next", "")) == old_id:
			n["next"] = new_name
		for ch: Dictionary in n.get("choices", []):
			if str(ch.get("next", "")) == old_id:
				ch["next"] = new_name
	return true


## Removes a node; links that pointed at it end the conversation instead.
static func remove(nodes: Array, node_id: String) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if str((nodes[i] as Dictionary).get("id", "")) == node_id:
			nodes.remove_at(i)
	for n: Dictionary in nodes:
		if str(n.get("next", "")) == node_id:
			n.erase("next")
		for ch: Dictionary in n.get("choices", []):
			if str(ch.get("next", "")) == node_id:
				ch.erase("next")


## Node ids reachable from the start (the first node). Gated nodes count as
## reachable through their "next" too, since the walk skips past them.
static func reachable(nodes: Array) -> Dictionary:
	var seen := {}
	if nodes.is_empty():
		return seen
	var todo: Array[String] = [str((nodes[0] as Dictionary).get("id", ""))]
	var by_id := {}
	for n: Dictionary in nodes:
		by_id[str(n.get("id", ""))] = n
	while not todo.is_empty():
		var id: String = todo.pop_back()
		if seen.has(id) or not by_id.has(id):
			continue
		seen[id] = true
		var n: Dictionary = by_id[id]
		if str(n.get("next", "")) != "":
			todo.append(str(n["next"]))
		for ch: Dictionary in n.get("choices", []):
			if str(ch.get("next", "")) != "":
				todo.append(str(ch["next"]))
	return seen


## Everything worth fixing before shipping a conversation.
static func problems(nodes: Array) -> Array[String]:
	var out: Array[String] = []
	var all := ids(nodes)
	var counted := {}
	for id in all:
		if id == "":
			out.append("a node has no id")
		elif counted.has(id):
			out.append("two nodes are called '%s'" % id)
		counted[id] = true
	for n: Dictionary in nodes:
		var id := str(n.get("id", ""))
		if str(n.get("text", "")).strip_edges() == "":
			out.append("'%s' has no text" % id)
		var nxt := str(n.get("next", ""))
		if nxt != "" and not nxt in all:
			out.append("'%s' goes to missing '%s'" % [id, nxt])
		for ch: Dictionary in n.get("choices", []):
			var cn := str(ch.get("next", ""))
			if cn != "" and not cn in all:
				out.append("a choice on '%s' goes to missing '%s'" % [id, cn])
			if str(ch.get("text", "")).strip_edges() == "":
				out.append("a choice on '%s' has no text" % id)
	var reach := reachable(nodes)
	for id in all:
		if id != "" and not reach.has(id):
			out.append("'%s' can't be reached from the start" % id)
	return out


## Lays nodes out left to right by depth from the start (sets "pos").
static func auto_layout(nodes: Array, gap: Vector2 = Vector2(420, 260)) -> void:
	if nodes.is_empty():
		return
	var by_id := {}
	for n: Dictionary in nodes:
		by_id[str(n.get("id", ""))] = n
	var depth := {}
	var queue: Array[String] = [str((nodes[0] as Dictionary).get("id", ""))]
	depth[queue[0]] = 0
	while not queue.is_empty():
		var id: String = queue.pop_front()
		var n: Dictionary = by_id.get(id, {})
		var outs: Array[String] = []
		if str(n.get("next", "")) != "":
			outs.append(str(n["next"]))
		for ch: Dictionary in n.get("choices", []):
			if str(ch.get("next", "")) != "":
				outs.append(str(ch["next"]))
		for o in outs:
			if by_id.has(o) and not depth.has(o):
				depth[o] = int(depth[id]) + 1
				queue.append(o)
	var last := 0
	for d: int in depth.values():
		last = maxi(last, d)
	var rows := {}
	for n2: Dictionary in nodes:
		var id2 := str(n2.get("id", ""))
		var col := int(depth.get(id2, last + 1))  # unreachable ones go in a column at the end
		var row := int(rows.get(col, 0))
		rows[col] = row + 1
		n2["pos"] = [col * gap.x, row * gap.y]


## A tab-separated recording script: file, speaker, line, one row per node.
## Hand it to the voice session (or ElevenLabs); files named in column 1 drop
## straight into assets/voice/dialog.
static func voice_script(npc: NPCResource) -> String:
	var rows: Array[String] = ["file\tspeaker\tline"]
	for n: Dictionary in npc.dialog:
		var speaker := str(n.get("speaker", ""))
		var file := str(n.get("voice_path", ""))
		if file == "":
			file = voice_path(npc.id, str(n.get("id", "")))
		rows.append("%s\t%s\t%s" % [file.get_file(), speaker if speaker != "" else npc.display_name, str(n.get("text", "")).replace("\t", " ").replace("\n", " ")])
	return "\n".join(rows) + "\n"
