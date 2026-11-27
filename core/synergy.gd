extends RefCounted
## Named combos: groups of items that feed each other. A combo is ACTIVE when you own at least one
## item from each of its parts, and FIRES on a spin when every part did something in it (read
## from the spin's log lines, which name the item that acted). The table shows active combos
## under the House Rules and bannering the name when one fires; the Cage says which item would
## complete one.

const Content := preload("res://core/content.gd")

const COMBOS := [
	{"id": "encore_chain", "name": "ENCORE CHAIN", "desc": "Extra balls feed Encore and Wind-Up.",
		"parts": [["respin", "second_wind"], ["encore", "wind_up"]]},
	{"id": "skyscraper", "name": "SKYSCRAPER", "desc": "Tall stacks scored by High Rise or Old Timers.",
		"parts": [["high_rise", "veterans"], ["keystone", "tall_stack", "compounding", "snowball", "seedling", "jar"]]},
	{"id": "long_odds", "name": "LONG ODDS", "desc": "An Odds Maker boosting a box you also build on.",
		"parts": [["odds_maker"], ["even_stevens", "box_office", "streak_rider", "coin_purse"]]},
	{"id": "growth_engine", "name": "GROWTH ENGINE", "desc": "Chips that grow other chips, and chips that love growing.",
		"parts": [["echo", "ledger", "fuse", "diamond"], ["compounding", "snowball", "seedling", "jar", "keystone"]]},
	{"id": "crown_jewels", "name": "CROWN JEWELS", "desc": "Multiplier chips set off together by a Conductor.",
		"parts": [["conductor"], ["kingmaker", "ace", "crown"]]},
	{"id": "house_of_zero", "name": "HOUSE OF ZERO", "desc": "Zero chips paid twice over by zero rules.",
		"parts": [["sentinel", "wildcard_zero", "green_thumb", "spare_key"], ["oros_coin", "zero_tolerance"]]},
]


## Every item id you own: chip kinds on the felt, House Rules (yours and the wheel's), felt upgrades.
static func owned(felt) -> Dictionary:
	var out := {}
	for c in felt.perm_chips():
		out[c.kind] = true
	for r in felt.house_rules + felt.wheel_rules:
		out[r] = true
	for u in felt.square_upgrades.values() + felt.bet_upgrades.values():
		out[u] = true
	return out


static func _active_in(have: Dictionary) -> Array:
	var out := []
	for c in COMBOS:
		if c.parts.all(func(part): return part.any(func(id): return have.has(id))):
			out.append(c)
	return out


## The combos your build has switched on.
static func active(felt) -> Array:
	return _active_in(owned(felt))


## Combos that owning `id` as well would switch on (for the Cage).
static func completes(felt, id: String) -> Array:
	var have := owned(felt)
	var before: Array = _active_in(have).map(func(c): return c.id)
	have[id] = true
	return _active_in(have).filter(func(c): return c.id not in before)


## Combos that fired in this spin: every part had an item act (it's named in the spin's log).
static func fired(felt, res: Dictionary) -> Array:
	var text := ""
	for st in res.get("log", {}).values():
		for line in st:
			text += str(line).to_lower() + "\n"
	var out := []
	for c in active(felt):
		if c.parts.all(func(part): return part.any(func(id): return text.contains(_name(id).to_lower()))):
			out.append(c)
	return out


## "Respin or Second Wind + Encore or Wind-Up": what a combo is made of, for its card.
static func parts_text(c: Dictionary) -> String:
	return " + ".join(c.parts.map(func(part): return " or ".join(part.map(func(id): return _name(id)))))


static func _name(id: String) -> String:
	for t in [Content.CHIPS, Content.HOUSE_RULES, Content.UPGRADES]:
		if t.has(id):
			return t[id].name
	return id
