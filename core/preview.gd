extends RefCounted
## "What if" previews built from Resolver dry-runs (never mutate the felt):
##   fires_at        - if this pocket hits, which bet areas score and how much
##   pays_on         - the pockets where a chip (placed on a given square) adds something
##   ev_gain_*       - how much an item would add to the average spin with your current felt
##   clearing_pockets - the pockets that would pay the rest of the table in one spin
## Used by the felt hover, the Cage hints and the payment-first HUD.

const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const Resolver := preload("res://core/resolver.gd")


## Results are cached by the felt's state, so hovering back and forth (and the per-refresh
## "could clear" rings) don't re-run dozens of spin resolutions on slow devices.
static var _cache := {}
const CACHE_MAX := 256


static func signature(felt) -> String:
	var parts := []
	for c in felt.chips:
		parts.append("%s:%s:%d:%s:%s:%d" % [c.kind, c.bet, c.value, c.flaw, c.mod, c.copies])
	var all := [felt.board.wheel_id, ",".join(parts), ",".join(felt.house_rules), ",".join(felt.wheel_rules),
		felt.square_upgrades, felt.bet_upgrades, felt.boss_rule, felt.condition, felt.frozen_id,
		felt.red_streak, felt.hit_streak, felt.last_pocket, felt.spin_no, felt.final_spin,
		felt.weights, felt.arc_start, felt.extra_ball, felt.second_wind_used, felt.ovation_used]
	return "|".join(all.map(func(x): return str(x)))


static func _cached(key: String, make: Callable):
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	var v = make.call()
	_cache[key] = v
	return v


## If `pocket` hits: {keys (bet areas that score or trigger), take, cash}.
static func fires_at(felt, pocket: int) -> Dictionary:
	return _cached("f%d#%s" % [pocket, signature(felt)], func(): return _fires_at(felt, pocket))


static func _fires_at(felt, pocket: int) -> Dictionary:
	var r := Resolver.resolve_spin(felt, pocket)
	var keys := {}
	for e in r.events:
		if e.key != "" and e.kind in ["win", "bonus", "cash"]:
			keys[e.key] = true
	return {"keys": keys.keys(), "take": r.take, "cash": r.cash}


## Pockets where adding chip `kind` on `key` gives more Take, cash or levels than without it.
static func pays_on(felt, kind: String, key: String, value: int = 1, flaw: String = "") -> Array:
	return _cached("p%s/%s/%d/%s#%s" % [kind, key, value, flaw, signature(felt)], func(): return _pays_on(felt, kind, key, value, flaw))


static func _pays_on(felt, kind: String, key: String, value: int = 1, flaw: String = "") -> Array:
	var with = felt.copy()
	with.add_chip(kind, key, value, flaw)
	var out := []
	for p in felt.board.pockets:
		var a := Resolver.resolve_spin(felt, p)
		var b := Resolver.resolve_spin(with, p)
		var grew := false
		for e in b.effects:
			if e.type == "value" and e.delta > 0:
				grew = true
		if _gross(b) > _gross(a) + 0.001 or b.cash > a.cash or grew:
			out.append(p)
	return out


## What a spin paid before losses are netted off (so a chip's bonus still shows on a spin
## where other bets lose more than it adds).
static func _gross(r: Dictionary) -> float:
	var g := 0.0
	var m := 1.0
	for e in r.events:
		if e.kind in ["win", "bonus"]:
			g += e.amount
		elif e.kind == "mult":
			m *= e.amount
	return g * m


## Pockets where an existing chip (by id) pays: the felt with and without it.
static func chip_pays_on(felt, chip_id: int) -> Array:
	var c = felt.find(chip_id)
	if c == null:
		return []
	var without = felt.copy()
	without.remove(chip_id)
	return pays_on(without, c.kind, c.bet, c.value, c.flaw)


