"""The Kades of the Lantern Wards (docs/lore/LORE_DIGEST.md §6.2.1), scattered
through the game. Idempotent: run again any time.

  Kade Rennick  test vendor, Neon Block            (tools/demo/make_test_units.py)
  Kade Ostrin   the "other Kade" on Rennick's phone (eavesdrop)
  Kade Imbri    on the reconciled border casualty list (ticker)
  Kade Torvald  Neon Gutter regular: a deserter listed dead; with the Casualty
                Ledger he hands over the Ministry's re-registration form (evidence)
  Kade Brisk    Rennick's smuggler supplier, Neon Block, fetch quest that
                unlocks extra stock at Rennick's stall
  Kade Halloway Veil news anchor (ticker)
  Kade Tamsin   Greywrithe agent on a wanted notice (ticker, graffiti)
  Kade Lusk     Ocular Guard commander, late-game boss character
  Kade Ash      a child's name scratched in the Cathedral of Forgotten Names (gossip)
Run from the repo root: python3 tools/demo/make_kades.py
"""
import json


def append_to_list(path, entries, pretty=False):
    src = open(path).read().rstrip()
    ids = [e["id"] for e in json.loads(src)]
    add = [e for e in entries if e["id"] not in ids]
    if not add:
        return
    if pretty:
        body = ",\n".join("\t" + json.dumps(e, indent="\t", ensure_ascii=False).replace("\n", "\n\t") for e in add)
    else:
        body = ",\n".join("\t" + json.dumps(e, ensure_ascii=False) for e in add)
    open(path, "w").write(src[:-1].rstrip() + ",\n" + body + "\n]\n")


def add_to_dict(path, entries):
    src = open(path).read().rstrip()
    d = json.loads(src)
    add = {k: v for k, v in entries.items() if k not in d}
    if not add:
        return
    body = ",\n".join('\t"%s": %s' % (k, json.dumps(v, indent="\t", ensure_ascii=False).replace("\n", "\n\t")) for k, v in add.items())
    open(path, "w").write(src[:-1].rstrip() + ",\n" + body + "\n}\n")


# --- Ticker / gossip / graffiti -------------------------------------------------
rumors = json.load(open("data/rumors.json"))
if "r_kade_casualty" in rumors:
    src = open("data/rumors.json").read()
    src = src.replace("Kade Imbri, Kade Torvald, Kade Ash, Kade Ostrin…", "Kade Imbri, Kade Torvald, Kade Vell, Kade Marren…")
    open("data/rumors.json", "w").write(src)
add_to_dict("data/rumors.json", {
    "r_kade_halloway": {"channel": "news", "text": "INTERCEPTED VEIL FEED: '…this is Kade Halloway, reporting from Aurum Prime, where the Republic celebrates another free and fair election.' The Cantorate reminds you that listening to enemy feeds is a sin."},
    "r_kade_halloway_2": {"channel": "news", "text": "INTERCEPTED VEIL FEED: Kade Halloway calls the ninth collapsed ceasefire 'a regrettable Doctrine provocation.' Our anchors used the same words an hour earlier."},
    "r_kade_tamsin": {"channel": "news", "text": "WANTED: Greywrithe operative 'Kade Tamsin', suspected in the Supply Works sabotage. Possibly also Kestral Omen-Six. Possibly not a person. Report all Kades."},
    "r_kade_tamsin_graffiti": {"channel": "graffiti", "text": "TAMSIN WAS HERE (OR WASN'T)"},
    "r_kade_lusk": {"channel": "news", "text": "BORDER DESK: Ocular Guard Commander Kade Lusk seen at the Solenne Gate. Veil's 'clean war' has a face, citizens. Memorise it."},
    "r_kade_ash": {"channel": "gossip", "text": "There's a name scratched low on the wall in the Cathedral of Forgotten Names. Kid height. 'Kade Ash.' No dates. Nobody knows who scratched it."},
})

# --- Evidence: the Ministry's form ------------------------------------------------
add_to_dict("data/evidence.json", {
    "kade_form": {"title": "Form CH-1: Ward Re-registration", "source": "Kade Torvald, Neon Gutter",
                  "description": "A Ministry of Clear History form. 'Family name of record (all residents): KADE. Prior names: — (struck for clarity).' The stamp is older than the Republic."},
})

