"""Tactical masks + interaction anchors showcase: "Vault Breach".

Writes data/maps/vault_breach_demo.json and the mission demo_vault_breach
(data/missions.json). Everything the MASKS tab can paint is on it:
  * a vault wall (impassable + full cover) with a sealed shutter (door group
    "vault_door") that a terminal opens
  * the Foreman sits in the vault SHIELDED; three switches pressed in order
    (core #1 → #2 → #3) drop the shield; the wrong order shocks you and resets
  * two cloaked Choir Enforcers; a smoke generator strips their camo
  * half cover crates, full cover pillars, a sight-blocking glass pane
  * a wire trap on the approach (Shift+click to rewire it), hidden loot,
    a med station and a data cache inside the vault
Run from the repo root: python3 tools/demo/make_tactics_demo.py
"""
import json

W, D = 16, 14
MAP_ID = "vault_breach_demo"
tiles, gameplay, objects, anchors = {}, {}, [], []


def key(x, y):
    return "%d,%d" % (x, y)


for x in range(W):
    for y in range(D):
        floor = "terrain:metal_grate" if x >= 10 else "terrain:concrete"
        tiles[key(x, y)] = [[0, floor]]


def wall(x, y, h=2):
    tiles[key(x, y)] = [[z, "terrain:metal_grate"] for z in range(h + 1)]
    gameplay[key(x, y)] = {"walkable": False, "cover": 2}


def mask(x, y, **kw):
    gameplay.setdefault(key(x, y), {}).update(kw)


# The vault: wall along x = 9 with a two-cell shutter in the middle.
for y in range(1, 13):
    if y in (6, 7):
        tiles[key(9, y)] = [[0, "terrain:metal_grate"]]
        mask(9, y, walkable=False, cover=2, group="vault_door")
    else:
        wall(9, y)
for x in range(10, 16):
    wall(x, 0)
    wall(x, 13)

# Cover on the approach.
for c in [(4, 6), (4, 7), (6, 4), (6, 9), (2, 3), (2, 10)]:
    tiles[key(*c)].append([1, "terrain:crate"])
    mask(*c, walkable=False, cover=1)
for c in [(7, 2), (7, 11)]:
    wall(*c, 2)
# A tall glass pane: walkable around, no line of sight through.
mask(5, 6, blocks_los=True)
# Cover inside the vault.
for c in [(12, 4), (12, 9), (14, 6), (14, 7)]:
    tiles[key(*c)].append([1, "terrain:crate"])
    mask(*c, walkable=False, cover=1)

uid = [0]


def anchor(x, y, kind, **kw):
    uid[0] += 1
    a = {"id": "anc_%s_%d" % (MAP_ID, uid[0]), "cell": [x, y], "kind": kind, "label": "", "hidden": False,
         "scope": "both", "ap": 1, "reach": 1, "once": False, "enabled": True, "requires_flag": "",
         "requires_item": "", "consume_item": False, "sequence": "", "step": 0, "actions": [], "fail_actions": []}
    a.update(kw)
    anchors.append(a)
    return a


anchor(8, 9, "terminal", label="Shutter Terminal", actions=[{"do": "open", "arg": "vault_door"},
                                                          {"do": "news", "arg": "Supply Works vault shutter opened without authorisation."}])
shock = [{"do": "damage", "arg": "10%"}, {"do": "toast", "arg": "FEEDBACK SURGE"}]
anchor(3, 1, "switch", label="Core Relay", sequence="core", step=1, fail_actions=shock)
anchor(5, 12, "switch", label="Core Relay", sequence="core", step=2, fail_actions=shock)
anchor(8, 1, "switch", label="Core Relay", sequence="core", step=3, fail_actions=shock,
       actions=[{"do": "unshield", "arg": "foreman_grisk"}, {"do": "cue", "arg": "shield.down"}])
anchor(1, 6, "device", label="Smoke Generator", once=True, actions=[{"do": "reveal", "arg": ""}])
anchor(6, 7, "trap", label="Tripwire", hidden=True, once=True,
       trap={"damage": 30, "status": "shocked", "hostile": "player", "disarm": 0.75})
anchor(1, 12, "loot", label="Loose Floor Panel", hidden=True, once=True, reach=0,
       actions=[{"do": "give", "arg": "con_synth_stew:2"}, {"do": "coins", "arg": "150"}])
anchor(0, 1, "medstation", label="Med Station", once=True, actions=[{"do": "heal", "arg": "40%"}])
anchor(15, 6, "intel", label="Vault Cache", once=True, actions=[{"do": "chips", "arg": "2"}, {"do": "flag", "arg": "vault_cache_taken"}])

world = {
    "format": 2, "id": MAP_ID, "name": "Supply Works Vault", "kind": "encounter",
    "width": W, "depth": D, "tile_width": 128, "tile_height": 64, "height_step": 32,
    "tiles": tiles, "details": [], "particles": {}, "objects": objects,
    "spawns": {"player": [[1, 5], [1, 7], [2, 6], [0, 8], [2, 8]], "enemy": []},
    "gameplay": gameplay, "anchors": anchors,
    "post": "neon_noir",
}
json.dump(world, open("data/maps/%s.json" % MAP_ID, "w"), indent="\t")

