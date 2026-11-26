extends Control
## The Cage between tables: a row of vendor windows, each selling different things for a
## different currency (cash, or chips off your next stack). The felt on the right is where you
## place, move or sell your permanent chips.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const RunState := preload("res://core/run_state.gd")
const FeltView := preload("res://scenes/ui/felt_view.gd")
const Token := preload("res://scenes/ui/token_button.gd")

const CAGE := Rect2(8, 28, 288, 150)

var main
var cage_view: Control
var counter: Control          ## holds one token row per vendor window
var windows: Array = []       ## [{rect, vendor}] for drawing
var service_box: HBoxContainer
var desc_title: Label
var desc_body: Label
var next_lbl: Label
var felt_view
var mode_box: HBoxContainer
var rack: HFlowContainer
var status_lbl: Label
var mode := "place"
var selected_item := -1
var board_id := ""
var t := 0.0


func setup() -> void:
	cage_view = Control.new()
	cage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(cage_view, Vector2.ZERO, Vector2(640, 360))
	cage_view.draw.connect(_draw_cage)
	add_child(cage_view)
	counter = Control.new()
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(counter, Vector2.ZERO, Vector2(640, 360))
	add_child(counter)
	service_box = HBoxContainer.new()
	service_box.add_theme_constant_override("separation", 6)
	P.place(service_box, Vector2(8, 184))
	add_child(service_box)
	var dp := Panel.new()
	dp.add_theme_stylebox_override("panel", P.box(Color("#1a120c"), P.WOOD, 1))
	P.place(dp, Vector2(8, 234), Vector2(288, 82))
	add_child(dp)
	desc_title = P.label(dp, "", P.FONT, P.GOLD)
	P.place(desc_title, Vector2(6, 4))
	desc_body = P.label(dp, "", P.FONT_SMALL, P.CREAM)
	desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_body.add_theme_constant_override("line_spacing", -1)
	P.place(desc_body, Vector2(6, 18), Vector2(276, 62))
	next_lbl = P.label(self, "", P.FONT_SMALL, P.CREAM)
	next_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(next_lbl, Vector2(8, 320), Vector2(200, 36))
	var nb := P.button(self, "NEXT TABLE >", _next, Vector2(84, 30), P.FONT_SMALL)
	var mb := P.button(self, "MENU", func(): main.open_pause(), Vector2(40, 14), P.FONT_SMALL)
	P.place(mb, Vector2(594, 6))
	nb.add_theme_stylebox_override("normal", P.box(Color("#b8862b"), P.BLACK, 1))
	nb.add_theme_stylebox_override("hover", P.box(Color("#d9a63c"), P.CREAM, 1))
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		nb.add_theme_color_override(s, P.WOOD_DARK)
	P.place(nb, Vector2(212, 322))

	felt_view = FeltView.new()
	P.place(felt_view, Vector2(304, 32))
	felt_view.bet_clicked.connect(_on_felt)
	felt_view.bet_hovered.connect(func(k): status_lbl.text = felt_view.describe(k) if k != "" else _hint())
	add_child(felt_view)
	P.place(P.label(self, "YOUR CHIPS", P.FONT_SMALL, P.DIM), Vector2(304, 152))
	mode_box = HBoxContainer.new()
	mode_box.add_theme_constant_override("separation", 4)
	P.place(mode_box, Vector2(304, 164))
	add_child(mode_box)
	for m in [["place", "PLACE"], ["move", "MOVE $%d" % Content.RELOCATE_PRICE], ["sell", "SELL"]]:
		var b := P.button(mode_box, m[1], _set_mode.bind(m[0]), Vector2(70, 16), P.FONT_SMALL)
		b.toggle_mode = true
		b.set_meta("mode", m[0])
	P.place(P.label(self, "RACK", P.FONT_SMALL, P.DIM), Vector2(304, 188))
	rack = HFlowContainer.new()
	rack.add_theme_constant_override("h_separation", 4)
	rack.add_theme_constant_override("v_separation", 4)
	P.place(rack, Vector2(304, 198), Vector2(330, 0))
	add_child(rack)
	status_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(status_lbl, Vector2(304, 300), Vector2(330, 50))


