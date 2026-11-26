extends Control
## The table. Bet from your stack, place rack chips, spin, then watch the count:
## every paying chip pops in order, multipliers stamp, losses tick off, and the spin's Take
## slams into the meter.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const Portraits := preload("res://scenes/ui/portraits.gd")
const Resolver := preload("res://core/resolver.gd")
const Odds := preload("res://core/odds.gd")
const RunState := preload("res://core/run_state.gd")
const FeltView := preload("res://scenes/ui/felt_view.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")
const Token := preload("res://scenes/ui/token_button.gd")
const TableCount := preload("res://scenes/screens/table_count.gd")
const TableOverlays := preload("res://scenes/screens/table_overlays.gd")
const Preview := preload("res://core/preview.gd")
const Story := preload("res://core/story.gd")
const Profile := preload("res://core/profile.gd")
const InfoCard := preload("res://scenes/ui/info_card.gd")
const Placing := preload("res://scenes/ui/placing.gd")

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
var balls_view: Control   ## "BALLS 4/6" under the wheel
var stack_view: Control   ## your betting-chip stack, lying under the felt
var spin_btn: Button
var clear_btn: Button
var undo_btn: Button
var bet_history: Array = []   ## [{key, amount}] of bets placed since the last spin, for Undo
var status_lbl: Label
var denom_box: HBoxContainer
var rack_grid: GridContainer
var rules_flow: VBoxContainer
var boss_panel: Panel
var boss_lbl: Label
var job_panel: Panel
var job_lbl: Label
var boss_face: Control
var boss_who := ""
var boss_name: Label
var log_box: RichTextLabel

var bet_size := 1
var selected_item := -1
var spinning := false
var shown_take := 0.0
var meter_pulse := 0.0
var meter_paid_flash := 0.0     ## the gold flash when the meter crosses the payment line
var board_id := ""
var announced := ""
var table_key := ""
var history: Array = []
var score_rows: Array = []      ## {kind, text, amount}
var spin_score := 0.0
var spin_score_vis := false
var score_pop := 0.0
var hits := 0                    ## scoring events this spin (the combo counter)
var shown_cash := -1.0           ## HUD cash, counted up toward run.cash
var zoom_bg: ColorRect            ## dims the table while the felt is zoomed for touch betting
var zoomed := false
var overlays   ## the free-chip panel, touch bet menu, quick edits and tips (table_overlays.gd)
var speed_btn: Button   ## fast-forward: > / >> / >>>
var pinned: Dictionary = {}      ## bet keys that survive Clear (Alt-click to pin)
const ZOOM := 1.8
var count                        ## the spin count-up (table_count.gd)
var receipt := ""                ## one-line "where the Take came from" under the score
var chance := 0.0
var take_per_spin := 0.0


## Fastest speed (the >> button): a short wheel spin and a brisk count.
func fast() -> bool:
	return main.short_spins()


