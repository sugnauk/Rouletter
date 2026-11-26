extends SceneTree
## Headless test runner:  godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 1 if any assertion fails.

const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const Wheels := preload("res://core/wheels.gd")
const FeltState := preload("res://core/felt_state.gd")
const Resolver := preload("res://core/resolver.gd")
const Odds := preload("res://core/odds.gd")
const RunState := preload("res://core/run_state.gd")
const Profile := preload("res://core/profile.gd")
const Story := preload("res://core/story.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	for t in [
		"test_wheels_shape", "test_payout_formula", "test_every_bet_every_pocket", "test_fairness_all_wheels",
		"test_la_partage_french", "test_net_take", "test_perm_never_lost", "test_magnet", "test_gilded_hot_double",
		"test_link", "test_pinned_sector", "test_croupier", "test_ledger", "test_compounding_mint_respin",
		"test_collector", "test_wildcard_zero", "test_en_prison", "test_red_streak", "test_hot_hand",
		"test_signature", "test_thirteen", "test_enforcers", "test_resolver_is_pure", "test_odds",
		"test_run_table_flow", "test_rebet_and_clear", "test_pit_boss", "test_loan_shark_and_fence", "test_inside_content", "test_shop", "test_lose_and_bust", "test_rent_control_target",
		"test_full_run_victory", "test_seeded_reproducible", "test_profile", "test_story_beats", "test_sfx_synth",
	]:
		call(t)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", what)


func near(a: float, b: float, what: String, eps := 1e-9) -> void:
	check(absf(a - b) < eps, "%s (got %f, want %f)" % [what, a, b])


func felt(wheel: String, chips: Array):
	var f = FeltState.new(wheel)
	for c in chips:
		f.add_chip(c[0], c[1], c[2])
	return f


# --- Wheels & board -------------------------------------------------------------------

func test_wheels_shape() -> void:
	var sizes := {"french": 37, "european": 37, "american": 38, "mini": 13, "triple_zero": 39}
	for id in sizes:
		var b = Board.new(id)
		check(b.pockets.size() == sizes[id], "%s pocket count" % id)
		check(b.order.size() == sizes[id], "%s wheel order size" % id)
		var sorted_order: Array = b.order.duplicate()
		sorted_order.sort()
		var sorted_pockets: Array = b.pockets.duplicate()
		sorted_pockets.sort()
		check(sorted_order == sorted_pockets, "%s wheel order is a permutation of its pockets" % id)
		var sec := 0
		for k in ["VOI", "TIE", "ORP"]:
			sec += b.bet(k).numbers.size()
		check(sec == b.pockets.size() - (b.zeros.size() - 1), "%s call bets cover the wheel" % id)
		check(b.bet("RED").numbers.size() == b.numbers / 2, "%s half red" % id)
	check(Wheels.label(-1) == "00" and Wheels.label(-2) == "000", "zero labels")
	var m = Board.new("mini")
	check(m.cols == 4 and m.bet("DOZ1").numbers == [1, 2, 3, 4], "mini felt is 3x4 with thirds of 4")
	check(m.neighbours(5).size() == 4, "mini adjacency")


func test_payout_formula() -> void:
	var e = Board.new("european")
	var want := {"S17": 35.0, "SP1_4": 17.0, "ST1": 11.0, "CO1": 8.0, "LN1": 5.0, "COL1": 2.0, "DOZ2": 2.0, "RED": 1.0, "TIE": 2.0, "ORP": 3.5}
	for k in want:
		near(e.bet(k).payout, want[k], "european payout %s" % k)
	var m = Board.new("mini")
	var want_m := {"S7": 11.0, "SP1_4": 5.0, "ST1": 3.0, "CO1": 2.0, "COL1": 2.0, "LOW": 1.0}
	for k in want_m:
		near(m.bet(k).payout, want_m[k], "mini payout %s" % k)


