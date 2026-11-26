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
const Feats := preload("res://core/feats.gd")
const Preview := preload("res://core/preview.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	for t in [
		"test_wheels_shape", "test_payout_formula", "test_every_bet_every_pocket", "test_fairness_all_wheels",
		"test_la_partage_french", "test_net_take", "test_perm_never_lost", "test_magnet", "test_gilded_hot_double",
		"test_link", "test_pinned_sector", "test_croupier", "test_ledger", "test_compounding_mint_respin",
		"test_collector", "test_wildcard_zero", "test_en_prison", "test_red_streak", "test_hot_hand",
		"test_signature", "test_thirteen", "test_enforcers", "test_resolver_is_pure", "test_odds",
		"test_run_table_flow", "test_rebet_and_clear", "test_pit_boss", "test_loan_shark_and_fence", "test_inside_content", "test_act2", "test_dealer_and_endless", "test_run_save", "test_run_marker", "test_feats", "test_rarity_and_levels", "test_version", "test_staged_vendors", "test_item_hints", "test_abandon_reset_history", "test_grades", "test_content_batch", "test_almanac_categories", "test_big_content_batch", "test_trigger_chips", "test_new_rules", "test_shop", "test_lose_and_bust", "test_rent_control_target",
		"test_full_run_victory", "test_seeded_reproducible", "test_profile", "test_preview", "test_pinned_clear", "test_cage_decisions", "test_bridges", "test_refine", "test_table_variety", "test_long_term", "test_stacking_twins", "test_free_chips", "test_story_beats", "test_sfx_synth", "test_music_synth",
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
	var sizes := {"french": 37, "european": 37, "american": 38, "mini": 13, "triple_zero": 39, "sunrise": 37, "no_zero": 36}
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
		check(sec == b.pockets.size() - maxi(0, b.zeros.size() - 1), "%s call bets cover the wheel" % id)
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
	run.table_offer = []   # most tests skip the free pick; test_free_chips covers it
	return run


func test_run_table_flow() -> void:
	var run = new_run()
	check(run.phase == RunState.Phase.TABLE and run.table_name() == "Floor", "starts at Night 1 Floor")
	check(run.inventory.size() == 2 and run.inventory[0].kind == "magnet" and run.inventory[1].kind == "perm", "European kit")
	for w in Wheels.ORDER:
		check(Wheels.get_def(w).get("style", "") != "", "%s has a starter plan" % w)
	check("satin_gloves" in new_run("no_zero").felt.house_rules, "Cheater's Wheel starts with Satin Gloves")
	check(run.table.target == Content.NIGHT_BASE[0], "first target")
	check(run.place_bet("S17", 3) and run.table.stack == Content.START_STACK - 3, "bet from stack")
	check(run.place_bet("S17", 2) and run.felt.chips_on("S17")[0].value == 5, "bets merge")
	check(run.take_back("S17") and run.table.stack == Content.START_STACK, "take back")
	check(not run.can_bet_on("VOI"), "call bets locked by default")
	check(run.place_bet("SP1_4", 1) and run.take_back("SP1_4"), "splits can be bet on")
	check(run.place_chip(0, "S30"), "place kit magnet")
	run.place_bet("S17", 1)
	run.table.objective = ""
	var before_cash: int = run.cash
	run.spin(17)
	check(run.table.stack == Content.START_STACK - 1 + 1 and run.table.take == 35.0, "win returns stake and scores")
	check(run.phase == RunState.Phase.SHOP, "target 30 cleared in one hit -> shop")
	check(run.cash == before_cash + Content.CLEAR_CASH[0] + mini(before_cash / 5, 5), "clear reward with comps (balls-left cash is in the bonus pick)")
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


func test_act2() -> void:
	var run = RunState.new()
	run.start_run(7, "european", Profile.default_unlocks(), 2)
	check(run.nights_total() == 8 and run.enforcer_order.size() == 8 and run.enforcer_order[7] == "owner", "Act II: 8 nights, the Owner last")
	for i in range(4):
		check(Content.ENFORCERS[run.enforcer_order[i]].get("act", 1) == 1, "Act I Enforcers first")
	# Jump to night 5's boss table: the Act II Enforcers, upstairs names.
	run.night = 4
	run.table_idx = 1
	check(run.upstairs() and run.table_name() == "Velvet Room", "upstairs table names")
	run.night = 7
	run.table_idx = 2
	run._start_table()
	check(run.felt.boss_rule == "owner" and run.felt.boss_is("zero_tax") and run.felt.boss_is("called") and not run.felt.boss_is("frozen"), "the Owner combines two rules")
	run.table.take = run.table.target - 1
	run.place_bet("S17", 1)
	run.spin(17)
	check(run.phase == RunState.Phase.VICTORY, "beating the Owner wins Act II")
	# Act I still ends after night 4.
	var a1 = new_run()
	a1.night = 3
	a1.table_idx = 2
	a1._start_table()
	a1.table.take = a1.table.target
	a1.place_bet("S17", 1)
	a1.spin(17)
	check(a1.phase == RunState.Phase.VICTORY and a1.nights_total() == 4, "Act I ends after night 4")
	# New Enforcer twists.
	var r = new_run()
	r.felt.boss_rule = "no_inside"
	check(not r.can_bet_on("SP1_4") and r.can_bet_on("S1") and r.can_bet_on("RED"), "the Inspector closes inside bets")
	r.enforcer_order = ["kline", "kline", "kline", "kline"]
	r.table_idx = 2
	r._start_table()
	check(r.felt.boss_rule == "short" and r.table.spins_left == Content.SHORT_SPINS, "Mr. Kline: four spins")
	var v = new_run()
	v.felt.boss_rule = "drain"
	var st: int = v.table.stack
	v.spin(5)
	check(v.table.stack == st - Content.DRAIN_PER_SPIN, "Velvet drains 2 chips a spin")
	# Profile: Act II opens after an Act I win.
	var p = Profile.new()
	check(not p.act2_unlocked(), "Act II locked at first")
	p.record_run(4, 50.0, true, 1, Content.MARKER_ACT1)
	check(p.act2_unlocked() and p.total_paid == Content.MARKER_ACT1, "winning Act I opens Act II")
	p.record_run(8, 10.0, true, 2)
	check(p.act2_runs == 1 and p.act2_wins == 1, "Act II runs counted")


func test_dealer_and_endless() -> void:
	var run = new_run()
	run.table.take = run.table.target + 6.5
	run.place_bet("S1", 1)
	run.spin(5)  # a miss, but Take is already past the target, so the table clears 6 over
	check(run.phase == RunState.Phase.SHOP and run.overflow >= 6, "spare Take past the payment is banked")
	run.shop.vendors = ["cashier", "dealer"]
	run._restock()
	var fav := -1
	var vou := -1
	for i in range(run.shop.stock.size()):
		match run.shop.stock[i].type:
			"favour":
				fav = i
			"voucher":
				vou = i
	check(fav >= 0 and vou >= 0, "the Dealer sells a favour and a voucher")
	run.overflow = 100
	var fid: String = run.shop.stock[fav].id
	check(run.price_text(run.shop.stock[fav]).ends_with("TAKE") and run.buy(fav) and run.overflow < 100, "paid in spare Take")
	run.vouchers = ["patience", "comp_card", "vip_rack"]
	run.favours = ["extra_spin", "fat_stack", "head_start"]
	var cash0: int = run.cash
	run.leave_shop()
	check(run.table.spins_left == Content.SPINS + 2, "Patience +1 and Extra Spin +1")
	check(run.table.stack == run.stack_size + Content.FAT_STACK, "Fat Stack")
	check(run.table.take == floor(run.table.target * Content.HEAD_START), "Head Start")
	check(run.favours.is_empty() and run.relic_slots() == Content.RELIC_SLOTS + 1, "favours are spent; VIP Rack adds a slot")
	run.table.take = run.table.target
	run.place_bet("S17", 1)
	run.spin(17)
	check(run.cash > cash0, "cleared")
	run.vouchers.append("house_credit")
	run._restock()
	for it in run.shop.stock:
		if it.currency == "cash":
			check(run.price_of(it) == maxi(1, it.price - 1), "House Credit takes $1 off")
	# Endless
	var e = RunState.new()
	e.start_run(3, "european", Profile.default_unlocks(), 3)
	check(e.endless() and e.nights_total() > 1000, "endless never ends on a win")
	var t8: int = Content.targets_for(8)[0]
	var t9: int = Content.targets_for(9)[0]
	check(t8 > Content.NIGHT_BASE[7] and t9 > t8, "endless targets keep climbing")
	check(Content.ENFORCERS.has(e.enforcer_order[8 % e.enforcer_order.size()]), "Enforcers cycle")


func test_run_save() -> void:
	var run = new_run()
	run.place_bet("S17", 2)
	run.spin(17)  # clears: now in the Cage
	run.cash = 33
	run.vouchers = ["patience"]
	run.felt.add_chip("perm", "SP1_4", 3, "hot")
	var path := "user://test_run.save"
	check(run.save_to(path), "save mid-run")
	var r2 = RunState.new()
	check(r2.load_from(path), "load")
	check(r2.phase == run.phase and r2.cash == 33 and r2.night == run.night and r2.table_idx == run.table_idx, "phase, cash and position restored")
	check(r2.felt.chips.size() == run.felt.chips.size() and r2.felt.chips[-1].flaw == "hot" and r2.felt.chips[-1].value == 3, "felt chips restored with flaws")
	check(r2.shop.stock.size() == run.shop.stock.size() and r2.vouchers == ["patience"], "shop and perks restored")
	# Same seed position: the next restock and table play out identically.
	run.leave_shop()
	r2.leave_shop()
	check(r2.table.target == run.table.target and r2.table.spins_left == run.table.spins_left, "next table identical")
	var a: Dictionary = run.spin()
	var b: Dictionary = r2.spin()
	check(a.pocket == b.pocket, "the RNG continues from the same place")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(not RunState.new().load_from(path), "no save, nothing to load")


func test_run_marker() -> void:
	var run = new_run()
	check(run.marker_total() == Content.MARKER_ACT1 and run.marker_paid() == 0, "a fresh run owes the whole marker")
	run.place_bet("S17", 1)
	run.spin(17)
	var p1: int = run.marker_paid()
	check(p1 > 0 and p1 < run.marker_total() / 10, "the first table pays a small share")
	run.leave_shop()
	run.table.take = run.table.target
	run.place_bet("S17", 1)
	run.spin(17)
	check(run.marker_paid() > p1, "each table pays more")
	var w = new_run()
	w.night = 3
	w.table_idx = 2
	w._start_table()
	check(w.marker_paid() < w.marker_total() and w.marker_paid() > w.marker_total() / 2, "the last table is a big share")
	w.table.take = w.table.target
	w.place_bet("S17", 1)
	w.spin(17)
	check(w.phase == RunState.Phase.VICTORY and w.marker_paid() == w.marker_total() and w.marker_left() == 0, "a win pays the marker in full")


func test_feats() -> void:
	var run = new_run()
	run.place_bet("S17", 3)
	var res: Dictionary = run.spin(17)
	var got := Feats.check("spin", {"res": res, "run": run, "staked": 3, "target": 8}, [])
	check("straight_up" in got and "jackpot" in got and not ("high_roller" in got), "spin feats: straight up and jackpot")
	check(not ("straight_up" in Feats.check("spin", {"res": res, "run": run, "staked": 3, "target": 8}, ["straight_up"])), "earned feats don't repeat")
	check("high_roller" in Feats.check("spin", {"res": res, "run": run, "staked": 25, "target": 999}, []), "high roller")
	var info := {"spins_left": 0, "boss": true, "enforcer": "sal"}
	var c := Feats.check("clear", {"info": info, "run": run}, [])
	check("last_gasp" in c and "beat_sal" in c and not ("beat_oro" in c), "clear feats")
	run.wheel_id = "american"
	var e := Feats.check("end", {"won": true, "run": run}, [])
	check("paid_in_full" in e and "hard_way" in e and not ("euro_win" in e), "end feats")
	check(Feats.check("end", {"won": false, "run": run}, []).is_empty(), "losing earns no end feats")
	check(run.best_spin == res.take, "the run remembers its best spin")
	var st := Feats.check("clear", {"info": {"spins_left": 0, "spins_used": 6, "boss": true, "enforcer": "oro"}, "run": run}, [])
	check("last_ball_enforcer" in st and not ("one_spin_table" in st), "paid the Enforcer on the last ball")
	check("one_spin_table" in Feats.check("clear", {"info": {"spins_left": 5, "spins_used": 1, "boss": false, "enforcer": ""}, "run": run}, []), "one and done")
	var cb := Feats.check("spin", {"res": res, "run": run, "staked": 1, "target": 20, "before": 4.0, "spins_before": 1, "cleared": true}, [])
	check("comeback" in cb, "the comeback")
	var r2 = new_run()
	r2.place_bet("S5", 1)
	check(Feats.check("end", {"won": true, "run": r2}, []).has("no_outside_win"), "Inside Man when no outside bets")
	r2.place_bet("RED", 1)
	check(not Feats.check("end", {"won": true, "run": r2}, []).has("no_outside_win"), "...broken by an outside bet")


func test_rarity_and_levels() -> void:
	# Rarity weighting: commons show up far more often than legendaries.
	var run = new_run()
	var counts := {"perm": 0, "kingmaker": 0}
	for i in range(3000):
		var k: String = run._pick_rare(["perm", "kingmaker"])
		counts[k] += 1
	check(counts.perm > counts.kingmaker * 3 and counts.kingmaker > 100, "commons outnumber legendaries (%d vs %d)" % [counts.perm, counts.kingmaker])
	check(Content.rarity_of("kingmaker") == "legendary" and Content.rarity_of("perm") == "common", "rarity lookup")
	# Levelling: a twin stacked on its chip raises its value.
	run.inventory = [{"kind": "magnet", "value": 1}, {"kind": "magnet", "value": 1}]
	check(run.place_chip(0, "S9") and run.place_chip(0, "S9"), "place twins")
	var m: Array = run.felt.chips_on("S9").filter(func(c): return c.kind == "magnet")
	check(m.size() == 1 and m[0].value == 2, "twins merge into a level 2 chip")
	# Levels matter for the specials.
	var k2 = felt("european", [["kingmaker", "S7", 2], ["perm", "RED", 2]])
	near(Resolver.resolve_spin(k2, 7).take, (70.0 + 2.0) * 2.0, "level 2 Kingmaker: x2")
	var mi = felt("european", [["mint", "S3", 3]])
	check(Resolver.resolve_spin(mi, 20).cash == 3, "level 3 Mint: +$3")
	# New content.
	var mr = felt("european", [["mirror", "S1", 1]])
	near(Resolver.resolve_spin(mr, 36).take, 35.0, "Mirror on 1 catches 36")
	near(Resolver.resolve_spin(mr, 1).take, 35.0, "Mirror still pays its own number")
	near(Resolver.resolve_spin(mr, 0).take, 0.0, "zero has no mirror")
	var pl = felt("european", [["porch_light", "S32", 2]])
	near(Resolver.resolve_spin(pl, 15).take, 35.0, "Porch Light: wheel neighbour pays half (2 x 35 / 2)")
	near(Resolver.resolve_spin(pl, 19).take, 0.0, "two pockets away pays nothing")
	var sv = felt("european", [["perm", "S17", 1], ["perm", "S16", 1]])
	sv.house_rules.append("sevens")
	near(Resolver.resolve_spin(sv, 17).take, 70.0, "Lucky Sevens doubles 17")
	near(Resolver.resolve_spin(sv, 16).take, 35.0, "...not 16")
	var sg = felt("european", [["perm", "RED", 4]])
	sg.house_rules.append("satin_gloves")
	near(Resolver.resolve_spin(sg, 1).take, 6.0, "Satin Gloves: red pays 1.5:1")


func test_version() -> void:
	var Version := preload("res://core/version.gd")
	var re := RegEx.new()
	re.compile("^\\d+\\.\\d+\\.\\d+$")
	check(re.search(Version.VERSION) != null, "version is MAJOR.MINOR.PATCH (%s)" % Version.VERSION)
	check(Version.label().begins_with("v" + Version.VERSION), "title label shows the version")


func test_staged_vendors() -> void:
	var run = new_run()
	run.new_player = true
	check(run._pick_vendors() == ["cashier"], "first night: only the Cashier")
	run.night = 1
	for i in range(10):
		var v: Array = run._pick_vendors()
		check(v.size() == 2 and v[1] == "pit_boss", "night 2: the Pit Boss joins")
	run.beaten = ["sal"]
	var seen := {}
	for i in range(40):
		seen[run._pick_vendors()[1]] = true
	check(seen.has("loan_shark") and seen.has("dealer"), "after an Enforcer: Loan Shark and Dealer too")
	run.new_player = false
	run.night = 0
	run.beaten = []
	check(run._pick_vendors().size() == 2, "returning players get two windows from the start")
	for k in Story.TIPS:
		check(Story.TIPS[k].id.begins_with("tip_") and not Story.TIPS[k].lines.is_empty(), "tip %s" % k)


func test_item_hints() -> void:
	var run = new_run()
	run.felt.add_chip("porch_light", "S5", 1)
	run.felt.house_rules.append("satin_gloves")
	var h: Array = run.item_hints({"type": "rule", "id": "dealer_signature"})
	check(h.size() >= 1 and "Porch Light" in h[0], "wheel items point at your Porch Light")
	check(run.item_hints({"type": "chip", "id": "kingmaker"}).is_empty() or not "Satin" in run.item_hints({"type": "chip", "id": "kingmaker"})[0], "no false friends")
	run.enforcer_order = ["accountant", "accountant", "accountant", "accountant"]
	run.table_idx = 2
	var bad: Array = run.item_hints({"type": "rule", "id": "satin_gloves"})
	check(bad.any(func(x): return x.begins_with("Useless against The Accountant")), "even-money rules flagged useless against the Accountant")
	var good: Array = run.item_hints({"type": "chip", "id": "bridge"})
	check(good.any(func(x): return x.begins_with("Good against The Accountant")), "inside chips flagged good against the Accountant")
	for id in Content.TAGS:
		check(Content.CHIPS.has(id) or Content.UPGRADES.has(id) or Content.HOUSE_RULES.has(id), "tagged item %s exists" % id)


func test_abandon_reset_history() -> void:
	var run = new_run()
	var ended := []
	run.run_ended.connect(func(w): ended.append(w))
	check(run.abandon() and run.phase == RunState.Phase.GAME_OVER and ended == [false], "abandoning a run ends it as a loss")
	check(not run.abandon(), "can't abandon twice")
	var p = Profile.new()
	p.markers = 9
	p.feats = ["jackpot"]
	p.settings.music = 0.2
	for i in range(12):
		p.add_history({"wheel": "european", "acts": 1, "nights": i, "take": 10, "best_spin": 5, "won": false})
	check(p.history.size() == 10 and p.history[0].nights == 11, "history keeps the newest 10")
	p.reset()
	check(p.markers == 0 and p.feats.is_empty() and p.history.is_empty() and is_equal_approx(p.settings.music, 0.2), "reset wipes progress but keeps options")


func test_grades() -> void:
	var g0 = RunState.new()
	g0.start_run(11, "european", Profile.default_unlocks(), 1, 0)
	var g8 = RunState.new()
	g8.start_run(11, "european", Profile.default_unlocks(), 1, 8)
	check(g8.table.stack == g0.table.stack - 5, "Short Stack: 5 fewer chips")
	check(g8.table.spins_left == g0.table.spins_left, "Fast Tables spare the Floor table")
	g8.table_idx = 1
	g8._start_table()
	check(g8.table.spins_left == Content.SPINS - 1, "Fast Tables: a spin fewer at the High Roller")
	check(g8.table.target > g0.table.target, "Heavy Payments and Vance's Own raise the payment")
	check(g8.marker_total() == int(round(Content.MARKER_ACT1 * (1.0 + Content.MARKER_GRADE_STEP * 8))), "a bigger marker")
	var item := {"type": "chip", "id": "perm", "price": 4, "currency": "cash", "vendor": "cashier"}
	check(g8.price_of(item) == 5 and g0.price_of(item) == 4, "Tight Cage: +$1")
	var p = Profile.new()
	check(p.max_grade() == 0, "only grade 1 at first")
	p.record_run(4, 300.0, true, 1, 0, 0)
	check(p.max_grade() == 1, "a win opens the next grade")
	p.record_run(4, 300.0, false, 1, 0, 1)
	check(p.max_grade() == 1, "a loss doesn't")
	check(Content.GRADES.size() == 9, "nine grades")


func test_content_batch() -> void:
	var bc = felt("european", [["black_cat", "S1", 2]])
	near(Resolver.resolve_spin(bc, 2).take, 4.0, "Black Cat: +2 per level on a black hit")
	near(Resolver.resolve_spin(bc, 3).take, 0.0, "...nothing on red")
	var pn = felt("european", [["penny", "S9", 1]])
	check(Resolver.resolve_spin(pn, 9).cash == 2, "Lucky Penny: +$2 when it hits")
	var sn = felt("european", [["snowball", "S9", 1]])
	check(Resolver.resolve_spin(sn, 9).felt_after.chips[0].value == 3, "Snowball grows 2 levels on a hit")
	var se = felt("european", [["sentinel", "S0", 1]])
	near(Resolver.resolve_spin(se, 0).take, 35.0 + 8.0, "Sentinel: its zero pays plus 8")
	var cr = felt("european", [["crown", "COL1", 1], ["perm", "S1", 1]])
	near(Resolver.resolve_spin(cr, 1).take, (2.0 + 35.0) * 1.25, "Column Crown x1.25 on its column")
	near(Resolver.resolve_spin(cr, 2).take, 0.0, "...and nothing off it")
	var lp = felt("european", [])
	lp.square_upgrades[5] = "lamp"
	check(Resolver.resolve_spin(lp, 5).cash == 3, "Lucky Lamp: +$3")
	var sk = felt("european", [["bet", "DOZ1", 4], ["bet", "S20", 1]])
	sk.bet_upgrades["DOZ1"] = "silk"
	var rs := Resolver.resolve_spin(sk, 20)
	check(rs.stack == 4 + 1 and rs.lost == 0, "Silk Box: the losing dozen bet goes back to the stack")
	var sw = felt("european", [["perm", "S8", 1], ["perm", "ST7", 1]])
	sw.square_upgrades[8] = "sweet_spot"
	near(Resolver.resolve_spin(sw, 8).take, 35.0 * 1.5 + 11.0 * 1.5, "Sweet Spot: every covering bet x1.5")
	var lc = felt("european", [["perm", "S4", 1]])
	lc.house_rules.append("last_call")
	near(Resolver.resolve_spin(lc, 4).take, 35.0, "Last Call: not on an ordinary spin")
	lc.final_spin = true
	near(Resolver.resolve_spin(lc, 4).take, 70.0, "Last Call: the final spin doubles")
	var ins = felt("european", [["bet", "S1", 5], ["bet", "S2", 2], ["perm", "S3", 1]])
	ins.house_rules.append("insurance")
	near(Resolver.resolve_spin(ins, 3).take, 35.0 - 2.0, "Insurance: the biggest losing bet is forgiven")
	var hs = felt("european", [["perm", "DOZ1", 1]])
	hs.house_rules.append("high_society")
	near(Resolver.resolve_spin(hs, 5).take, 3.0, "High Society: dozens pay 3:1")
	var bt = felt("european", [["perm", "S2", 1], ["perm", "S1", 1]])
	bt.house_rules.append("black_tie")
	near(Resolver.resolve_spin(bt, 2).take, 52.5, "Black Tie: black straight x1.5")
	near(Resolver.resolve_spin(bt, 1).take, 35.0, "...red untouched")
	var run = new_run()
	run.inventory = [{"kind": "crown", "value": 1}, {"kind": "sentinel", "value": 1}]
	check(not run.place_chip(0, "S5") and run.place_chip(0, "COL2"), "Column Crown only on a column")
	check(not run.place_chip(0, "S5") and run.place_chip(0, "S0"), "Sentinel only on a zero")
	run.felt.house_rules.append("comped")
	var cash0: int = run.cash
	run.table.take = run.table.target
	run.place_bet("S17", 1)
	run.spin(17)
	check(run.last_result.size() > 0 and run.cash >= cash0 + Content.CLEAR_CASH[0] + Content.COMPED_CASH, "Comped Drinks: +$3 a clear")
	check(Content.CHIPS.size() >= 18 and Content.UPGRADES.size() >= 9 and Content.HOUSE_RULES.size() >= 16, "content counts")


func test_almanac_categories() -> void:
	var counted := {}
	for g in Content.ALMANAC:
		var table: Dictionary = Content.almanac_table(g[1])
		check(not g[2].is_empty(), "category %s has items" % g[0])
		for id in g[2]:
			check(table.has(id), "%s is in %s" % [id, g[1]])
			check(not counted.has(id), "%s listed once" % id)
			counted[id] = true
	for table in [Content.CHIPS, Content.UPGRADES, Content.HOUSE_RULES, Content.FAVOURS, Content.VOUCHERS]:
		for id in table:
			check(counted.has(id), "%s appears in an Almanac category" % id)


func test_big_content_batch() -> void:
	var sl = felt("european", [["street_light", "S4", 1]])
	near(Resolver.resolve_spin(sl, 5).take, 3.0, "Street Light: another number in its street")
	near(Resolver.resolve_spin(sl, 7).take, 0.0, "...not the next street")
	var rh = felt("european", [["red_herring", "S2", 2]])
	near(Resolver.resolve_spin(rh, 1).take, 4.0, "Red Herring: +2 per level on red")
	var jr = felt("european", [["jar", "S9", 1]])
	var j1 := Resolver.resolve_spin(jr, 10)
	var j2 := Resolver.resolve_spin(j1.felt_after, 11)
	check(j2.felt_after.chips[0].value == 3, "Jackpot Jar grows on every miss")
	var j3 := Resolver.resolve_spin(j2.felt_after, 9)
	near(j3.take, 3.0 * 35.0, "...pays at its full level")
	check(j3.felt_after.chips[0].value == 1, "...then empties")
	var hg = felt("european", [["hedge", "RED", 1]])
	near(Resolver.resolve_spin(hg, 2).take, 1.0, "Hedge: +1 when red misses")
	near(Resolver.resolve_spin(hg, 1).take, 1.0, "...and the red pays normally when it hits")
	var ws = felt("european", [["wheel_spoke", "S32", 1]])
	near(Resolver.resolve_spin(ws, 19).take, 4.0, "Wheel Spoke: two pockets away")
	near(Resolver.resolve_spin(ws, 4).take, 0.0, "...three is too far")
	var ec = felt("european", [["echo", "S5", 1], ["perm", "S6", 1], ["magnet", "S30", 2]])
	var er := Resolver.resolve_spin(ec, 5)
	check(er.felt_after.chips[1].value == 2 and er.felt_after.chips[2].value == 3, "Echo levels every other chip")
	var ac = felt("european", [["ace", "S2", 1], ["perm", "BLACK", 2]])
	near(Resolver.resolve_spin(ac, 2).take, (35.0 + 2.0) * 2.0, "Ace of Spades doubles the spin")
	var tj = felt("european", [["tip_jar", "S1", 1], ["bet", "S2", 3], ["bet", "S3", 4]])
	check(Resolver.resolve_spin(tj, 20).cash == 5, "Tip Jar: $1 per losing chip, capped at 5")
	var gt = felt("european", [["green_thumb", "S0", 1]])
	check(Resolver.resolve_spin(gt, 0).felt_after.chips[0].value == 2, "Green Thumb grows on a zero")
	var sp = felt("european", [["signpost", "CO1", 1]])
	check(Resolver.resolve_spin(sp, 1).cash == 2, "Signpost: +$2 when its corner hits")
	var dm = felt("european", [["perm", "S8", 1]])
	dm.square_upgrades[8] = "diamond"
	check(Resolver.resolve_spin(dm, 8).felt_after.chips[0].value == 2, "Diamond Square levels its chips")
	var mg = felt("european", [["perm", "S8", 2]])
	mg.square_upgrades[8] = "magnetized"
	near(Resolver.resolve_spin(mg, 11).take, 35.0, "Magnetized: half on a grid neighbour")
	var tw = felt("european", [["perm", "S2", 1]])
	tw.square_upgrades[2] = "twin_square"
	near(Resolver.resolve_spin(tw, 35).take, 35.0, "Twin Square: pays on its mirror")
	var sk = felt("european", [["perm", "S32", 2], ["perm", "S26", 2]])
	sk.square_upgrades[0] = "spoke"
	near(Resolver.resolve_spin(sk, 0).take, 35.0 + 35.0, "Spoke: both wheel neighbours of 0 score half")
	var gtm = felt("european", [["perm", "DOZ1", 2]])
	gtm.bet_upgrades["DOZ1"] = "gold_trim"
	var gr := Resolver.resolve_spin(gtm, 3)
	near(gr.take, 5.0, "Gold Trim: 2.5:1")
	check(gr.cash == 1, "...and +$1")
	var fb = felt("european", [["perm", "COL1", 3]])
	fb.bet_upgrades["COL1"] = "fat_box"
	near(Resolver.resolve_spin(fb, 1).take, 6.0 + 6.0, "Fat Box: +2 per chip")
	var rb = felt("european", [["perm", "DOZ2", 1]])
	rb.bet_upgrades["DOZ2"] = "repeat_box"
	rb.last_pocket = 14
	near(Resolver.resolve_spin(rb, 20).take, 4.0, "Repeat Box doubles a repeat")
	rb.last_pocket = 3
	near(Resolver.resolve_spin(rb, 20).take, 2.0, "...not otherwise")
	var lc = felt("european", [["perm", "RED", 1]])
	lc.bet_upgrades["RED"] = "lucky_colour"
	near(Resolver.resolve_spin(lc, 1).take, 2.0, "Lucky Colour: red pays 2:1")
	var run = new_run()
	run.inventory = [{"kind": "hedge", "value": 1}, {"kind": "ace", "value": 1}]
	check(not run.place_chip(0, "S5") and run.place_chip(0, "ODD"), "Hedge only on an even-money box")
	check(not run.place_chip(0, "S1") and run.place_chip(0, "S2"), "Ace of Spades only on black")
	run.shop = {"pending_upgrade": "lucky_colour"}
	check(run.upgrade_targets().size() == 6 and "RED" in run.upgrade_targets(), "Lucky Colour targets the even-money boxes")
	check(Content.CHIPS.size() >= 28 and Content.UPGRADES.size() >= 17, "content counts (%d chips, %d upgrades)" % [Content.CHIPS.size(), Content.UPGRADES.size()])


## Trigger chips: [kind, square, pocket that fires it, take, cash, pocket that doesn't].
const TRIGGER_CASES := [
	["odd_fellow", "S10", 3, 2.0, 0, 4], ["even_keel", "S9", 4, 2.0, 0, 3],
	["low_roller", "S30", 5, 2.0, 0, 20], ["penthouse", "S3", 20, 2.0, 0, 5],
	["dozen_watch", "S1", 12, 2.0, 0, 13], ["pillar", "S1", 4, 2.0, 0, 2],
	["night_owl", "S1", 20, 1.0, 0, -99], ["piggy_bank", "S1", 20, 0.0, 1, -99],
	["clover", "S32", 4, 2.0, 0, 2], ["doorbell", "S8", 11, 3.0, 0, 12],
	["prime_time", "S1", 7, 3.0, 0, 9], ["square_deal", "S2", 16, 5.0, 0, 15],
	["teen_idol", "S1", 14, 3.0, 0, 20], ["fibonacci", "S4", 13, 4.0, 0, 14],
	["nickel", "S1", 25, 3.0, 0, 26], ["seventh_heaven", "S1", 27, 4.0, 0, 28],
	["last_digit", "S3", 23, 4.0, 0, 24], ["far_side", "S0", 5, 10.0, 0, 2],
	["golden_goose", "S9", 9, 35.0, 5, -99], ["heart_of_gold", "S9", 9, 45.0, 0, -99],
	["spare_key", "S1", 0, 0.0, 4, 2],
]


func test_trigger_chips() -> void:
	for t in TRIGGER_CASES:
		var f = felt("european", [[t[0], t[1], 1]])
		var r := Resolver.resolve_spin(f, t[2])
		near(r.take, t[3], "%s fires on %d (take)" % [t[0], t[2]])
		check(r.cash == t[4], "%s fires on %d (cash %d)" % [t[0], t[2], r.cash])
		if t[5] != -99:
			var q := Resolver.resolve_spin(f, t[5])
			near(q.take, 0.0, "%s stays quiet on %d" % [t[0], t[5]])
	var sd = felt("european", [["seedling", "S1", 4]])
	var s1 := Resolver.resolve_spin(sd, 20)
	check(s1.felt_after.chips[0].value == 5, "Seedling grows on a miss")
	check(Resolver.resolve_spin(s1.felt_after, 20).felt_after.chips[0].value == 5, "...up to level 5")
	var lv = felt("european", [["odd_fellow", "S10", 3]])
	near(Resolver.resolve_spin(lv, 3).take, 6.0, "trigger rewards scale with level")
	check(Content.CHIPS.size() >= 50, "50 chips (%d)" % Content.CHIPS.size())
	check(Content.HOUSE_RULES.size() >= 25, "25 House Rules (%d)" % Content.HOUSE_RULES.size())


func test_preview() -> void:
	var f = felt("european", [["bet", "S17", 1]])
	var fa := Preview.fires_at(f, 17)
	check("S17" in fa.keys and fa.take > 30.0, "fires_at: the straight scores on its pocket")
	check(Preview.fires_at(f, 5).keys.is_empty(), "fires_at: a miss lights nothing")
	var odd := Preview.pays_on(f, "odd_fellow", "S10")
	check(odd.size() == 19 and odd.all(func(p): return p % 2 == 1 or p == 10), "pays_on: Odd Fellow pays on the 18 odd pockets and its own square (%s)" % str(odd))
	check(Preview.absolute_trigger("odd_fellow") and not Preview.absolute_trigger("bet"), "absolute triggers")
	check(Preview.clearing_pockets(f, 20.0) == [17], "clearing_pockets: only 17 pays 20")
	check(Preview.clearing_pockets(f, 0.0).is_empty(), "nothing to clear once paid")
	check(Preview.ev_gain_chip(f, "odd_fellow", "S10") > 0.5, "ev gain of a trigger chip is positive")
	check(Preview.rep_key(f, "bet") == "S1", "rep key defaults to a straight")
	var before: float = Resolver.resolve_spin(f, 17).take
	Preview.pays_on(f, "odd_fellow", "S10")
	near(Resolver.resolve_spin(f, 17).take, before, "previews never mutate the felt")


func test_pinned_clear() -> void:
	var run = new_run()
	run.place_bet("S17", 3)
	run.place_bet("RED", 2)
	check(run.clear_bets(["S17"]) and run.felt.value_on("S17") == 3 and run.felt.value_on("RED") == 0, "Clear keeps pinned bets")
	run.last_bets = {"S17": 3, "RED": 2}
	var h := Preview.cage_hints(run, {"type": "chip", "id": "odd_fellow"})
	check(h.pockets.size() >= 18 and h.lines.size() == 1, "Cage hint for an absolute trigger lights its pockets %s %s" % [str(h), str(run.felt.chips.map(func(c): return [c.kind, c.bet]))])
	var hr := Preview.cage_hints(run, {"type": "rule", "id": "red_streak"})
	check(hr.lines.size() == 1, "Cage hint for a rule uses the last layout: %s" % str(hr.lines))
	var hm := Preview.cage_hints(run, {"type": "chip", "id": "magnet"})
	check(hm.lines.size() <= 1, "Cage hint for a placed chip picks a best bet")


func test_cage_decisions() -> void:
	var run = new_run()
	run.place_bet("S17", 1)
	run.spin(17)
	check(run.phase == RunState.Phase.SHOP and run.shop.get("offer", []).is_empty(), "the Cage no longer has its own opening pick")
	# Early clear: cleared on the first ball with spins to spare.
	check(run.shop.bonus.size() == 3, "early clear offers a bonus choice")
	var c0: int = run.cash
	check(run.take_bonus(0) and run.cash == c0 + run.table.spins_left and run.shop.bonus.is_empty(), "cash bonus pays")
	# Reserve + reroll.
	run.cash = 50
	var keep: Dictionary = run.shop.stock[0]
	check(run.reserve(0), "reserve an item")
	check(run.reroll(), "reroll")
	check(run.shop.stock.has(keep) and run.shop.stock[run.shop.reserved] == keep, "the reserved item survives the reroll")
	run.shop.free_rerolls = 1
	var cr: int = run.cash
	check(run.reroll() and run.cash == cr and run.shop.free_rerolls == 0, "free rerolls cost nothing")
	# Trade-in at the Cashier.
	run.leave_shop()
	run.place_chip(0, "S5")  # the Magnet
	run.place_bet("S17", 1)
	run.spin(17)
	var mag = run.felt.perm_chips().filter(func(c): return c.kind == "magnet")
	if not mag.is_empty():
		run.cash = 10
		var nk: String = run.convert_chip(mag[0].id)
		check(nk != "" and nk != "magnet" and run.cash == 10 - Content.CONVERT_PRICE, "trade-in swaps the chip for $3")
		check(run.felt.chips_on("S5").any(func(c): return c.kind == nk), "...on the same square")
	# No bonus on a slow clear.
	var r2 = new_run()
	r2.table.spins_left = 1
	r2.place_bet("S17", 1)
	r2.spin(17)
	check(r2.shop.bonus.is_empty(), "no bonus for a last-ball clear")


func test_bridges() -> void:
	# Outside Connection: DOZ1 wins on 5; perm chips on 3 (lv2) and 20 (outside the dozen).
	var f = felt("european", [["bet", "DOZ1", 1], ["perm", "S3", 2], ["perm", "S20", 1]])
	var base: float = Resolver.resolve_spin(f, 5).take
	f.house_rules.append("outside_connection")
	near(Resolver.resolve_spin(f, 5).take, base + 2.0, "Outside Connection: +1 per level of number chips in the dozen")
	# Colour Coded: RED wins on 1; perm chips on 3 (red, lv2) and 20 (black).
	var g = felt("european", [["bet", "RED", 1], ["perm", "S3", 2], ["perm", "S20", 1]])
	var gb: float = Resolver.resolve_spin(g, 1).take
	g.house_rules.append("colour_coded")
	near(Resolver.resolve_spin(g, 1).take, gb + 2.0, "Colour Coded: +1 per level on red numbers")
	# Inside Track: a split wins on 1, the perm chip on 1 grows.
	var h = felt("european", [["bet", "SP1_2", 1], ["perm", "S1", 1]])
	h.house_rules.append("inside_track")
	var r := Resolver.resolve_spin(h, 1)
	check(r.felt_after.chips_on("S1").any(func(c): return not c.is_bet() and c.value == 2), "Inside Track grows the chip on the winning number")
	# Rainy Day: a blank spin pays $2.
	var d = felt("european", [["bet", "S17", 1]])
	d.house_rules.append("rainy_day")
	check(Resolver.resolve_spin(d, 5).cash == 2 and Resolver.resolve_spin(d, 17).cash == 0, "Rainy Day pays on a blank spin only")


func test_refine() -> void:
	var f = felt("european", [["perm", "S17", 2]])
	var base: float = Resolver.resolve_spin(f, 17).take
	f.chips[0].mod = "focused"
	near(Resolver.resolve_spin(f, 17).take, base * 2.0, "Focused doubles its own number")
	f.chips[0].mod = "steady"
	near(Resolver.resolve_spin(f, 5).take, 2.0, "Steady pays +1 per level on a miss")
	check(FeltState.from_dict(f.to_dict()).chips[0].mod == "steady", "refines survive a save")
	var run = new_run()
	run.place_bet("S17", 1)
	run.spin(17)
	run.shop.vendors = ["cashier", "pit_boss"]
	var c = run.felt.add_chip("perm", "S8", 1)
	check(not run.can_refine(c.id), "level 1 chips can't be refined")
	c.value = 2
	run.cash = 10
	check(run.refine(c.id, "focused") and c.mod == "focused" and run.cash == 10 - Content.REFINE_PRICE, "refine sets the path for $6")
	check(not run.refine(c.id, "steady"), "one path per chip")
	run.cash = 10
	check(run.pick_up(c.id) and run.inventory.back().get("mod", "") == "focused", "moving a chip keeps its refine")


func test_table_variety() -> void:
	# Eight Act I Enforcers, four per run, all different.
	var act1 := Content.ENFORCERS.keys().filter(func(k): return Content.ENFORCERS[k].get("act", 1) == 1)
	check(act1.size() == 8, "eight Act I Enforcers (%d)" % act1.size())
	var run = new_run()
	var first4: Array = run.enforcer_order.slice(0, 4)
	check(first4.all(func(k): return k in act1), "a run meets four Act I Enforcers")
	for e in Content.ENFORCERS:
		check(Content.COUNTERS.has(Content.ENFORCERS[e].rule) or Content.ENFORCERS[e].rule == "owner", "%s has counter hints" % e)
	# The Duchess: piles of 5+ pay half.
	var f = felt("european", [["bet", "RED", 6]])
	var full: float = Resolver.resolve_spin(f, 1).take
	f.boss_rule = "crowd"
	near(Resolver.resolve_spin(f, 1).take, full * 0.5, "The Duchess halves big piles")
	# Spread Out: covering all three dozens scores +25%.
	var g = felt("european", [["bet", "DOZ1", 2], ["bet", "DOZ2", 1], ["bet", "DOZ3", 1]])
	near(Resolver.resolve_spin(g, 5).take, 2.0, "three dozens: 4 won, 2 lost")
	g.condition = "regions"
	near(Resolver.resolve_spin(g, 5).take, 3.0, "Spread Out multiplies the winnings")
	# Tight Felt: at most 6 spots.
	run.table.condition = "scarce"
	run.felt.condition = "scarce"
	for k in ["S1", "S2", "S3", "S4", "S5", "S6"]:
		run.place_bet(k, 1)
	check(not run.place_bet("S7", 1) and run.place_bet("S6", 1), "Tight Felt blocks a 7th spot but not stacking")
	check(run.bet_block_reason("S7") != "", "...and says why")
	# Countess Ilsa: no encores.
	var r2 = new_run()
	r2.felt.boss_rule = "no_repeat"
	r2.place_bet("S17", 1)
	r2.spin(5)
	check(not r2.place_bet("S17", 1) and r2.place_bet("S18", 1), "Ilsa blocks last spin's spots")
	# Miss Tempo: a blank spin costs 10% of the Take built.
	var r3 = new_run()
	r3.table.take = 20.0
	r3.felt.boss_rule = "tempo"
	r3.place_bet("S17", 1)
	r3.spin(5)
	near(r3.table.take, 18.0, "Miss Tempo cuts a blank spin")
	# The Timekeeper: the payment grows 5% a spin.
	var r4 = new_run()
	r4.felt.boss_rule = "clock"
	var t0: int = r4.table.target
	r4.place_bet("S17", 1)
	r4.spin(5)
	check(r4.table.target == t0 + int(ceil(t0 * 0.05)), "the Timekeeper grows the payment")
	# Objectives.
	var r5 = new_run()
	r5.table.objective = "outside_only"
	r5.place_bet("RED", 5)
	r5.spin(1)
	check(r5.objective_met(), "Clean Hands: outside bets only")
	r5.place_bet("S17", 1)
	r5.spin(5)
	check(not r5.objective_met() and r5.objective_text().ends_with("(blown)"), "...blown by an inside bet")
	var r6 = new_run()
	r6.table.objective = "straight"
	r6.place_bet("S17", 1)
	var c6: int = r6.cash
	r6.spin(17)
	check(r6.last_result.size() > 0 and r6.phase == RunState.Phase.SHOP, "cleared")
	# Routes.
	check(r6.shop.get("routes", []).size() == 2, "a route choice before the High Roller")
	check(r6.pick_route("back_room") and r6.shop.routes.is_empty(), "pick a route")
	r6.inventory = []
	r6.leave_shop()
	check(r6.table.spins_left <= 5 and r6.table.route == "back_room", "the Back Room is a short table")
	# Events.
	var r7 = new_run()
	r7.place_bet("S17", 1)
	r7.spin(17)
	r7.shop.event = "lou_bet"
	r7.cash = 10
	r7.answer_event(0)
	check(r7.cash == 7 and r7.shop.lou_bet and r7.shop.event == "", "Lou's side bet costs $3")
	r7.shop.event = "fence_hot"
	r7.answer_event(0)
	check(r7.inventory.back().get("flaw", "") == "hot", "the Fence's free chip is hot")
	r7.shop.event = "dolores_tip"
	r7.answer_event(0)
	check("extra_spin" in r7.favours, "Dolores' extra ball")


func test_long_term() -> void:
	# Seeds: the same seed deals the same run.
	var a = RunState.new()
	a.start_run(777, "european", Profile.default_unlocks())
	var b = RunState.new()
	b.start_run(777, "european", Profile.default_unlocks())
	check(a.run_seed == 777 and a.enforcer_order == b.enforcer_order and a.table.objective == b.table.objective, "same seed, same run")
	check(RunState.parse_seed("12345") == 12345 and RunState.parse_seed("lucky") == RunState.parse_seed("lucky") and RunState.parse_seed("") == 0, "seed parsing")
	# Weekly preset: stable within a week, changes week to week.
	var w1: Dictionary = RunState.weekly_preset(1795000000)
	var w2: Dictionary = RunState.weekly_preset(1795000000 + 3600)
	var w3: Dictionary = RunState.weekly_preset(1795000000 + 7 * 86400)
	check(w1.id == w2.id and w1.seed == w2.seed and w1.id != w3.id, "weekly preset is per week")
	check(w1.wheel in Wheels.ORDER, "weekly wheel is real")
	# Saves keep the new fields; old saves without them still load.
	var c = RunState.new()
	c.start_run(5, "european", Profile.default_unlocks(), 1, 0, {"challenge": "shoestring", "weekly": "W1"})
	var d: Dictionary = c.to_dict()
	var e = RunState.new()
	check(e.from_dict(d) and e.challenge == "shoestring" and e.weekly == "W1" and e.run_seed == 5, "challenge and seed survive a save")
	d.erase("challenge")
	check(RunState.new().from_dict(d), "old saves without the new fields load")
	# Challenges.
	check(c.stack_size == Content.SHOESTRING_STACK, "Shoestring stack")
	c.place_bet("S17", 1)
	c.spin(17)
	check(not "pit_boss" in c.shop.vendors and not "loan_shark" in c.shop.vendors, "Shoestring: no Pit Boss or Loan Shark")
	var n = RunState.new()
	n.start_run(5, "european", Profile.default_unlocks(), 1, 0, {"challenge": "no_outside"})
	check(not n.place_bet("RED", 1) and n.place_bet("S1", 1), "No Outside Bets closes the boxes")
	var f = RunState.new()
	f.start_run(5, "european", Profile.default_unlocks(), 1, 0, {"challenge": "fence_run"})
	check(f.inventory.size() == 2 and f.cash == Content.START_CASH + Content.FENCE_RUN_CASH, "Fence's Run kit")
	f.place_bet("S17", 1)
	f.spin(17)
	check(f.shop.vendors == ["fence"], "Fence's Run: only the Fence")
	var g = RunState.new()
	g.start_run(5, "french", Profile.default_unlocks(), 1, 0, {"challenge": "gauntlet"})
	check(g.table.boss and g.table.enforcer != "", "Gauntlet: the first table is an Enforcer")
	g.place_bet("S17", 1)
	g.table.take = g.table.target
	g.spin(17)
	check(g.phase == RunState.Phase.SHOP and g.table_idx == 1 and g.night == 0, "Gauntlet: an Enforcer table doesn't end the night early")
	g.inventory = []
	g.shop.offer = []
	g.leave_shop()
	check(g.table.boss and g.table.enforcer != g.beaten[0], "Gauntlet: the second table is a different Enforcer")
	check(Feats.check("end", {"won": true, "run": g}, []).has("ch_gauntlet"), "challenge Feat")
	var tour := Feats.check("end", {"won": true, "run": g, "wheels_won": ["european", "american", "mini", "triple_zero", "sunrise", "no_zero"]}, [])
	check(tour.has("grand_tour"), "Grand Tour once every wheel is won")
	check(not Feats.check("end", {"won": true, "run": g, "wheels_won": []}, []).has("grand_tour"), "...not before")
	# Starter kits.
	var k = RunState.new()
	k.start_run(5, "european", Profile.default_unlocks(), 1, 0, {"starter": "banker_kit"})
	check(k.inventory.is_empty() and k.cash == Content.START_CASH + 8, "Banker's Kit")
	var k2 = RunState.new()
	k2.start_run(5, "european", Profile.default_unlocks(), 1, 0, {"starter": "collector_kit"})
	check(k2.inventory.size() == 3, "Collector's Kit")
	check(Profile.catalogue().any(func(x): return x.category == "starter"), "starters are sold at the Pawn Shop")


## Stacking a chip on its twin must never be worse than owning the two chips apart.
func test_stacking_twins() -> void:
	var run = new_run()
	run.inventory = [{"kind": "kingmaker", "value": 1}, {"kind": "kingmaker", "value": 1}]
	check(run.place_chip(0, "S17") and run.place_chip(0, "S17"), "stack two Kingmakers")
	var k = run.felt.chips_on("S17")[0]
	check(k.value == 2 and k.copies == 2, "level 2 from 2 chips")
	var f = felt("european", [["bet", "S17", 1], ["kingmaker", "S17", 2]])
	f.chips[1].copies = 2
	var apart = felt("european", [["bet", "S17", 1], ["kingmaker", "S17", 1], ["kingmaker", "S17", 1]])
	near(Resolver.resolve_spin(f, 17).take, Resolver.resolve_spin(apart, 17).take, "stacked Kingmakers multiply like two apart (x2.25)")
	var grown = felt("european", [["bet", "S17", 1], ["kingmaker", "S17", 2]])
	near(Resolver.resolve_spin(grown, 17).take, (35.0 + 70.0) * 2.0, "a level grown (not stacked) still adds +0.5")
	# Fixed effects count every stacked chip.
	var r = felt("european", [["respin", "S5", 2]])
	r.chips[0].copies = 2
	check(Resolver.resolve_spin(r, 5).respins == 2, "stacked Respins give a spin each")
	var cp = felt("european", [["compounding", "S5", 2]])
	cp.chips[0].copies = 2
	check(Resolver.resolve_spin(cp, 9).felt_after.chips[0].value == 4, "stacked Compounding grows +2 a spin")
	var e = felt("european", [["echo", "S5", 2], ["perm", "S9", 1]])
	e.chips[0].copies = 2
	check(Resolver.resolve_spin(e, 5).felt_after.chips_on("S9")[0].value == 3, "stacked Echo gives +2 levels")
	var wz = felt("european", [["wildcard_zero", "S0", 2]])
	wz.chips[0].copies = 2
	var wz1 = felt("european", [["wildcard_zero", "S0", 1]])
	near(Resolver.resolve_spin(wz, 0).take, 2.0 * Resolver.resolve_spin(wz1, 0).take, "stacked Wildcard Zeros pay twice")
	var sd = felt("european", [["seedling", "S1", 5]])
	sd.chips[0].copies = 2
	check(Resolver.resolve_spin(sd, 20).felt_after.chips[0].value == 7, "stacked Seedlings grow +2, up to 10")
	# Selling a stack refunds every chip in it; moving keeps the count.
	run.leave_shop() if run.phase == RunState.Phase.SHOP else null
	run.place_bet("S17", 1)
	run.spin(17)
	var kc = run.felt.chips_on("S17").filter(func(c): return not c.is_bet())[0]
	run.cash = 10
	run.pick_up(kc.id)
	check(run.inventory.back().get("copies", 1) == 2, "moving a stack keeps its chips")
	run.place_chip(run.inventory.size() - 1, "S20")
	var kc2 = run.felt.chips_on("S20")[0]
	var c0: int = run.cash
	check(kc2.copies == 2 and run.sell_chip(kc2.id) and run.cash == c0 + int(Content.CHIPS.kingmaker.price * 2 * Content.SELL_SHARE), "selling a stack refunds both chips")


func test_free_chips() -> void:
	var run = RunState.new()
	run.start_run(11, "european", Profile.default_unlocks())
	check(run.table_offer.size() == 3, "the first table opens with a free pick of three chips")
	var dirs := {}
	for o in run.table_offer:
		dirs[o.dir] = true
		check(o.type == "chip" and o.id != "perm", "free picks are special chips (%s)" % o.id)
	check(dirs.size() == 3, "...from three different build directions")
	var d: Dictionary = run.to_dict()
	var back = RunState.new()
	check(back.from_dict(d) and back.table_offer.size() == 3, "the offer survives a save")
	d.erase("table_offer")
	check(RunState.new().from_dict(d), "old saves without it still load")
	var inv: int = run.inventory.size()
	var picked: String = run.table_offer[1].id
	check(run.take_table_offer(1) and run.table_offer.is_empty() and run.inventory.back().kind == picked and run.inventory.size() == inv + 1, "taking one puts it in the rack")
	check(not run.take_table_offer(0), "only one pick per table")
	run.inventory = []
	run.place_bet("S17", 1)
	run.table.take = run.table.target
	run.spin(17)
	run.leave_shop()
	check(run.table_offer.size() == 3, "the next table offers a fresh pick")
	run.place_bet("S17", 1)
	run.spin(5)
	check(run.table_offer.is_empty(), "spinning passes on the pick")
	var nz = RunState.new()
	nz.start_run(3, "no_zero", Profile.default_unlocks())
	check(not nz.table_offer.any(func(o): return Content.CHIPS[o.id].get("zero_only", false)), "no zero chips on a wheel without a zero")
	var fr = RunState.new()
	fr.start_run(3, "european", Profile.default_unlocks(), 1, 0, {"challenge": "fence_run"})
	check(fr.table_offer.is_empty(), "no free picks in the Fence's Run")
	# The Cage: three chips at the Cashier, plain Permanents now rare.
	var perms := 0
	var total := 0
	run.shop.vendors = ["cashier", "fence"]
	for i in range(50):
		run._restock()
		var chips: Array = run.shop.stock.filter(func(it): return it.type == "chip" and it.vendor == "cashier")
		check(chips.size() == Content.CASHIER_CHIPS, "the Cashier stocks 3 chips")
		for it in run.shop.stock:
			if it.type == "chip":
				total += 1
				perms += 1 if it.id == "perm" else 0
	check(float(perms) / total < 0.3, "plain Permanents are rare in the Cage (%d of %d)" % [perms, total])


func test_new_rules() -> void:
	var zt = felt("european", [["bet", "RED", 4]])
	zt.house_rules.append("zero_tolerance")
	var r := Resolver.resolve_spin(zt, 0)
	check(r.lost == 0 and r.stack == 4, "Zero Tolerance: bets come back on a zero")
	var bk = felt("european", [])
	bk.house_rules.append("bankroll")
	check(Resolver.resolve_spin(bk, 5).stack == 1, "Bankroll: +1 chip a spin")
	var dd = felt("european", [["perm", "S5", 1]])
	dd.house_rules.append("double_down")
	dd.spin_no = 1
	near(Resolver.resolve_spin(dd, 5).take, 70.0, "Double Down: first spin x2")
	dd.spin_no = 2
	near(Resolver.resolve_spin(dd, 5).take, 35.0, "...only the first")
	var lb = felt("european", [["perm", "S5", 1]])
	lb.house_rules.append("late_bloomer")
	lb.spin_no = 4
	near(Resolver.resolve_spin(lb, 5).take, 52.5, "Late Bloomer: x1.5 from spin 4")
	var co = felt("european", [["perm", "CO1", 1]])
	co.house_rules.append("corner_office")
	near(Resolver.resolve_spin(co, 1).take, 10.0, "Corner Office: corners pay 10")
	var bs = felt("european", [["perm", "S5", 2]])
	bs.house_rules.append("big_spender")
	check(Resolver.resolve_spin(bs, 5).cash == 3, "Big Spender: +$3 on a 70-Take spin")
	var vt = felt("european", [["perm", "S5", 3]])
	vt.house_rules.append("veterans")
	near(Resolver.resolve_spin(vt, 5).take, 105.0 * 1.5, "Old Timers: level 3+ x1.5")
	var run = new_run()
	run.felt.house_rules.append("patron")
	run.enforcer_order = ["sal", "sal", "sal", "sal"]
	run.table_idx = 2
	run._start_table()
	check(run.table.spins_left == Content.SPINS + 1, "Patron: +1 spin at Enforcer tables")
	var ci = new_run()
	ci.felt.house_rules.append("compound_interest")
	ci.cash = 40
	ci.table.take = ci.table.target
	ci.place_bet("S17", 1)
	ci.spin(17)
	check(ci.cash >= 40 + Content.CLEAR_CASH[0] + 4, "Compound Interest: +$1 per $10 held")


func test_shop() -> void:
	var run = new_run()
	run.place_bet("S17", 1)
	run.spin(17)
	run.cash = 100
	check(run.shop.vendors.size() == 2 and run.shop.vendors[0] == "cashier", "the Cashier plus one rotating vendor")
	run.shop.vendors = ["cashier", "pit_boss"]
	run._restock()
	check(run.shop.stock.size() == 6, "Cashier (3 chips + upgrade) and Pit Boss (2 rules)")
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
	check(res.markers == 3 and p.best_take == 1234, "run earns markers and records the best Take")
	check(p.buy_unlock("american") and p.markers == 0, "unlock american")
	var path := "user://test_profile.json"
	check(p.save(path), "save")
	var q = Profile.new()
	check(q.load_from(path) and q.best_take == p.best_take and q.is_unlocked("american") and q.runs == 1, "round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var run = RunState.new()
	run.start_run(1, "european", Profile.default_unlocks())
	for i in range(20):
		run._restock()
		for item in run.shop.stock:
			check(item.type in ["loan", "favour", "voucher"] or item.id in Profile.default_unlocks() or item.id == "perm", "shop only stocks unlocked content (%s)" % item.id)
		check(not ("fence" in run.shop.vendors), "the Fence needs unlocking")


func test_music_synth() -> void:
	var Music := preload("res://scenes/ui/music.gd")
	for track in ["lounge", "enforcer"]:
		var t0 := Time.get_ticks_msec()
		var w = Music.synth(track)
		var secs: float = w.data.size() / 2.0 / Music.RATE
		check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and secs > 10.0 and secs < 40.0, "%s loops (%.1fs)" % [track, secs])
		var loud := 0
		for i in range(0, w.data.size(), 64):
			loud = maxi(loud, absi(w.data.decode_s16(i)))
		check(loud > 3000, "%s is audible" % track)
		print("  music %s synthesised in %d ms" % [track, Time.get_ticks_msec() - t0])
		var tw = Music.synth(track + "_tension")
		check(tw.data.size() == w.data.size() and tw.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s tension layer matches the loop length" % track)


func test_sfx_synth() -> void:
	var Sfx := preload("res://scenes/ui/sfx.gd")
	for cue in ["click", "chip_place", "chip_remove", "spin", "ball_drop", "win", "big_win", "mult", "lose", "cash", "buy", "clear", "bust", "jackpot", "feat", "near", "unlock", "sting", "stack", "refund", "clear_all", "undo"]:
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
	p.seen_beats = ["first_night"]
	p.best_night = 1
	p.runs = 3
	var ids := []
	for b in Story.beats_due(p):
		ids.append(b.id)
	check(ids == ["first_enforcer", "regular", "nine_hundred"], "milestone beats in order (first Enforcer, third run, second run)")
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
	check(not Story.interlude(2, p).is_empty() and Story.interlude(1, p).is_empty() and Story.interlude(9, p).is_empty(), "interludes rotate once seen, only before nights 2-8")
	var ids_all := {}
	for sc in Story.all_scenes():
		check(not ids_all.has(sc.id) and sc.title != "" and not sc.lines.is_empty(), "scene %s is unique and complete" % sc.id)
		ids_all[sc.id] = true
	for v in Content.VENDORS:
		check(Story.VENDOR_INTROS.has(v), "vendor %s has an intro" % v)