func _process(delta: float) -> void:
	if visible:
		t += delta
		cage_view.queue_redraw()


func _draw_cage() -> void:
	var c := cage_view
	var run = main.run
	var font := P.title_font()
	# Header plaque.
	Art.plaque(c, Rect2(8, 3, 150, 20))
	Art.text(c, font, Vector2(83, 17), "THE CAGE", 8, P.CREAM, true)
	Art.icon(c, "cash", Vector2(176, 13), 1)
	Art.text(c, font, Vector2(186, 18), "$%d" % run.cash, 16, P.GOLD)
	if run.overflow > 0 or "dealer" in run.shop.get("vendors", []):
		Art.text(c, P.font(), Vector2(250, 12), "SPARE TAKE", 8, P.DIM)
		Art.text(c, P.font(), Vector2(250, 22), str(run.overflow), 8, P.VIOLET)
	for win in windows:
		_draw_window(c, win.rect, win.vendor)


## One vendor's window: wood frame, dark interior, a lamp, brass bars, velvet counter, name.
func _draw_window(c: Control, w: Rect2, vendor: String) -> void:
	var accent: Color = {"cash": P.GOLD, "stack": P.RED.lightened(0.2), "loan": P.CYAN, "take": P.VIOLET}.get(Content.VENDORS[vendor].currency, P.GOLD)
	c.draw_rect(w.grow(4), P.WOOD_DARK)
	c.draw_rect(w.grow(2), P.WOOD)
	c.draw_rect(w, Color("#0d0907"))
	for i in range(4):
		c.draw_circle(Vector2(w.get_center().x, w.position.y + 6), 50.0 - i * 12.0, Color(1, 0.8, 0.4, 0.03 + i * 0.01), true, -1.0, false)
	c.draw_rect(Rect2(w.get_center().x - 1, w.position.y, 2, 6), P.GOLD.darkened(0.3))
	var counter_r := Rect2(w.position.x, w.position.y + 54, w.size.x, w.size.y - 54)
	c.draw_rect(counter_r, Color("#5c1020") if vendor == "cashier" else Color("#123a24"))
	for x in range(int(counter_r.position.x), int(counter_r.end.x), 3):
		c.draw_rect(Rect2(x, counter_r.position.y, 1, counter_r.size.y), Color("#4a0c19") if vendor == "cashier" else Color("#0d2c1b"))
	c.draw_rect(Rect2(counter_r.position, Vector2(counter_r.size.x, 3)), P.WOOD)
	# Bars stop at the counter so the tokens sit in front of them.
	for x in range(int(w.position.x) + 8, int(w.end.x), 18):
		c.draw_rect(Rect2(x, w.position.y, 2, 54), P.GOLD.darkened(0.35))
		c.draw_rect(Rect2(x, w.position.y, 1, 54), P.GOLD.lightened(0.1))
	c.draw_rect(Rect2(w.position.x, w.position.y + 30, w.size.x, 2), P.GOLD.darkened(0.35))
	# Name plate over the bars.
	_plate(c, w, 14, Content.VENDORS[vendor].name.to_upper(), accent)
	_plate(c, w, 38, {"cash": "CASH", "stack": "PAY IN CHIPS", "loan": "PAY LATER", "take": "PAY IN SPARE TAKE"}.get(Content.VENDORS[vendor].currency, ""), accent.darkened(0.25))


func _plate(c: Control, w: Rect2, y: float, text: String, col: Color) -> void:
	var tw := P.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var plate := Rect2(floor(w.get_center().x - tw / 2.0 - 4), w.position.y + y, tw + 8, 11)
	c.draw_rect(plate, Color("#0d0907"))
	c.draw_rect(plate, col.darkened(0.3), false, 1.0)
	Art.text(c, P.font(), Vector2(w.get_center().x, w.position.y + y + 9), text, 8, col, true)


