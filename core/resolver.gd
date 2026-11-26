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
	var biggest_loss := 0
	var lost_chips := 0
	var hits := []
	for c in w.chips.duplicate():
		var b: Dictionary = B.bet(c.bet)
		var covers: bool = pocket in b.numbers
		var mirrored := false
		if not covers and c.kind == "mirror" and Board.is_straight(c.bet) and pocket > 0 \
				and pocket == B.numbers + 1 - Board.straight_number(c.bet):
			covers = true
			mirrored = true
		var outside: bool = B.is_outside(c.bet)
		var dead: bool = (w.boss_is("no_outside") and outside) or (w.boss_is("no_inside") and B.is_line_bet(c.bet)) \
				or c.id == w.frozen_id
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
			elif w.bet_upgrades.get(c.bet, "") == "silk":
				res.stack += c.value
				res.log.upgrades.append("Silk Box: %s bet goes back to the stack" % c.bet)
				_event(res, "push", c.bet, 0.0, "silk")
				_remove(res, w, c, "push")
			else:
				lost += c.value
				lost_chips += c.value
				biggest_loss = maxi(biggest_loss, c.value)
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
		_event(res, "win", c.bet, pamt, "mirror" if mirrored else ("straight" if b.type == "straight" else b.type))
		if mirrored:
			res.log.chips.append("Mirror on %s catches %s" % [c.bet, B.label(pocket)])
		hits.append(c)
	# Porch Light: half a straight when the ball lands one pocket away on the wheel.
	for c in w.perm_chips():
		if c.kind == "porch_light" and Board.is_straight(c.bet):
			var pn := Board.straight_number(c.bet)
			if pn != pocket and B.wheel_distance(pn, pocket) == 1 and c.id != w.frozen_id:
				var pl: float = c.value * B.bet(c.bet).payout * Content.PORCH_SHARE
				if c.flaw == "cracked":
					pl *= 0.5
				take += pl
				res.log.chips.append("Porch Light on %s: neighbour %s, +%s" % [B.label(pn), B.label(pocket), _fmt(pl)])
				_event(res, "bonus", c.bet, pl, "porch light")
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
	var kings := []
	var crowns := []
	var aces := []
	for c in hits:
		match c.kind:
			"bridge":
				var nb: float = Content.BRIDGE_PER_NUMBER * B.bet(c.bet).numbers.size() * c.value
				take += nb
				res.log.chips.append("Bridge: +%d for %d numbers" % [int(nb), B.bet(c.bet).numbers.size()])
				_event(res, "bonus", c.bet, nb, "bridge")
			"kingmaker":
				kings.append(c.value)
			"crown":
				crowns.append(c.value)
			"penny":
				res.cash += Content.PENNY_CASH * c.value
				res.log.chips.append("Lucky Penny: +$%d" % (Content.PENNY_CASH * c.value))
				_event(res, "cash", c.bet, Content.PENNY_CASH * c.value, "penny")
			"snowball":
				_value(res, c, 2)
				res.log.chips.append("Snowball on %s grows to %d" % [c.bet, c.value])
			"jar":
				if c.value > 1:
					res.log.chips.append("Jackpot Jar on %s pays out and empties" % c.bet)
					_value(res, c, 1 - c.value)
			"echo":
				for oc in w.perm_chips():
					if oc.id != c.id:
						_value(res, oc, 1)
				res.log.chips.append("Echo: every other permanent chip gains a level")
			"ace":
				aces.append(c.value)
			"signpost":
				res.cash += Content.SIGNPOST_CASH * c.value
				res.log.chips.append("Signpost: +$%d" % (Content.SIGNPOST_CASH * c.value))
				_event(res, "cash", c.bet, Content.SIGNPOST_CASH * c.value, "signpost")
			"croupier":
				if lost > 0:
					take += lost * c.value
					res.log.chips.append("Croupier rakes %d losing chips: +%d" % [lost, lost * c.value])
					_event(res, "bonus", c.bet, lost * c.value, "rake")
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
	for c in w.perm_chips():
		if c.id == w.frozen_id:
			continue
		var crack: float = 0.5 if c.flaw == "cracked" else 1.0
		var own: int = Board.straight_number(c.bet) if Board.is_straight(c.bet) else -99
		var covered: bool = pocket in B.bet(c.bet).numbers
		match c.kind:
			"street_light":
				if own > 0 and pocket > 0 and pocket != own and Board.grid_col(pocket) == Board.grid_col(own):
					_bonus(res, c, Content.STREET_LIGHT_BONUS * c.value * crack, "street light")
					take += Content.STREET_LIGHT_BONUS * c.value * crack
			"red_herring":
				if pocket > 0 and B.is_red(pocket):
					_bonus(res, c, Content.RED_HERRING_BONUS * c.value * crack, "red herring")
					take += Content.RED_HERRING_BONUS * c.value * crack
			"hedge":
				if not covered:
					_bonus(res, c, Content.HEDGE_BONUS * c.value * crack, "hedge")
					take += Content.HEDGE_BONUS * c.value * crack
			"wheel_spoke":
				if own >= 0 and pocket != own:
					var wd: int = B.wheel_distance(own, pocket)
					if wd >= 1 and wd <= 2:
						_bonus(res, c, Content.SPOKE_CHIP_BONUS * c.value * crack, "wheel spoke")
						take += Content.SPOKE_CHIP_BONUS * c.value * crack
			"jar":
				if not covered:
					_value(res, c, 1)
			"green_thumb":
				if zero_hit:
					_value(res, c, 1)
					res.log.chips.append("Green Thumb grows to %d" % c.value)
			"tip_jar":
				var tips: int = mini(Content.TIP_JAR_CAP, lost_chips) * c.value
				if tips > 0:
					res.cash += tips
					_event(res, "cash", c.bet, tips, "tip jar")
		# Felt upgrades that let a square's chips catch nearby balls.
		if own > 0 and own != pocket:
			var sq: String = w.square_upgrades.get(own, "")
			var part := 0.0
			if sq == "magnetized" and pocket in B.neighbours(own):
				part = c.value * B.bet(c.bet).payout * 0.5 * crack
			elif sq == "twin_square" and pocket > 0 and pocket == B.numbers + 1 - own:
				part = c.value * B.bet(c.bet).payout * crack
			if part > 0.0:
				take += part
				_bonus(res, c, part, sq.replace("_", " "))
		if c.kind == "black_cat" and pocket > 0 and not B.is_red(pocket):
			var bc: float = Content.BLACK_CAT_BONUS * c.value * (0.5 if c.flaw == "cracked" else 1.0)
			take += bc
			res.log.chips.append("Black Cat: black %s, +%s" % [B.label(pocket), _fmt(bc)])
			_event(res, "bonus", c.bet, bc, "black cat")
		elif c.kind == "sentinel" and zero_hit:
			var sb: float = Content.SENTINEL_BONUS * c.value * (0.5 if c.flaw == "cracked" else 1.0)
			take += sb
			res.log.chips.append("Sentinel: +%s on the zero" % _fmt(sb))
			_event(res, "bonus", c.bet, sb, "sentinel")
	if w.square_upgrades.get(pocket, "") == "spoke":
		var idx: int = B.order.find(pocket)
		for d in [-1, 1]:
			var nb: int = B.order[(idx + d + B.order.size()) % B.order.size()]
			for c in w.chips_on(Board.straight_key(nb)):
				if not c.is_bet():
					var sp: float = c.value * B.bet(c.bet).payout * 0.5
					take += sp
					_bonus(res, c, sp, "spoke")
	if w.square_upgrades.get(pocket, "") == "diamond":
		for c in w.chips_on(pkey):
			if not c.is_bet():
				_value(res, c, 1)
				res.log.upgrades.append("Diamond Square: %s chip grows to %d" % [c.kind, c.value])
	if w.square_upgrades.get(pocket, "") == "lamp":
		res.cash += Content.LAMP_CASH
		res.log.upgrades.append("Lucky Lamp on %s: +$%d" % [B.label(pocket), Content.LAMP_CASH])
		_event(res, "cash", pkey, Content.LAMP_CASH, "lamp")
	if zero_hit:
		for c in w.perm_chips():
			if c.flaw == "hot":
				res.log.chips.append("Hot chip on %s confiscated by the house" % c.bet)
				_event(res, "loss", c.bet, 0.0, "confiscated")
				_remove(res, w, c, "confiscated")
	for c in w.perm_chips():
		if c.kind == "mint":
			res.cash += c.value
			res.log.chips.append("Mint: +$%d" % c.value)
			_event(res, "cash", c.bet, c.value, "mint")
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
	for av in aces:
		if take > 0.0:
			var am: float = 2.0 + 0.5 * (av - 1)
			take *= am
			res.log.chips.append("Ace of Spades x%.1f" % am)
			_mult(res, am, "Ace of Spades")
	for cv in crowns:
		if take > 0.0:
			var cm: float = Content.CROWN_MULT + 0.25 * (cv - 1)
			take *= cm
			res.log.chips.append("Column Crown x%.2f" % cm)
			_mult(res, cm, "Column Crown")
	if w.has_rule("last_call") and w.final_spin and take > 0.0:
		take *= 2.0
		res.log.rules.append("Last Call: the final spin scores double")
		_mult(res, 2.0, "Last Call")
	for kv in kings:
		if take > 0.0:
			var km: float = Content.KINGMAKER_MULT + Content.KING_STEP * (kv - 1)
			take *= km
			res.log.chips.append("Kingmaker x%.1f" % km)
			_mult(res, km, "Kingmaker")
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
	if zero_hit and w.boss_is("zero_tax"):
		res.zero_tax = true
		res.log.rules.append("Madame Oro takes her cut")

	# Take is what the spin paid minus what it cost you: hedging both colours scores nothing.
	w.red_streak = res.red_streak
	w.hit_streak = res.hit_streak
	w.last_pocket = pocket
	if w.has_rule("insurance") and biggest_loss > 0:
		lost -= biggest_loss
		res.log.rules.append("Insurance: the %d-chip loss doesn't count" % biggest_loss)
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


