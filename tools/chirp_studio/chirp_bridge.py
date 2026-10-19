#!/usr/bin/env python3
"""Chirp Studio <-> game bridge for Beyond: The Neon Void.

  sync    Rewrites the app's seed data (inside the .html) from the game:
          every class with three signature abilities, the cast and NPCs with
          their voice profile, every battle bark and every dialog line, each
          with the exact file the game plays. Run it after game data changes.
  import  Reads the manifest the app exports and pushes it into the game:
          voice profiles (personality / line set / ElevenLabs voice id), edited
          bark and dialog text, and recorded audio (copied, never moved).

  py -3 tools/chirp_studio/chirp_bridge.py sync
  py -3 tools/chirp_studio/chirp_bridge.py import [manifest.json] [--audio-root DIR] [--dry-run]

Bind the app's save folder to the game's project folder and recordings land
straight in assets/voice/barks and assets/voice/dialog; the manifest goes to
tools/chirp_studio/manifest.json, which is where import looks by default.
"""
import argparse
import json
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
HTML = REPO / "tools/chirp_studio/black_doctrine_chirp_studio.html"
EXTRA = REPO / "tools/chirp_studio/extra_personalities.json"
MANIFEST = REPO / "tools/chirp_studio/manifest.json"
SEED_RE = re.compile(r'(<script id="seed-data" type="application/json">)(.*?)(</script>)', re.S)

EVENT_LABELS = {
	"battle_start": "Battle Start", "turn_start": "Turn Start", "crit": "Critical Hit", "kill": "Takedown",
	"ally_down": "Ally Down", "low_hp": "Low HP", "big_hit": "Big Hit Taken", "miss": "Miss", "heal": "Healed",
	"victory": "Victory", "buzzed": "Buzzed", "shield_down": "Shield Down",
}
GROUPS = {"team:0": ("Crew (anyone)", "Fallback lines for any crew member"),
	"team:1": ("Doctrine (any trooper)", "Fallback lines for any Doctrine unit")}
# Voice file base for lines that don't name one yet (matches data/barks.json).
GROUP_FILE_BASE = {"team:0": "crew", "team:1": "doctrine_trooper"}
EXTRA_NPC_CATEGORIES = {
	"bartender": {"name": "Bartender", "role": "Pours, listens, remembers tabs"},
	"fixer": {"name": "Fixer", "role": "Jobs, favours and quiet introductions"},
	"street_kid": {"name": "Street Kid", "role": "Runner, lookout, pickpocket"},
	"doctrine_patrol": {"name": "Doctrine Patrol", "role": "Wardens and Choir on the beat"},
}
SLOTS = {"fire_spell": ["ATTACK", "MAGIC"], "water_spell": ["HEAL", "BUFF", "UTILITY"], "ice_spell": ["DEBUFF", "SPECIAL", "MAGIC"]}


def load(p: Path):
	return json.loads(p.read_text(encoding="utf-8"))


def save(p: Path, data) -> None:
	p.write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")


def strip_res(path: str) -> str:
	"""res://assets/voice/barks/rook_crit_1.ogg -> assets/voice/barks/rook_crit_1"""
	p = path[len("res://"):] if path.startswith("res://") else path
	return p.rsplit(".", 1)[0] if "." in p.rsplit("/", 1)[-1] else p


def file_base(who: str) -> str:
	return GROUP_FILE_BASE.get(who, re.sub(r"[^a-z0-9]+", "_", who.lower()).strip("_"))


# --- game -> seed -------------------------------------------------------------

def build_classes() -> dict:
	abilities = {a["id"]: a for a in load(REPO / "data/abilities.json")}
	out = {}
	for c in load(REPO / "data/classes.json"):
		pool = list(c.get("innate_ability_ids", [])) + list(c.get("learnable_ability_ids", []))
		pool += [a["id"] for a in abilities.values() if a.get("class_id") == c["id"] and a["id"] not in pool]
		pool = [a for a in pool if a in abilities]
		used = set()
		entry = {"name": c["display_name"],
			"role": "%s%s · Tier %s" % ("" if c.get("playable", True) else "Enemy · ", str(c.get("role", "")).title(), c.get("tier", 1))}
		for slot, kinds in SLOTS.items():
			pick = next((a for k in kinds for a in pool if abilities[a]["kind"] == k and a not in used), None)
			if pick is None:
				pick = next((a for a in pool if a not in used), None)
			if pick:
				used.add(pick)
			entry[slot] = abilities[pick]["display_name"] if pick else "Basic Attack"
		out[c["id"]] = entry
	return out