func _hint() -> String:
	if main.run.shop.get("pending_upgrade", "") != "":
		return "Click a glowing spot on the felt to lay your %s." % Content.UPGRADES[main.run.shop.pending_upgrade].name
	match mode:
		"move":
			return "Click one of your chips on the felt to pick it up ($%d), then place it again." % Content.RELOCATE_PRICE
		"sell":
			return "Click one of your chips on the felt to sell it for half its price."
	return "Pick a chip from your rack, then click the felt to place it."


## What the description panel says when nothing is hovered: who's on duty and how they deal.
func _idle_desc(run) -> void:
	var lines := []
	for v in run.shop.vendors:
		lines.append("%s: %s" % [Content.VENDORS[v].name.to_upper(), Content.VENDORS[v].blurb])
	_describe("", "\n".join(lines))


func _describe(title: String, body: String) -> void:
	desc_title.text = title
	desc_body.text = body


func _set_mode(m: String) -> void:
	mode = m
	selected_item = -1
	Sfx.play("click")
	refresh()


func _next() -> void:
	if main.run.has_unplaced_chips():
		status_lbl.text = "Place the chips in your rack before you leave."
		Sfx.play("click")
		if selected_item < 0:
			selected_item = 0
			refresh()
			status_lbl.text = "Place the chips in your rack before you leave."
	elif main.run.leave_shop():
		Sfx.play("click")
		main.route()
	else:
		status_lbl.text = "Lay your upgrade first."


func refresh() -> void:
	var run = main.run
	if run.phase != RunState.Phase.SHOP:
		return
	felt_view.marks = main.profile.settings.cb_marks
	var bid: String = run.wheel_id + str(run.has_feature("call_bets"))
	if felt_view.run != run or board_id != bid:
		felt_view.run = run
		felt_view.layout()
		board_id = bid
	_build_windows(run)
	if desc_title.text == "":
		_idle_desc(run)
	for ch in service_box.get_children():
		ch.queue_free()
	var rr = Token.new("reroll", Vector2(40, 44))
	rr.price = "$%d" % run.shop.reroll
	rr.dim = run.cash < run.shop.reroll
	rr.hover_target = func(_s): _describe("Reroll  $%d" % run.shop.reroll, "New stock on the counter. Gets $1 pricier each time.")
	rr.pressed.connect(func():
		if run.reroll():
			for it in run.shop.stock:
				main.profile.note_seen(it.id)
			Sfx.play("buy")
			main.fx.burst(Vector2(152, 110), 14, [P.GOLD, P.CREAM]))
	service_box.add_child(rr)
	var sb = Token.new("stack", Vector2(40, 44))
	sb.price = "$%d" % run.stack_price()
	sb.dim = run.cash < run.stack_price()
	sb.hover_target = func(_s): _describe("Bigger Stack  $%d" % run.stack_price(), "+%d betting chips at every table from now on (you have %d)." % [Content.STACK_UPGRADE, run.stack_size])
	sb.pressed.connect(func():
		if run.buy_stack():
			Sfx.play("buy"))
	service_box.add_child(sb)
	var rules := P.label(service_box, "", P.FONT_SMALL, P.DIM)
	rules.custom_minimum_size = Vector2(190, 44)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rl := []
	for r in run.felt.house_rules:
		rl.append(Content.HOUSE_RULES[r].name)
	rules.text = "HOUSE RULES %d/%d\n%s" % [rl.size(), run.relic_slots(), ", ".join(rl) if not rl.is_empty() else "none yet"]
	if not run.vouchers.is_empty() or not run.favours.is_empty():
		var vn := []
		for v in run.vouchers:
			vn.append(Content.VOUCHERS[v].name)
		for f in run.favours:
			vn.append(Content.FAVOURS[f].name + " (next)")
		rules.text += "\nPERKS: " + ", ".join(vn)
	var nxt := "NEXT: Night %d %s - pay %d" % [run.night + 1, run.table_name(), run.current_target()]
	if run.stack_owed > 0:
		nxt += "  (stack %d, -%d to the Pit Boss)" % [run.stack_size - run.stack_owed, run.stack_owed]
	if run.loan_pct > 0.0:
		nxt += "  (+%d%% to the Loan Shark)" % int(round(run.loan_pct * 100))
	if run.table_idx == 2:
		var e: Dictionary = Content.ENFORCERS[run.night_enforcer()]
		nxt += "\n%s: %s" % [e.name, e.desc]
	next_lbl.text = nxt
	next_lbl.add_theme_color_override("font_color", P.DANGER if run.table_idx == 2 else P.CREAM)
	for b in mode_box.get_children():
		b.button_pressed = b.get_meta("mode") == mode
	felt_view.targets = run.upgrade_targets()
	felt_view.queue_redraw()
	_refresh_rack()
	status_lbl.text = _hint()
	cage_view.queue_redraw()