func setup() -> void:
	count = TableCount.new(self)
	overlays = TableOverlays.new(self)
	hud = _canvas(Vector2(0, 0), Vector2(640, 24), _draw_hud)

	wheel_view = WheelView.new()
	P.place(wheel_view, Vector2(4, 24), Vector2(176, 166))
	balls_view = _canvas(Vector2(4, 190), Vector2(176, 13), _draw_balls)
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
	# Undo / Clear sit just under the felt, at its right-hand end.
	undo_btn = P.button(self, "UNDO", _on_undo, Vector2(44, 14), P.FONT_SMALL)
	P.place(undo_btn, Vector2(MID_X + 236, 134))
	clear_btn = P.button(self, "CLEAR", _on_clear, Vector2(44, 14), P.FONT_SMALL)
	P.place(clear_btn, Vector2(MID_X + 284, 134))
	gauge_view = _canvas(Vector2(4, 232), Vector2(176, 124), _draw_gauges)
	stack_view = _canvas(Vector2(MID_X, 134), Vector2(232, 14), _draw_stack)

	felt_view = FeltView.new()
	P.place(felt_view, Vector2(MID_X, 32))
	felt_view.bet_clicked.connect(_on_bet_clicked)
	felt_view.bet_held.connect(func(k): overlays.on_bet_held(k))
	felt_view.rack_dropped.connect(func(i: int, k: String):
		if spinning or k == "" or main.run.phase != RunState.Phase.TABLE:
			return
		selected_item = i
		_place_selected(k))
	felt_view.bet_hovered.connect(_on_hover)
	add_child(felt_view)
	status_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	status_lbl.clip_text = true
	P.place(status_lbl, Vector2(MID_X, 150), Vector2(330, 10))
	history_view = _canvas(Vector2(MID_X, 162), Vector2(330, 18), _draw_history)
	score_view = _canvas(Vector2(MID_X, 184), Vector2(330, 170), _draw_score)
	# Clicking the score panel opens the full calculation (the spin log).
	score_view.mouse_filter = Control.MOUSE_FILTER_STOP
	score_view.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and receipt != "":
			log_box.visible = true)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.visible = false
	log_box.add_theme_stylebox_override("normal", P.box(Color(0.03, 0.06, 0.04, 0.96), P.LINE.darkened(0.4)))
	P.place(log_box, Vector2(MID_X, 184), Vector2(330, 170))
	add_child(log_box)

	P.place(P.label(self, "BET CHIP", P.FONT_SMALL, P.DIM), Vector2(RIGHT_X, 26))
	var mb := P.button(self, "MENU", func(): main.open_pause(), Vector2(40, 12), P.FONT_SMALL)
	P.place(mb, Vector2(RIGHT_X + 72, 6))
	# Fast-forward: Normal > Fast >> Fastest >>> (F on the keyboard).
	speed_btn = P.button(self, ">", func():
		main.cycle_speed()
		speed_btn.text = Profile.SPEEDS[main.speed()].label, Vector2(26, 12), P.FONT_SMALL)
	speed_btn.tooltip_text = ""
	speed_btn.mouse_entered.connect(func(): _status("Game speed: %s. Click (or press F) to change." % Profile.SPEEDS[main.speed()].name))
	P.place(speed_btn, Vector2(RIGHT_X + 44, 6))
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
	rules_flow = VBoxContainer.new()
	rules_flow.add_theme_constant_override("separation", 2)
	P.place(rules_flow, Vector2(RIGHT_X, 156), Vector2(RIGHT_W, 0))
	add_child(rules_flow)
	boss_panel = Panel.new()
	boss_panel.add_theme_stylebox_override("panel", P.box(Color("#2a0f12"), P.DANGER, 1))
	P.place(boss_panel, Vector2(RIGHT_X, 250), Vector2(RIGHT_W, 104))
	add_child(boss_panel)
	boss_face = Control.new()
	P.place(boss_face, Vector2(4, 4), Vector2(32, 32))
	boss_name = P.label(boss_panel, "", P.FONT_SMALL, P.DANGER)
	boss_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(boss_name, Vector2(40, 6), Vector2(RIGHT_W - 44, 30))
	boss_face.draw.connect(func():
		if boss_who != "":
			Portraits.draw(boss_face, boss_who, Rect2(0, 0, 32, 32)))
	boss_panel.add_child(boss_face)
	boss_lbl = P.label(boss_panel, "", P.FONT_SMALL, P.CREAM)
	boss_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(boss_lbl, Vector2(5, 38), Vector2(RIGHT_W - 10, 62))
	# Ordinary tables: the condition and side job, in the same spot.
	job_panel = Panel.new()
	job_panel.add_theme_stylebox_override("panel", P.box(Color("#10201a"), P.LINE, 1))
	P.place(job_panel, Vector2(RIGHT_X, 250), Vector2(RIGHT_W, 104))
	add_child(job_panel)
	job_lbl = P.label(job_panel, "", P.FONT_SMALL, P.CREAM)
	job_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_lbl.add_theme_constant_override("line_spacing", -2)
	P.place(job_lbl, Vector2(5, 4), Vector2(RIGHT_W - 10, 96))
	# Tap-to-zoom felt (touch screens, or the Options toggle): a dim layer under a big felt.
	zoom_bg = ColorRect.new()
	zoom_bg.color = Color(0.02, 0.01, 0.02, 0.82)
	zoom_bg.position = Vector2(-4000, -4000)
	zoom_bg.size = Vector2(8640, 8360)
	zoom_bg.visible = false
	zoom_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	zoom_bg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_unzoom())
	var zl := P.label(zoom_bg, "TAP TO BET   -   HOLD TO TAKE BACK   -   TAP OUTSIDE TO CLOSE", P.FONT_SMALL, P.CREAM)
	zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	P.place(zl, Vector2(4000, 4000 + 30), Vector2(640, 10))
	add_child(zoom_bg)
	move_child(felt_view, -1)


