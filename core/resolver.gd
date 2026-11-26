extends RefCounted
## Pure spin resolution. `resolve_spin(felt, pocket)` never mutates `felt`; it works on a copy
## and returns the result plus the resulting felt (`felt_after`).
##
## Fixed resolution order, shown to the player:
##   1. base     - every chip covering the pocket scores value x payout; losing bets leave
##   2. upgrades - felt upgrades (Gilded, Hot, Double Felt, Pinned, Neighbour Link)
##   3. chips    - chip effects (Magnet slides as the ball drops, Croupier, Ledger, Mint, ...)
##   4. rules    - House Rules multiply the spin's Take; Enforcer twists
##
## Outputs: `take` (score added this spin), `stack` (betting chips returned to the stack:
## winning stakes, pushes, La Partage halves), `cash`, `respins`.
## A betting chip's net result is take + stake back - stake, so a plain bet is exactly
## fair-minus-zeros: -zeros / pockets per unit.

const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")

const STAGES := ["base", "upgrades", "chips", "rules"]


static func resolve_spin(felt, pocket: int) -> Dictionary:
	var w = felt.copy()
	var B = w.board
	var res := {
		"pocket": pocket, "take": 0.0, "gross": 0.0, "lost": 0, "stack": 0, "cash": 0, "respins": 0,
		"zero_tax": false, "red_streak": felt.red_streak, "hit_streak": felt.hit_streak, "effects": [], "events": [],
		"log": {"base": [], "upgrades": [], "chips": [], "rules": []},
		"felt_after": w,
	}
	var zero_hit: bool = B.is_zero(pocket)
	var pkey := Board.straight_key(pocket)

	# Magnets slide as the ball drops.
	for c in w.chips:
		if c.kind == "magnet" and Board.is_straight(c.bet):
			var n := Board.straight_number(c.bet)
			if n != pocket and pocket in B.neighbours(n):
				res.effects.append({"type": "move", "id": c.id, "from": c.bet, "to": pkey})
				res.log.chips.append("Magnet slides from %s onto %s" % [B.label(n), B.label(pocket)])
				c.bet = pkey

	var wildcards := 0
	for c in w.chips:
		if c.kind == "wildcard_zero":
			wildcards += 1

	var take := 0.0
	var lost := 0
	var hits := []
	for c in w.chips.duplicate():
		var b: Dictionary = B.bet(c.bet)
		var covers: bool = pocket in b.numbers
		var outside: bool = B.is_outside(c.bet)
		var dead: bool = (w.boss_rule == "no_outside" and outside) or c.id == w.frozen_id
		if c.is_bet():
			if covers and not dead:
				var amt := _score(w, c, b, pocket, res)
				take += amt
				_event(res, "win", c.bet, amt, "straight" if b.type == "straight" else b.type)
				res.stack += c.value
				_remove(res, w, c, "won")
			elif zero_hit and outside and wildcards > 0:
				res.stack += c.value
				res.log.chips.append("Wildcard Zero: %s bet pushes" % c.bet)
				_event(res, "push", c.bet, 0.0, "push")
				_remove(res, w, c, "push")
			elif zero_hit and B.is_even_money(c.bet) and w.has_rule("en_prison"):
				res.log.rules.append("En Prison: %s bet stays for the next spin" % c.bet)
				_event(res, "push", c.bet, 0.0, "en prison")
			elif zero_hit and B.is_even_money(c.bet) and w.has_rule("la_partage"):
				var back: int = c.value / 2
				res.stack += back
				lost += c.value - back
				res.log.rules.append("La Partage: %d of %s bet returned" % [back, c.bet])
				_event(res, "loss", c.bet, -(c.value - back), "half back")
				_remove(res, w, c, "half")
			else:
				lost += c.value
				_event(res, "loss", c.bet, -c.value, "")
				_remove(res, w, c, "lost")
			continue
		if not covers:
			continue
		if dead:
			res.log.rules.append("%s chip on %s pays nothing (Enforcer)" % [c.kind, c.bet])
			_event(res, "push", c.bet, 0.0, "frozen" if c.id == w.frozen_id else "off the books")
			continue
		var pamt := _score(w, c, b, pocket, res)
		take += pamt
		_event(res, "win", c.bet, pamt, "straight" if b.type == "straight" else b.type)
		hits.append(c)
	if lost > 0:
		res.log.base.append("%d betting chips lost" % lost)

	# Neighbour Link.
	if w.square_upgrades.get(pocket, "") == "link":
		for m in B.neighbours(pocket):
			for c in w.chips_on(Board.straight_key(m)):
				var amt: float = c.value * B.bet(Board.straight_key(m)).payout * Content.LINK_SHARE
				take += amt
				res.log.upgrades.append("Link: chip on %s scores %.1f" % [B.label(m), amt])
				_event(res, "bonus", Board.straight_key(m), amt, "link")

	# Chip effects.
	var kings := 0
	for c in hits:
		match c.kind:
			"bridge":
				var nb: float = Content.BRIDGE_PER_NUMBER * B.bet(c.bet).numbers.size()
				take += nb
				res.log.chips.append("Bridge: +%d for %d numbers" % [int(nb), B.bet(c.bet).numbers.size()])
				_event(res, "bonus", c.bet, nb, "bridge")
			"kingmaker":
				kings += 1
			"croupier":
				if lost > 0:
					take += lost
					res.log.chips.append("Croupier rakes %d losing chips: +%d" % [lost, lost])
					_event(res, "bonus", c.bet, lost, "rake")
			"ledger":
				for m in B.neighbours(pocket):
					for pc in w.chips_on(Board.straight_key(m)):
						if not pc.is_bet():
							_value(res, pc, 1)
							res.log.chips.append("Ledger: chip on %s grows to %d" % [B.label(m), pc.value])
			"respin":
				res.respins += 1
				res.log.chips.append("Respin: +1 spin")
			"collector":
				var bonus := _collector_bonus(w, c)
				if bonus > 0:
					take += bonus
					res.log.chips.append("Collector: +%d for crowding" % bonus)
					_event(res, "bonus", c.bet, bonus, "collector")
	if zero_hit and wildcards > 0:
		take += Content.WILDCARD_BONUS * wildcards
		res.log.chips.append("Wildcard Zero: +%d" % int(Content.WILDCARD_BONUS * wildcards))
		for c in w.chips:
			if c.kind == "wildcard_zero":
				_event(res, "bonus", c.bet, Content.WILDCARD_BONUS, "wildcard")
	if zero_hit:
		for c in w.perm_chips():
			if c.flaw == "hot":
				res.log.chips.append("Hot chip on %s confiscated by the house" % c.bet)
				_event(res, "loss", c.bet, 0.0, "confiscated")
				_remove(res, w, c, "confiscated")
	for c in w.perm_chips():
		if c.kind == "mint":
			res.cash += 1
			res.log.chips.append("Mint: +$1")
			_event(res, "cash", c.bet, 1, "mint")
		elif c.kind == "compounding":
			_value(res, c, 1)
			res.log.chips.append("Compounding on %s grows to %d" % [c.bet, c.value])

	# House Rules multiply the spin.
	if w.has_rule("red_streak"):
		if pocket > 0 and B.is_red(pocket):
			var m: float = 1.0 + Content.RED_STREAK_STEP * felt.red_streak
			if m > 1.0 and take > 0.0:
				res.log.rules.append("Red Streak x%.1f" % m)
				_mult(res, m, "Red Streak")
			take *= m
			res.red_streak = felt.red_streak + 1
		else:
			res.red_streak = 0
	if w.has_rule("hot_hand") and pocket == felt.last_pocket and take > 0.0:
		take *= Content.HOT_HAND_MULT
		res.log.rules.append("Hot Hand: %s again! x3" % B.label(pocket))
		_mult(res, Content.HOT_HAND_MULT, "Hot Hand")
	if w.has_rule("dealer_signature") and felt.last_pocket != -99 and take > 0.0 \
			and B.wheel_distance(pocket, felt.last_pocket) <= Content.SIGNATURE_RANGE:
		take *= 1.0 + Content.SIGNATURE_BONUS
		res.log.rules.append("Dealer's Signature: +50%")
		_mult(res, 1.0 + Content.SIGNATURE_BONUS, "Signature")
	for k in range(kings):
		if take > 0.0:
			take *= Content.KINGMAKER_MULT
			res.log.chips.append("Kingmaker x%.1f" % Content.KINGMAKER_MULT)
			_mult(res, Content.KINGMAKER_MULT, "Kingmaker")
	res.hit_streak = felt.hit_streak
	if w.has_rule("momentum"):
		if take > lost:
			var mm: float = 1.0 + Content.MOMENTUM_STEP * felt.hit_streak
			if mm > 1.0:
				take *= mm
				res.log.rules.append("Momentum x%.2f" % mm)
				_mult(res, mm, "Momentum")
			res.hit_streak = felt.hit_streak + 1
		else:
			res.hit_streak = 0
	if zero_hit and w.boss_rule == "zero_tax":
		res.zero_tax = true
		res.log.rules.append("Madame Oro takes her cut")

	# Take is what the spin paid minus what it cost you: hedging both colours scores nothing.
	w.red_streak = res.red_streak
	w.hit_streak = res.hit_streak
	w.last_pocket = pocket
	res.gross = take
	res.lost = lost
	res.take = maxf(0.0, take - lost)
	if lost > 0 and take > 0.0:
		res.log.base.append("Net of %d lost: %s" % [lost, _fmt(res.take)])
	return res


