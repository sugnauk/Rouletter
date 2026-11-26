extends Control
## The table. Bet from your stack, place rack chips, spin, then watch the count:
## every paying chip pops in order, multipliers stamp, losses tick off, and the spin's Take
## slams into the meter.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const Resolver := preload("res://core/resolver.gd")
const Odds := preload("res://core/odds.gd")
const RunState := preload("res://core/run_state.gd")
const FeltView := preload("res://scenes/ui/felt_view.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")
const Token := preload("res://scenes/ui/token_button.gd")

const LEFT_W := 180
const MID_X := 188
const RIGHT_X := 524
const RIGHT_W := 112
const DENOMS := [1, 5, 10]

var main
var felt_view
var wheel_view
var hud: Control
var history_view: Control
var score_view: Control
var gauge_view: Control
var spin_btn: Button
var status_lbl: Label
var denom_box: HBoxContainer
var rack_grid: GridContainer
var rules_flow: HFlowContainer
var boss_panel: Panel
var boss_lbl: Label
var log_box: RichTextLabel

var bet_size := 1
var selected_item := -1
var spinning := false
var shown_take := 0.0
var meter_pulse := 0.0
var board_id := ""
var announced := ""
var table_key := ""
var history: Array = []
var score_rows: Array = []      ## {kind, text, amount}
var spin_score := 0.0
var spin_score_vis := false
var score_pop := 0.0
var chance := 0.0
var take_per_spin := 0.0


func setup() -> void:
	hud = _canvas(Vector2(0, 0), Vector2(640, 24), _draw_hud)

	wheel_view = WheelView.new()
	P.place(wheel_view, Vector2(4, 24), Vector2(176, 176))
	add_child(wheel_view)
	spin_btn = P.button(self, "SPIN", _on_spin, Vector2(168, 22), P.FONT)
	spin_btn.add_theme_font_override("font", P.title_font())
	spin_btn.add_theme_stylebox_override("normal", P.box(Color("#b8862b"), P.BLACK, 1))
	spin_btn.add_theme_stylebox_override("hover", P.box(Color("#d9a63c"), P.CREAM, 1))
	spin_btn.add_theme_stylebox_override("pressed", P.box(Color("#8a6420"), P.BLACK, 1))
	spin_btn.add_theme_stylebox_override("disabled", P.box(Color("#4a3a1c"), P.BLACK, 1))
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		spin_btn.add_theme_color_override(s, P.WOOD_DARK)
	P.place(spin_btn, Vector2(8, 204))
	gauge_view = _canvas(Vector2(4, 232), Vector2(176, 124), _draw_gauges)

	felt_view = FeltView.new()
	P.place(felt_view, Vector2(MID_X, 32))
	felt_view.bet_clicked.connect(_on_bet_clicked)
	felt_view.bet_hovered.connect(func(k): _status(felt_view.describe(k) if k != "" else _hint()))
	add_child(felt_view)
	status_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	P.place(status_lbl, Vector2(MID_X, 150), Vector2(330, 10))
	history_view = _canvas(Vector2(MID_X, 162), Vector2(330, 18), _draw_history)
	score_view = _canvas(Vector2(MID_X, 184), Vector2(330, 170), _draw_score)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.visible = false
	log_box.add_theme_stylebox_override("normal", P.box(Color(0.03, 0.06, 0.04, 0.96), P.LINE.darkened(0.4)))
	P.place(log_box, Vector2(MID_X, 184), Vector2(330, 170))
	add_child(log_box)
	var lb := P.button(self, "LOG", func(): log_box.visible = not log_box.visible, Vector2(30, 12), P.FONT_SMALL)
	P.place(lb, Vector2(MID_X + 298, 186))

	P.place(P.label(self, "BET CHIP", P.FONT_SMALL, P.DIM), Vector2(RIGHT_X, 26))
	denom_box = HBoxContainer.new()
	denom_box.add_theme_constant_override("separation", 4)
	P.place(denom_box, Vector2(RIGHT_X, 36))
	add_child(denom_box)
	for v in DENOMS:
		var t = Token.new("", Vector2(34, 28))
		t.chip_value = v
		t.hover_text = "Each click bets %d chip%s from your stack. Right-click a square to take bets back." % [v, "" if v == 1 else "s"]
		t.hover_target = _status
		t.pressed.connect(func():
			bet_size = v
			Sfx.play("click")
			_refresh_tokens())
		denom_box.add_child(t)
	P.place(P.label(self, "RACK", P.FONT_SMALL, P.DIM), Vector2(RIGHT_X, 70))
	rack_grid = GridContainer.new()
	rack_grid.columns = 4
	rack_grid.add_theme_constant_override("h_separation", 4)
	rack_grid.add_theme_constant_override("v_separation", 4)
	P.place(rack_grid, Vector2(RIGHT_X, 80))
	add_child(rack_grid)
	P.place(P.label(self, "HOUSE RULES", P.FONT_SMALL, P.DIM), Vector2(RIGHT_X, 146))
	rules_flow = HFlowContainer.new()
	rules_flow.add_theme_constant_override("h_separation", 3)
	rules_flow.add_theme_constant_override("v_separation", 3)
	P.place(rules_flow, Vector2(RIGHT_X, 156), Vector2(RIGHT_W, 0))
	add_child(rules_flow)
	boss_panel = Panel.new()
	boss_panel.add_theme_stylebox_override("panel", P.box(Color("#2a0f12"), P.DANGER, 1))
	P.place(boss_panel, Vector2(RIGHT_X, 250), Vector2(RIGHT_W, 104))
	add_child(boss_panel)
	boss_lbl = P.label(boss_panel, "", P.FONT_SMALL, P.CREAM)
	boss_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(boss_lbl, Vector2(5, 4), Vector2(RIGHT_W - 10, 96))