func test_every_bet_every_pocket() -> void:
	for id in Wheels.ORDER:
		var b = Board.new(id)
		for k in b.all_bet_keys():
			var bd: Dictionary = b.bet(k)
			var f = felt(id, [["bet", k, 2]])
			f.wheel_rules = []
			for p in b.pockets:
				var r := Resolver.resolve_spin(f, p)
				if p in bd.numbers:
					check(is_equal_approx(r.take, 2.0 * bd.payout) and r.stack == 2, "%s %s hit on %d" % [id, k, p])
				else:
					check(r.take == 0.0 and r.stack == 0, "%s %s miss on %d" % [id, k, p])


func test_fairness_all_wheels() -> void:
	var edge := {"french": -1.0 / 37.0, "european": -1.0 / 37.0, "american": -2.0 / 38.0,
		"mini": -1.0 / 13.0, "triple_zero": -3.0 / 39.0}
	for id in edge:
		var b = Board.new(id)
		var worst := 0.0
		for k in b.all_bet_keys():
			var f = felt(id, [["bet", k, 1]])
			f.wheel_rules = []
			worst = maxf(worst, absf(Resolver.expected_value(f).net - edge[id]))
		check(worst < 1e-9, "%s: every bet is exactly fair-minus-zeros (worst deviation %.12f)" % [id, worst])


func test_la_partage_french() -> void:
	var f = felt("french", [["bet", "RED", 2]])  # half of an odd stack rounds down, so use 2
	near(Resolver.expected_value(f).net / 2.0, -1.0 / 74.0, "French even-money edge halves", 1e-9)
	var g = felt("french", [["bet", "RED", 10]])
	check(Resolver.resolve_spin(g, 0).stack == 5, "half back on zero")


func test_net_take() -> void:
	# Hedging both colours used to be a free clear. Take is now net of the spin's losses.
	var f = felt("european", [["bet", "RED", 12], ["bet", "BLACK", 12]])
	for p in [1, 2, 17, 36]:
		var r := Resolver.resolve_spin(f, p)
		check(r.take == 0.0 and r.gross == 12.0 and r.lost == 12, "red+black hedge scores 0 on %d" % p)
	check(Resolver.resolve_spin(f, 0).take == 0.0, "hedge on zero scores 0, never negative")
	var g = felt("european", [["bet", "S5", 2], ["bet", "S8", 1], ["perm", "S9", 1]])
	check(Resolver.resolve_spin(g, 5).take == 70.0 - 1.0, "straight win minus the other losing bet")
	check(Resolver.resolve_spin(g, 9).take == 35.0 - 3.0, "perm hit pays, betting losses subtract")
	var kinds := []
	for e in Resolver.resolve_spin(g, 5).events:
		kinds.append(e.kind)
	check(kinds == ["win", "loss"], "scoring events in resolution order")


func test_perm_never_lost() -> void:
	var f = felt("european", [["perm", "S17", 1]])
	var miss := Resolver.resolve_spin(f, 4)
	check(miss.take == 0.0 and miss.felt_after.chips.size() == 1, "perm survives a miss")
	var hit := Resolver.resolve_spin(f, 17)
	check(hit.take == 35.0 and hit.stack == 0 and hit.felt_after.chips.size() == 1, "perm scores and stays")
	near(Resolver.expected_value(f).take, 35.0 / 37.0, "perm EV")


# --- Upgrades and chips -------------------------------------------------------------------

func test_magnet() -> void:
	var f = felt("european", [["magnet", "S5", 1]])
	var r := Resolver.resolve_spin(f, 8)
	check(r.take == 35.0 and r.felt_after.chips[0].bet == "S8", "magnet slides and scores")
	check(Resolver.resolve_spin(f, 9).take == 0.0, "magnet needs adjacency")
	var a = felt("american", [["magnet", "S2", 1]])
	check(Resolver.resolve_spin(a, -1).take == 35.0, "00 borders the first street")