## Scoring events in resolution order, for the UI's count-up.
##   kind: win | bonus | loss | push | cash | mult
static func _event(res: Dictionary, kind: String, key: String, amount: float, label: String) -> void:
	res.events.append({"kind": kind, "key": key, "amount": amount, "label": label})


static func _mult(res: Dictionary, m: float, label: String) -> void:
	res.events.append({"kind": "mult", "key": "", "amount": m, "label": label})


## Average over every pocket on the wheel.
##   take: expected score per spin (net of that spin's losses, floored at 0)
##   net:  expected (payouts + stake returned - stakes); a plain bet reads exactly -zeros/pockets
static func expected_value(felt) -> Dictionary:
	var t := 0.0
	var g := 0.0
	var s := 0.0
	var cash := 0.0
	var pockets: Array = felt.board.pockets
	for p in pockets:
		var r := resolve_spin(felt, p)
		t += r.take
		g += r.gross
		s += r.stack
		cash += r.cash
	var n := float(pockets.size())
	return {"take": t / n, "net": (g + s) / n - felt.bet_stakes(), "cash": cash / n}


static func log_lines(res: Dictionary) -> Array:
	var out := []
	for s in STAGES:
		for line in res.log[s]:
			out.append("[%s] %s" % [s, line])
	return out


