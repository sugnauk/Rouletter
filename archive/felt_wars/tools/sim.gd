extends SceneTree
## Headless balancing sim:  godot --headless --script res://tools/sim.gd [-- runs=300]
## 1. Fairness: an unmodified board is exactly -1/37 per unit.
## 2. Modifier EV shifts.
## 3. Bot-played runs: win rate per table, to check the difficulty curve.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")
const Content := preload("res://core/content.gd")
const FeltState := preload("res://core/felt_state.gd")
const Resolver := preload("res://core/resolver.gd")
const RunState := preload("res://core/run_state.gd")

const PL := Chip.Side.PLAYER
const HO := Chip.Side.HOUSE


func _initialize() -> void:
	var runs := 300
	for a in OS.get_cmdline_user_args():
		if a.begins_with("runs="):
			runs = int(a.substr(5))
	fairness()
	modifiers()
	bot_runs(runs)
	quit()


func fairness() -> void:
	print("== Fairness (plain one-unit bets, no House chips) ==")
	var worst := 0.0
	for k in Board.all_bet_keys():
		var f = FeltState.new()
		f.add_chip(PL, "temp", k, 1)
		worst = maxf(worst, absf(Resolver.expected_value(f).player + 1.0 / 37.0))
	print("  every bet EV = -1/37 = %.6f  (max deviation %.12f)  %s" % [-1.0 / 37.0, worst, "OK" if worst < 1e-9 else "BROKEN"])


func ev_of(setup: Callable) -> float:
	var f = FeltState.new()
	setup.call(f)
	return Resolver.expected_value(f).player


func modifiers() -> void:
	print("== Modifier EV per spin (player) ==")
	var rows := [
		["perm 1 on 17", func(f): f.add_chip(PL, "perm", "S17", 1), 35.0 / 37.0],
		["perm 1 on 17, gilded", func(f): f.add_chip(PL, "perm", "S17", 1); f.square_upgrades[17] = "gilded", 40.0 / 37.0],
		["perm 1 on DOZ1", func(f): f.add_chip(PL, "perm", "DOZ1", 1), 24.0 / 37.0],
		["perm 1 on DOZ1, hot", func(f): f.add_chip(PL, "perm", "DOZ1", 1); f.bet_upgrades["DOZ1"] = "hot", 36.0 / 37.0],
		["mint", func(f): f.add_chip(PL, "mint", "S9", 1), 35.0 / 37.0 + 2.0],
		["House x1 on 0", func(f): f.add_house_value(0, 1), -35.0 / 37.0],
		["House x1 on 0, rent control", func(f): f.add_house_value(0, 1); f.house_rules.append("rent_control"), -31.0 / 37.0],
		["House x1 on 0, la partage", func(f): f.add_house_value(0, 1); f.house_rules.append("la_partage"), -17.0 / 37.0],
	]
	for r in rows:
		var ev := ev_of(r[1])
		print("  %-32s %+8.4f  (expected %+8.4f) %s" % [r[0], ev, r[2], "OK" if absf(ev - r[2]) < 1e-9 else "MISMATCH"])


## A simple greedy bot: keep a reserve, retake the House's cheapest squares near your chips,
## otherwise stack fresh permanent chips; place inventory chips as soon as it gets them.
func bot_turn(run) -> void:
	for kind in run.inventory.keys().duplicate():
		var bet := "S0" if kind == "wildcard_zero" else Board.straight_key(_best_open(run))
		run.place_special(kind, bet)
	var reserve := 60
	var guard := 0
	while run.bankroll - Content.PERM_PRICE >= reserve and guard < 10:
		guard += 1
		var target := -1
		var cost := 999
		for n in range(1, 37):
			if run.felt.owner(n) == HO:
				var need: int = run.felt.weight(n, HO) - run.felt.weight(n, PL) + 1
				if need < cost:
					cost = need
					target = n
		if target != -1 and run.bankroll - run.perm_cost(cost) >= reserve:
			run.buy_perm(Board.straight_key(target), cost)
		else:
			run.buy_perm(Board.straight_key(_best_open(run)), 1)


func _best_open(run) -> int:
	# Prefer squares adjacent to your own territory (walls and flanks), else any open one.
	var mine: Array = run.felt.owned_squares(PL)
	for n in range(1, 37):
		if run.felt.owner(n) == -1:
			for m in Board.neighbours(n):
				if m in mine:
					return n
	for n in range(1, 37):
		if run.felt.owner(n) == -1:
			return n
	return 1 + (mine.size() % 36)


func bot_runs(runs: int) -> void:
	print("== Bot runs (%d seeds) ==" % runs)
	var reached := [0, 0, 0, 0]
	var won := [0, 0, 0, 0]
	var outcomes := {"victory": 0, "bust": 0, "boss_timeout": 0}
	var spins_total := 0
	for s in range(runs):
		var run = RunState.new()
		run.start_run(1000 + s)
		var steps := 0
		while steps < 2000:
			steps += 1
			match run.phase:
				RunState.Phase.MAP:
					var opts: Array = run.available_nodes()
					var pick: int = opts[0]
					for id in opts:
						if run.floor_map[id].type != "event":
							pick = id
					run.enter_node(pick)
					reached[run.current_layer] += 1
				RunState.Phase.TABLE:
					bot_turn(run)
					var layer: int = run.current_layer
					run.spin()
					spins_total += 1
					if run.phase == RunState.Phase.SPOILS or run.phase == RunState.Phase.VICTORY:
						won[layer] += 1
				RunState.Phase.SPOILS:
					run.take_spoil(0)
					if run.pending_upgrade != "":
						run.apply_upgrade(run.upgrade_targets()[0])
				RunState.Phase.EVENT:
					run.choose_event(1)
				RunState.Phase.VICTORY:
					outcomes.victory += 1
					break
				RunState.Phase.GAME_OVER:
					if run.message.contains("Pit Boss"):
						outcomes.boss_timeout += 1
					else:
						outcomes.bust += 1
					break
	for i in range(4):
		var label := "Pit Boss" if i == 3 else "Table %d" % (i + 1)
		var rate: float = 0.0 if reached[i] == 0 else 100.0 * won[i] / reached[i]
		print("  %-9s reached %4d  broke bank %4d  (%.0f%%)" % [label, reached[i], won[i], rate])
	print("  outcomes: %s   avg spins/run %.1f" % [outcomes, float(spins_total) / runs])
