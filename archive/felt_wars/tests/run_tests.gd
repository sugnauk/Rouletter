extends SceneTree
## Headless test runner:  godot --headless --script res://tests/run_tests.gd
## Exits with code 1 if any assertion fails.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")
const Content := preload("res://core/content.gd")
const FeltState := preload("res://core/felt_state.gd")
const Resolver := preload("res://core/resolver.gd")
const HouseAI := preload("res://core/house_ai.gd")
const RunState := preload("res://core/run_state.gd")
const GameRng := preload("res://core/rng.gd")

const PL := Chip.Side.PLAYER
const HO := Chip.Side.HOUSE

var passed := 0
var failed := 0


func _initialize() -> void:
	for t in [
		"test_board_shapes", "test_every_bet_every_pocket", "test_fairness",
		"test_perm_never_lost", "test_house_collects", "test_capture", "test_house_seizes_outside",
		"test_ownership_ties_and_double_felt", "test_magnet", "test_gilded", "test_hot", "test_link",
		"test_croupier", "test_ledger", "test_compounding_and_mint", "test_respin", "test_collector",
		"test_wildcard_zero", "test_la_partage", "test_red_streak", "test_rent_control", "test_thirteen",
		"test_flanking", "test_walled", "test_decay", "test_capture_double", "test_resolver_is_pure",
		"test_house_ai_personalities", "test_scripted_run", "test_game_over", "test_shift_over",
		"test_seeded_reproducible",
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


func near(a: float, b: float, what: String) -> void:
	check(absf(a - b) < 1e-9, "%s (got %f, want %f)" % [what, a, b])


func felt_with(chips: Array):
	var f = FeltState.new()
	for c in chips:
		f.add_chip(c[0], c[1], c[2], c[3])
	return f


# --- Board & base payouts --------------------------------------------------------

func test_board_shapes() -> void:
	var counts := {"straight": 37, "split": 60, "street": 12, "corner": 22, "column": 3, "dozen": 3,
		"red": 1, "black": 1, "odd": 1, "even": 1, "low": 1, "high": 1}
	var seen := {}
	for k in Board.all_bet_keys():
		var b: Dictionary = Board.bet(k)
		seen[b.type] = seen.get(b.type, 0) + 1
		var size_by_type := {"straight": 1, "split": 2, "street": 3, "corner": 4, "column": 12, "dozen": 12}
		check(b.numbers.size() == size_by_type.get(b.type, 18), "bet %s size" % k)
	for t in counts:
		check(seen.get(t, 0) == counts[t], "bet type %s count %d" % [t, seen.get(t, 0)])
	check(Board.RED.size() == 18, "18 reds")
	check(Board.neighbours(5).size() == 4, "5 has 4 neighbours")
	check(Board.neighbours(1).has(0) and Board.neighbours(0).has(3), "0 borders first street")
	check(Board.WHEEL_ORDER.size() == 37, "wheel has 37 pockets")


func test_every_bet_every_pocket() -> void:
	for k in Board.all_bet_keys():
		var b: Dictionary = Board.bet(k)
		var f = felt_with([[PL, "temp", k, 2]])
		for p in range(37):
			var r := Resolver.resolve_spin(f, p)
			if p in b.numbers:
				check(r.player == 2 * (b.payout + 1) and r.bank == -2 * b.payout, "%s hit on %d" % [k, p])
			else:
				check(r.player == 0 and r.bank == 2, "%s miss on %d" % [k, p])


func test_fairness() -> void:
	# An unmodified board is exactly the European house edge: -1/37 per unit bet.
	for k in Board.all_bet_keys():
		var ev := Resolver.expected_value(felt_with([[PL, "temp", k, 1]]))
		near(ev.player, -1.0 / 37.0, "fair EV for %s" % k)
		near(ev.bank, 1.0 / 37.0, "bank EV for %s" % k)
	var ev2 := Resolver.expected_value(felt_with([[PL, "temp", "RED", 5], [PL, "temp", "S17", 3]]))
	near(ev2.player, -8.0 / 37.0, "fair EV scales with total stake")


func test_perm_never_lost() -> void:
	var f = felt_with([[PL, "perm", "S17", 1]])
	var miss := Resolver.resolve_spin(f, 4)
	check(miss.player == 0 and miss.felt_after.chips.size() == 1, "perm chip survives a miss")
	var hit := Resolver.resolve_spin(f, 17)
	check(hit.player == 35 and hit.felt_after.chips.size() == 1, "perm chip pays and stays")
	near(Resolver.expected_value(f).player, 35.0 / 37.0, "perm chip EV = +35/37")
	var o = felt_with([[PL, "perm", "DOZ2", 1]])
	near(Resolver.expected_value(o).player, 24.0 / 37.0, "perm dozen EV = 12*2/37")


func test_house_collects() -> void:
	var f = felt_with([[HO, "house", "S0", 2]])
	var r := Resolver.resolve_spin(f, 0)
	check(r.player == -70 and r.bank == 70, "House on 0 x2 collects 70")
	near(Resolver.expected_value(f).player, -70.0 / 37.0, "House stack EV")


func test_capture() -> void:
	var f = felt_with([[PL, "perm", "S5", 3], [HO, "house", "S5", 2]])
	check(f.owner(5) == PL, "out-stacked square is yours")
	var r := Resolver.resolve_spin(f, 5)
	check(r.player == 3 * 35 + 2, "capture pays chip + seizes House value")
	check(r.felt_after.chips_on("S5", HO).is_empty(), "House chips removed on capture")
	var g = felt_with([[PL, "perm", "S5", 2], [HO, "house", "S5", 3]])
	var r2 := Resolver.resolve_spin(g, 5)
	check(r2.player == -105 and r2.felt_after.chips_on("S5", PL).is_empty(), "House capture seizes your chips")


func test_house_seizes_outside() -> void:
	var f = felt_with([[PL, "perm", "RED", 4], [HO, "house", "S1", 1]])
	var r := Resolver.resolve_spin(f, 1)
	check(r.felt_after.chips_on("RED", PL).is_empty(), "outside chip seized on a House square")
	check(r.bank == 4 + 35 and r.player == -35, "seized value + collection go to the bank")
	var r2 := Resolver.resolve_spin(f, 3)
	check(r2.player == 4, "outside chip pays on a neutral red")


func test_ownership_ties_and_double_felt() -> void:
	var f = felt_with([[PL, "perm", "S8", 2], [HO, "house", "S8", 2]])
	check(f.owner(8) == HO, "House wins ties")
	f.square_upgrades[8] = "double_felt"
	check(f.owner(8) == HO, "double felt doubles both sides")
	f.chips[0].value = 3
	check(f.owner(8) == PL and f.weight(8, PL) == 6, "double felt weight")


# --- Chips ---------------------------------------------------------------------

func test_magnet() -> void:
	var f = felt_with([[PL, "magnet", "S5", 1]])
	var r := Resolver.resolve_spin(f, 8)
	check(r.player == 35, "magnet slid and paid")
	check(r.felt_after.chips[0].bet == "S8", "magnet now sits on the winner")
	check(Resolver.resolve_spin(f, 9).player == 0, "magnet ignores non-adjacent pockets")


func test_gilded() -> void:
	var f = felt_with([[PL, "perm", "S9", 1]])
	f.square_upgrades[9] = "gilded"
	check(Resolver.resolve_spin(f, 9).player == 40, "gilded pays 40")
	var h = felt_with([[HO, "house", "S9", 1]])
	h.square_upgrades[9] = "gilded"
	check(Resolver.resolve_spin(h, 9).player == -40, "gilded also pays the House")


func test_hot() -> void:
	var f = felt_with([[PL, "perm", "COL2", 2]])
	f.bet_upgrades["COL2"] = "hot"
	check(Resolver.resolve_spin(f, 5).player == 6, "hot column pays 3:1")
	near(Resolver.expected_value(f).player, 12.0 * 6.0 / 37.0, "hot column EV shift")


func test_link() -> void:
	var f = felt_with([[PL, "perm", "S20", 1], [PL, "perm", "S17", 2], [PL, "perm", "S23", 1], [PL, "perm", "S30", 1]])
	f.square_upgrades[20] = "link"
	var r := Resolver.resolve_spin(f, 20)
	check(r.player == 35 + int(round(2 * 35 * 0.25)) + int(round(35 * 0.25)), "link pays neighbours 25%")


func test_croupier() -> void:
	var f = felt_with([[PL, "croupier", "S4", 1], [HO, "house", "S0", 1], [HO, "house", "S30", 2]])
	var r := Resolver.resolve_spin(f, 4)
	check(r.player == 35 + 2, "croupier rakes 1 per House chip")
	check(r.felt_after.chips_on("S0", HO).is_empty(), "raked 1-value House chip is gone")
	check(r.felt_after.chips_on("S30", HO)[0].value == 1, "raked House stack shrinks")


func test_ledger() -> void:
	var f = felt_with([[PL, "ledger", "S14", 1], [PL, "perm", "S11", 1], [PL, "perm", "S15", 2], [PL, "perm", "S20", 1]])
	var r := Resolver.resolve_spin(f, 14)
	check(r.felt_after.chips_on("S11", PL)[0].value == 2, "ledger grows left neighbour")
	check(r.felt_after.chips_on("S15", PL)[0].value == 3, "ledger grows upper neighbour")
	check(r.felt_after.chips_on("S20", PL)[0].value == 1, "ledger ignores non-neighbours")


func test_compounding_and_mint() -> void:
	var f = felt_with([[PL, "compounding", "S7", 1], [PL, "mint", "S33", 1]])
	var r := Resolver.resolve_spin(f, 2)
	check(r.player == Content.MINT_INCOME and r.bank == -Content.MINT_INCOME, "mint pays every spin")
	check(r.felt_after.chips_on("S7", PL)[0].value == 2, "compounding grows")


func test_respin() -> void:
	var f = felt_with([[PL, "respin", "S12", 1]])
	check(Resolver.resolve_spin(f, 12).respins == 1, "respin grants a spin")
	check(Resolver.resolve_spin(f, 13).respins == 0, "respin needs a hit")


func test_collector() -> void:
	# 2 shares dozen 1; 11 shares the grid row (2,5,8,11...); 25 shares neither row nor dozen with 2? (25 row 0).
	var f = felt_with([[PL, "collector", "S2", 1], [PL, "perm", "S7", 3], [PL, "perm", "S35", 2], [PL, "perm", "S25", 4]])
	var r := Resolver.resolve_spin(f, 2)
	check(r.player == 35 + 3 + 2, "collector counts dozen + column value")


func test_wildcard_zero() -> void:
	var f = felt_with([[PL, "wildcard_zero", "S0", 1], [PL, "temp", "RED", 5], [HO, "house", "S0", 3]])
	var r := Resolver.resolve_spin(f, 0)
	check(r.player == 5, "outside bet pushes and House collects nothing")
	check(r.felt_after.chips_on("S0", PL).size() == 1, "wildcard survives on a House-held 0")


func test_la_partage() -> void:
	var f = felt_with([[PL, "temp", "EVEN", 10], [HO, "house", "S0", 2]])
	f.house_rules.append("la_partage")
	var r := Resolver.resolve_spin(f, 0)
	check(r.player == 5 - 35, "half back on 0 and House collection halved")


func test_red_streak() -> void:
	var f = felt_with([[PL, "perm", "RED", 10]])
	f.house_rules.append("red_streak")
	var r1 := Resolver.resolve_spin(f, 1)
	check(r1.player == 10 and r1.red_streak == 1, "first red: no bonus")
	var r2 := Resolver.resolve_spin(r1.felt_after, 3)
	check(r2.player == 11 and r2.red_streak == 2, "second red: +10%")
	var r3 := Resolver.resolve_spin(r2.felt_after, 2)
	check(r3.red_streak == 0, "black resets the streak")


func test_rent_control() -> void:
	var f = felt_with([[HO, "house", "S0", 2]])
	f.house_rules.append("rent_control")
	check(Resolver.resolve_spin(f, 0).player == -63, "rent control cuts 10%")


func test_thirteen() -> void:
	var f = felt_with([[PL, "perm", "S13", 1], [PL, "perm", "S14", 1], [HO, "house", "S13", 5]])
	f.house_rules.append("thirteen")
	check(Resolver.resolve_spin(f, 13).player == 0, "13 pays nobody")
	check(Resolver.resolve_spin(f, 14).player == 70, "13's neighbour pays double")


# --- Territory ------------------------------------------------------------------

func test_flanking() -> void:
	var f = felt_with([[HO, "house", "S5", 2], [PL, "perm", "S2", 1], [PL, "perm", "S8", 1], [PL, "perm", "S4", 1]])
	check(f.is_flanked(5), "three neighbours flank 5")
	var r := Resolver.resolve_spin(f, 30)
	check(r.felt_after.chips_on("S5", HO)[0].value == 1, "flanked House stack weakens")


func test_walled() -> void:
	var f = felt_with([[PL, "perm", "S10", 1], [PL, "perm", "S11", 1], [PL, "perm", "S12", 1]])
	check(f.is_walled(11), "full street is walled")
	var rng = GameRng.new(3)
	for i in range(20):
		HouseAI.take_turn(f, rng, "shuffler", 2, {})
	for n in [10, 11, 12]:
		check(f.raw_value(n, HO) == 0, "House never enters walled street (%d)" % n)


func test_decay() -> void:
	var f = felt_with([[PL, "perm", "S3", 4], [PL, "perm", "S6", 1]])
	f.pit_rules = ["decay"]
	var r := Resolver.resolve_spin(f, 20)
	check(r.felt_after.chips_on("S3", PL)[0].value == 3, "decay hits the biggest chip")


func test_capture_double() -> void:
	var f = felt_with([[PL, "perm", "S3", 3], [HO, "house", "S3", 2]])
	check(f.owner(3) == PL, "normally yours")
	f.pit_rules = ["capture_double"]
	check(f.owner(3) == HO, "heavy House chips take it")


func test_resolver_is_pure() -> void:
	var f = felt_with([[PL, "compounding", "S7", 1], [PL, "temp", "RED", 5], [HO, "house", "S0", 1]])
	Resolver.resolve_spin(f, 7)
	Resolver.expected_value(f)
	check(f.chips.size() == 3 and f.chips[0].value == 1 and f.chips[0].bet == "S7", "input felt untouched")


func test_house_ai_personalities() -> void:
	var rng = GameRng.new(11)
	var f = FeltState.new()
	HouseAI.seed_table(f, rng, 0)
	for i in range(6):
		HouseAI.take_turn(f, rng, "zero_priest", 1, {})
	for n in f.owned_squares(HO):
		check(Board.distance_from_zero(n) <= 2, "zero priest grows from 0 (%d)" % n)
	var b = FeltState.new()
	for i in range(8):
		HouseAI.take_turn(b, rng, "banker", 2, {"dozen": 1})
	for n in b.owned_squares(HO):
		check(Board.dozen_of(n) == 1, "banker stays in its dozen (%d)" % n)
	var s = felt_with([[PL, "perm", "S20", 1]])
	HouseAI.take_turn(s, rng, "shuffler", 2, {})
	check(s.owner(20) == HO, "shuffler retakes a thin square")


# --- Run state machine -------------------------------------------------------------

func test_scripted_run() -> void:
	var run = RunState.new()
	run.start_run(42)
	check(run.phase == RunState.Phase.MAP, "run starts on the map")
	check(run.available_nodes() == [0, 1], "first layer offers two tables")
	check(not run.enter_node(3), "cannot skip ahead")
	check(run.enter_node(0), "enter first table")
	check(run.phase == RunState.Phase.TABLE, "at a table")
	check(run.felt.owner(0) == HO, "House always holds 0")
	var before: int = run.bankroll
	check(run.buy_perm("S17", 5), "buy a permanent 5")
	check(run.bankroll == before - 5 * Content.PERM_PRICE, "perm cost charged")
	check(run.place_special("magnet", "S30"), "place inventory magnet")
	check(not run.place_special("magnet", "S31"), "inventory is consumed")
	check(not run.place_special("mint", "RED"), "mint is straight-only")
	check(run.place_temp("RED", 5), "temp bet")
	check(run.expected_value().player > 0.0, "investing makes EV positive")
	var guard := 0
	while run.phase == RunState.Phase.TABLE and guard < 40:
		guard += 1
		if run.felt.owner(17) != Chip.Side.PLAYER:
			run.buy_perm("S17", 1)
		run.spin(17)
	check(run.phase == RunState.Phase.SPOILS, "breaking the bank leads to spoils")
	check(run.felt.side_chips(HO).is_empty(), "House leaves the felt")
	check(run.felt.chips_on("S17", PL).size() == 1, "your chips carry over")
	check(run.spoils.size() == 3, "three spoils offered")
	# Prefer an upgrade if offered, to exercise targeting.
	var idx := 0
	for i in range(run.spoils.size()):
		if run.spoils[i].kind == "upgrade":
			idx = i
	var spoil: Dictionary = run.spoils[idx]
	check(run.take_spoil(idx), "take spoil")
	if spoil.kind == "upgrade":
		check(run.phase == RunState.Phase.SPOILS, "upgrade waits for a target")
		check(run.apply_upgrade(run.upgrade_targets()[0]), "upgrade placed")
	check(run.phase == RunState.Phase.MAP, "back on the map")
	check(run.available_nodes() == [2, 3], "second layer unlocked")
	check(run.enter_node(2), "enter event")
	check(run.phase == RunState.Phase.EVENT, "event phase")
	run.choose_event(1)
	check(run.phase == RunState.Phase.MAP, "walk away from event")


func test_game_over() -> void:
	var run = RunState.new()
	run.start_run(1)
	run.enter_node(0)
	run.bankroll = 10
	run.felt.add_house_value(0, 3)
	run.spin(0)
	check(run.phase == RunState.Phase.GAME_OVER and run.bankroll == 0, "House collection busts you")
	check(run.spin(1).is_empty(), "no spinning after game over")


func test_shift_over() -> void:
	var run = RunState.new()
	run.start_run(5)
	run.enter_node(1)
	run.table.spins_left = 1
	var empty := -1
	for n in range(1, 37):
		if run.felt.owner(n) == -1:
			empty = n
			break
	var before: int = run.bankroll
	run.spin(empty)
	check(run.phase == RunState.Phase.MAP, "shift over sends you to the map")
	check(run.bankroll == before - int(before * Content.SHIFT_PENALTY), "shift penalty")


func test_seeded_reproducible() -> void:
	var a = RunState.new()
	var b = RunState.new()
	a.start_run(99)
	b.start_run(99)
	a.enter_node(0)
	b.enter_node(0)
	var pa := []
	var pb := []
	for i in range(8):
		if a.phase == RunState.Phase.TABLE:
			pa.append(a.spin().pocket)
		if b.phase == RunState.Phase.TABLE:
			pb.append(b.spin().pocket)
	check(pa == pb and pa.size() > 0, "same seed, same spins")
