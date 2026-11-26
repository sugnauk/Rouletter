extends SceneTree
## Headless balancing sim:  godot --headless --path . --script res://tools/sim.gd [-- runs=200 all act=2]
##   all    -> bot plays with every unlock (default: starting pool only)
##   act=2  -> Act II runs (8 nights, ending at the Owner)
##   grade=N -> marker grade N (1-9, difficulty ladder)
##   report  -> also print item, Enforcer, condition and "where runs end" tables (docs/balance_report.md)
## Prints clear rates per table for each wheel, using a simple greedy bot.

var offered := {}     ## item id -> times on a Cage counter
var bought := {}      ## item id -> times the bot bought it
var enf := {}         ## enforcer -> [reached, cleared]
var cond := {}        ## table condition -> [reached, cleared]
var ends := {}        ## "N2 High Roller" -> runs that ended there

const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const Wheels := preload("res://core/wheels.gd")
const Resolver := preload("res://core/resolver.gd")
const RunState := preload("res://core/run_state.gd")
const Profile := preload("res://core/profile.gd")


func _initialize() -> void:
	var runs := 200
	var all := false
	var acts := 1
	var grade := 0
	var want_report := false
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a == "report":
			want_report = true
		if a.begins_with("runs="):
			runs = int(a.substr(5))
		elif a == "all":
			all = true
		elif a.begins_with("act="):
			acts = int(a.substr(4))
		elif a.begins_with("wheel="):
			only = a.substr(6)
		elif a.begins_with("grade="):
			grade = int(a.substr(6)) - 1
	var unlocks := Profile.default_unlocks()
	if all:
		for e in Profile.catalogue():
			unlocks.append(e.id)
	print("== Fairness: plain one-unit bets ==")
	for id in Wheels.ORDER:
		var f = preload("res://core/felt_state.gd").new(id)
		f.add_chip("bet", "RED", 2)
		print("  %-12s pockets %2d  even-money EV/unit %+.4f" % [id, f.board.pockets.size(), Resolver.expected_value(f).net / 2.0])
	print("== Bot runs (%d per wheel, %s pool) ==" % [runs, "full" if all else "starting"])
	for id in Wheels.ORDER:
		if only == "" or id == only:
			sim_wheel(id, runs, unlocks, acts, grade)
	if want_report:
		print_report()
	quit()


func _bump(d: Dictionary, k: String, i: int = -1) -> void:
	if i < 0:
		d[k] = d.get(k, 0) + 1
	else:
		if not d.has(k):
			d[k] = [0, 0]
		d[k][i] += 1


func print_report() -> void:
	print("== Items: bought / offered (bot buys left to right, so read this as 'how often it was in reach') ==")
	var ids: Array = offered.keys()
	ids.sort_custom(func(a, b): return float(bought.get(a, 0)) / offered[a] > float(bought.get(b, 0)) / offered[b])
	for id in ids:
		var nm: String = Content.CHIPS.get(id, Content.UPGRADES.get(id, Content.HOUSE_RULES.get(id, {}))).get("name", id)
		print("  %-22s %5d / %5d  %3.0f%%" % [nm, bought.get(id, 0), offered[id], 100.0 * bought.get(id, 0) / offered[id]])
	print("== Enforcers: cleared / reached ==")
	for e in enf:
		print("  %-22s %4d / %4d  %3.0f%%" % [Content.ENFORCERS[e].name, enf[e][1], enf[e][0], 100.0 * enf[e][1] / maxf(1, enf[e][0])])
	print("== Table conditions: cleared / reached ==")
	for c in cond:
		print("  %-22s %4d / %4d  %3.0f%%" % [Content.CONDITIONS[c].name if Content.CONDITIONS.has(c) else "(none)", cond[c][1], cond[c][0], 100.0 * cond[c][1] / maxf(1, cond[c][0])])
	print("== Where lost runs ended ==")
	var ks: Array = ends.keys()
	ks.sort_custom(func(a, b): return ends[a] > ends[b])
	for k in ks:
		print("  %-26s %4d" % [k, ends[k]])