func test_gilded_hot_double() -> void:
	var f = felt("european", [["perm", "S9", 1], ["perm", "COL2", 2], ["perm", "S20", 1]])
	f.square_upgrades[9] = "gilded"
	f.bet_upgrades["COL2"] = "hot"
	f.square_upgrades[20] = "double_felt"
	near(Resolver.resolve_spin(f, 9).take, 40.0, "gilded 40:1")
	near(Resolver.resolve_spin(f, 5).take, 6.0, "hot column 3:1")
	near(Resolver.resolve_spin(f, 20).take, 70.0 + 6.0, "double felt + hot column on 20")


func test_link() -> void:
	var f = felt("european", [["perm", "S20", 1], ["perm", "S17", 2], ["perm", "S30", 1]])
	f.square_upgrades[20] = "link"
	near(Resolver.resolve_spin(f, 20).take, 35.0 + 2 * 35 * 0.25, "link scores neighbours")


func test_pinned_sector() -> void:
	var f = felt("european", [["perm", "VOI", 1]])
	var p: float = f.board.bet("VOI").payout
	f.square_upgrades[26] = "pinned"
	near(Resolver.resolve_spin(f, 26).take, 2.0 * p, "pinned doubles call bets")
	near(Resolver.resolve_spin(f, 0).take, p, "unpinned pocket normal")


func test_croupier() -> void:
	var f = felt("european", [["croupier", "S4", 1], ["bet", "S10", 3], ["bet", "RED", 2]])
	var r := Resolver.resolve_spin(f, 4)
	check(r.gross == 35.0 + 5.0 and r.take == 35.0, "croupier's rake cancels the spin's losses")


func test_ledger() -> void:
	var f = felt("european", [["ledger", "S14", 1], ["perm", "S11", 1], ["perm", "S15", 2], ["perm", "S20", 1]])
	var r := Resolver.resolve_spin(f, 14)
	check(r.felt_after.chips_on("S11")[0].value == 2 and r.felt_after.chips_on("S15")[0].value == 3, "ledger grows neighbours")
	check(r.felt_after.chips_on("S20")[0].value == 1, "ledger ignores non-neighbours")


func test_compounding_mint_respin() -> void:
	var f = felt("european", [["compounding", "S7", 1], ["mint", "S33", 1], ["respin", "S12", 1]])
	var r := Resolver.resolve_spin(f, 2)
	check(r.cash == 1 and r.respins == 0, "mint pays cash every spin")
	check(r.felt_after.chips_on("S7")[0].value == 2, "compounding grows")
	check(Resolver.resolve_spin(f, 12).respins == 1, "respin on hit")


func test_collector() -> void:
	var f = felt("european", [["collector", "S2", 1], ["perm", "S7", 3], ["perm", "S35", 2], ["perm", "S25", 4]])
	check(Resolver.resolve_spin(f, 2).take == 35.0 + 3.0 + 2.0, "collector counts dozen + column")


func test_wildcard_zero() -> void:
	var f = felt("triple_zero", [["wildcard_zero", "S-2", 1], ["bet", "RED", 5]])
	for z in [0, -1]:
		var r := Resolver.resolve_spin(f, z)
		check(r.take == Content.WILDCARD_BONUS and r.stack == 5, "wildcard triggers on zero %d" % z)
	var r2 := Resolver.resolve_spin(f, -2)
	check(r2.take == 35.0 + Content.WILDCARD_BONUS, "wildcard also scores its own zero")


func test_en_prison() -> void:
	var f = felt("european", [["bet", "EVEN", 4]])
	f.house_rules.append("en_prison")
	var r := Resolver.resolve_spin(f, 0)
	check(r.stack == 0 and r.felt_after.chips.size() == 1, "imprisoned bet stays")
	check(Resolver.resolve_spin(r.felt_after, 2).stack == 4, "and can win next spin")


