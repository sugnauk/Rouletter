extends RefCounted
## Dealer personalities: how the House counter-places chips after each spin.
## Placement is free for the House (it is the House), so the budget per spin is the
## main difficulty dial. Walled streets (fully player-owned) are off limits.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")

const PL := Chip.Side.PLAYER
const HO := Chip.Side.HOUSE


## Seed a fresh table: the House always holds 0, plus `extra` random squares.
static func seed_table(felt, rng, extra: int) -> void:
	felt.add_house_value(0, 1)
	var open := []
	for n in range(1, 37):
		if felt.owner(n) == -1:
			open.append(n)
	open = rng.shuffle(open)
	for i in range(mini(extra, open.size())):
		felt.add_house_value(open[i], 1)


## Returns log lines describing what the House did.
static func take_turn(felt, rng, dealer: String, budget: int, ctx: Dictionary) -> Array:
	var log := []
	match dealer:
		"shuffler":
			_shuffle_one(felt, rng, log)
			_spend(felt, rng, budget, log, _valid(felt), true)
		"banker":
			var dz: int = ctx.get("dozen", 0)
			var squares := []
			for n in _valid(felt):
				if Board.dozen_of(n) == dz:
					squares.append(n)
			_spend(felt, rng, budget, log, squares, true)
		"zero_priest":
			_spend(felt, rng, budget, log, _frontier(felt), false)
		_:
			_spend(felt, rng, budget, log, _valid(felt), true)
	return log


static func _valid(felt) -> Array:
	var out := []
	for n in range(37):
		if not felt.is_walled(n):
			out.append(n)
	return out


## Squares next to House territory that the House does not hold yet, nearest 0 first.
static func _frontier(felt) -> Array:
	var held: Array = felt.owned_squares(HO)
	var out := []
	for n in held:
		for m in Board.neighbours(n):
			if m not in out and m not in held and not felt.is_walled(m):
				out.append(m)
	out.sort_custom(func(a, b): return Board.distance_from_zero(a) < Board.distance_from_zero(b))
	return out


## Cost (in House chip value) to take square n from the player, or 0 if not player-owned.
static func _retake_cost(felt, n: int) -> int:
	if felt.owner(n) != PL:
		return 0
	var p: int = felt.weight(n, PL)
	var h: int = felt.weight(n, HO)
	var per := 1
	if felt.square_upgrades.get(n, "") == "double_felt":
		per *= 2
	if felt.has_pit("capture_double"):
		per *= 2
	return int(ceil(float(p - h) / per))


static func _spend(felt, rng, budget: int, log: Array, squares: Array, contest: bool) -> void:
	var left := budget
	var guard := 0
	while left > 0 and not squares.is_empty() and guard < 50:
		guard += 1
		# 1) Retake the cheapest player square in reach.
		var target := -1
		var best := 999
		for n in squares:
			var cost := _retake_cost(felt, n)
			if cost > 0 and cost <= left and cost < best:
				best = cost
				target = n
		if target != -1 and (contest or best <= left):
			felt.add_house_value(target, best)
			left -= best
			log.append("House retakes %d (+%d)" % [target, best])
			continue
		# 2) Otherwise claim an empty square, or reinforce its weakest held one.
		var empty := []
		for n in squares:
			if felt.owner(n) == -1:
				empty.append(n)
		if not empty.is_empty():
			var n: int = empty[0] if not contest else rng.pick(empty)
			felt.add_house_value(n, 1)
			log.append("House claims %d" % n)
		else:
			var held := []
			for n in squares:
				if felt.owner(n) == HO:
					held.append(n)
			if held.is_empty():
				# Nothing claimable: pile onto a contested square for later.
				var n: int = rng.pick(squares)
				felt.add_house_value(n, 1)
				log.append("House stacks on %d" % n)
			else:
				held.sort_custom(func(a, b): return felt.raw_value(a, HO) < felt.raw_value(b, HO))
				felt.add_house_value(held[0], 1)
				log.append("House reinforces %d" % held[0])
		left -= 1


## The Shuffler moves one stack (never the one on 0) to a random open square.
static func _shuffle_one(felt, rng, log: Array) -> void:
	var stacks := []
	for c in felt.side_chips(HO):
		if c.bet != "S0":
			stacks.append(c)
	if stacks.is_empty():
		return
	var c = rng.pick(stacks)
	var open := []
	for n in range(1, 37):
		if felt.owner(n) == -1 and not felt.is_walled(n):
			open.append(n)
	if open.is_empty():
		return
	var to: int = rng.pick(open)
	var from := Board.straight_number(c.bet)
	felt.remove(c.id)
	felt.add_house_value(to, c.value)
	log.append("Shuffler moves %d chips from %d to %d" % [c.value, from, to])