func sim_wheel(wheel: String, runs: int, unlocks: Array, acts: int = 1, grade: int = 0) -> void:
	var reached := []
	var cleared := []
	var n: int = Content.NIGHTS if acts == 1 else Content.ACT2_NIGHTS
	reached.resize(n * 3)
	cleared.resize(n * 3)
	reached.fill(0)
	cleared.fill(0)
	var wins := 0
	for s in range(runs):
		var run = RunState.new()
		run.start_run(5000 + s, wheel, unlocks, acts, grade)
		var guard := 0
		while guard < 400:
			guard += 1
			if run.phase == RunState.Phase.TABLE:
				var idx: int = run.night * 3 + run.table_idx
				if run.table.spins_used == 0:
					reached[idx] += 1
					if run.table.boss:
						_bump(enf, run.table.enforcer, 0)
					else:
						_bump(cond, run.table.get("condition", ""), 0)
				if not run.table_offer.is_empty():
					run.take_table_offer(0)
				bot_bet(run)
				var boss_now: String = run.table.enforcer if run.table.boss else ""
				var cond_now: String = run.table.get("condition", "")
				run.spin()
				if run.phase != RunState.Phase.TABLE and run.phase != RunState.Phase.GAME_OVER:
					cleared[idx] += 1
					if boss_now != "":
						_bump(enf, boss_now, 1)
					else:
						_bump(cond, cond_now, 1)
				elif run.phase == RunState.Phase.GAME_OVER:
					_bump(ends, "N%d %s" % [run.night + 1, run.table_name()])
			elif run.phase == RunState.Phase.SHOP:
				if not run.shop.offer.is_empty():
					run.take_offer(0)
				if not run.shop.bonus.is_empty():
					run.take_bonus(0)
				if not run.shop.get("stash", []).is_empty():
					if not run.take_stash(0):
						run.take_stash(1)
				if not run.shop.get("routes", []).is_empty():
					run.pick_route("")
				if run.shop.get("event", "") != "":
					run.answer_event(1)
				for it in run.shop.stock:
					if not it.sold and it.type in ["chip", "upgrade", "rule"]:
						_bump(offered, it.id)
				bot_shop(run)
				for it in run.shop.stock:
					if it.sold and it.type in ["chip", "upgrade", "rule"]:
						_bump(bought, it.id)
				run.leave_shop()
			else:
				break
		if run.phase == RunState.Phase.VICTORY:
			wins += 1
	var line := "  %-12s" % wheel
	for i in range(reached.size()):
		var rate: float = 0.0 if reached[i] == 0 else 100.0 * cleared[i] / reached[i]
		line += " %3.0f" % rate
	print(line + "   | win %.0f%%" % (100.0 * wins / runs))


## Spread the stack over the remaining spins on straight-up numbers next to our permanent chips.
func bot_bet(run) -> void:
	place_inventory(run)
	if run.is_called_spin():
		return
	var per: int = maxi(1, run.table.stack / maxi(1, run.table.spins_left))
	var need: float = run.table.target - run.table.take
	# On pace (the stack could cover the need at dozen odds)? Play low variance; else go for straights.
	# Losses now come off each spin's Take, so concentrate: one outside box when on pace,
	# a couple of numbers when behind.
	var keys := []
	if need <= run.table.stack * 1.2 and run.can_bet_on("DOZ1"):
		keys = ["DOZ1"]
	else:
		# Novel wheels: a crooked wheel's fat pockets, or the Carousel's hot arc, come first.
		var fav := []
		for n in run.felt.weights.keys() + run.felt.arc_pockets():
			if n > 0 and n not in fav:
				fav.append(n)
		fav += favourite_numbers(run).filter(func(n): return n not in fav)
		keys = []
		for n in fav:
			if keys.size() < 2 and run.can_bet_on(Board.straight_key(n)):
				keys.append(Board.straight_key(n))
	if keys.is_empty():
		return
	var i := 0
	while per > 0 and run.table.stack > 0 and i < 40:
		run.place_bet(keys[i % keys.size()], 1)
		per -= 1
		i += 1