func test_red_streak() -> void:
	var f = felt("european", [["perm", "RED", 10]])
	f.house_rules.append("red_streak")
	var r1 := Resolver.resolve_spin(f, 1)
	var r2 := Resolver.resolve_spin(r1.felt_after, 3)
	check(r1.take == 10.0 and is_equal_approx(r2.take, 11.0), "streak bonus")
	check(Resolver.resolve_spin(r2.felt_after, 2).red_streak == 0, "black resets")


func test_hot_hand() -> void:
	var f = felt("european", [["perm", "S8", 1]])
	f.house_rules.append("hot_hand")
	f.last_pocket = 8
	check(Resolver.resolve_spin(f, 8).take == 105.0, "repeat triples")


func test_signature() -> void:
	var f = felt("european", [["perm", "S32", 1]])
	f.house_rules.append("dealer_signature")
	f.last_pocket = 19  # 32 -> 15 -> 19: distance 2 on the wheel
	near(Resolver.resolve_spin(f, 32).take, 52.5, "signature +50% near last ball")
	f.last_pocket = 5
	near(Resolver.resolve_spin(f, 32).take, 35.0, "far from last ball: normal")


func test_thirteen() -> void:
	var f = felt("european", [["perm", "S13", 1], ["perm", "S14", 1]])
	f.house_rules.append("thirteen")
	check(Resolver.resolve_spin(f, 13).take == 0.0, "13 cursed")
	check(Resolver.resolve_spin(f, 14).take == 70.0, "neighbour doubled")


func test_enforcers() -> void:
	var f = felt("european", [["perm", "RED", 5], ["bet", "DOZ1", 2], ["perm", "S1", 1]])
	f.boss_rule = "no_outside"
	var r := Resolver.resolve_spin(f, 1)
	check(r.take == 35.0 - 2.0 and r.stack == 0, "no_outside: outside chips pay nothing (dead bet is lost)")
	var g = felt("european", [["perm", "S0", 1]])
	g.boss_rule = "zero_tax"
	check(Resolver.resolve_spin(g, 0).zero_tax, "zero tax flagged")
	var h = felt("european", [["perm", "S6", 3]])
	h.boss_rule = "frozen"
	h.frozen_id = h.chips[0].id
	check(Resolver.resolve_spin(h, 6).take == 0.0, "frozen chip pays nothing")


func test_resolver_is_pure() -> void:
	var f = felt("european", [["compounding", "S7", 1], ["bet", "RED", 5], ["magnet", "S8", 1]])
	Resolver.resolve_spin(f, 7)
	Resolver.expected_value(f)
	check(f.chips.size() == 3 and f.chips[0].value == 1 and f.chips[2].bet == "S8", "input felt untouched")


func test_odds() -> void:
	var f = felt("european", [["perm", "S17", 1]])
	near(Odds.hit_chance(f, 35, 1), 1.0 / 37.0, "one spin, one number")
	near(Odds.hit_chance(f, 35, 2), 1.0 - pow(36.0 / 37.0, 2), "two spins")
	near(Odds.hit_chance(f, 70, 2), 1.0 / (37.0 * 37.0), "need two hits")
	check(Odds.hit_chance(f, 0, 3) == 1.0, "already there")


# --- Run state machine -------------------------------------------------------------------

func new_run(wheel := "european", seed := 42):
	var run = RunState.new()
	run.start_run(seed, wheel, Profile.default_unlocks())
	return run


