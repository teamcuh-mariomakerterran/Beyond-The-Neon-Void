class_name Additions
extends RefCounted
## Sync Blade "Additions": Legend of Dragoon-style timed attack chains.
##
## An ability with an `addition` dict plays a rhythm of beats. Each beat hit
## inside the window adds a strike; a miss (or a press at the wrong moment)
## ends the chain. Land every beat and the finisher fires. Chains master with
## use: more damage and a slightly wider window.

const MAX_MASTERY := 5
const USES_PER_LEVEL := 15
const AUTO_RATIO := 0.7


static func beats(ability: Ability) -> Array:
	return ability.addition.get("beats", [0.0])


static func mastery(character: CharacterData, ability_id: String) -> int:
	if character == null:
		return 1
	return clampi(1 + int(character.addition_uses.get(ability_id, 0)) / USES_PER_LEVEL, 1, MAX_MASTERY)


static func record_use(character: CharacterData, ability_id: String) -> void:
	if character:
		character.addition_uses[ability_id] = int(character.addition_uses.get(ability_id, 0)) + 1


## Press window (seconds either side of a beat); mastery widens it a little.
static func window(ability: Ability, level: int) -> float:
	return float(ability.addition.get("window", 0.13)) + 0.012 * (level - 1)


## Damage multiplier for `hits` landed out of the chain's beats.
## 0 hits = a glancing 0.5; each hit adds per_hit; a full chain adds the finisher.
static func multiplier(ability: Ability, hits: int, level: int = 1) -> float:
	var n := beats(ability).size()
	hits = clampi(hits, 0, n)
	var m := 0.5 + float(ability.addition.get("per_hit", 0.3)) * hits
	if hits == n:
		m += float(ability.addition.get("finisher", 0.6))
	return m * (1.0 + 0.08 * (level - 1))


## What "auto" mode (and the AI) lands: ~70% of the beats, never the finisher.
static func auto_hits(ability: Ability) -> int:
	var n := beats(ability).size()
	return mini(int(floor(n * AUTO_RATIO)), n - 1) if n > 1 else 1


## Grades a press at time `t` against the chain: returns the beat index it hit,
## or -1 for a miss. `next` is the beat the player is on.
static func judge(ability: Ability, level: int, next: int, t: float) -> int:
	var b := beats(ability)
	if next >= b.size():
		return -1
	return next if absf(t - float(b[next])) <= window(ability, level) else -1