static func _bonus(res: Dictionary, c, amount: float, label: String) -> void:
	res.log.chips.append("%s on %s: +%s" % [label.capitalize(), c.bet, _fmt(amount)])
	_event(res, "bonus", c.bet, amount, label)


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
	if w.has_rule("satin_gloves") and b.type in ["red", "black", "odd", "even", "low", "high"]:
		payout += 0.5
		res.log.rules.append("Satin Gloves: %s pays 1.5:1" % c.bet)
	var bu: String = w.bet_upgrades.get(c.bet, "")
	if bu == "gold_trim":
		payout += 0.5
		res.cash += 1
		res.log.upgrades.append("Gold Trim %s: +0.5x and +$1" % c.bet)
	elif bu == "lucky_colour":
		payout += 1.0
		res.log.upgrades.append("Lucky Colour %s pays 2:1" % c.bet)
	if w.has_rule("high_society") and b.type in ["column", "dozen"]:
		payout += 1.0
		res.log.rules.append("High Society: %s +1x" % c.bet)
	if w.has_rule("split_decision") and b.type in Board.LINE_TYPES:
		payout += 1.0
		res.log.rules.append("Split Decision: %s +1x" % c.bet)
	var amount: float = c.value * payout
	if b.type in Board.LINE_TYPES and up == "cornerstone":
		amount *= 2.0
		res.log.upgrades.append("Cornerstone %s: x2" % B.label(pocket))
	if bu == "fat_box":
		amount += 2.0 * c.value
		res.log.upgrades.append("Fat Box %s: +%d" % [c.bet, 2 * c.value])
	elif bu == "repeat_box" and w.last_pocket in b.numbers:
		amount *= 2.0
		res.log.upgrades.append("Repeat Box %s: same box again, x2" % c.bet)
	if up == "sweet_spot":
		amount *= 1.5
		res.log.upgrades.append("Sweet Spot %s: x1.5" % B.label(pocket))
	if w.has_rule("black_tie") and straight and pocket > 0 and not B.is_red(pocket):
		amount *= 1.5
		res.log.rules.append("Black Tie: black %s x1.5" % B.label(pocket))
	if w.has_rule("sevens") and straight and pocket > 0 and "7" in B.label(pocket):
		amount *= 2.0
		res.log.rules.append("Lucky Sevens: %s x2" % B.label(pocket))
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