func test_run_table_flow() -> void:
	var run = new_run()
	check(run.phase == RunState.Phase.TABLE and run.table_name() == "Floor", "starts at Night 1 Floor")
	check(run.inventory.size() == 1 and run.inventory[0].kind == "magnet", "European kit")
	check(run.table.target == Content.NIGHT_BASE[0], "first target")
	check(run.place_bet("S17", 3) and run.table.stack == Content.START_STACK - 3, "bet from stack")
	check(run.place_bet("S17", 2) and run.felt.chips_on("S17")[0].value == 5, "bets merge")
	check(run.take_back("S17") and run.table.stack == Content.START_STACK, "take back")
	check(not run.can_bet_on("VOI"), "call bets locked by default")
	check(run.place_bet("SP1_4", 1) and run.take_back("SP1_4"), "splits can be bet on")
	check(run.place_chip(0, "S30"), "place kit magnet")
	run.place_bet("S17", 1)
	var before_cash: int = run.cash
	run.spin(17)
	check(run.table.stack == Content.START_STACK - 1 + 1 and run.table.take == 35.0, "win returns stake and scores")
	check(run.phase == RunState.Phase.SHOP, "target 30 cleared in one hit -> shop")
	check(run.cash == before_cash + Content.CLEAR_CASH[0] + 5 + mini(before_cash / 5, 5), "clear reward with comps")
	check(run.felt.bet_chips().is_empty() and run.felt.perm_chips().size() == 1, "bets cleared, perm stays")


func test_rebet_and_clear() -> void:
	var run = new_run()
	run.place_bet("S17", 3)
	run.place_bet("SP1_4", 2)
	run.spin(5)  # a miss: both bets lost
	check(run.felt.chips_on("S17").is_empty(), "bets are consumed by the spin")
	var start: int = run.table.stack
	check(run.rebet() == 5, "rebet lays the same 5 chips")
	check(run.felt.value_on("S17") == 3 and run.felt.value_on("SP1_4") == 2 and run.table.stack == start - 5, "rebet restores the layout from the stack")
	check(run.rebet() == 0, "rebet does not double bets already out")
	check(run.clear_bets() and run.table.stack == start, "clear returns every bet to the stack")
	check(not run.clear_bets(), "clear with nothing out is a no-op")
	run.spin(5)
	check(run.rebet() == 0, "an empty spin leaves nothing to rebet")
	var st: int = run.table.stack
	run.place_bet("S9", 5)
	check(run.unbet("S9", 2) == 2 and run.felt.value_on("S9") == 3 and run.table.stack == st - 3, "undo takes part of a bet back")
	check(run.unbet("S9", 9) == 3 and run.felt.chips_on("S9").is_empty() and run.table.stack == st, "undo never returns more than was bet")


func test_pit_boss() -> void:
	var run = new_run()
	run.place_bet("S17", 1)
	run.spin(17)
	check(run.phase == RunState.Phase.SHOP, "in the Cage")
	run.shop.vendors = ["cashier", "pit_boss"]
	run._restock()
	var rules := []
	for i in range(run.shop.stock.size()):
		if run.shop.stock[i].vendor == "pit_boss":
			rules.append(i)
	check(rules.size() == 2, "Pit Boss shows two rules")
	var a: Dictionary = run.shop.stock[rules[0]]
	var b: Dictionary = run.shop.stock[rules[1]]
	var cash_before: int = run.cash
	var pa: int = run.price_of(a)
	check(a.currency == "stack" and run.price_text(a) == "%d CHIPS" % pa, "priced in chips")
	check(run.buy(rules[0]) and run.cash == cash_before and run.stack_owed == pa, "paid with stack chips, not cash")
	check(run.price_of(b) == b.price + Content.PIT_BOSS_STEP, "each rule owned raises his price")
	run.stack_owed = run.stack_size - Content.MIN_STACK
	check(not run.can_afford(b) and not run.buy(rules[1]), "never below the minimum stack")
	run.stack_owed = pa
	run.leave_shop()
	check(run.table.stack == run.stack_size - pa and run.table.docked == pa and run.stack_owed == 0, "docked at the next table, once")