func _canvas(pos: Vector2, sz: Vector2, fn: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(c, pos, sz)
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c


func _hint() -> String:
	if selected_item >= 0 and selected_item < main.run.inventory.size():
		var kind: String = main.run.inventory[selected_item].kind
		return "Holding %s. %s" % [Content.CHIPS[kind].name, Content.place_hint(kind)]
	if DisplayServer.is_touchscreen_available():
		return "Tap: bet %d   Hold: edit (take back, -chip, pin, clear area)" % bet_size
	return "Click: bet %d  Right: take back  Shift: -%d  Ctrl: clear area  Alt: pin" % [bet_size, bet_size]


func _has_bets() -> bool:
	for c in main.run.felt.chips:
		if c.is_bet():
			return true
	return false


func _on_undo() -> void:
	var run = main.run
	if spinning or main.dialogue.is_open() or bet_history.is_empty():
		return
	var last: Dictionary = bet_history.pop_back()
	if run.unbet(last.key, last.amount) > 0:
		_chips_home(last.key)
		Sfx.play("undo")
	refresh()


func _on_clear() -> void:
	var run = main.run
	if spinning or main.dialogue.is_open():
		return
	bet_history.clear()
	var keys: Array = run.felt.chips.filter(func(c): return c.is_bet() and not pinned.has(c.bet)).map(func(c): return c.bet)
	if run.clear_bets(pinned.keys()):
		for k in keys:
			_chips_home(k)
		Sfx.play("clear_all")
		refresh()


## Hover previews on the felt:
##  - placing a rack chip: cyan on every pocket it would pay on from this square
##  - a number: gold on every bet and chip that would score if it hit, and the Take it would make
##  - a square with your permanent chips: cyan on the pockets those chips pay on
func _on_hover(k: String) -> void:
	felt_view.preview = {}
	# Chips you own on this spot: show what they do.
	var perms: Array = Placing.perms_on(main.run, k) if k != "" and main.run.felt.board.has_bet(k) else []
	if perms.is_empty() or spinning or selected_item >= 0:
		main.hide_card()
	else:
		var d := InfoCard.for_chip(perms[0], main.run)
		if perms.size() > 1:
			d.body += "\nAlso here: " + ", ".join(perms.slice(1).map(func(c): return "%s x%d" % [Content.CHIPS[c.kind].name, c.value]))
		main.card_at_felt(felt_view, k, d)
	if k == "" or spinning:
		_status(felt_view.describe(k) if k != "" else _hint())
		felt_view.queue_redraw()
		return
	var run = main.run
	var B = run.felt.board
	var txt: String = felt_view.describe(k)
	if selected_item >= 0 and selected_item < run.inventory.size():
		var item: Dictionary = run.inventory[selected_item]
		if run.can_place_chip(item.kind, k):
			var ps := Preview.pays_on(run.felt, item.kind, k, item.value, item.get("flaw", ""))
			for p in ps:
				felt_view.preview[Board.straight_key(p)] = P.CYAN
			txt = "%s here pays on %d of %d pockets" % [Content.CHIPS[item.kind].name, ps.size(), B.pockets.size()]
		else:
			txt = "%s can't go here" % Content.CHIPS[item.kind].name
	else:
		for c in run.felt.chips_on(k):
			if not c.is_bet():
				for p in Preview.chip_pays_on(run.felt, c.id):
					felt_view.preview[Board.straight_key(p)] = P.CYAN
		if Board.is_straight(k):
			var f := Preview.fires_at(run.felt, Board.straight_number(k))
			for fk in f.keys:
				felt_view.preview[fk] = P.GOLD
			if f.take > 0.0 or f.cash > 0:
				txt += "   |   if %s hits: +%d Take%s" % [B.label(Board.straight_number(k)), int(f.take), ("  +$%d" % f.cash) if f.cash > 0 else ""]
	_status(txt)
	felt_view.queue_redraw()


## Gold rings on the bets that could pay the rest of the table in one hit.
func _mark_clearing() -> void:
	var run = main.run
	felt_view.ring_keys = {}
	for k in pinned.keys():
		if not run.felt.chips_on(k).any(func(c): return c.is_bet()):
			pinned.erase(k)
	felt_view.pinned = pinned
	if spinning or run.phase != RunState.Phase.TABLE or run.table.is_empty():
		return
	var need: float = run.table.target - run.table.take
	var ps := Preview.clearing_pockets(run.felt, need)
	if ps.is_empty():
		return
	var B = run.felt.board
	for c in run.felt.chips:
		if B.bet(c.bet).numbers.any(func(n): return n in ps):
			felt_view.ring_keys[c.bet] = true


## Where the betting stack sits (the chip towers in the left column), for chips flying to/from it.
const STACK_AT := Vector2(MID_X + 60, 141)   ## where betting chips fly from / back to (the stack under the felt)


## Chips going back from a square to the stack.
func _chips_home(key: String) -> void:
	main.fx.fly(main.fx.local(felt_view.key_global(key)), STACK_AT, P.CREAM, 2)


## The novel wheels' state on the wheel drawing: crooked widths, the Carousel's arc.
func _sync_wheel(run) -> void:
	wheel_view.weights = run.felt.weights
	wheel_view.arc = run.felt.arc_pockets()
	wheel_view.next_arc = run.felt.arc_pockets(1)
	wheel_view.twin = run.felt.board.def.get("twin", false)
	wheel_view.queue_redraw()


func _status(s: String) -> void:
	status_lbl.text = s if s != "" else _hint()


func _process(delta: float) -> void:
	if not visible:
		return
	meter_pulse = maxf(0.0, meter_pulse - delta * 2.5)
	meter_paid_flash = maxf(0.0, meter_paid_flash - delta * 1.2)
	score_pop = maxf(0.0, score_pop - delta * 5.0)
	var cash: int = main.run.cash
	if shown_cash < 0.0:
		shown_cash = cash
	elif not is_equal_approx(shown_cash, cash):
		var next := move_toward(shown_cash, cash, maxf(4.0, absf(cash - shown_cash) * 3.0) * delta)
		if cash > shown_cash and int(next) != int(shown_cash):
			Sfx.play("cash", 1.4)  # a coin tick for every dollar counted up
		shown_cash = next
	# Music tension: rises on the last two balls and when the payment is within reach.
	var tb: Dictionary = main.run.table
	if main.run.phase == RunState.Phase.TABLE and not tb.is_empty():
		var need: float = tb.target - tb.take
		var lvl := 0.0
		if tb.spins_left <= 1:
			lvl = 1.0
		elif tb.spins_left == 2:
			lvl = 0.6
		if need > 0.0 and need <= tb.target * 0.3:
			lvl = maxf(lvl, 0.5)
		Sfx.set_tension(lvl)
	else:
		Sfx.set_tension(0.0)
	# The SPIN button breathes while it's ready and bets are down.
	if not spin_btn.disabled and _has_bets():
		var g := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		spin_btn.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.18, 0.9), g)
	else:
		spin_btn.modulate = Color.WHITE
	hud.queue_redraw()
	stack_view.queue_redraw()
	balls_view.queue_redraw()
	if spinning:
		score_view.queue_redraw()