func _canvas(pos: Vector2, sz: Vector2, fn: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(c, pos, sz)
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c


func _hint() -> String:
	return "Click: bet %d   Right-click: take back   Space: spin" % bet_size


func _status(s: String) -> void:
	status_lbl.text = s if s != "" else _hint()


func _process(delta: float) -> void:
	if not visible:
		return
	meter_pulse = maxf(0.0, meter_pulse - delta * 2.5)
	score_pop = maxf(0.0, score_pop - delta * 5.0)
	hud.queue_redraw()
	if spinning:
		score_view.queue_redraw()


# --- Refresh ----------------------------------------------------------------------

func refresh() -> void:
	var run = main.run
	if run.phase != RunState.Phase.TABLE and not spinning:
		return
	var bid: String = run.wheel_id + str(run.has_feature("call_bets"))
	if board_id != bid or felt_view.run != run:
		felt_view.run = run
		felt_view.layout()
		wheel_view.board = run.felt.board
		board_id = bid
	var tk := "%d-%d-%d" % [run.rng.seed_value, run.night, run.table_idx]
	if tk != table_key:
		table_key = tk
		history = []
		score_rows = []
		spin_score_vis = false
		wheel_view.result = -99
		log_box.clear()
		log_box.append_text("[color=#f2c14e]%s[/color]\n" % run.message)
	felt_view.targets = []
	felt_view.queue_redraw()
	var t: Dictionary = run.table
	if not spinning:
		shown_take = t.take
		var ev: Dictionary = run.expected_value()
		take_per_spin = ev.take
		chance = Odds.hit_chance(run.felt, t.target - t.take, t.spins_left)
	spin_btn.disabled = spinning or run.phase != RunState.Phase.TABLE
	spin_btn.text = "CALLED SPIN" if run.is_called_spin() else "SPIN"
	_refresh_tokens()
	if t.boss:
		var e: Dictionary = Content.ENFORCERS[t.enforcer]
		boss_panel.visible = true
		boss_lbl.text = "ENFORCER\n%s\n\n%s" % [e.name.to_upper(), e.desc]
		var key := "%d-%d" % [run.night, run.table_idx]
		if announced != key and t.spins_used == 0:
			announced = key
			main.say([{"speaker": e.name, "text": e.intro}])
	else:
		boss_panel.visible = false
	if status_lbl.text == "":
		_status("")
	hud.queue_redraw()
	gauge_view.queue_redraw()
	score_view.queue_redraw()
	history_view.queue_redraw()


func _refresh_tokens() -> void:
	var run = main.run
	for i in range(denom_box.get_child_count()):
		var t = denom_box.get_child(i)
		t.selected = DENOMS[i] == bet_size and selected_item < 0
		t.queue_redraw()
	for c in rack_grid.get_children():
		c.queue_free()
	var inv: Array = run.inventory
	if selected_item >= inv.size():
		selected_item = -1
	for i in range(inv.size()):
		var item: Dictionary = inv[i]
		var tok = Token.new(item.kind, Vector2(25, 25))
		tok.badge = "x%d" % item.value if item.value > 1 else ""
		tok.selected = i == selected_item
		tok.hover_text = "%s: %s" % [Content.CHIPS[item.kind].name, Content.CHIPS[item.kind].desc]
		tok.hover_target = _status
		tok.pressed.connect(_select_item.bind(i))
		rack_grid.add_child(tok)
	if inv.is_empty():
		var e := P.label(rack_grid, "", P.FONT_SMALL, P.DIM)
		e.text = "empty"
	for c in rules_flow.get_children():
		c.queue_free()
	for r in run.felt.wheel_rules + run.felt.house_rules:
		var tok = Token.new(r, Vector2(20, 20))
		tok.hover_text = "%s%s: %s" % [Content.HOUSE_RULES[r].name, " (wheel)" if r in run.felt.wheel_rules else "", Content.HOUSE_RULES[r].desc]
		tok.hover_target = _status
		rules_flow.add_child(tok)


func _select_item(i: int) -> void:
	selected_item = -1 if selected_item == i else i
	Sfx.play("click")
	if selected_item >= 0:
		_status("Placing %s: click a square." % Content.CHIPS[main.run.inventory[i].kind].name)
	_refresh_tokens()


# --- Drawing ------------------------------------------------------------------------

func _draw_hud(c: Control) -> void:
	var run = main.run
	if run.table.is_empty():
		return
	var t: Dictionary = run.table
	var font := P.title_font()
	Art.plaque(c, Rect2(4, 3, 176, 18))
	Art.text(c, font, Vector2(92, 16), "NIGHT %d  %s" % [run.night + 1, run.table_name().to_upper()], 8, P.CREAM, true)
	# Take meter.
	var mr := Rect2(MID_X, 3, 300, 18)
	Art.plaque(c, mr, true)
	var inner := Rect2(mr.position + Vector2(3, 3), mr.size - Vector2(6, 6))
	c.draw_rect(inner, P.BLACK)
	var k := clampf(shown_take / maxf(1.0, t.target), 0.0, 1.0)
	var fill := Color("#e0a82e").lerp(P.CREAM, meter_pulse * 0.6)
	c.draw_rect(Rect2(inner.position, Vector2(floor(inner.size.x * k), inner.size.y)), fill)
	c.draw_rect(Rect2(inner.position, Vector2(floor(inner.size.x * k), 2)), fill.lightened(0.4))
	for i in range(1, 10):
		var x: float = inner.position.x + floor(inner.size.x * i / 10.0)
		c.draw_rect(Rect2(x, inner.position.y, 1, inner.size.y), Color(0, 0, 0, 0.35))
	Art.text(c, font, Vector2(mr.get_center().x, 16), "TAKE %d / %d" % [int(shown_take), t.target], 8, P.CREAM if k < 0.55 else P.WOOD_DARK, true)
	# Spins as balls.
	var total: int = t.spins_used + t.spins_left
	for i in range(total):
		var p := Vector2(MID_X + 308 + i * 9, 12)
		if i < t.spins_left:
			Art.icon(c, "spin", p, 1)
		else:
			c.draw_circle(p, 3.5, P.DIM.darkened(0.4), false, 1.0, false)
	# Cash.
	Art.icon(c, "cash", Vector2(RIGHT_X + 52, 12), 1)
	Art.text(c, font, Vector2(RIGHT_X + 62, 16), "$%d" % run.cash, 8, P.GOLD)


func _draw_gauges(c: Control) -> void:
	var run = main.run
	if run.table.is_empty():
		return
	var font := P.font()
	Art.text(c, font, Vector2(4, 8), "PAY-OFF CHANCE", 8, P.DIM)
	var col := P.GOOD if chance >= 0.66 else (P.GOLD if chance >= 0.33 else P.DANGER)
	c.draw_rect(Rect2(4, 12, 168, 8), P.BLACK)
	c.draw_rect(Rect2(5, 13, floor(166 * chance), 6), col)
	Art.text(c, font, Vector2(168 - font.get_string_size("%d%%" % int(round(chance * 100)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 8), "%d%%" % int(round(chance * 100)), 8, col)
	Art.text(c, font, Vector2(4, 32), "TAKE/SPIN", 8, P.DIM)
	Art.text(c, font, Vector2(84, 32), "%.1f" % take_per_spin, 8, P.CREAM)
	# The stack as a physical tower of chips.
	var stack: int = run.table.stack
	Art.text(c, font, Vector2(4, 50), "STACK", 8, P.DIM)
	Art.text(c, P.title_font(), Vector2(4, 66), "%d" % stack, 8, P.CREAM)
	# Break the stack into casino denominations (blue 10, red 5, white 1), at most 10 chips per tower.
	var counts := {10: stack / 10, 5: (stack % 10) / 5, 1: stack % 5}
	var ti := 0
	for d in [10, 5, 1]:
		var left: int = counts[d]
		while left > 0 and ti < 6:
			var in_tower := mini(10, left)
			for j in range(in_tower):
				Art.chip(c, Vector2(56 + ti * 19, 112 - j * 3), 7.0, Art.denom_color(d))
			left -= in_tower
			ti += 1
	if stack == 0:
		Art.text(c, font, Vector2(56, 100), "EMPTY", 8, P.DANGER)


func _draw_history(c: Control) -> void:
	var run = main.run
	var font := P.font()
	c.draw_rect(Rect2(0, 0, c.size.x, c.size.y), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(0, 0, c.size.x, c.size.y), P.WOOD, false, 1.0)
	Art.text(c, font, Vector2(4, 12), "LAST", 8, P.DIM)
	var x := 30.0
	for i in range(history.size() - 1, -1, -1):
		var p: int = history[i]
		var col: Color = P.GREEN if p <= 0 else (P.RED if run.felt.board.is_red(p) else P.BLACK)
		var w := 20.0
		var r := Rect2(x, 3, w, 12)
		c.draw_rect(r, col)
		c.draw_rect(r, P.GOLD if i == history.size() - 1 else P.LINE.darkened(0.5), false, 1.0)
		Art.text(c, font, Vector2(r.get_center().x, 12), run.felt.board.label(p), 8, P.CREAM, true)
		x += w + 3
		if x > c.size.x - 22:
			break


func _draw_score(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, c.size.x, c.size.y), Color(0.02, 0.07, 0.04, 0.85))
	c.draw_rect(Rect2(0, 0, c.size.x, c.size.y), P.WOOD, false, 1.0)
	var font := P.font()
	var tfont := P.title_font()
	if not spin_score_vis and score_rows.is_empty():
		Art.text(c, tfont, Vector2(165, 40), "PLACE YOUR BETS", 8, P.GOLD, true)
		var tips := ["Take = what a spin pays minus what it lost.",
			"Permanent chips are never lost: they score every hit.",
			"Covering everything scores nothing. Pick your shots.",
			"Reach the payment before the balls run out."]
		for i in range(tips.size()):
			Art.text(c, font, Vector2(165, 66 + i * 14), tips[i], 8, P.DIM, true)
		return
	var big := "+%d" % int(round(spin_score))
	var size := 16 if score_pop < 0.5 else 24
	Art.text(c, tfont, Vector2(165, 30), big, size, P.GOLD if spin_score > 0 else P.DIM, true)
	var y := 52.0
	for row in score_rows.slice(maxi(0, score_rows.size() - 8)):
		var col: Color = {"win": P.GOOD, "bonus": P.CYAN, "loss": P.DANGER, "mult": P.VIOLET, "cash": P.GOLD, "push": P.DIM}.get(row.kind, P.CREAM)
		var ic: String = {"win": "bet", "bonus": "perm", "loss": "bet", "mult": "red_streak", "cash": "cash", "push": "bet"}.get(row.kind, "bet")
		if row.has("icon") and row.icon != "":
			ic = row.icon
		Art.icon(c, ic, Vector2(16, y - 3), 1)
		Art.text(c, font, Vector2(28, y), row.text, 8, P.CREAM)
		var amt: String = row.amount
		var w := font.get_string_size(amt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		Art.text(c, font, Vector2(c.size.x - 10 - w, y), amt, 8, col)
		y += 14.0


# --- Input ------------------------------------------------------------------------

func _on_bet_clicked(key: String, button: int) -> void:
	var run = main.run
	if spinning or run.phase != RunState.Phase.TABLE or main.dialogue.is_open():
		return
	if button == MOUSE_BUTTON_RIGHT:
		if run.take_back(key):
			Sfx.play("chip_remove")
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if selected_item >= 0:
		if run.place_chip(selected_item, key):
			selected_item = -1
			felt_view.pop(key)
			main.fx.burst(felt_view.global_position + felt_view.key_center(key), 8, [P.GOLD, P.CREAM], 60.0)
			Sfx.play("chip_place")
		else:
			_status("That chip can't go there.")
		return
	var amt: int = mini(bet_size, run.table.stack)
	if run.place_bet(key, amt):
		felt_view.pop(key)
		Sfx.play("chip_place")
	elif run.is_called_spin():
		_status("Big Sal calls this spin. No new bets.")
	elif run.table.stack <= 0:
		_status("Your stack is empty.")
	else:
		_status("Closed tonight.")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialogue.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_spin()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L:
			log_box.visible = not log_box.visible


# --- The spin and the count ------------------------------------------------------------

func _on_spin() -> void:
	var run = main.run
	if spinning or run.phase != RunState.Phase.TABLE or main.dialogue.is_open():
		return
	spinning = true
	spin_btn.disabled = true
	selected_item = -1
	Sfx.play("spin")
	score_rows = []
	spin_score = 0.0
	spin_score_vis = false
	var pockets: Array = run.felt.board.pockets
	var pocket: int = pockets[run.rng.range_i(0, pockets.size() - 1)]
	wheel_view.spin_to(pocket)
	await wheel_view.spin_done
	Sfx.play("ball_drop")
	var before: float = run.table.take
	var target: int = run.table.target
	var res: Dictionary = run.spin(pocket)
	history.append(pocket)
	history_view.queue_redraw()
	await _play_count(res, before, target)
	_log(res)
	if run.phase != RunState.Phase.TABLE:
		if run.phase == RunState.Phase.GAME_OVER:
			main.fx.stamp("BUSTED", P.DANGER, 1.6)
			main.shake(5.0, 0.5)
			Sfx.play("bust")
		else:
			main.fx.stamp("PAID", P.GOLD, 1.6)
			main.fx.coin_rain(90)
			Sfx.play("clear")
		await get_tree().create_timer(1.5).timeout
		spinning = false
		main.route()
	else:
		spinning = false
		refresh()


func _play_count(res: Dictionary, before: float, target: int) -> void:
	var run = main.run
	var B = run.felt.board
	var fx = main.fx
	var pkey := Board.straight_key(res.pocket)
	var pocket_pos: Vector2 = felt_view.global_position + felt_view.key_center(pkey)
	felt_view.flash(pkey, 1.2)
	var straight_hit := false
	for e in res.events:
		if e.kind == "win" and e.label == "straight":
			straight_hit = true
	if B.is_zero(res.pocket):
		fx.banner("ZERO!", P.GOOD, 1.0, 112)
	elif straight_hit:
		fx.banner("STRAIGHT UP!", P.GOLD, 1.1, 112)
		fx.burst(pocket_pos, 26, [P.GOLD, P.CREAM, P.RED])
	if res.zero_tax:
		fx.banner("ORO TAKES 10%", P.DANGER, 1.2, 140, 8)
		before *= 1.0 - Content.ZERO_TAX
	spin_score_vis = true
	var gross := 0.0
	var lost := 0.0
	var delay := 0.24
	var combo := 0
	# Build up first: wins and bonuses, then multipliers, then the losses tick off.
	var order := {"win": 0, "bonus": 1, "cash": 2, "push": 3, "mult": 4, "loss": 5}
	var events: Array = res.events.duplicate()
	events.sort_custom(func(a, b): return order[a.kind] < order[b.kind])
	for e in events:
		var key: String = e.key
		var at: Vector2 = felt_view.global_position + felt_view.key_center(key) if key != "" else Vector2(353, 120)
		var name: String = _bet_name(key)
		match e.kind:
			"win":
				gross += e.amount
				felt_view.flash(key, 0.6)
				felt_view.pop(key)
				felt_view.float_text(key, "+%d" % int(e.amount), P.GOLD)
				fx.burst(at, 6 + mini(20, int(e.amount / 4.0)), [P.GOLD, P.CREAM])
				score_rows.append({"kind": "win", "text": "%s  %s" % [name, e.label.to_upper()], "amount": "+%d" % int(e.amount), "icon": _chip_icon(key)})
				Sfx.play("win", 1.0 + 0.09 * combo)
				combo += 1
			"bonus":
				gross += e.amount
				felt_view.float_text(key, "+%d" % int(e.amount), P.CYAN)
				fx.burst(at, 8, [P.CYAN, P.CREAM])
				score_rows.append({"kind": "bonus", "text": "%s  %s" % [name, e.label.to_upper()], "amount": "+%d" % int(e.amount), "icon": _chip_icon(key)})
				Sfx.play("win", 1.0 + 0.09 * combo)
				combo += 1
			"loss":
				lost += -e.amount
				felt_view.float_text(key, "%d" % int(e.amount), P.DANGER)
				score_rows.append({"kind": "loss", "text": "%s  LOST%s" % [name, (" (" + e.label + ")") if e.label != "" else ""], "amount": "%d" % int(e.amount), "icon": ""})
				Sfx.play("lose")
			"mult":
				gross *= e.amount
				fx.banner("x%s %s" % [_fmt(e.amount), e.label.to_upper()], P.VIOLET, 0.9, 140, 8)
				score_rows.append({"kind": "mult", "text": e.label.to_upper(), "amount": "x" + _fmt(e.amount), "icon": "red_streak" if e.label == "Red Streak" else ("hot_hand" if e.label == "Hot Hand" else "dealer_signature")})
				main.shake(2.0, 0.15)
				Sfx.play("mult")
			"cash":
				felt_view.float_text(key, "+$%d" % int(e.amount), P.GOOD)
				score_rows.append({"kind": "cash", "text": "%s  MINT" % name, "amount": "+$%d" % int(e.amount), "icon": "mint"})
				Sfx.play("cash")
			"push":
				felt_view.float_text(key, e.label.to_upper(), P.DIM)
				score_rows.append({"kind": "push", "text": "%s  %s" % [name, e.label.to_upper()], "amount": "0", "icon": ""})
		spin_score = maxf(0.0, gross - lost)
		score_pop = 1.0
		score_view.queue_redraw()
		await get_tree().create_timer(delay).timeout
		delay = maxf(0.08, delay * 0.82)
	if res.respins > 0:
		fx.banner("+%d SPIN" % res.respins, P.CYAN, 0.9, 140, 8)
	spin_score = res.take
	score_pop = 1.0
	if res.events.is_empty():
		score_rows.append({"kind": "push", "text": "%s %s - nothing on it" % [B.label(res.pocket), B.colour_name(res.pocket).to_upper()], "amount": "0", "icon": ""})
	score_view.queue_redraw()
	# Slam the spin's Take into the meter.
	var after: float = before + res.take
	if res.take > 0.0:
		var big: bool = res.take >= target * 0.4
		meter_pulse = 1.0
		if big:
			main.shake(4.0, 0.35)
			fx.burst(Vector2(MID_X + 150, 12), 40, [P.GOLD, P.CREAM, P.GOOD], 140.0)
			Sfx.play("big_win")
		var tw := create_tween()
		tw.tween_method(func(v: float): shown_take = v, before, after, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
	else:
		shown_take = after
	await get_tree().create_timer(0.25).timeout


func _bet_name(key: String) -> String:
	if key == "":
		return ""
	if Board.is_straight(key):
		return main.run.felt.board.label(Board.straight_number(key))
	return felt_view._outside_name(key).to_upper()


func _chip_icon(key: String) -> String:
	for c in main.run.felt.chips_on(key):
		if not c.is_bet():
			return c.kind
	return "bet"


func _fmt(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.1f" % x


func _log(res: Dictionary) -> void:
	var B = main.run.felt.board
	log_box.append_text("[color=#f2c14e]Ball: %s %s   Take +%d (paid %d, lost %d)[/color]\n" % [
		B.label(res.pocket), B.colour_name(res.pocket), int(res.take), int(res.gross), res.lost])
	for l in Resolver.log_lines(res):
		log_box.append_text("  " + l + "\n")