func test_loan_shark_and_fence() -> void:
	var run = new_run()
	run.unlocked.append("fence")
	run.place_bet("S17", 1)
	run.spin(17)
	run.shop.vendors = ["cashier", "loan_shark"]
	run._restock()
	var li := -1
	for i in range(run.shop.stock.size()):
		if run.shop.stock[i].type == "loan" and run.shop.stock[i].price == 10:
			li = i
	var cash0: int = run.cash
	var due: int = run.current_target()
	check(li >= 0 and run.buy(li) and run.cash == cash0 + 10 and is_equal_approx(run.loan_pct, 0.35), "a $10 loan pays cash now")
	check(not run.buy(li), "each loan once")
	run.leave_shop()
	check(run.table.target == int(ceil(due * 1.35)) and is_equal_approx(run.loan_pct, 0.0), "the next payment grows by 35%, once")
	# Fence
	run.phase = RunState.Phase.SHOP
	run.shop = {"stock": [], "reroll": 2, "pending_upgrade": "", "vendors": ["cashier", "fence"]}
	run._restock()
	var fi := -1
	for i in range(run.shop.stock.size()):
		if run.shop.stock[i].vendor == "fence":
			fi = i
	var it: Dictionary = run.shop.stock[fi]
	check(it.flaw in Content.FLAWS and it.price == maxi(1, int(ceil(Content.CHIPS[it.id].price * 0.5))), "Fence chips are half price with a flaw")
	run.cash = 50
	check(run.buy(fi) and run.inventory[-1].flaw == it.flaw, "the flaw comes with the chip")
	# Flaw effects in the resolver.
	var f = felt("european", [["perm", "S7", 2]])
	f.chips[0].flaw = "cracked"
	near(Resolver.resolve_spin(f, 7).take, 35.0, "cracked scores half")
	var g = felt("european", [["perm", "S7", 1]])
	g.chips[0].flaw = "hot"
	check(Resolver.resolve_spin(g, 0).felt_after.chips.is_empty(), "hot chips are confiscated on a zero")
	check(Resolver.resolve_spin(g, 7).felt_after.chips.size() == 1, "...and only on a zero")
	var run2 = new_run()
	run2.place_bet("S17", 1)
	run2.spin(17)
	var sc = run2.felt.add_chip("perm", "S3", 1, "sticky")
	run2.cash = 20
	check(not run2.sell_chip(sc.id) and not run2.pick_up(sc.id), "sticky chips can't be sold or moved")


func test_inside_content() -> void:
	var f = felt("european", [["bridge", "CO1", 1]])
	near(Resolver.resolve_spin(f, 5).take, 8.0 + 4.0, "Bridge: corner pays 8 plus 1 per covered number")
	var k = felt("european", [["kingmaker", "S7", 1], ["perm", "RED", 2]])
	near(Resolver.resolve_spin(k, 7).take, (35.0 + 2.0) * 1.5, "Kingmaker multiplies the whole spin")
	var sd = felt("european", [["perm", "SP1_4", 1]])
	sd.house_rules.append("split_decision")
	near(Resolver.resolve_spin(sd, 4).take, 18.0, "Split Decision: split pays 18")
	var cs = felt("european", [["perm", "ST1", 1], ["perm", "S2", 1]])
	cs.square_upgrades[2] = "cornerstone"
	near(Resolver.resolve_spin(cs, 2).take, 22.0 + 35.0, "Cornerstone doubles inside bets on it, not the straight")
	var m = felt("european", [["perm", "RED", 4]])
	m.house_rules.append("momentum")
	var r1 := Resolver.resolve_spin(m, 1)
	var r2 := Resolver.resolve_spin(r1.felt_after, 3)
	var r3 := Resolver.resolve_spin(r2.felt_after, 3)
	near(r1.take, 4.0, "Momentum: first scoring spin plain")
	near(r2.take, 5.0, "Momentum: second x1.25")
	near(r3.take, 6.0, "Momentum: third x1.5")
	check(Resolver.resolve_spin(r3.felt_after, 2).felt_after.hit_streak == 0, "a blank spin resets Momentum")
	var run = new_run()
	run.inventory.append({"kind": "bridge", "value": 1})
	var bi: int = run.inventory.size() - 1
	check(not run.place_chip(bi, "S5") and run.place_chip(bi, "CO1"), "Bridge only sits on line bets")