# --- NPCs -----------------------------------------------------------------------
torvald = {
    "id": "kade_torvald", "display_name": "Kade Torvald",
    "description": "A Veil deserter on the last stool by the door. Very quiet about where he's from. Very loud about the jukebox.",
    "portrait_path": "", "sprite_path": "", "location_id": "neon_gutter",
    "is_vendor": False, "vendor_id": "", "quest_ids": [], "required_flag": "",
    "dialog": [
        {"id": "greet", "text": "You're looking at me like you've seen me on the ticker. You have. I'm dead.", "next": "dead"},
        {"id": "dead", "text": "Border list, reconciled. Kade Torvald, killed in action. Nobody told me. I found out in this bar.",
         "choices": [{"text": "You're from Veil?", "next": "veil"}, {"text": "Another Kade?", "next": "kade"}]},
        {"id": "veil", "text": "Lantern Wards. I walked across the line with a mop and a cleaning cart. Nobody stops a mop.", "next": "end"},
        {"id": "kade", "text": "We're all Kades. Ask Rennick on the Block. Ask the Ministry why. Actually, don't. They'll correct you.", "next": "end"},
        {"id": "end", "text": "Buy a dead man a drink. It's tax deductible."},
    ],
    "eavesdrop_lines": [
        {"text": "Kade Torvald, to his glass: 'Killed in action. Killed in ACTION. I was in the latrine.'"},
        {"text": "Kade Torvald, quietly: 'Grandmother kept the old name under the floorboards. On paper. Paper. Can you imagine.'"},
        {"text": "Kade Torvald, to Benno: 'Your casualty list and ours use the same font. Did you know that? Same font.'"},
    ],
    "evidence_talk": [
        {"needs": 1, "evidence": ["casualty_ledger"], "sets_flag": "evidence:kade_form", "give_item_id": "", "quest_id": "",
         "lines": ["That's the border list. The real one. Before the… reconciling.",
                   "Fine. You've earned this. My grandmother's. Form CH-1. Every family in the Wards signed one.",
                   "Read the line where it says 'prior names.' Then tell me the Republic's a republic."]},
    ],
}
brisk = {
    "id": "kade_brisk", "display_name": "Kade Brisk",
    "description": "Rennick's supplier. Moves crates that fall off trucks, sometimes before the trucks arrive.",
    "portrait_path": "", "sprite_path": "", "location_id": "neon_block_demo",
    "is_vendor": False, "vendor_id": "", "quest_ids": [], "required_flag": "",
    "dialog": [
        {"id": "greet", "text": "Brisk. Kade Brisk. Yes, another one. Rennick sent you?", "next": "pitch"},
        {"id": "pitch", "text": "Shipment's short. Two corrupted wafers and a memory core went missing between here and the drain.", "next": "deal"},
        {"id": "deal", "text": "Bring them back and Rennick gets the good stock. Laser rifles. Neural shunts. Things with warranties, almost."},
    ],
    "eavesdrop_lines": [
        {"text": "Kade Brisk, counting crates: 'Seven. Six. Seven. Why is it six.'"},
        {"text": "Kade Brisk, to a drone: 'I don't know any Tamsin. Lots of Kades. No Tamsins. Move along.'"},
        {"text": "Kade Brisk, under his breath: 'Ward rule one: never sign anything with a stamp older than you.'"},
    ],
    "intro_lines": [],
    "repeat_lines": ["Wafers and a core. You'd think they'd be easy to find. Everything's easy to find around here except the stuff you need."],
    "give_item_id": "", "give_item_qty": 1,
    "after_talk": "fetch",
    "fetch_items": {"mat_corrupted_wafer": 2, "mat_memory_core": 1},
    "fetch_reward_coins_each": 40, "fetch_reward_items_each": {},
    "fetch_reward_coins_done": 150, "fetch_reward_chips_done": 1, "fetch_reward_items_done": {},
    "closing_lines": ["Tell Rennick the good shelf is open."],
}
src = open("data/npcs.json").read().rstrip()
have = [n["id"] for n in json.loads(src)]
for npc in (torvald, brisk):
    if npc["id"] in have:
        continue
    entry = json.dumps(npc, indent="\t", ensure_ascii=False).replace("\n", "\n\t")
    src = src[:-1].rstrip() + ",\n\t" + entry + "\n]"
open("data/npcs.json", "w").write(src + "\n")

# --- Kade Lusk: Ocular Guard commander (late-game boss) --------------------------
append_to_list("data/characters.json", [{
    "id": "kade_lusk", "display_name": "Kade Lusk", "class_id": "cyber_sniper", "team": 1, "is_unique": True,
    "bio": "Ocular Guard Commander. Answers to the Archduchess, not the Archon. Lantern Wards born; never says so.",
    "base_stats": {"strength": 14, "agility": 18, "intelligence": 15, "vitality": 15, "level": 12},
    "weapon_specialties": [], "equipment": {"weapon": "wpn_laser_gun_2"}, "ai_behavior": "tactical",
    "learned_ability_ids": [], "is_boss": True, "boss_title": "Ocular Guard Commander",
    "barks": [
        {"event": "battle_start", "text": "Name of record?", "voice_path": "res://assets/voice/barks/kade_lusk_battle_start_1.ogg", "chance": 1.0},
        {"event": "kill", "text": "Struck for clarity.", "voice_path": "res://assets/voice/barks/kade_lusk_kill_1.ogg", "chance": 0.8},
        {"event": "low_hp", "text": "I was a Kade before I was a Commander. Remember that, if you remember anything.", "voice_path": "res://assets/voice/barks/kade_lusk_low_hp_1.ogg", "chance": 1.0},
    ],
}])

# --- Brisk on the Neon Block; Rennick's good shelf ---------------------------------
block = json.load(open("data/maps/neon_block_demo.json"))
block["anchors"] = [a for a in block.get("anchors", []) if a.get("id") != "anc_kade_brisk"] + [{
    "id": "anc_kade_brisk", "cell": [7, 11], "kind": "npc", "npc_id": "kade_brisk", "label": "Kade Brisk",
    "hidden": False, "scope": "both", "ap": 0, "reach": 1, "once": False, "enabled": True, "requires_flag": "",
    "requires_item": "", "consume_item": False, "sequence": "", "step": 0, "actions": [], "fail_actions": []}]
block.setdefault("gameplay", {})["7,11"] = {"walkable": False}
open("data/maps/neon_block_demo.json", "w").write(json.dumps(block, indent="\t") + "\n")
v = open("data/vendors.json").read()
if "npc:kade_brisk:fetched" not in v:
    v = v.replace('{"id": "acc_clear_eyes", "qty": 1},',
                  '{"id": "acc_clear_eyes", "qty": 1}, {"id": "wpn_laser_gun_2", "qty": 1, "required_flag": "npc:kade_brisk:fetched"}, {"id": "acc_neural_shunt", "qty": 1, "required_flag": "npc:kade_brisk:fetched"},')
    assert "npc:kade_brisk:fetched" in v
    json.loads(v)
    open("data/vendors.json", "w").write(v)
print("Kades placed: Ostrin, Imbri, Torvald, Brisk, Halloway, Tamsin, Lusk, Ash")