## Lay the vendor windows side by side across the cage area, each sized to its stock.
func _build_windows(run) -> void:
	for ch in counter.get_children():
		ch.queue_free()
	windows = []
	var groups := {}
	for v in run.shop.vendors:
		groups[v] = []
	for i in range(run.shop.stock.size()):
		groups[run.shop.stock[i].vendor].append(i)
	const TOK := Vector2(46, 62)
	const SEP := 6.0
	const GAP := 8.0
	var widths := []
	var total := 0.0
	for v in run.shop.vendors:
		var n: int = maxi(1, groups[v].size())
		var wv: float = n * TOK.x + (n - 1) * SEP + 16.0
		widths.append(wv)
		total += wv
	var extra: float = maxf(0.0, (CAGE.size.x - total - GAP * (widths.size() - 1)) / widths.size())
	var x := CAGE.position.x
	for wi in range(run.shop.vendors.size()):
		var v: String = run.shop.vendors[wi]
		var r := Rect2(x, CAGE.position.y, floor(widths[wi] + extra), CAGE.size.y)
		windows.append({"rect": r, "vendor": v})
		x = r.end.x + GAP
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(SEP))
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		P.place(row, Vector2(r.position.x, r.position.y + 62), Vector2(r.size.x, TOK.y))
		counter.add_child(row)
		if groups[v].is_empty():
			P.label(row, "SOLD OUT", P.FONT_SMALL, P.DIM)
		for i in groups[v]:
			var item: Dictionary = run.shop.stock[i]
			var tok = Token.new(item.get("icon", item.id), TOK)
			tok.price = "SOLD" if item.sold else run.price_text(item)
			if item.type in ["chip", "upgrade", "rule"]:
				tok.rarity = Content.rarity_of(item.id)
			if item.get("flaw", "") != "":
				tok.badge = Content.FLAWS[item.flaw].short
			elif item.type == "loan":
				tok.badge = "$%d" % item.price
			tok.dim = item.sold or not run.can_afford(item)
			tok.disabled = item.sold
			var tag: String = {"chip": "CHIP", "upgrade": "FELT UPGRADE", "rule": "HOUSE RULE", "loan": "LOAN",
				"favour": "FAVOUR (next table)", "voucher": "VOUCHER (whole run)"}[item.type]
			var vname: String = Content.VENDORS[v].name
			tok.hover_target = func(_s):
				var body: String = run.item_desc(item)
				if v != "cashier" and v != "pit_boss" and item.type != "loan":
					body += "\n" + Content.VENDORS[v].blurb
				if item.currency == "stack":
					body += "\n%s takes %s off your next stack (you can spare %d)." % [vname, run.price_text(item).to_lower(), maxi(0, run.stack_spare())]
				var rar: String = Content.rarity_of(item.id)
				if item.type in ["chip", "upgrade", "rule"] and rar != "common":
					tag = rar.to_upper() + " " + tag
				if item.type == "chip" and run.felt.perm_chips().any(func(c): return c.kind == item.id and c.flaw == item.get("flaw", "")):
					body += "\nYou own one: stack this on it to level it up."
				for h in run.item_hints(item):
					body += "\n" + h
				_describe("%s  -  %s  %s" % [run.item_name(item), tag, run.price_text(item)], body)
			tok.pressed.connect(_buy.bind(i))
			row.add_child(tok)