## A legal square to imagine a chip on (for previews before it's placed).
static func rep_key(felt, kind: String) -> String:
	var spec: Dictionary = Content.CHIPS.get(kind, {})
	var B = felt.board
	if spec.get("zero_only", false):
		return Board.straight_key(B.zeros[0]) if not B.zeros.is_empty() else ""
	if spec.get("line_only", false):
		return "CO1" if B.has_bet("CO1") else "SP1_2"
	if spec.get("even_only", false):
		return "RED"
	if spec.get("box_only", false):
		return "RED"
	if spec.get("coldoz_only", false):
		return "COL1"
	if spec.get("column_only", false):
		return "COL1"
	if spec.get("black_only", false):
		for n in range(1, B.numbers + 1):
			if not B.is_red(n):
				return Board.straight_key(n)
	return "S1"


## Triggers whose pockets don't depend on where the chip sits (safe to preview from the Cage).
static func absolute_trigger(kind: String) -> bool:
	var t: Dictionary = Content.CHIPS.get(kind, {}).get("trigger", {})
	return not t.is_empty() and t.on in ["odd", "even", "low", "high", "set", "zero"]


## Average extra Take per spin from adding a House Rule to your felt as it stands.
static func ev_gain_rule(felt, rule: String) -> float:
	if rule in felt.house_rules:
		return 0.0
	var with = felt.copy()
	with.house_rules.append(rule)
	return Resolver.expected_value(with).take - Resolver.expected_value(felt).take


## Average extra Take per spin from adding chip `kind` on `key`.
static func ev_gain_chip(felt, kind: String, key: String) -> float:
	if key == "":
		return 0.0
	var with = felt.copy()
	with.add_chip(kind, key, 1)
	return Resolver.expected_value(with).take - Resolver.expected_value(felt).take


## Pockets whose spin alone would pay the remaining `need`.
static func clearing_pockets(felt, need: float) -> Array:
	return _cached("c%s#%s" % [str(need), signature(felt)], func(): return _clearing_pockets(felt, need))


static func _clearing_pockets(felt, need: float) -> Array:
	var out := []
	if need <= 0.0:
		return out
	for p in felt.board.pockets:
		if Resolver.resolve_spin(felt, p).take >= need:
			out.append(p)
	return out


## The felt as it would stand at the next table if you re-laid `bets` (key -> chips).
static func with_layout(felt, bets: Dictionary):
	var f = felt.copy()
	for k in bets:
		if f.board.has_bet(k) and bets[k] > 0:
			f.add_chip("bet", k, bets[k])
	return f


## Loadout-aware lines for a Cage item: what it would add to your felt and last layout.
## Returns {lines: Array[String], pockets: Array} (pockets to light on the Cage felt).
static func cage_hints(run, item: Dictionary) -> Dictionary:
	var out := {"lines": [], "pockets": []}
	var f = with_layout(run.felt, run.last_bets)
	var have_layout: bool = not run.last_bets.is_empty()
	match item.type:
		"rule":
			if not have_layout:
				return out
			var g := ev_gain_rule(f, item.id)
			if absf(g) >= 0.05:
				out.lines.append("With your last layout: %s%.1f Take a spin on average." % ["+" if g > 0 else "", g])
			else:
				out.lines.append("Does little for your last layout.")
		"chip":
			var kind: String = item.id
			if absolute_trigger(kind):
				var key := rep_key(f, kind)
				out.pockets = pays_on(f, kind, key)
				out.lines.append("Pays on %d of %d pockets (lit on the felt): about +%.1f Take a spin." % [out.pockets.size(), f.board.pockets.size(), ev_gain_chip(f, kind, key)])
			elif have_layout:
				var best := ""
				var best_g := 0.0
				for k in run.last_bets:
					if run.can_place_chip(kind, k):
						var g := ev_gain_chip(f, kind, k)
						if g > best_g:
							best_g = g
							best = k
				if best != "":
					var B = f.board
					var where: String = B.label(Board.straight_number(best)) if Board.is_straight(best) else best
					out.lines.append("Best on your %s bet: about +%.1f Take a spin." % [where, best_g])
					out.pockets = pays_on(f, kind, best)
	return out