# --- Refresh ----------------------------------------------------------------------

func refresh() -> void:
	var run = main.run
	if run.phase != RunState.Phase.TABLE and not spinning:
		return
	felt_view.marks = main.profile.settings.cb_marks
	var bid: String = run.wheel_id + str(run.has_feature("call_bets"))
	if board_id != bid or felt_view.run != run:
		felt_view.run = run
		felt_view.layout()
		wheel_view.board = run.felt.board
		board_id = bid
	var tk := "%d-%s-%d-%d" % [run.run_seed, run.wheel_id, run.night, run.table_idx]
	if tk != table_key:
		table_key = tk
		history = []
		score_rows = []
		spin_score_vis = false
		wheel_view.result = -99
		wheel_view.result2 = -99
		log_box.clear()
		log_box.append_text("[color=#f2c14e]%s[/color]\n" % run.message)
	felt_view.targets = []
	_sync_wheel(run)
	felt_view.queue_redraw()
	var t: Dictionary = run.table
	if not spinning:
		shown_take = t.take
		var ev: Dictionary = run.expected_value()
		take_per_spin = ev.take
		chance = Odds.hit_chance(run.felt, t.target - t.take, t.spins_left)
	spin_btn.disabled = spinning or run.phase != RunState.Phase.TABLE
	clear_btn.disabled = spinning or run.phase != RunState.Phase.TABLE or run.is_called_spin() or not _has_bets()
	undo_btn.disabled = spinning or run.phase != RunState.Phase.TABLE or bet_history.is_empty()
	spin_btn.text = "PICK A CHIP" if not run.table_offer.is_empty() else ("CALLED SPIN" if run.is_called_spin() else ("PLACE CHIPS" if run.has_unplaced_chips() else "SPIN"))
	_refresh_tokens()
	_mark_clearing()
	speed_btn.text = Profile.SPEEDS[main.speed()].label
	overlays.refresh_offer(run)
	overlays.first_time_tips(run)
	if t.boss:
		var e: Dictionary = Content.ENFORCERS[t.enforcer]
		boss_panel.visible = true
		job_panel.visible = false
		boss_lbl.text = e.desc
		if t.get("objective", "") != "":
			var o: Dictionary = Content.OBJECTIVES[t.objective]
			boss_lbl.text += "\nJOB: %s +$%d%s" % [o.name, o.cash, " (done)" if run.objective_met() else ""]
		boss_who = e.name
		boss_face.queue_redraw()
		boss_name.text = "ENFORCER\n" + e.name.to_upper()
		var key := "%d-%d" % [run.night, run.table_idx]
		if announced != key and t.spins_used == 0:
			announced = key
			main.say([{"speaker": e.name, "text": e.intro}])
	else:
		boss_panel.visible = false
		var lines := []
		if t.get("route", "") != "":
			lines.append(Content.ROUTES[t.route].name.to_upper())
		if t.get("condition", "") != "":
			var c: Dictionary = Content.CONDITIONS[t.condition]
			lines.append("%s\n%s" % [c.name.to_upper(), c.desc])
		if t.get("objective", "") != "":
			var o: Dictionary = Content.OBJECTIVES[t.objective]
			var st := ""
			if run.objective_met():
				st = " DONE"
			elif t.objective in ["outside_only", "few"] and not t.obj_ok:
				st = " BLOWN"
			elif t.objective == "three_hits":
				st = " %d/3" % mini(3, t.get("obj_hits", 0))
			lines.append("SIDE JOB +$%d%s\n%s: %s" % [o.cash, st, o.name, o.desc])
		job_panel.visible = not lines.is_empty()
		job_lbl.text = "\n".join(lines)
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
		tok.rarity = Content.rarity_of(item.kind)
		tok.badge = "x%d" % item.value if item.value > 1 else ""
		if item.get("flaw", "") != "":
			tok.badge = Content.FLAWS[item.flaw].short
		tok.selected = i == selected_item
		tok.hover_text = "%s: %s" % [Content.CHIPS[item.kind].name, Content.CHIPS[item.kind].desc]
		tok.drag_data = {"rack": i}
		tok.drag_started = func():
			selected_item = i
			Placing.mark(felt_view, run, i)
		tok.hover_target = func(txt: String):
			_status("%s: click it, then a spot on the felt (or drag it there)." % Content.CHIPS[item.kind].name)
			main.card_near(tok, InfoCard.for_item(item))
			if Preview.absolute_trigger(item.kind):
				felt_view.preview = {}
				for p in Preview.pays_on(run.felt, item.kind, Preview.rep_key(run.felt, item.kind), item.value):
					felt_view.preview[Board.straight_key(p)] = P.CYAN
				felt_view.queue_redraw()
		tok.hover_exit = func():
			main.hide_card()
			felt_view.preview = {}
			felt_view.queue_redraw()
		tok.pressed.connect(_select_item.bind(i))
		rack_grid.add_child(tok)
	Placing.mark(felt_view, run, selected_item)
	if inv.is_empty():
		var e := P.label(rack_grid, "", P.FONT_SMALL, P.DIM)
		e.text = "empty"
	for c in rules_flow.get_children():
		c.queue_free()
	for r in run.felt.wheel_rules + run.felt.house_rules:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var tok = Token.new(r, Vector2(16, 16))
		var info: Dictionary = Content.HOUSE_RULES[r]
		tok.hover_text = "%s%s: %s" % [info.name, " (wheel)" if r in run.felt.wheel_rules else "", info.desc]
		var built_in: bool = r in run.felt.wheel_rules
		tok.hover_target = func(_s): main.card_near(tok, InfoCard.for_rule(r, built_in))
		tok.hover_exit = main.hide_card
		row.add_child(tok)
		var lbl := P.label(row, info.name, P.FONT_SMALL, P.CREAM)
		lbl.custom_minimum_size = Vector2(RIGHT_W - 20, 16)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		var rule_id: String = r
		var wheel_rule: bool = r in run.felt.wheel_rules
		lbl.mouse_entered.connect(func(): main.card_near(lbl, InfoCard.for_rule(rule_id, wheel_rule)))
		lbl.mouse_exited.connect(main.hide_card)
		rules_flow.add_child(row)
	# Dealer vouchers last the whole run: list them under the rules.
	for v in run.vouchers:
		var vrow := HBoxContainer.new()
		vrow.add_theme_constant_override("separation", 4)
		var vt = Token.new(Content.VOUCHERS[v].icon, Vector2(16, 16))
		vt.hover_text = "%s (voucher): %s" % [Content.VOUCHERS[v].name, Content.VOUCHERS[v].desc]
		var vid: String = v
		vt.hover_target = func(_s): main.card_near(vt, InfoCard.for_voucher(vid))
		vt.hover_exit = main.hide_card
		vrow.add_child(vt)
		var vl := P.label(vrow, Content.VOUCHERS[v].name, P.FONT_SMALL, P.VIOLET)
		vl.custom_minimum_size = Vector2(RIGHT_W - 20, 16)
		vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rules_flow.add_child(vrow)