mission = {
    "id": "demo_vault_breach",
    "display_name": "Vault Breach (tactics demo)",
    "chapter": 1,
    "map_id": MAP_ID,
    "music_id": "battle_supply_works",
    "briefing": "The Foreman is hiding behind a core shield in the vault. Hack the shutter terminal (yellow), "
                "throw the three Core Relays in order to drop his shield, and light the smoke generator — "
                "something cloaked is waiting on the approach. Full cover blocks shots head-on; flank it.",
    "enemies": [
        {"character_id": "foreman_grisk", "cell": [13, 7], "level": 3, "statuses": ["shielded"]},
        {"character_id": "doctrine_warden", "cell": [11, 5], "level": 2},
        {"character_id": "doctrine_warden", "cell": [11, 8], "level": 2},
        {"character_id": "factory_marksman", "cell": [13, 2], "level": 2},
        {"character_id": "choir_enforcer", "cell": [6, 2], "level": 2, "statuses": ["cloaked"]},
        {"character_id": "choir_enforcer", "cell": [6, 11], "level": 2, "statuses": ["cloaked"]},
    ],
    "win_condition": "defeat_all",
    "soul_coin_reward": 300,
    "xp_reward": 160,
    "loot_table_id": "loot_supply_works",
    "microchip_reward": 2,
    "story_flags_on_win": ["demo_vault_breach_done"],
}
missions = json.load(open("data/missions.json"))
missions = [m for m in missions if m["id"] != mission["id"]] + [mission]
open("data/missions.json", "w").write(json.dumps(missions, indent="\t", ensure_ascii=False) + "\n")
print("wrote data/maps/%s.json (%d anchors, %d masked cells) + mission %s" % (MAP_ID, len(anchors), len(gameplay), mission["id"]))

# --- Explore side: an NPC with interaction stages + a way into the vault ------
npc = {
    "id": "ma_rivet", "display_name": "Ma Rivet",
    "description": "Runs a scrap stall out of a shopping cart. Knows every wire in the block and who cut it.",
    "portrait_path": "", "sprite_path": "", "location_id": "neon_block_demo",
    "is_vendor": False, "vendor_id": "", "quest_ids": [], "required_flag": "",
    # No intro_lines: the first meeting plays this dialog graph (choices work).
    "dialog": [
        {"id": "greet", "text": "Hold it, chrome. You're standing on my inventory.", "next": "ask"},
        {"id": "ask", "text": "...You've got hands. Good. My knees don't do stairs anymore.",
         "choices": [{"text": "What do you need?", "next": "need"}, {"text": "Inventory?", "next": "inv"}]},
        {"id": "inv", "text": "Everything in this gutter is inventory if you squint. Even you.", "next": "need"},
        {"id": "need", "text": "Scrap wire and dead batteries. Three and two. Storm drains are full of both. Here — gin for the road."},
    ],
    "eavesdrop_lines": [
        {"text": "Ma Rivet, to a rat: 'You again. Rent's due, Gerald.'"},
        {"text": "Ma Rivet, sorting wire: 'Red to red, blue to blue, Doctrine cable to the gutter where it belongs.'"},
        {"text": "Ma Rivet, under her breath: 'Core relays in the Works hum in a three-four time. Always did.'"},
    ],
    "intro_lines": [],
    "repeat_lines": ["Wire, batteries, the usual. Nothing's free in the Void.",
                     "That shutter in the Supply Works? Hums on the same circuit as the core relays. Order matters, kid."],
    "give_item_id": "con_neon_gin", "give_item_qty": 1,
    "after_talk": "fetch",
    "fetch_items": {"mat_scrap_wire": 3, "mat_dead_battery": 2},
    "fetch_reward_coins_each": 40, "fetch_reward_items_each": {},
    "fetch_reward_coins_done": 120, "fetch_reward_chips_done": 2, "fetch_reward_items_done": {"acc_jump_boots": 1},
    "closing_lines": ["Now scram. You're scaring off the rats, and the rats are customers."],
}
# Appended as text so the hand-formatted npcs.json keeps its layout.
src = open("data/npcs.json").read().rstrip()
cut = src.find(',\n\t{\n\t\t"id": "%s"' % npc["id"])
if cut >= 0:
    src = src[:cut] + "\n]"
if True:
    entry = json.dumps(npc, indent="\t", ensure_ascii=False).replace("\n", "\n\t")
    open("data/npcs.json", "w").write(src[:-1].rstrip() + ",\n\t" + entry + "\n]\n")

block = json.load(open("data/maps/neon_block_demo.json"))
block["anchors"] = [
    {"id": "anc_neon_block_demo_1", "cell": [8, 7], "kind": "npc", "npc_id": "ma_rivet", "label": "Ma Rivet",
     "hidden": False, "scope": "both", "ap": 0, "reach": 1, "once": False, "enabled": True, "requires_flag": "",
     "requires_item": "", "consume_item": False, "sequence": "", "step": 0, "actions": [], "fail_actions": []},
    {"id": "anc_neon_block_demo_2", "cell": [13, 6], "kind": "transition", "label": "Supply Works Vault (tactics demo)",
     "hidden": False, "scope": "explore", "ap": 0, "reach": 0, "once": False, "enabled": True, "requires_flag": "",
     "requires_item": "", "consume_item": False, "sequence": "", "step": 0,
     "actions": [{"do": "battle", "arg": "demo_vault_breach"}], "fail_actions": []},
    {"id": "anc_neon_block_demo_3", "cell": [0, 7], "kind": "loot", "label": "Storm Drain", "hidden": True,
     "scope": "both", "ap": 0, "reach": 0, "once": True, "enabled": True, "requires_flag": "", "requires_item": "",
     "consume_item": False, "sequence": "", "step": 0,
     "actions": [{"do": "give", "arg": "mat_scrap_wire:3"}, {"do": "give", "arg": "mat_dead_battery:2"}], "fail_actions": []},
]
open("data/maps/neon_block_demo.json", "w").write(json.dumps(block, indent="\t") + "\n")
print("Ma Rivet (fetch quest) + vault entrance + hidden storm drain added to neon_block_demo")
