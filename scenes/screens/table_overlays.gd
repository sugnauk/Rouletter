extends RefCounted
## The table screen's overlays and quick edits, split out of table_screen.gd:
##   - the free pick-1-of-3 chip panel at the start of every table
##   - the touch long-press bet menu, and the quick edits it shares with Shift/Ctrl/Alt-click
##   - Dolores' first-time tips for the table's systems
## `t` is the table screen.

const P := preload("res://scenes/ui/palette.gd")
const InfoCard := preload("res://scenes/ui/info_card.gd")
const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const RunState := preload("res://core/run_state.gd")
const Token := preload("res://scenes/ui/token_button.gd")
const Preview := preload("res://core/preview.gd")
const Story := preload("res://core/story.gd")

var t   ## the table screen
var offer_panel: Panel = null   ## the free pick-1-of-3 chip at the start of each table
var offer_key := ""
var bet_menu: Control = null     ## touch: the long-press edit menu


func _init(table) -> void:
	t = table


## Dolores explains each new system the first time it turns up (one at a time).
func first_time_tips(run) -> void:
	if t.main.dialogue.is_open() or t.spinning:
		return
	var td: Dictionary = run.table
	for pair in [["free_chip", not run.table_offer.is_empty()], ["job", td.get("objective", "") != ""],
			["condition", td.get("condition", "") != ""], ["odds", run.night == 0 and run.table_offer.is_empty()]]:
		if pair[1] and Story.TIPS[pair[0]].id not in t.main.profile.seen_beats:
			t.main.tip(pair[0], true)
			return


## The free special chip waiting at the start of every table: three to choose from, over the
## score panel so the felt stays visible for hover previews.
## The free-chip panel sits over the score panel, wherever that is.
func relayout() -> void:
	offer_key = ""
	if t.main != null and t.main.run != null:
		refresh_offer(t.main.run)