def build_cast() -> tuple:
	chars = [c for c in load(REPO / "data/characters.json") if not c["id"].startswith("test_")]
	npcs = load(REPO / "data/npcs.json")
	barks = load(REPO / "data/barks.json")
	classes = {c["id"]: c for c in load(REPO / "data/classes.json")}
	cast, cast_barks, dialog = {}, {}, {}

	def profile(e: dict) -> dict:
		return {"personality": e.get("voice_personality", ""), "sex": e.get("voice_sex", ""), "voice_id": e.get("voice_id", "")}

	for c in chars:
		cl = classes.get(c.get("class_id", ""), {})
		side = "Crew" if int(c.get("team", 0)) == 0 else "Doctrine"
		cast[c["id"]] = {"name": c["display_name"], "role": "%s · %s" % (side, cl.get("display_name", c.get("class_id", ""))),
			"kind": "unit", "class_id": c.get("class_id", ""), "bio": c.get("bio", ""), **profile(c)}
	for n in npcs:
		e = cast.get(n["id"])
		if e:
			e["kind"] = "unit+npc"
			for k, v in profile(n).items():
				e[k] = e[k] or v
		else:
			cast[n["id"]] = {"name": n["display_name"], "role": "NPC · %s" % str(n.get("location_id", "")).replace("_", " ").title(),
				"kind": "npc", "class_id": "", "bio": n.get("description", ""), **profile(n)}
		lines = []
		for node in n.get("dialog", []):
			vp = str(node.get("voice_path", ""))
			lines.append({"id": node["id"], "text": node.get("text", ""), "speaker": node.get("speaker", ""),
				"file": strip_res(vp) if vp else "assets/voice/dialog/%s_%s" % (n["id"], node["id"])})
		if lines:
			dialog[n["id"]] = lines
	for who, (name, role) in GROUPS.items():
		cast[who] = {"name": name, "role": role, "kind": "group", "class_id": "", "bio": "", "personality": "", "sex": "", "voice_id": ""}
	if "team:1" in cast:
		cast["team:1"]["personality"] = "wasteland_prophet"

	def add(who: str, ev: str, text: str, voice: str, src: str, chance=None) -> None:
		evs = cast_barks.setdefault(who, {})
		arr = evs.setdefault(ev, [])
		line = {"text": text, "file": strip_res(voice) if voice else "assets/voice/barks/%s_%s_%d" % (file_base(who), ev, len(arr) + 1), "src": src}
		if chance is not None:
			line["chance"] = chance
		arr.append(line)

	for who, evs in barks.items():
		if who.startswith("_"):
			continue
		if who not in cast:
			cast[who] = {"name": who, "role": "Barks", "kind": "group", "class_id": "", "bio": "", "personality": "", "sex": "", "voice_id": ""}
		for ev, arr in evs.items():
			for x in arr:
				if isinstance(x, dict):
					add(who, ev, x.get("text", ""), x.get("voice", x.get("voice_path", "")), "barks.json", x.get("chance"))
				else:
					add(who, ev, str(x), "", "barks.json")
	for c in chars:
		for x in c.get("barks", []):
			add(c["id"], x.get("event", "battle_start"), x.get("text", ""), x.get("voice_path", ""), "characters.json", x.get("chance"))
	return cast, cast_barks, dialog


def cmd_sync(args) -> int:
	html = Path(args.html)
	s = html.read_text(encoding="utf-8")
	m = SEED_RE.search(s)
	if not m:
		print("no seed-data block in", html)
		return 1
	seed = json.loads(m.group(2))
	extra = load(EXTRA)
	for pid, p in extra.items():
		if not pid.startswith("_") and pid not in seed["personalities"]:
			seed["personalities"][pid] = p
	seed["classes"] = build_classes()
	for k, v in EXTRA_NPC_CATEGORIES.items():
		seed["npcCategories"].setdefault(k, v)
	cast, cast_barks, dialog = build_cast()
	seed["characters"] = cast
	seed["castBarks"] = cast_barks
	seed["dialog"] = dialog
	seed["castEventLabels"] = EVENT_LABELS
	seed["game"] = {"name": "Beyond: The Neon Void", "synced_from": "data/*.json", "voice_roots": ["assets/voice/barks", "assets/voice/dialog"]}
	body = json.dumps(seed, indent=2, ensure_ascii=False).replace("</", "<\\/")
	html.write_text(s[:m.start(2)] + body + s[m.end(2):], encoding="utf-8")
	n_barks = sum(len(a) for evs in cast_barks.values() for a in evs.values())
	n_dialog = sum(len(a) for a in dialog.values())
	print("synced %s: %d classes, %d cast, %d barks, %d dialog lines, %d personalities"
		% (html.name, len(seed["classes"]), len(cast), n_barks, n_dialog, len(seed["personalities"])))
	return 0


# --- manifest -> game ---------------------------------------------------------