func _select_item(i: int) -> void:
	selected_item = -1 if selected_item == i else i
	Sfx.play("click")
	if selected_item >= 0:
		_status("Placing %s: click a lit spot (green levels up your twin). Right-click to cancel." % Content.CHIPS[main.run.inventory[i].kind].name)
	_refresh_tokens()


## Pick a chip placed this turn back up off `key` (free until the next spin) and hold it.
func unplace_at(key: String) -> bool:
	var run = main.run
	for c in Placing.perms_on(run, key):
		if run.is_fresh(c.id):
			var nm: String = Content.CHIPS[c.kind].name
			if run.unplace(c.id):
				selected_item = run.inventory.size() - 1
				main.hide_card()
				Sfx.play("chip_remove")
				_status("Picked up %s: click a lit spot to put it somewhere else." % nm)
				refresh()
				return true
	return false


## Place the selected rack chip on `key`; the next chip in the rack is picked up straight after.
func _place_selected(key: String) -> void:
	var run = main.run
	if selected_item < 0 or selected_item >= run.inventory.size():
		return
	var kind: String = run.inventory[selected_item].kind
	var twin: bool = run.felt.chips_on(key).any(func(c): return not c.is_bet() and c.kind == kind)
	if run.place_chip(selected_item, key):
		selected_item = 0 if not run.inventory.is_empty() else -1
		felt_view.pop(key)
		main.fx.burst(main.fx.local(felt_view.key_global(key)), 8 if not twin else 20, [P.GOLD, P.CREAM] if not twin else [P.GOOD, P.GOLD, P.CREAM], 60.0)
		if twin:
			main.fx.pop_text(main.fx.local(felt_view.key_global(key)) - Vector2(0, 10), "LEVEL UP!", P.GOOD)
		Sfx.play("stack" if twin else "chip_place")
		_status("Placed. Next: %s." % Content.CHIPS[run.inventory[0].kind].name if selected_item >= 0 else "Placed.")
		_refresh_tokens()
	else:
		_status("%s can't go there: try a lit spot." % Content.CHIPS[kind].name)
		Sfx.play("click")


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
	var mr := Rect2(MID_X, 3, 330, 18)
	Art.plaque(c, mr, true)
	var inner := Rect2(mr.position + Vector2(3, 3), mr.size - Vector2(6, 6))
	c.draw_rect(inner, P.BLACK)
	var k := clampf(shown_take / maxf(1.0, t.target), 0.0, 1.0)
	var fill := Color("#e0a82e").lerp(P.CREAM, meter_pulse * 0.6)
	c.draw_rect(Rect2(inner.position, Vector2(floor(inner.size.x * k), inner.size.y)), fill)
	c.draw_rect(Rect2(inner.position, Vector2(floor(inner.size.x * k), 2)), fill.lightened(0.4))
	if meter_pulse > 0.05 and k > 0.0 and k < 1.0:   # the bright leading edge, sparkling as it fills
		var ex: float = inner.position.x + floor(inner.size.x * k)
		c.draw_rect(Rect2(ex - 2, inner.position.y, 2, inner.size.y), Color(1, 1, 1, meter_pulse))
		var ms := Time.get_ticks_msec() / 60
		for i in range(4):
			var sx: float = ex - 1 + ((ms * 7 + i * 13) % 7) - 3
			var sy: float = inner.position.y - 3 + ((ms * 5 + i * 11) % (int(inner.size.y) + 6))
			c.draw_rect(Rect2(sx, sy, 1, 1), Color(P.CREAM, meter_pulse))
	if meter_paid_flash > 0.0:
		c.draw_rect(inner, Color(P.CREAM, meter_paid_flash * 0.7))
	for i in range(1, 10):
		var x: float = inner.position.x + floor(inner.size.x * i / 10.0)
		c.draw_rect(Rect2(x, inner.position.y, 1, inner.size.y), Color(0, 0, 0, 0.35))
	if shown_take >= t.target:
		var g := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		c.draw_rect(mr.grow(1), Color(P.GOLD, 0.5 + 0.5 * g), false, 2.0)
		c.draw_rect(mr.grow(3), Color(P.GOLD, 0.25 * g), false, 1.0)
	var mtxt: String = ("PAID!  %d / %d" % [int(shown_take), t.target]) if shown_take >= t.target else ("TAKE %d / %d   NEED %d" % [int(shown_take), t.target, int(ceil(t.target - shown_take))])
	Art.text(c, font, Vector2(mr.get_center().x, 16), mtxt, 8, P.CREAM if k < 0.55 else P.WOOD_DARK, true)
	# Cash.
	Art.text(c, font, Vector2(RIGHT_X + 2, 16), "$%d" % int(round(shown_cash if shown_cash >= 0.0 else run.cash)), 8, P.CREAM if shown_cash >= 0.0 and int(shown_cash) != run.cash else P.GOLD)