func test_shop() -> void:
	var run = new_run()
	run.place_bet("S17", 1)
	run.spin(17)
	run.cash = 100
	check(run.shop.vendors.size() == 2 and run.shop.vendors[0] == "cashier", "the Cashier plus one rotating vendor")
	run.shop.vendors = ["cashier", "pit_boss"]
	run._restock()
	check(run.shop.stock.size() == 5, "Cashier (2 chips + upgrade) and Pit Boss (2 rules)")
	var up_i := -1
	for i in range(run.shop.stock.size()):
		if run.shop.stock[i].type == "upgrade":
			up_i = i
	check(run.buy(up_i), "buy upgrade")
	check(not run.leave_shop(), "must lay the upgrade first")
	check(run.apply_upgrade(run.upgrade_targets()[0]), "lay upgrade")
	check(run.buy(0) and run.inventory.size() >= 1, "buy chip")
	check(not run.buy(0), "sold out")
	var stock_before = run.shop.stock
	check(run.reroll() and run.shop.reroll == Content.REROLL_BASE + 1 and run.shop.stock != stock_before, "reroll")
	var ss: int = run.stack_size
	check(run.buy_stack() and run.stack_size == ss + Content.STACK_UPGRADE, "bigger stack")
	check(run.place_chip(0, "S30"), "place a chip from the shop")
	var placed_id: int = run.felt.perm_chips()[0].id
	var cash: int = run.cash
	check(run.pick_up(placed_id) and run.cash == cash - Content.RELOCATE_PRICE, "pick up to relocate")
	var idx: int = run.inventory.size() - 1
	check(run.place_chip(idx, "S33"), "re-place in shop")
	check(run.sell_chip(run.felt.chips_on("S33")[0].id), "sell")
	check(run.leave_shop() and run.phase == RunState.Phase.TABLE and run.table_name() == "High Roller", "next table")
	check(run.table.target == int(round(Content.NIGHT_BASE[0] * Content.TABLE_MULT[1])), "high roller target")


func test_lose_and_bust() -> void:
	var run = new_run()
	run.table.spins_left = 1
	run.spin(5)
	check(run.phase == RunState.Phase.GAME_OVER, "missed payment ends the run")
	var b = new_run("european", 7)
	b.inventory = []
	b.place_bet("S1", b.table.stack)
	b.spin(2)
	check(b.phase == RunState.Phase.GAME_OVER and b.message.contains("Bust"), "bust with empty felt")


func test_rent_control_target() -> void:
	var run = new_run()
	run.felt.house_rules.append("rent_control")
	run._start_table()
	check(run.table.target == int(round(Content.NIGHT_BASE[0] * 0.9)), "rent control lowers the payment")


func test_full_run_victory() -> void:
	var run = new_run("mini", 3)
	var ended := []
	run.run_ended.connect(func(w): ended.append(w))
	var guard := 0
	while run.phase != RunState.Phase.VICTORY and run.phase != RunState.Phase.GAME_OVER and guard < 500:
		guard += 1
		if run.phase == RunState.Phase.SHOP:
			run.leave_shop()
			continue
		if run.felt.boss_rule == "no_outside" or run.is_called_spin():
			if run.felt.perm_chips().is_empty():
				run.inventory.append({"kind": "perm", "value": 50})
				run.place_chip(run.inventory.size() - 1, "S7")
		elif run.felt.bet_chips().is_empty():
			run.place_bet("S7", mini(run.table.stack, 20))
		if run.felt.boss_rule == "frozen" and run.felt.bet_chips().is_empty():
			run.place_bet("S7", mini(run.table.stack, 20))
		run.spin(7)
	check(run.phase == RunState.Phase.VICTORY, "a hot number on every spin wins the run (phase %d)" % run.phase)
	check(run.nights_cleared == Content.NIGHTS and ended == [true], "4 nights, run_ended(true)")


