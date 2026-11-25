extends RefCounted
## Pure spin resolution. `resolve_spin(felt, pocket)` never mutates `felt`; it works on a copy
## and returns the effects plus the resulting felt (`felt_after`).
##
## Fixed resolution order, shown to the player:
##   1. base     - who owns the pocket; base payouts, collections, captures, lost bets
##   2. upgrades - felt upgrades (Gilded, Hot, Neighbour Link)
##   3. chips    - chip effects (Magnet slides as the ball drops, Croupier, Ledger, Mint, ...)
##   4. rules    - House Rules, then House pressure (flanking, Pit Boss twists)
##
## Coin flows: `player` is the change to the player's bankroll, `bank` the change to the
## table's bank. Temp stakes were already taken from the bankroll when placed, so a lost temp
## bet only moves coins into the bank and a winning one returns the stake plus winnings.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")
const Content := preload("res://core/content.gd")

const PL := Chip.Side.PLAYER
const HO := Chip.Side.HOUSE
const STAGES := ["base", "upgrades", "chips", "rules"]


static func resolve_spin(felt, pocket: int) -> Dictionary:
	var w = felt.copy()
	var res := {
		"pocket": pocket, "player": 0, "bank": 0, "respins": 0,
		"red_streak": felt.red_streak, "owner": -1, "effects": [],
		"log": {"base": [], "upgrades": [], "chips": [], "rules": []},
		"felt_after": w,
	}
	var pkey := Board.straight_key(pocket)

	# --- Magnets slide as the ball drops (a chip effect that has to happen before payout).
	for c in w.chips:
		if c.side == PL and c.kind == "magnet" and Board.is_straight(c.bet):
			var n := Board.straight_number(c.bet)
			if n != pocket and pocket in Board.neighbours(n):
				res.effects.append({"type": "move", "id": c.id, "from": c.bet, "to": pkey})
				res.log.chips.append("Magnet slides from %d onto %d" % [n, pocket])
				c.bet = pkey

	var owner: int = w.owner(pocket)
	res.owner = owner
	var thirteen: bool = w.has_rule("thirteen")
	var void13 := thirteen and pocket == 13
	var boost13 := thirteen and (13 in Board.neighbours(pocket))
	var partage: bool = w.has_rule("la_partage") and pocket == 0
	var wildcard := false
	if pocket == 0:
		for c in w.chips_on("S0", PL):
			if c.kind == "wildcard_zero":
				wildcard = true
	var streak_mult := 1.0
	if w.has_rule("red_streak"):
		if pocket != 0 and Board.is_red(pocket):
			streak_mult = 1.0 + Content.RED_STREAK_STEP * felt.red_streak
			res.red_streak = felt.red_streak + 1
		else:
			res.red_streak = 0
	w.red_streak = res.red_streak

	# --- Player chips.
	var hits := []
	for c in w.chips.duplicate():
		if c.side != PL:
			continue
		var b: Dictionary = Board.bet(c.bet)
		var covers: bool = pocket in b.numbers
		var straight: bool = b.type == "straight"
		if not covers:
			if c.kind == "temp":
				if pocket == 0 and not straight and wildcard:
					_coins(res, c.value, 0, "chips", "Wildcard Zero: %s bet pushes" % c.bet)
				elif pocket == 0 and not straight and partage:
					var back: int = c.value / 2
					_coins(res, back, c.value - back, "rules", "La Partage: half of %s bet returned" % c.bet)
				else:
					_coins(res, 0, c.value, "base", "%s bet (%d) lost" % [c.bet, c.value])
				_remove(res, w, c, "lost")
			continue
		if owner == HO and c.kind == "wildcard_zero":
			continue  # it never pays, it only blocks the House on 0
		if owner == HO:
			_coins(res, 0, c.value, "base", "House holds %d: your %s chip on %s is seized" % [pocket, c.kind, c.bet])
			_remove(res, w, c, "seized")
			continue
		if void13 and straight:
			res.log.rules.append("Thirteen: 13 is cursed, your chip pays nothing")
			if c.kind == "temp":
				_coins(res, c.value, 0, "rules", "Stake returned on cursed 13")
				_remove(res, w, c, "push")
			continue
		var amount: int = c.value * int(b.payout)
		res.log.base.append("%s x%d on %s pays %d:1 = %d" % [c.kind, c.value, c.bet, b.payout, amount])
		if straight and w.square_upgrades.get(pocket, "") == "gilded":
			var gilded: int = c.value * Content.GILDED_PAYOUT
			res.log.upgrades.append("Gilded %d: +%d" % [pocket, gilded - amount])
			amount = gilded
		if w.bet_upgrades.get(c.bet, "") == "hot":
			amount += c.value
			res.log.upgrades.append("Hot %s: +%d" % [c.bet, c.value])
		if c.kind == "collector" and straight:
			var bonus := _collector_bonus(w, c)
			if bonus > 0:
				amount += bonus
				res.log.chips.append("Collector on %d: +%d for crowding" % [pocket, bonus])
		if streak_mult > 1.0:
			var boosted := int(round(amount * streak_mult))
			res.log.rules.append("Red Streak x%.1f: +%d" % [streak_mult, boosted - amount])
			amount = boosted
		if boost13 and straight:
			res.log.rules.append("Thirteen's neighbour pays double: +%d" % amount)
			amount *= 2
		_coins(res, amount, -amount, "", "")
		if c.kind == "temp":
			_coins(res, c.value, 0, "", "")
			_remove(res, w, c, "paid")
		else:
			hits.append(c)

	# --- House chips on the pocket.
	var house_here: Array = w.chips_on(pkey, HO)
	if not house_here.is_empty():
		var hv := 0
		for h in house_here:
			hv += h.value
		if owner == HO:
			if void13:
				res.log.rules.append("Thirteen: the House collects nothing on 13")
			elif wildcard:
				res.log.chips.append("Wildcard Zero: the House collects nothing on 0")
			else:
				var take := hv * 35
				res.log.base.append("House holds %d (x%d): collects %d" % [pocket, hv, take])
				if w.square_upgrades.get(pocket, "") == "gilded":
					var gt := hv * Content.GILDED_PAYOUT
					res.log.upgrades.append("Gilded %d pays the House too: +%d" % [pocket, gt - take])
					take = gt
				if w.has_rule("rent_control"):
					var cut := int(round(take * Content.RENT_CONTROL_CUT))
					take -= cut
					res.log.rules.append("Rent Control: -%d" % cut)
				if partage:
					res.log.rules.append("La Partage: House collection halved (-%d)" % (take - take / 2))
					take = take / 2
				_coins(res, -take, take, "", "")
		else:
			for h in house_here:
				_coins(res, h.value, -h.value, "base", "You capture %d: seize %d House chip value" % [pocket, h.value])
				_remove(res, w, h, "captured")

	# --- Neighbour Link.
	if w.square_upgrades.get(pocket, "") == "link" and owner != -1 and not void13:
		for m in Board.neighbours(pocket):
			for c in w.chips_on(Board.straight_key(m), owner):
				var amt := int(round(c.value * 35 * Content.LINK_SHARE))
				if owner == PL:
					_coins(res, amt, -amt, "upgrades", "Link: your chip on %d pays %d" % [m, amt])
				else:
					_coins(res, -amt, amt, "upgrades", "Link: House chip on %d collects %d" % [m, amt])

	# --- Chip effects for chips that hit.
	for c in hits:
		match c.kind:
			"croupier":
				for h in w.side_chips(HO):
					if h.bet == pkey:
						continue
					_value(res, w, h, -1)
					_coins(res, 1, -1, "", "")
				res.log.chips.append("Croupier rakes the House's missed chips")
			"ledger":
				for m in Board.neighbours(pocket):
					for pc in w.chips_on(Board.straight_key(m), PL):
						if pc.kind != "temp":
							_value(res, w, pc, 1)
							res.log.chips.append("Ledger: chip on %d grows to %d" % [m, pc.value])
			"respin":
				res.respins += 1
				res.log.chips.append("Respin: the dealer owes you a spin")
	for c in w.side_chips(PL):
		if c.kind == "mint":
			_coins(res, Content.MINT_INCOME, -Content.MINT_INCOME, "chips", "Mint on %s: +%d" % [c.bet, Content.MINT_INCOME])
		elif c.kind == "compounding":
			_value(res, w, c, 1)
			res.log.chips.append("Compounding on %s grows to %d" % [c.bet, c.value])

	# --- House pressure: flanking, then Pit Boss twists.
	var flanked := []
	for n in range(37):
		if w.owner(n) == HO and w.is_flanked(n):
			flanked.append(n)
	for n in flanked:
		var biggest = _biggest(w.chips_on(Board.straight_key(n), HO))
		if biggest != null:
			_value(res, w, biggest, -1)
			res.log.rules.append("Flanked: House stack on %d weakens" % n)
	if w.has_pit("decay"):
		var mine := []
		for c in w.side_chips(PL):
			if c.kind != "temp":
				mine.append(c)
		var big = _biggest(mine)
		if big != null:
			_value(res, w, big, -1)
			res.log.rules.append("Pit Boss (Decay): your chip on %s loses 1" % big.bet)
	return res


