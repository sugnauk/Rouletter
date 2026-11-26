extends RefCounted
## The count: how a resolved spin is presented at the table, in three beats.
##   1. reveal  - the pocket lights up on the felt (and the wheel already shows it)
##   2. build   - every winning bet and triggered effect pulses in turn, building the score
##   3. count   - the spin's Take flows into the payment meter
## Ordinary spins stay brisk; exceptional ones (a one-spin clear, a final-ball clear, a personal
## best, a big combo) get a longer beat and a musical sting. Fast spins (Options) shrink every pause.
## Split out of table_screen.gd; `t` is the table screen.

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const RunState := preload("res://core/run_state.gd")

var t   ## the table screen


func _init(table) -> void:
	t = table


func _wait(secs: float) -> void:
	await t.get_tree().create_timer(secs * (0.25 if t.fast() else 1.0)).timeout


## ctx: {before, target, spins_before, stakes}
func play(res: Dictionary, ctx: Dictionary) -> void:
	var main = t.main
	var run = main.run
	var B = run.felt.board
	var fx = main.fx
	var felt_view = t.felt_view
	var before: float = ctx.before
	var target: int = ctx.target
	var meter_at := Vector2(t.MID_X + 150, 12)

	# --- Beat 1: reveal -------------------------------------------------------------
	var pkey := Board.straight_key(res.pocket)
	var pocket_pos: Vector2 = fx.local(felt_view.key_global(pkey))
	felt_view.flash(pkey, 1.4)
	var straight_hit: bool = res.events.any(func(e): return e.kind == "win" and e.label == "straight")
	if B.is_zero(res.pocket):
		fx.banner("ZERO!", P.GOOD, 1.0, 112)
	elif straight_hit:
		fx.banner("STRAIGHT UP!", P.GOLD, 1.1, 112)
		fx.burst(pocket_pos, 26, [P.GOLD, P.CREAM, P.RED])
	else:
		fx.pop_text(pocket_pos - Vector2(0, 10), "%s %s" % [B.label(res.pocket), B.colour_name(res.pocket).to_upper()], P.CREAM, 0.8)
	if res.zero_tax:
		fx.banner("ORO TAKES 10%", P.DANGER, 1.2, 140, 8)
		before *= 1.0 - Content.ZERO_TAX
	await _wait(0.3)

	# --- Beat 2: light up the build --------------------------------------------------
	t.spin_score_vis = true
	var gross := 0.0
	var lost := 0.0
	var delay := 0.24
	var combo := 0
	t.hits = 0
	var order := {"win": 0, "bonus": 1, "cash": 2, "push": 3, "mult": 4, "loss": 5}
	var events: Array = res.events.duplicate()
	events.sort_custom(func(a, b): return order[a.kind] < order[b.kind])
	for e in events:
		var key: String = e.key
		var at: Vector2 = fx.local(felt_view.key_global(key)) if key != "" else Vector2(353, 120)
		var name: String = t._bet_name(key)
		match e.kind:
			"win":
				gross += e.amount
				felt_view.flash(key, 0.6)
				felt_view.pop(key)
				felt_view.float_text(key, "+%d" % int(e.amount), P.GOLD)
				fx.burst(at, 6 + mini(20, int(e.amount / 4.0)), [P.GOLD, P.CREAM])
				fx.fly(at, meter_at, P.GOLD, 2 + mini(6, int(e.amount / 6.0)))
				t.hits += 1
				t.score_rows.append({"kind": "win", "text": "%s  %s" % [name, e.label.to_upper()], "amount": "+%d" % int(e.amount), "icon": t._chip_icon(key)})
				Sfx.play("win", 1.0 + 0.09 * combo)
				combo += 1
			"bonus":
				gross += e.amount
				felt_view.flash(key, 0.4)
				felt_view.float_text(key, "+%d" % int(e.amount), P.CYAN)
				fx.burst(at, 8, [P.CYAN, P.CREAM])
				fx.fly(at, meter_at, P.CYAN, 2)
				t.hits += 1
				t.score_rows.append({"kind": "bonus", "text": "%s  %s" % [name, e.label.to_upper()], "amount": "+%d" % int(e.amount), "icon": t._chip_icon(key)})
				Sfx.play("win", 1.0 + 0.09 * combo)
				combo += 1
			"loss":
				lost += -e.amount
				felt_view.float_text(key, "%d" % int(e.amount), P.DANGER)
				t.score_rows.append({"kind": "loss", "text": "%s  LOST%s" % [name, (" (" + e.label + ")") if e.label != "" else ""], "amount": "%d" % int(e.amount), "icon": ""})
				Sfx.play("lose")
			"mult":
				gross *= e.amount
				fx.banner("x%s %s" % [t._fmt(e.amount), e.label.to_upper()], P.VIOLET, 0.9, 140, 8)
				t.score_rows.append({"kind": "mult", "text": e.label.to_upper(), "amount": "x" + t._fmt(e.amount), "icon": "red_streak" if e.label == "Red Streak" else ("hot_hand" if e.label == "Hot Hand" else "dealer_signature")})
				main.shake(2.0, 0.15)
				Sfx.play("mult")
			"cash":
				felt_view.float_text(key, "+$%d" % int(e.amount), P.GOOD)
				t.score_rows.append({"kind": "cash", "text": "%s  %s" % [name, e.label.to_upper()], "amount": "+$%d" % int(e.amount), "icon": "cash"})
				Sfx.play("cash")
			"push":
				felt_view.float_text(key, e.label.to_upper(), P.DIM)
				t.score_rows.append({"kind": "push", "text": "%s  %s" % [name, e.label.to_upper()], "amount": "0", "icon": ""})
		t.spin_score = maxf(0.0, gross - lost)
		t.score_pop = 1.0
		t.score_view.queue_redraw()
		await _wait(delay)
		delay = maxf(0.08, delay * 0.82)
	if res.respins > 0:
		fx.banner("+%d SPIN" % res.respins, P.CYAN, 0.9, 140, 8)
	t.spin_score = res.take
	t.score_pop = 1.0
	if res.events.is_empty():
		t.score_rows.append({"kind": "push", "text": "%s %s - nothing on it" % [B.label(res.pocket), B.colour_name(res.pocket).to_upper()], "amount": "0", "icon": ""})
	t.receipt = receipt(res)
	t.score_view.queue_redraw()

	# --- Beat 3: count the Take into the payment -------------------------------------
	var after: float = before + res.take
	var cleared: bool = run.phase == RunState.Phase.SHOP or run.phase == RunState.Phase.VICTORY
	var final_ball: bool = cleared and ctx.spins_before <= 1
	var personal_best: bool = res.take > 0.0 and res.take > main.profile.best_spin
	if personal_best:
		main.profile.best_spin = int(res.take)
	var ratio: float = res.take / maxf(1.0, target)
	var exceptional: bool = final_ball or ratio >= 1.0 or (personal_best and res.take >= 20.0) or t.hits >= 5
	if res.take > 0.0:
		t.meter_pulse = 1.0
		if final_ball:
			fx.banner("ON THE LAST BALL!", P.GOLD, 1.8, 96, 16)
			fx.flash(0.6)
			main.shake(5.0, 0.45)
			fx.coin_rain(50)
			Sfx.play("sting")
		elif ratio >= 1.0:
			# One spin paid the whole table: the full jackpot treatment.
			fx.banner("JACKPOT!", P.GOLD, 1.6, 100, 24)
			fx.flash(0.7)
			main.shake(6.0, 0.5)
			fx.coin_rain(60)
			fx.burst(meter_at, 60, [P.GOLD, P.CREAM, P.GOOD, P.CYAN], 170.0)
			Sfx.play("jackpot")
		elif ratio >= 0.4:
			fx.banner("BIG WIN", P.GOLD, 1.2, 100, 16)
			fx.flash(0.3)
			main.shake(4.0, 0.35)
			fx.burst(meter_at, 40, [P.GOLD, P.CREAM, P.GOOD], 140.0)
			Sfx.play("big_win")
		elif ratio >= 0.15:
			fx.banner("NICE", P.GOOD, 0.8, 100, 8)
		if personal_best and res.take >= 20.0 and not final_ball and ratio < 1.0:
			fx.banner("PERSONAL BEST +%d" % int(res.take), P.CYAN, 1.4, 150, 8)
			Sfx.play("sting")
		if exceptional and not t.fast():
			Engine.time_scale = 0.45
			await t.get_tree().create_timer(0.35, true, false, true).timeout
			Engine.time_scale = 1.0
		var tw: Tween = t.create_tween()
		tw.tween_method(func(v: float): t.shown_take = v, before, after, 0.55 * (0.4 if t.fast() else 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
	else:
		t.shown_take = after
		near_miss(res)
	if res.get("tempo_cut", 0.0) > 0.0:
		fx.banner("MISSED A BEAT  -%d" % int(res.tempo_cut), P.DANGER, 1.0, 140, 8)
		Sfx.play("lose")
	if run.phase == RunState.Phase.TABLE and run.table.target > target:
		fx.pop_text(meter_at + Vector2(0, 14), "PAYMENT +%d" % (run.table.target - target), P.DANGER, 1.0)
	await _wait(0.6 if exceptional else 0.25)


## A one-line summary of where the spin's Take came from.
func receipt(res: Dictionary) -> String:
	var B = t.main.run.felt.board
	var parts := []
	var wins := 0.0
	var bonus := 0.0
	for e in res.events:
		match e.kind:
			"win":
				wins += e.amount
			"bonus":
				bonus += e.amount
	if wins > 0.0:
		parts.append("Bets +%d" % int(wins))
	if bonus > 0.0:
		parts.append("Chips +%d" % int(bonus))
	for e in res.events:
		if e.kind == "mult":
			parts.append("%s x%s" % [e.label, t._fmt(e.amount)])
	if res.lost > 0:
		parts.append("Lost -%d" % res.lost)
	if res.cash > 0:
		parts.append("+$%d" % res.cash)
	if parts.is_empty():
		return "%s %s: nothing on it" % [B.label(res.pocket), B.colour_name(res.pocket)]
	return "  ·  ".join(parts) + "   =  +%d" % int(res.take)


## The ball landed right next to one of your numbers: let the player feel it.
func near_miss(res: Dictionary) -> void:
	var run = t.main.run
	var B = run.felt.board
	for c in run.felt.chips:
		if not Board.is_straight(c.bet):
			continue
		var n := Board.straight_number(c.bet)
		if n == res.pocket:
			continue
		if B.wheel_distance(n, res.pocket) == 1 or res.pocket in B.neighbours(n):
			t.felt_view.near(c.bet)
			t.main.fx.pop_text(t.main.fx.local(t.felt_view.key_global(c.bet)) - Vector2(0, 8), "SO CLOSE", P.CREAM)
			Sfx.play("near")
			return


## The reward breakdown after a table is paid.
func show_tally() -> void:
	var run = t.main.run
	var info: Dictionary = t.main.last_clear
	if info.is_empty():
		return
	var rows := [
		["PAYMENT", "%d / %d" % [int(info.take), info.target], P.CREAM],
		["BASE PAY", "+$%d" % Content.CLEAR_CASH[info.table], P.GOLD],
	]
	if info.get("bonus_pick", false):
		rows.append(["%d BALLS LEFT" % info.spins_left, "PICK A BONUS", P.CYAN])
	elif info.spins_left > 0:
		rows.append(["%d SPIN%s LEFT" % [info.spins_left, "" if info.spins_left == 1 else "S"], "+$%d" % (info.spins_left * Content.CASH_PER_SPIN_LEFT), P.GOLD])
	if info.comps > 0:
		rows.append(["COMPS", "+$%d" % info.comps, P.GOLD])
	for x in info.get("extras", []):
		rows.append([x[0], "+$%d" % x[1], P.CYAN])
	var spare: int = maxi(0, int(info.take - info.target))
	if spare > 0:
		rows.append(["SPARE TAKE", "+%d" % spare, P.VIOLET])
	rows.append(["MARKER LEFT", "$" + P.money(run.marker_left()) if run.marker_left() > 0 else "PAID IN FULL", P.DANGER if run.marker_left() > 0 else P.GOOD])
	t.main.fx.show_tally("TABLE CLEARED  +$%d" % info.reward, rows)