## Score one covering chip: base payout, then felt upgrades, then Thirteen.
static func _score(w, c, b: Dictionary, pocket: int, res: Dictionary) -> float:
	var B = w.board
	var straight: bool = b.type == "straight"
	var payout: float = b.payout
	var up: String = w.square_upgrades.get(pocket, "")
	var base: float = c.value * payout
	res.log.base.append("%s x%d on %s pays %s:1 = %s" % [c.kind, c.value, c.bet, _fmt(payout), _fmt(base)])
	if straight and up == "gilded":
		payout *= 8.0 / 7.0
		res.log.upgrades.append("Gilded %s: pays %s:1" % [B.label(pocket), _fmt(payout)])
	if w.bet_upgrades.get(c.bet, "") == "hot":
		payout += 1.0
		res.log.upgrades.append("Hot %s: +1x" % c.bet)
	if w.has_rule("split_decision") and b.type in Board.LINE_TYPES:
		payout += 1.0
		res.log.rules.append("Split Decision: %s +1x" % c.bet)
	var amount: float = c.value * payout
	if b.type in Board.LINE_TYPES and up == "cornerstone":
		amount *= 2.0
		res.log.upgrades.append("Cornerstone %s: x2" % B.label(pocket))
	if c.flaw == "cracked":
		amount *= 0.5
		res.log.chips.append("Cracked chip on %s scores half" % c.bet)
	if straight and up == "double_felt":
		amount *= 2.0
		res.log.upgrades.append("Double Felt: x2")
	if b.type == "sector" and up == "pinned":
		amount *= 2.0
		res.log.upgrades.append("Pinned Pocket: call bet x2")
	if w.has_rule("thirteen") and straight and B.numbers >= 13:
		if pocket == 13:
			res.log.rules.append("Thirteen: cursed, pays nothing")
			return 0.0
		if 13 in B.neighbours(pocket):
			amount *= 2.0
			res.log.rules.append("Thirteen's neighbour: x2")
	return amount


static func _collector_bonus(w, chip) -> int:
	var B = w.board
	var n := Board.straight_number(chip.bet)
	if n <= 0:
		return 0
	var total := 0
	for c in w.perm_chips():
		if c.id == chip.id or not Board.is_straight(c.bet):
			continue
		var m := Board.straight_number(c.bet)
		if m > 0 and (B.dozen_of(m) == B.dozen_of(n) or Board.grid_row(m) == Board.grid_row(n)):
			total += c.value
	return total


static func _remove(res: Dictionary, w, c, why: String) -> void:
	res.effects.append({"type": "remove", "id": c.id, "reason": why})
	w.remove(c.id)


static func _value(res: Dictionary, c, delta: int) -> void:
	c.value += delta
	res.effects.append({"type": "value", "id": c.id, "delta": delta})


static func _fmt(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.2f" % x