func favourite_numbers(run) -> Array:
	var out := []
	for c in run.felt.perm_chips():
		if Board.is_straight(c.bet) and Board.straight_number(c.bet) > 0:
			out.append(Board.straight_number(c.bet))
	for n in range(1, run.felt.board.numbers + 1):
		if n not in out:
			out.append(n)
	return out


## Placement: line-only chips on a corner by our numbers, zero chips on a zero (if the wheel
## has one), everything else spread over fresh numbers.
func place_inventory(run) -> void:
	var guard := 0
	while not run.inventory.is_empty() and guard < 20:
		guard += 1
		var item: Dictionary = run.inventory[0]
		var key := ""
		# Spreading chips over more numbers beat stacking twins in the sim (steadier Take), so
		# the bot only levels up when it has run out of fresh numbers.
		if run.felt.perm_chips().size() >= run.felt.board.numbers:
			for c in run.felt.perm_chips():
				if c.kind == item.kind and c.flaw == item.get("flaw", ""):
					key = c.bet
					break
		if key == "":
			var B = run.felt.board
			if Content.CHIPS[item.kind].get("zero_only", false):
				key = "S0" if not B.zeros.is_empty() else ""
			elif Content.CHIPS[item.kind].get("even_only", false):
				key = "RED"
			elif Content.CHIPS[item.kind].get("black_only", false):
				for n in range(1, B.numbers + 1):
					if not B.is_red(n) and run.felt.chips_on(Board.straight_key(n)).is_empty():
						key = Board.straight_key(n)
						break
			elif Content.CHIPS[item.kind].get("box_only", false):
				key = "ODD"
			elif Content.CHIPS[item.kind].get("coldoz_only", false):
				key = "DOZ%d" % (1 + run.felt.perm_chips().size() % 3)
				if not B.has_bet(key):
					key = "COL1"
			elif Content.CHIPS[item.kind].get("column_only", false):
				key = "COL%d" % (1 + run.felt.perm_chips().size() % 3)
			elif Content.CHIPS[item.kind].get("line_only", false):
				var n: int = favourite_numbers(run)[0]
				for k in ["CO%d" % n, "CO%d" % (n - 1), "SP%d_%d" % [n, n + 3], "ST%d" % (n - (n - 1) % 3)]:
					if B.has_bet(k):
						key = k
						break
			else:
				key = Board.straight_key(1 + (run.felt.perm_chips().size() * 7) % B.numbers)
		if key == "" or not run.place_chip(0, key):
			run.inventory.remove_at(0)


## Cash items first (chips, upgrades), Dealer perks with spare Take, then House Rules only if
## the Pit Boss's price leaves a healthy stack; never borrow.
func bot_shop(run) -> void:
	var order := []
	for t in ["chip", "upgrade", "voucher", "favour", "rule"]:
		for i in range(run.shop.stock.size()):
			if run.shop.stock[i].type == t:
				order.append(i)
	for i in order:
		var item: Dictionary = run.shop.stock[i]
		if item.sold or not run.can_afford(item):
			continue
		if item.currency == "stack" and run.stack_spare() - run.price_of(item) < 6:
			continue
		# Like a player: box chips are the reliable start; past night 2 they can't keep up, so skip them.
		if item.type == "chip" and run.night >= 2 and "box" in Content.tags_of(item.id):
			continue
		if true:
			run.buy(i)
			if run.shop.pending_upgrade != "":
				var t: Array = run.upgrade_targets()
				var pick: String = t[0]
				for c in run.felt.perm_chips():
					if c.bet in t:
						pick = c.bet
				run.apply_upgrade(pick)
	if run.cash >= run.stack_price() + 4:
		run.buy_stack()
	place_inventory(run)