def cmd_import(args) -> int:
	mpath = Path(args.manifest)
	if not mpath.exists():
		print("no manifest at", mpath, "(Export tab -> write to the bound folder, or copy it here)")
		return 1
	man = load(mpath)
	cast = man.get("cast", {})
	report = []
	chars_p, npcs_p, barks_p = REPO / "data/characters.json", REPO / "data/npcs.json", REPO / "data/barks.json"
	chars, npcs, barks = load(chars_p), load(npcs_p), load(barks_p)
	changed = set()

	# Voice profiles.
	for table, path in ((chars, chars_p), (npcs, npcs_p)):
		for e in table:
			c = cast.get(e["id"])
			if not c:
				continue
			for src, dst in (("personality", "voice_personality"), ("sex", "voice_sex"), ("voice_id", "voice_id")):
				v = str(c.get(src, "") or "")
				if v and e.get(dst, "") != v:
					e[dst] = v
					changed.add(path)
					report.append("%s: %s = %s" % (e["id"], dst, v))

	# Bark text, matched by the file each line plays.
	def bark_lines():
		for who, evs in barks.items():
			if who.startswith("_"):
				continue
			for ev, arr in evs.items():
				for i, x in enumerate(arr):
					yield who, ev, arr, i, x, barks_p
		for c in chars:
			for i, x in enumerate(c.get("barks", [])):
				yield c["id"], x.get("event", ""), c["barks"], i, x, chars_p

	by_file = {}
	counts = {}
	for who, ev, arr, i, x, path in bark_lines():
		n = counts[(who, ev)] = counts.get((who, ev), 0) + 1
		voice = x.get("voice", x.get("voice_path", "")) if isinstance(x, dict) else ""
		f = strip_res(voice) if voice else "assets/voice/barks/%s_%s_%d" % (file_base(who), ev, n)
		by_file[f] = (arr, i, path)
	for who, c in cast.items():
		for ev, lines in (c.get("barks") or {}).items():
			for line in lines:
				hit = by_file.get(strip_res(str(line.get("path", ""))))
				if not hit:
					continue
				arr, i, path = hit
				x = arr[i]
				old = x.get("text", "") if isinstance(x, dict) else str(x)
				new = str(line.get("text", ""))
				# Text-only lines learn their voice file, so recordings play.
				if not isinstance(x, dict) and path == barks_p:
					x = arr[i] = {"text": old, "voice": str(line.get("path", ""))}
					changed.add(path)
					report.append("%s %s: voice file %s" % (who, ev, line.get("path", "")))
				if new and new != old:
					if isinstance(x, dict):
						x["text"] = new
					else:
						arr[i] = new
					changed.add(path)
					report.append("%s %s: %r" % (who, ev, new))

	# Dialog text.
	for n in npcs:
		c = cast.get(n["id"])
		for line in (c or {}).get("dialog", []) or []:
			for node in n.get("dialog", []):
				if node.get("id") == line.get("id") and line.get("text") and node.get("text") != line["text"]:
					node["text"] = line["text"]
					changed.add(npcs_p)
					report.append("%s/%s: dialog text" % (n["id"], node["id"]))

	# Recordings: copied in from an extracted ZIP or another bound folder.
	copied = 0
	if args.audio_root:
		root = Path(args.audio_root)
		for f in sorted((root / "assets/voice").rglob("*")) if (root / "assets/voice").exists() else []:
			if f.suffix.lower() not in (".ogg", ".wav", ".mp3"):
				continue
			dst = REPO / f.relative_to(root)
			if dst.resolve() == f.resolve():
				continue
			if not args.dry_run:
				dst.parent.mkdir(parents=True, exist_ok=True)
				shutil.copy2(f, dst)
			copied += 1

	if not args.dry_run:
		for path in changed:
			save(path, {chars_p: chars, npcs_p: npcs, barks_p: barks}[path])
	for r in report:
		print("  " + r)
	print("%s%d change(s) to %s, %d recording(s) copied" % ("[dry run] " if args.dry_run else "", len(report),
		", ".join(sorted(p.name for p in changed)) or "nothing", copied))
	return 0


def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	s = sub.add_parser("sync", help="game data -> app seed")
	s.add_argument("--html", default=str(HTML))
	i = sub.add_parser("import", help="app manifest -> game data")
	i.add_argument("manifest", nargs="?", default=str(MANIFEST))
	i.add_argument("--audio-root", default="", help="folder holding assets/voice/... (an extracted ZIP)")
	i.add_argument("--dry-run", action="store_true")
	args = ap.parse_args()
	return cmd_sync(args) if args.cmd == "sync" else cmd_import(args)


if __name__ == "__main__":
	sys.exit(main())