## The balls left at this table, as a row under the wheel.
func _draw_balls(c: Control) -> void:
	var run = main.run
	if run.table.is_empty():
		return
	var td: Dictionary = run.table
	var total: int = td.spins_used + td.spins_left
	var font := P.font()
	var label := "BALLS %d/%d" % [td.spins_left, total]
	Art.text(c, font, Vector2(4, 10), label, 8, P.DANGER if td.spins_left <= 1 else P.CREAM)
	var x0: float = 8.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var step: float = minf(10.0, (c.size.x - x0 - 4.0) / maxf(1.0, total))
	for i in range(total):
		var p := Vector2(x0 + 4 + i * step, 6).floor()
		if i < td.spins_left:
			Art.icon(c, "spin", p, 1)
		else:
			c.draw_circle(p, 3.5, P.DIM.darkened(0.4), false, 1.0, false)


## The betting-chip stack, lying on its side under the felt: one sliver per chip, in casino
## denominations (blue 10, red 5, white 1), with the count.
func _draw_stack(c: Control) -> void:
	var run = main.run
	if run.table.is_empty():
		return
	var stack: int = run.table.stack
	var font := P.font()
	Art.text(c, font, Vector2(0, 10), "STACK", 8, P.DIM)
	Art.text(c, P.title_font(), Vector2(30, 11), "%d" % stack, 8, P.CREAM if stack > 0 else P.DANGER)
	var x := 54.0
	var counts := {10: stack / 10, 5: (stack % 10) / 5, 1: stack % 5}
	for d in [10, 5, 1]:
		for j in range(counts[d]):
			if x > c.size.x - 3:
				break
			var col: Color = Art.denom_color(d)
			c.draw_rect(Rect2(x, 1, 3, 12), col.darkened(0.5))
			c.draw_rect(Rect2(x, 2, 3, 10), col)
			c.draw_rect(Rect2(x, 6, 3, 2), Color(1, 1, 1, 0.3))
			x += 4.0
		x += 4.0
	if stack == 0:
		Art.text(c, font, Vector2(54, 10), "EMPTY", 8, P.DANGER)


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
	# Tonight's marker: what's still owed to Mr. Vance across the whole run.
	var mt: int = run.marker_total()
	var mp: int = run.marker_paid()
	Art.text(c, font, Vector2(4, 46), "MARKER", 8, P.DIM)
	var owed := "$%s LEFT" % P.money(maxi(0, mt - mp)) if mp < mt else "PAID"
	Art.text(c, font, Vector2(168 - font.get_string_size(owed, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 46), owed, 8, P.DANGER.lerp(P.GOLD, clampf(float(mp) / mt, 0.0, 1.0)))
	c.draw_rect(Rect2(4, 49, 168, 4), P.BLACK)
	c.draw_rect(Rect2(5, 50, floor(166.0 * clampf(float(mp) / mt, 0.0, 1.0)), 2), P.GOLD)


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
	if hits >= 2:
		var hue := fmod(Time.get_ticks_msec() / 900.0, 1.0)
		var cc := Color.from_hsv(hue, 0.45, 1.0) if hits >= 4 else P.CYAN
		Art.text(c, font, Vector2(c.size.x - 12 - font.get_string_size("x%d HITS" % hits, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 14), "x%d HITS" % hits, 8, cc)
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
	if receipt != "" and not spinning:
		c.draw_rect(Rect2(4, c.size.y - 26, c.size.x - 8, 1), P.LINE.darkened(0.5))
		var rw := font.get_string_size(receipt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		Art.text(c, font, Vector2(165, c.size.y - 15), receipt if rw < c.size.x - 12 else receipt.substr(0, 60) + "...", 8, P.CREAM, true)
		Art.text(c, font, Vector2(165, c.size.y - 5), "click for the full calculation", 8, P.DIM, true)


# --- Input ------------------------------------------------------------------------

## Zoom the felt so small targets (splits, corners) are big enough for a finger.
func _zoom_enabled() -> bool:
	return main.profile.settings.get("zoom_felt", false) or DisplayServer.is_touchscreen_available()


func _zoom() -> void:
	zoomed = true
	zoom_bg.visible = true
	felt_view.scale = Vector2(ZOOM, ZOOM)
	felt_view.position = ((Vector2(640, 360) - felt_view.size * ZOOM) / 2.0 + Vector2(0, 12)).floor()
	Sfx.play("click")


func _unzoom() -> void:
	if not zoomed:
		return
	zoomed = false
	zoom_bg.visible = false
	felt_view.scale = Vector2.ONE
	felt_view.position = Vector2(MID_X, 32)


func _on_bet_clicked(key: String, button: int) -> void:
	var run = main.run
	if spinning or run.phase != RunState.Phase.TABLE or main.dialogue.is_open():
		return
	if button == MOUSE_BUTTON_LEFT and not zoomed and _zoom_enabled():
		_zoom()
		return
	# Quick layout edits: Shift-click takes back one chip size, Ctrl-click an outside box (or a
	# street/line) clears every bet inside that region, Alt-click pins a bet so Clear keeps it.
	# On touch screens a long press opens the same edits as a menu (_on_bet_held).
	if button == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT) and selected_item < 0:
		overlays.edit_minus(key)
		return
	if button == MOUSE_BUTTON_LEFT and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)) and selected_item < 0:
		overlays.edit_clear_area(key)
		return
	if button == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_ALT) and selected_item < 0:
		overlays.edit_pin(key)
		return
	if button == MOUSE_BUTTON_RIGHT:
		if selected_item >= 0:   # right-click while holding a rack chip just puts it down
			selected_item = -1
			_status("")
			_refresh_tokens()
			return
		if not run.felt.chips_on(key).any(func(c): return c.is_bet()) and unplace_at(key):
			return
		overlays.edit_take_back(key)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if selected_item >= 0:
		_place_selected(key)
		return
	var amt: int = mini(bet_size, run.table.stack)
	if run.place_bet(key, amt):
		bet_history.append({"key": key, "amount": amt})
		felt_view.pop(key)
		main.fx.fly(STACK_AT, main.fx.local(felt_view.key_global(key)), Art.denom_color(amt), 1)
		Sfx.play("chip_place")
	elif run.is_called_spin():
		_status("Big Sal calls this spin. No new bets.")
	elif run.table.stack <= 0:
		_status("Your stack is empty.")
	else:
		var why: String = run.bet_block_reason(key)
		_status(why if why != "" else "Closed tonight.")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialogue.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_spin()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			_on_clear()
		elif event.keycode == KEY_Z or event.keycode == KEY_BACKSPACE:
			_on_undo()
		elif event.keycode in [KEY_1, KEY_2, KEY_3]:
			bet_size = DENOMS[event.keycode - KEY_1]
			Sfx.play("click")
			_refresh_tokens()
			_status("")
		elif event.keycode == KEY_L:
			log_box.visible = not log_box.visible