func test_seeded_reproducible() -> void:
	var a = new_run("american", 99)
	var b = new_run("american", 99)
	var pa := []
	var pb := []
	for i in range(5):
		a.place_bet("RED", 1)
		b.place_bet("RED", 1)
		if a.phase == RunState.Phase.TABLE:
			pa.append(a.spin().pocket)
		if b.phase == RunState.Phase.TABLE:
			pb.append(b.spin().pocket)
	check(pa == pb and pa.size() > 0, "same seed, same spins")


func test_profile() -> void:
	var p = Profile.new()
	check(p.is_unlocked("european") and p.is_unlocked("french") and not p.is_unlocked("american"), "starter wheels")
	check(not p.buy_unlock("american"), "can't afford")
	var res: Dictionary = p.record_run(3, 1234.0, false)
	check(res.markers == 3 and p.debt == Content.DEBT_START - 1234 * Content.DEBT_PER_TAKE, "run pays debt, earns markers")
	check(p.buy_unlock("american") and p.markers == 0, "unlock american")
	var path := "user://test_profile.json"
	check(p.save(path), "save")
	var q = Profile.new()
	check(q.load_from(path) and q.debt == p.debt and q.is_unlocked("american") and q.runs == 1, "round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var run = RunState.new()
	run.start_run(1, "european", Profile.default_unlocks())
	for i in range(20):
		run._restock()
		for item in run.shop.stock:
			check(item.type == "loan" or item.id in Profile.default_unlocks() or item.id == "perm", "shop only stocks unlocked content (%s)" % item.id)
		check(not ("fence" in run.shop.vendors), "the Fence needs unlocking")


func test_sfx_synth() -> void:
	var Sfx := preload("res://scenes/ui/sfx.gd")
	for cue in ["click", "chip_place", "chip_remove", "spin", "ball_drop", "win", "big_win", "mult", "lose", "cash", "buy", "clear", "bust"]:
		var w = Sfx.synth(cue)
		var loud := 0
		if w != null:
			for i in range(0, w.data.size(), 2):
				loud = maxi(loud, absi(w.data.decode_s16(i)))
		check(w != null and loud > 2000, "sfx '%s' synthesises audible audio (peak %d)" % [cue, loud])


func test_story_beats() -> void:
	var p = Profile.new()
	check(Story.beats_due(p).is_empty(), "no beats before the first run")
	p.runs = 1
	check(Story.beats_due(p).size() == 1, "first-night beat")
	p.debt = 700000
	var ids := []
	for b in Story.beats_due(p):
		ids.append(b.id)
	check(ids == ["first_night", "nine_hundred", "three_quarters"], "threshold beats in order")
	p.debt = 1000000
	p.seen_beats = ["first_night"]
	p.best_night = 1
	p.runs = 3
	ids = []
	for b in Story.beats_due(p):
		ids.append(b.id)
	check(ids == ["first_enforcer", "regular"], "milestone beats (first Enforcer, third run)")
	p.runs = 6
	check(Story.beats_due(p).any(func(b): return b.id == "the_fixture"), "six runs without a win")
	p.wins = 1
	ids = []
	for b in Story.beats_due(p):
		ids.append(b.id)
	check("first_win" in ids and "the_fixture" not in ids, "a win replaces the fixture beat")
	var i2: Dictionary = Story.interlude(2, p)
	check(i2.id == "n2_dolores", "first unseen interlude")
	p.seen_beats.append("n2_dolores")
	check(Story.interlude(2, p).id == "n2_lou", "next unseen interlude")
	p.seen_beats.append("n2_lou")
	check(not Story.interlude(2, p).is_empty() and Story.interlude(1, p).is_empty() and Story.interlude(5, p).is_empty(), "interludes rotate once seen, only before nights 2-4")
	var ids_all := {}
	for sc in Story.all_scenes():
		check(not ids_all.has(sc.id) and sc.title != "" and not sc.lines.is_empty(), "scene %s is unique and complete" % sc.id)
		ids_all[sc.id] = true
	for v in Content.VENDORS:
		check(Story.VENDOR_INTROS.has(v), "vendor %s has an intro" % v)
