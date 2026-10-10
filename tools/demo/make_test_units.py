"""Test-unit content for the PixelLab exports in assets/units/test_*.

Adds (idempotent, run again any time):
  * NPC "kade": the test vendor (assets/units/test_vendorNPC_001), a shop
    run through interaction stages (intro → shop → closing)
  * mission "test_pixellab_skirmish": Test Runner (player-controlled guest)
    plus two crew vs. a Bulwark Brawler and two Corp Gunners on the dock
  * Kade standing on the Neon Block demo map with an NPC anchor
Characters / abilities / the vendor live in data/characters.json,
data/abilities.json and data/vendors.json.
Run from the repo root: python3 tools/demo/make_test_units.py
"""
import json

npc = {
    "id": "kade", "display_name": "Kade Rennick",
    "description": "Sells prototype gear off a fold-out table. Never looks up from his tablet for long.",
    "portrait_path": "res://assets/units/test_vendorNPC_001/extracted/cyberpunk_male_isometric_2_1_perspective_18/Idle/rotations/south.png",
    "sprite_path": "res://assets/units/test_vendorNPC_001", "location_id": "neon_block_demo",
    "is_vendor": True, "vendor_id": "test_vendor", "quest_ids": [], "required_flag": "",
    "dialog": [
        {"id": "greet", "text": "Hm? Oh. Customer. Hang on, finishing a bid.", "next": "look"},
        {"id": "look", "text": "There. Prototype stock, fell off a corp truck. Several trucks.", "next": "pitch"},
        {"id": "pitch", "text": "Prices are fair. Fair for me. Browse.",
         "choices": [{"text": "Kade? Like the Veil politician?", "next": "name"}, {"text": "Just browsing.", "next": ""}]},
        {"id": "name", "text": "Kade Sol? No relation. Well. Every relation. Half the Lantern Wards are Kades.", "next": "name2"},
        {"id": "name2", "text": "Kade's the family name, it goes first. The second one's yours. Rennick. That one's mine.", "next": "name3"},
        {"id": "name3", "text": "Grandmother said the Wards used to have a hundred family names. Then the Ministry of Clear History came through with one form.", "next": "name4"},
        {"id": "name4", "text": "'Simpler for the records,' they said. Everyone you meet from home is a Kade. Funny how nobody remembers what we were before.", "sets_flag": "heard_kade_name"},
    ],
    "eavesdrop_lines": [
        {"text": "Kade, to his tablet: 'Outbid by a drone. A drone, again.'"},
        {"text": "Kade, not looking up: 'If it's warm, it's new. If it's sparking, that's a feature.'"},
        {"text": "Kade, quietly: 'Corp gunners pay double for med-patches. I know because I sell them the patches.'"},
        {"text": "Kade, on a call: 'No, the OTHER Kade. Kade Ostrin. From the Wards. …They're all from the Wards.'"},
    ],
    "intro_lines": [],
    "repeat_lines": ["Back again? Stock rotates. Sometimes. When trucks fall."],
    "give_item_id": "", "give_item_qty": 1,
    "after_talk": "shop",
    "closing_lines": ["Pleasure. Don't tell anyone where you got it."],
}
src = open("data/npcs.json").read().rstrip()
cut = src.find(',\n\t{\n\t\t"id": "%s"' % npc["id"])
if cut >= 0:
    nxt = src.find('\n\t},\n\t{', cut + 5)
    src = src[:cut] + (src[nxt + 3:] if nxt >= 0 else "\n]")
entry = json.dumps(npc, indent="\t", ensure_ascii=False).replace("\n", "\n\t")
open("data/npcs.json", "w").write(src[:-1].rstrip() + ",\n\t" + entry + "\n]\n")

mission = {
    "id": "test_pixellab_skirmish",
    "display_name": "Test Units Skirmish",
    "chapter": 1,
    "map_id": "supply_works_dock",
    "music_id": "battle_supply_works",
    "briefing": "Test fight for the new PixelLab units. The Test Runner (yours) walks, runs and shoots; "
                "the Bulwark Brawler kicks (knockback), uppercuts and blasts; Corp Gunners shoot and patch themselves up.",
    "max_party_size": 2,
    "guests": [{"character_id": "test_hero", "cell": [0, 9], "level": 3, "controlled": True}],
    "enemies": [
        {"character_id": "test_enemy_001", "cell": [8, 9], "level": 3},
        {"character_id": "test_enemy_002", "cell": [10, 2], "level": 3},
        {"character_id": "test_enemy_002", "cell": [11, 4], "level": 2},
    ],
    "win_condition": "defeat_all",
    "soul_coin_reward": 100,
    "xp_reward": 60,
    "loot_table_id": "loot_supply_works",
    "microchip_reward": 1,
    "story_flags_on_win": [],
}
missions = json.load(open("data/missions.json"))
missions = [m for m in missions if m["id"] != mission["id"]] + [mission]
open("data/missions.json", "w").write(json.dumps(missions, indent="\t", ensure_ascii=False) + "\n")

block = json.load(open("data/maps/neon_block_demo.json"))
block["objects"] = [o for o in block["objects"] if o.get("id") != "obj_test_kade"] + [{
    "id": "obj_test_kade", "asset": "res://assets/units/test_vendorNPC_001", "cell": [6, 9], "z": 0,
    "offset": [0, 0], "scale": 1.0, "flip": False, "layer": 0, "kind": "character", "facing": "SW",
    "anim": None, "loot_item_id": "", "found_text": "", "empty_text": "", "dialog_npc": "", "location": None}]
block["anchors"] = [a for a in block.get("anchors", []) if a.get("id") != "anc_test_kade"] + [{
    "id": "anc_test_kade", "cell": [6, 9], "kind": "npc", "npc_id": "kade", "label": "Kade's Stall",
    "hidden": False, "scope": "both", "ap": 0, "reach": 1, "once": False, "enabled": True, "requires_flag": "",
    "requires_item": "", "consume_item": False, "sequence": "", "step": 0, "actions": [], "fail_actions": []}]
block.setdefault("gameplay", {}).pop("10,7", None)
block["gameplay"]["6,9"] = {"walkable": False}
open("data/maps/neon_block_demo.json", "w").write(json.dumps(block, indent="\t") + "\n")
print("kade + test_pixellab_skirmish + Kade on the Neon Block")