# --- The spin and the count ------------------------------------------------------------

func _on_spin() -> void:
	var run = main.run
	if spinning or run.phase != RunState.Phase.TABLE or main.dialogue.is_open():
		return
	_unzoom()
	if not run.table_offer.is_empty():
		_status("Pick your free chip first (or No thanks).")
		Sfx.play("click")
		return
	if run.has_unplaced_chips():
		_status("Place the chips in your rack before you spin.")
		if selected_item < 0:
			selected_item = 0
			_refresh_tokens()
		return
	spinning = true
	bet_history.clear()
	spin_btn.disabled = true
	selected_item = -1
	Sfx.play("spin")
	score_rows = []
	spin_score = 0.0
	spin_score_vis = false
	receipt = ""
	var pocket: int = run._draw_pocket()
	var pocket2: int = run._draw_pocket() if run.felt.board.def.get("twin", false) else -99
	wheel_view.spin_to(pocket, 0.7 if fast() else 1.9, pocket2)
	await wheel_view.spin_done
	Sfx.play("ball_drop")
	var ctx := {"before": run.table.take, "target": run.table.target, "spins_before": run.table.spins_left,
		"stakes": run.felt.bet_stakes(), "layout": run.felt.chips.filter(func(c): return c.is_bet()).map(func(c): return [c.bet, c.value])}
	var res: Dictionary = run.spin(pocket, pocket2)
	main.check_feats("spin", {"res": res, "staked": ctx.stakes, "target": ctx.target, "before": ctx.before,
		"spins_before": ctx.spins_before, "cleared": run.phase == RunState.Phase.SHOP or run.phase == RunState.Phase.VICTORY})
	history.append(pocket)
	if pocket2 != -99:
		history.append(pocket2)
	history_view.queue_redraw()
	await count.play(res, ctx)
	_log(res)
	var cleared: bool = run.phase == RunState.Phase.SHOP or run.phase == RunState.Phase.VICTORY
	if cleared and ctx.spins_before <= 1:
		log_box.append_text("[color=#f2c14e][b]*** PAID ON THE LAST BALL ***[/b][/color]\n")
		main.pending_lines.append({"speaker": "Dealer", "text": ["Last ball. Paid in full. I've seen grown men faint for less.", "The house hates a finish like that. I love it.", "On the very last ball. Somebody upstairs just spilled his drink."][randi() % 3]})
	if run.phase == RunState.Phase.GAME_OVER:
		main.last_layout = {"layout": ctx.layout, "short": maxi(0, int(ceil(run.table.target - run.table.take))), "target": run.table.target, "take": int(run.table.take)}
	if run.phase != RunState.Phase.TABLE:
		if run.phase == RunState.Phase.GAME_OVER:
			main.fx.stamp("BUSTED", P.DANGER, 1.6)
			main.shake(5.0, 0.5)
			Sfx.play("bust")
		else:
			main.fx.stamp("PAID", P.GOLD, 1.2)
			main.fx.coin_rain(90)
			Sfx.play("clear")
			if not main.fast_ui:
				await get_tree().create_timer(0.9).timeout
				count.show_tally()
		await get_tree().create_timer(1.5 if main.fast_ui or fast() else 2.8).timeout
		spinning = false
		main.route()
	else:
		spinning = false
		if run.rebet() > 0:
			Sfx.play("chip_place")
		main.save_run()
		refresh()


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