## Average over all 37 pockets. `player` is relative to the bankroll before temp bets were placed,
## so a single plain bet reads exactly -1/37 per unit.
static func expected_value(felt) -> Dictionary:
	var p := 0.0
	var b := 0.0
	for pocket in range(37):
		var r := resolve_spin(felt, pocket)
		p += r.player
		b += r.bank
	return {"player": p / 37.0 - felt.temp_stakes(), "bank": b / 37.0}


## Flatten the staged log into display lines in resolution order.
static func log_lines(res: Dictionary) -> Array:
	var out := []
	for s in STAGES:
		for line in res.log[s]:
			out.append("[%s] %s" % [s, line])
	return out


static func _coins(res: Dictionary, player: int, bank: int, stage: String, reason: String) -> void:
	res.player += player
	res.bank += bank
	res.effects.append({"type": "coins", "player": player, "bank": bank, "reason": reason})
	if stage != "":
		res.log[stage].append(reason)


static func _remove(res: Dictionary, w, c, why: String) -> void:
	res.effects.append({"type": "remove", "id": c.id, "reason": why})
	w.remove(c.id)


static func _value(res: Dictionary, w, c, delta: int) -> void:
	c.value += delta
	res.effects.append({"type": "value", "id": c.id, "delta": delta})
	if c.value <= 0:
		_remove(res, w, c, "worn out")


static func _biggest(arr: Array):
	var best = null
	for c in arr:
		if best == null or c.value > best.value:
			best = c
	return best


static func _collector_bonus(w, chip) -> int:
	var n := Board.straight_number(chip.bet)
	var total := 0
	for c in w.side_chips(PL):
		if c.id == chip.id or not Board.is_straight(c.bet):
			continue
		var m := Board.straight_number(c.bet)
		if m == 0 or n == 0:
			continue
		if Board.dozen_of(m) == Board.dozen_of(n) or Board.grid_row(m) == Board.grid_row(n):
			total += c.value
	return total