## Where a stock token sits on screen (for purchase sparkles).
func _token_pos(i: int) -> Vector2:
	var n := 0
	for row in counter.get_children():
		for tok in row.get_children():
			if tok is Button:
				if n == i:
					return main.fx.local(tok.global_position + tok.size / 2.0)
				n += 1
	return CAGE.get_center()


func _refresh_rack() -> void:
	for c in rack.get_children():
		c.queue_free()
	var inv: Array = main.run.inventory
	if selected_item >= inv.size():
		selected_item = -1
	if inv.is_empty():
		P.label(rack, "(nothing to place)", P.FONT_SMALL, P.DIM)
	for i in range(inv.size()):
		var item: Dictionary = inv[i]
		var tok = Token.new(item.kind, Vector2(25, 25))
		tok.rarity = Content.rarity_of(item.kind)
		tok.badge = "x%d" % item.value if item.value > 1 else ""
		if item.get("flaw", "") != "":
			tok.badge = Content.FLAWS[item.flaw].short
		tok.selected = i == selected_item
		tok.hover_target = func(_s): status_lbl.text = "%s: %s" % [Content.CHIPS[item.kind].name, Content.CHIPS[item.kind].desc]
		tok.pressed.connect(_select.bind(i))
		rack.add_child(tok)


func _select(i: int) -> void:
	selected_item = -1 if selected_item == i else i
	mode = "place"
	Sfx.play("click")
	refresh()


func _buy(i: int) -> void:
	var run = main.run
	var item: Dictionary = run.shop.stock[i]
	var owned_twin: bool = item.type == "chip" and run.felt.perm_chips().any(func(c): return c.kind == item.id and c.flaw == item.get("flaw", ""))
	if run.buy(i):
		main.profile.note_used(item.id)
		if owned_twin:
			main.tip("level", true)
		Sfx.play("buy")
		var tp := _token_pos(i)
		main.fx.burst(tp, 22, [P.GOLD, P.CREAM, P.chip_color(item.id)], 130.0)
		main.fx.pop_text(tp - Vector2(0, 20), "SOLD!", P.GOLD)
		if item.type == "chip":
			selected_item = run.inventory.size() - 1
			mode = "place"
		elif item.type == "rule":
			main.fx.banner(Content.HOUSE_RULES[item.id].name.to_upper(), P.GOLD, 1.0, 120, 8)
		refresh()
	else:
		if item.type == "loan":
			_describe("Already borrowed", "Each loan once per visit.")
		elif item.get("currency", "cash") == "take":
			_describe("Not enough spare Take", "The Dealer takes what you scored past each payment. You have %d." % run.overflow)
		elif item.get("currency", "cash") == "stack":
			_describe("Can't buy that", "The Pit Boss won't leave you fewer than %d betting chips, or your House Rule slots are full." % Content.MIN_STACK)
		else:
			_describe("Can't buy that", "Not enough cash, or your House Rule slots are full.")


func _on_felt(key: String, button: int) -> void:
	var run = main.run
	if button != MOUSE_BUTTON_LEFT or main.dialogue.is_open():
		return
	if run.shop.pending_upgrade != "":
		if run.apply_upgrade(key):
			felt_view.flash(key)
			main.fx.burst(main.fx.local(felt_view.key_global(key)), 20, [P.CYAN, P.GOLD, P.CREAM])
			Sfx.play("chip_place")
		return
	if selected_item >= 0:
		if run.place_chip(selected_item, key):
			selected_item = -1
			felt_view.pop(key)
			main.fx.burst(main.fx.local(felt_view.key_global(key)), 10, [P.GOLD, P.CREAM], 60.0)
			Sfx.play("chip_place")
		else:
			status_lbl.text = "That chip can't go there."
		return
	var mine: Array = run.felt.chips_on(key).filter(func(c): return not c.is_bet())
	if mine.is_empty():
		return
	if mode == "move" and run.pick_up(mine[0].id):
		selected_item = run.inventory.size() - 1
		mode = "place"
		Sfx.play("chip_remove")
		refresh()
	elif mode == "sell" and run.sell_chip(mine[0].id):
		main.fx.burst(main.fx.local(felt_view.key_global(key)), 12, [P.GOLD])
		Sfx.play("cash")