func refresh_offer(run) -> void:
	var key: String = "" if run.table_offer.is_empty() else "%s|%s" % [t.table_key, str(run.table_offer.map(func(o): return o.id))]
	if key == offer_key:
		return
	offer_key = key
	if offer_panel != null:
		offer_panel.queue_free()
		offer_panel = null
	if key == "":
		return
	offer_panel = Panel.new()
	offer_panel.add_theme_stylebox_override("panel", P.box(Color(0.05, 0.03, 0.02, 0.97), P.GOLD, 1))
	P.place(offer_panel, t.score_view.position, t.score_view.size)
	t.add_child(offer_panel)
	var title := P.label(offer_panel, "ON THE HOUSE: PICK A CHIP", P.FONT, P.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pw: float = offer_panel.size.x
	var ph: float = offer_panel.size.y
	P.place(title, Vector2(0, 8), Vector2(pw, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	P.place(row, Vector2(0, 26), Vector2(pw, 100))
	offer_panel.add_child(row)
	for i in range(run.table_offer.size()):
		var o: Dictionary = run.table_offer[i]
		var spec: Dictionary = Content.CHIPS[o.id]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.custom_minimum_size = Vector2(90, 0)
		row.add_child(col)
		var h := P.label(col, Content.DIRECTIONS[o.dir].to_upper(), P.FONT_SMALL, P.CYAN)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tok = Token.new(o.id, Vector2(46, 46))
		tok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tok.rarity = Content.rarity_of(o.id)
		tok.hover_target = func(_s):
			t._status("%s: %s" % [spec.name, spec.desc])
			t.felt_view.preview = {}
			if Preview.absolute_trigger(o.id):
				for p in Preview.pays_on(run.felt, o.id, Preview.rep_key(run.felt, o.id)):
					t.felt_view.preview[Board.straight_key(p)] = P.CYAN
			t.felt_view.queue_redraw()
			t.main.card_near(tok, InfoCard.for_offer(o.id, "FREE CHIP  " + Content.DIRECTIONS[o.dir].to_upper(), "Free: click to take it, then place it."))
		tok.hover_exit = func():
			t.main.hide_card()
			t.felt_view.preview = {}
			t.felt_view.queue_redraw()
		tok.pressed.connect(func():
			t.main.hide_card()
			if run.take_table_offer(i):
				t.main.profile.note_seen(o.id)
				t.main.profile.note_used(o.id)
				t.selected_item = run.inventory.size() - 1
				t.felt_view.preview = {}
				Sfx.play("buy")
				t.main.fx.burst(t.main.fx.local(tok.global_position + tok.size / 2.0), 24, [P.GOLD, P.CREAM, P.CYAN], 120.0)
				t.refresh()
				t._status("%s: click the felt to place it." % spec.name))
		col.add_child(tok)
		var n := P.label(col, spec.name, P.FONT_SMALL, P.CREAM)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(90, 0)
	var sub := P.label(offer_panel, "A free chip at every table.", P.FONT_SMALL, P.DIM)
	P.place(sub, Vector2(8, ph - 20))
	sub.visible = ph >= 140.0   # no room for the footnote on a phone held upright
	var sk := P.button(offer_panel, "No thanks", func():
		run.skip_table_offer()
		Sfx.play("click")
		t.refresh(), Vector2(64, 16), P.FONT_SMALL)
	P.place(sk, Vector2(pw - 72, ph - 22))


func edit_take_back(key: String) -> void:
	if t.main.run.take_back(key):
		t.bet_history = t.bet_history.filter(func(h): return h.key != key)
		t._chips_home(key)
		Sfx.play("refund")


func edit_minus(key: String) -> void:
	if t.main.run.unbet(key, t.bet_size) > 0:
		t.bet_history = t.bet_history.filter(func(h): return h.key != key)
		t._chips_home(key)
		Sfx.play("refund")


func edit_clear_area(key: String) -> void:
	var run = t.main.run
	var region: Array = run.felt.board.bet(key).numbers
	var n := 0
	for c in run.felt.chips.duplicate():
		if c.is_bet() and not t.pinned.has(c.bet) and run.felt.board.bet(c.bet).numbers.all(func(x): return x in region):
			t._chips_home(c.bet)
			n += run.take_back(c.bet) as int
	if n > 0:
		Sfx.play("clear_all")
		t._status("Cleared %d bet%s inside %s." % [n, "" if n == 1 else "s", t.felt_view.describe(key).split("  ")[0]])


func edit_pin(key: String) -> void:
	if t.main.run.felt.chips_on(key).any(func(c): return c.is_bet()):
		if t.pinned.has(key):
			t.pinned.erase(key)
		else:
			t.pinned[key] = true
		t.felt_view.pinned = t.pinned
		t.felt_view.queue_redraw()
		Sfx.play("click")
		t._status("Pinned: Clear keeps this bet." if t.pinned.has(key) else "Unpinned.")


## Touch: a long press on a square opens its edits (the mouse uses right-click / Shift / Ctrl / Alt).
func on_bet_held(key: String) -> void:
	var run = t.main.run
	if t.spinning or run.phase != RunState.Phase.TABLE or t.main.dialogue.is_open():
		return
	close_bet_menu()
	var has_bet: bool = run.felt.chips_on(key).any(func(c): return c.is_bet())
	var outside: bool = not Board.is_straight(key)
	var has_fresh: bool = run.felt.chips_on(key).any(func(c): return not c.is_bet() and run.is_fresh(c.id))
	if not has_bet and not outside and not has_fresh:
		# Nothing to edit: a long press inspects instead (phones have no hover).
		var perms: Array = run.felt.chips_on(key).filter(func(c): return not c.is_bet())
		var d: Dictionary = InfoCard.for_chip(perms[0], run) if not perms.is_empty() \
			else InfoCard.for_text(run.felt.board.label(Board.straight_number(key)) if Board.is_straight(key) else key, "", t.felt_view.describe(key))
		t.main.card_at_felt(t.felt_view, key, d)
		t.main.buzz("tick")
		return
	bet_menu = Control.new()
	bet_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bet_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	bet_menu.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_bet_menu())
	t.add_child(bet_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var items := []
	if has_bet:
		items.append(["Take back", func(): edit_take_back(key)])
		items.append(["-%d chip%s" % [t.bet_size, "" if t.bet_size == 1 else "s"], func(): edit_minus(key)])
		items.append(["Unpin" if t.pinned.has(key) else "Pin", func(): edit_pin(key)])
	if outside:
		items.append(["Clear inside", func(): edit_clear_area(key)])
	if has_fresh:
		items.append(["Pick up chip", func(): t.unplace_at(key)])
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", P.box(Color("#1a120c"), P.GOLD, 1))
	var at: Vector2 = t.felt_view.position + t.felt_view.key_center(key)
	var sz := Vector2(84, items.size() * 20 + 6)
	at = Vector2(clampf(at.x - sz.x / 2.0, 4, P.W - 4 - sz.x), clampf(at.y + 10, 4, P.H - 4 - sz.y))
	P.place(bg, at, sz)
	bet_menu.add_child(bg)
	P.place(box, Vector2(3, 3))
	bg.add_child(box)
	for it in items:
		var cb: Callable = it[1]
		P.button(box, it[0], func():
			cb.call()
			close_bet_menu(), Vector2(78, 18), P.FONT_SMALL)
	Sfx.play("click")


func close_bet_menu() -> void:
	if bet_menu != null:
		bet_menu.queue_free()
		bet_menu = null
