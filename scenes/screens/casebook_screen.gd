extends Control
## The Casebook: everything you've found, read and played, in one place.
##   COLLECTION  every chip, felt upgrade, House Rule and Dealer perk, grouped by family, with
##               bars for seen / bought / unlocked. Locked items point at the Pawn Shop.
##   STORY       every story scene you've seen, by chapter, ready to replay.
##   HOW TO PLAY short guide pages; Dolores can talk you through each one again.
##   RUNS        your recent runs and this week's weekly-challenge results.
## (Feats live in the Pawn Shop, next to the unlocks they pay for.)

const P := preload("res://scenes/ui/palette.gd")
const InfoCard := preload("res://scenes/ui/info_card.gd")
const Art := preload("res://scenes/ui/art.gd")
const Story := preload("res://core/story.gd")
const Content := preload("res://core/content.gd")
const Wheels := preload("res://core/wheels.gd")
const Token := preload("res://scenes/ui/token_button.gd")

const TABS := [["collection", "COLLECTION"], ["story", "STORY"], ["guide", "HOW TO PLAY"], ["runs", "RUNS"]]
const LIST_W := 372.0

## How to Play pages: [title, text, story keys Dolores can replay (TUTORIAL.<k> or TIPS.<k>)].
const GUIDE := [
	["The table", "Each table asks for a payment, in Take, within its balls (usually 6). Click a square, a split, a corner or an outside box to bet from your stack. Winning bets pay their odds into your Take and come back to your stack; losing bets cost their chips off that spin's Take. Covering everything scores nothing: pick your shots.", ["tut_table"]],
	["The Cage", "Between tables you visit the Cage. Each window sells something different for a different currency: the Cashier takes cash, the Pit Boss takes chips off your next stack, the Loan Shark adds to your next payment, the Dealer takes spare Take, the Fence sells cheap flawed chips.", ["tut_shop"]],
	["Chips and levels", "Permanent chips stay on the felt all run and score every time their spot hits. Put a chip on its twin and it levels up; a stack does everything all its chips would do apart, so you never lose by stacking.", ["level"]],
	["Free chips", "Every table opens with a free special chip: pick one of three, each pointing your build a different way, or pass.", ["free_chip"]],
	["Side jobs and conditions", "Tables can carry a side job (an optional goal that pays cash when you clear) and, from night 2, a condition: a twist like Tight Felt or Spread Out. Both show in the panel on the right of the table.", ["job", "condition"]],
	["Routes and Cage events", "Before the High Roller you can pick your table: the short Back Room, the long Long Table, or the usual. Before the Enforcer, someone in the Cage may offer a deal.", ["route", "event"]],
	["Enforcers and stashes", "The third table each night belongs to an Enforcer, who bends one rule. Beat them and raid their stash: their trophy (a House Rule sold nowhere else) or one of two rare chips.", []],
	["Refine and trade", "At the Cashier, REFINE gives a number chip at level 2+ a second act (Focused or Steady), and TRADE swaps a placed chip for a related one.", ["refine"]],
	["Flaws, rarity and spare Take", "Fence chips are cheap because they're flawed: cracked, hot or sticky. Blue frames are rare, gold legendary. Take you score past a payment is spare Take, the Dealer's currency.", ["flaw", "rarity", "spare"]],
	["Speed and controls", "The > button by MENU (or F) cycles Normal, Fast and Fastest. Right-click takes a bet back; Shift takes back one chip; Ctrl clears an area; Alt pins a bet so Clear keeps it. On a touch screen, hold a bet for the same options.", []],
]

var main
var tab := "collection"
var tab_btns := {}
var summary_lbl: Label
var list: VBoxContainer
var scroll: ScrollContainer
var detail_title: Label
var detail: Label
var action_btn
var list_w := LIST_W
var panel: Panel
var back_btn
var _action: Callable


func setup() -> void:
	P.place(P.label(self, "CASEBOOK", P.FONT_BIG, P.GOLD), Vector2(16, 6))
	var x := 216.0
	for t in TABS:
		var w: float = 96.0 if t[0] != "guide" else 104.0
		var b := P.button(self, t[1], func():
			tab = t[0]
			Sfx.play("click")
			refresh(), Vector2(w, 16), P.FONT_SMALL)
		P.place(b, Vector2(x, 6))
		tab_btns[t[0]] = b
		x += w + 4
	summary_lbl = P.label(self, "", P.FONT_SMALL, P.CREAM)
	P.place(summary_lbl, Vector2(16, 30))
	scroll = ScrollContainer.new()
	P.place(scroll, Vector2(16, 46), Vector2(list_w, 272))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(list_w - 12, 0)
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	panel = Panel.new()
	P.place(panel, Vector2(396, 46), Vector2(228, 272))
	add_child(panel)
	detail_title = P.label(panel, "", P.FONT, P.GOLD)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail_title, Vector2(8, 6), Vector2(212, 24))
	detail = P.label(panel, "", P.FONT_SMALL, P.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail, Vector2(8, 30), Vector2(212, 206))
	action_btn = P.button(panel, "", func():
		if _action.is_valid():
			_action.call(), Vector2(212, 20), P.FONT_SMALL)
	P.place(action_btn, Vector2(8, 244))
	back_btn = P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 22))
	P.place(back_btn, Vector2(16, 326))


## Portrait: the tabs under the title, the list on top and the detail panel under it.
func relayout(tall: bool) -> void:
	list_w = 328.0 if tall else LIST_W
	var x := 16.0 if tall else 216.0
	for t in TABS:
		var w: float = 78.0 if tall else (96.0 if t[0] != "guide" else 104.0)
		P.place(tab_btns[t[0]], Vector2(x, 28 if tall else 6), Vector2(w, 16))
		x += w + 4
	P.place(summary_lbl, Vector2(16, 50) if tall else Vector2(16, 30))
	P.place(scroll, Vector2(16, 64) if tall else Vector2(16, 46), Vector2(list_w, 290) if tall else Vector2(list_w, 272))
	list.custom_minimum_size.x = list_w - 12
	P.place(panel, Vector2(16, 360) if tall else Vector2(396, 46), Vector2(328, 244) if tall else Vector2(228, 272))
	var iw: float = panel.size.x - 16
	P.place(detail_title, Vector2(8, 6), Vector2(iw, 24))
	P.place(detail, Vector2(8, 30), Vector2(iw, 180 if tall else 206))
	P.place(action_btn, Vector2(8, 216 if tall else 244), Vector2(iw, 20))
	P.place(back_btn, Vector2(16, 612) if tall else Vector2(16, 326))
	if main != null and visible:
		refresh()


func _show(title: String, body: String, action_text: String = "", action: Callable = Callable()) -> void:
	detail_title.text = title
	detail.text = body
	_action = action
	action_btn.text = action_text
	action_btn.visible = action_text != ""


func refresh() -> void:
	for k in tab_btns:
		tab_btns[k].accent = P.GOLD if k == tab else P.LINE.darkened(0.4)
		tab_btns[k].pulse = k == tab
	for c in list.get_children():
		c.queue_free()
	scroll.scroll_vertical = 0
	match tab:
		"collection":
			_collection()
		"story":
			_story()
		"guide":
			_guide()
		"runs":
			_runs()


## A section header with a label, a count and a thin progress bar.
func _header(title: String, count: String, k: float, col: Color = P.GOOD) -> void:
	var head := Control.new()
	head.custom_minimum_size = Vector2(list_w - 12, 16)
	list.add_child(head)
	P.place(P.label(head, title, P.FONT, P.GOLD if k >= 1.0 else P.CREAM), Vector2(0, 4))
	var cnt := P.label(head, count, P.FONT_SMALL, P.GOOD if k >= 1.0 else P.DIM)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	P.place(cnt, Vector2(list_w - 12 - 300, 5), Vector2(200, 10))
	var bar := Control.new()
	P.place(bar, Vector2(list_w - 12 - 92, 8), Vector2(92, 4))
	bar.draw.connect(func():
		bar.draw_rect(Rect2(0, 0, 92, 4), P.BLACK)
		bar.draw_rect(Rect2(0, 0, floor(92 * k), 4), P.GOLD if k >= 1.0 else col))
	head.add_child(bar)


# --- COLLECTION ---------------------------------------------------------------------------

func _collection() -> void:
	var prof = main.profile
	var seen_all := 0
	var bought_all := 0
	var total := 0
	for group in Content.ALMANAC:
		var table: Dictionary = Content.almanac_table(group[1])
		var ids: Array = group[2]
		var seen: int = ids.filter(func(i): return i in prof.seen_items).size()
		var bought: int = ids.filter(func(i): return i in prof.used_items).size()
		var locked: int = ids.filter(func(i): return table[i].get("unlock", 0) > 0 and not prof.is_unlocked(i)).size()
		seen_all += seen
		bought_all += bought
		total += ids.size()
		_header(group[0], "%d seen  %d bought%s" % [seen, bought, ("  %d locked" % locked) if locked > 0 else ""], float(seen) / ids.size())
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(list_w - 12, 0)
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		list.add_child(flow)
		for id in ids:
			var known: bool = id in prof.seen_items
			var used: bool = id in prof.used_items
			var is_locked: bool = table[id].get("unlock", 0) > 0 and not prof.is_unlocked(id)
			var tok = Token.new(table[id].get("icon", id) if known or used else "", Vector2(26, 26))
			tok.rarity = Content.rarity_of(id)
			tok.selected = used
			tok.dim = not known and not used
			tok.badge = ("%dM" % table[id].unlock) if is_locked else ("" if known or used else "?")
			tok.hover_target = func(_s):
				_item_detail(id, table, known, used, is_locked)
				if known or used:
					var cd: Dictionary = InfoCard.for_id(id)
					if not cd.is_empty():
						main.card_near(tok, cd)
			tok.hover_exit = main.hide_card
			tok.pressed.connect(func(): _item_detail(id, table, known, used, is_locked))
			flow.add_child(tok)
	summary_lbl.text = "COLLECTION  %d / %d seen  -  %d bought  -  Feats and unlocks are in the Pawn Shop." % [seen_all, total, bought_all]
	_show("YOUR COLLECTION", "Everything the Cage can sell, by family. Bright tiles you've seen; gold frames you've bought; red tags are locked and cost Markers at the Pawn Shop. Hover or tap a tile.")


func _item_detail(id: String, table: Dictionary, known: bool, used: bool, is_locked: bool) -> void:
	var e: Dictionary = table[id]
	if not known and not used:
		if is_locked:
			_show("? ? ?", "Locked. Unlock it at the Pawn Shop for %d Markers, then look for it in the Cage." % e.unlock,
				"Go to the Pawn Shop", func(): main.show_screen("pawn"))
		else:
			_show("? ? ?", "Not seen in the Cage yet. Keep playing: it turns up in the Cage when you least expect it.")
		return
	var rar: String = Content.rarity_of(id)
	var tags: Array = Content.tags_of(id).map(func(t): return Content.TAG_NAMES.get(t, t))
	var lines := [e.desc]
	var fine: String = InfoCard.chip_detail(id) if Content.CHIPS.has(id) or Content.UPGRADES.has(id) else str(e.get("more", ""))
	if fine != "":
		lines.append(fine)
	if tags.size() > 0:
		lines.append("Works with: " + ", ".join(tags) + ".")
	lines.append(("%s.  " % rar.capitalize()) + ("Bought at least once." if used else "Seen, never bought."))
	if e.get("note", "") != "":
		lines.append("\n" + e.note)
	_show(e.name.to_upper(), "\n".join(lines))


# --- STORY ------------------------------------------------------------------------------------

func _story() -> void:
	var seen: Array = main.profile.seen_beats
	var chapters := [["Prologue", [{"id": "intro", "title": "The Marker", "lines": Story.INTRO}]],
		["The story", Story.BEATS], ["Faces in the Cage", Story.VENDOR_INTROS.values()]]
	var nights: Array = Story.INTERLUDES.keys()
	nights.sort()
	var between := []
	for n in nights:
		between.append_array(Story.INTERLUDES[n])
	chapters.append(["Between nights", between])
	var found := 0
	var total := 0
	for ch in chapters:
		var scenes: Array = ch[1]
		var n: int = scenes.filter(func(sc): return sc.id in seen).size()
		found += n
		total += scenes.size()
		_header(ch[0].to_upper(), "%d / %d" % [n, scenes.size()], float(n) / maxf(1.0, scenes.size()), P.VIOLET)
		for sc in scenes:
			var known: bool = sc.id in seen
			var b := P.button(list, sc.title if known else "? ? ?", func(): _play(sc.lines), Vector2(list_w - 12, 18), P.FONT_SMALL)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = not known
			if known:
				b.mouse_entered.connect(func():
					_show(sc.title.to_upper(), "%s: \"%s\"" % [sc.lines[0].speaker, sc.lines[0].text], "Replay this scene", func(): _play(sc.lines)))
	summary_lbl.text = "STORY  %d / %d pages found. Unseen pages stay sealed until they happen in a run." % [found, total]
	_show("THE STORY SO FAR", "Every scene you've seen, by chapter. Hover a page to read its first line; click to replay it.")


# --- HOW TO PLAY --------------------------------------------------------------------------------

func _guide() -> void:
	for i in range(GUIDE.size()):
		var g: Array = GUIDE[i]
		var b := P.button(list, "%d.  %s" % [i + 1, g[0].to_upper()], func(): _guide_page(g), Vector2(list_w - 12, 20), P.FONT_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(func(): _guide_page(g))
	var rb := P.button(list, "REPLAY THE GUIDED FIRST RUN", func():
		while "tutorial_done" in main.profile.seen_beats:
			main.profile.seen_beats.erase("tutorial_done")
		main.save_profile()
		Sfx.play("click")
		_show("GUIDED FIRST RUN", "Done: your next run on the European wheel will be guided again, step by step. You can skip it from any of Dolores's lines."),
		Vector2(list_w - 12, 20), P.FONT_SMALL)
	rb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_lbl.text = "HOW TO PLAY  -  short pages on every part of the game. Dolores can talk you through any of them again."
	_guide_page(GUIDE[0])


func _guide_page(g: Array) -> void:
	var lines := []
	for k in g[2]:
		var sc: Dictionary = {}
		if k.begins_with("tut_"):
			sc = Story.TUTORIAL.get(k.trim_prefix("tut_"), {})
		else:
			sc = Story.TIPS.get(k, {})
		if not sc.is_empty():
			lines.append_array(sc.lines)
	_show(g[0].to_upper(), g[1], "Hear it from Dolores" if not lines.is_empty() else "", func(): _play(lines))


# --- RUNS ---------------------------------------------------------------------------------------

func _runs() -> void:
	var prof = main.profile
	var h: Array = prof.history
	var wins := h.filter(func(e): return e.won).size()
	_header("RECENT RUNS", "%d won of %d" % [wins, h.size()], float(wins) / maxf(1.0, h.size()))
	if h.is_empty():
		P.label(list, "No runs yet. Your last 10 runs will be listed here.", P.FONT_SMALL, P.DIM)
	for e in h:
		var wname: String = Wheels.get_def(e.wheel).name if Wheels.WHEELS.has(e.wheel) else e.wheel
		var mode: String = ["", "", " (Act II)", " (endless)"][clampi(int(e.get("acts", 1)), 0, 3)]
		if e.get("challenge", "") != "":
			mode = " - " + Content.CHALLENGES[e.challenge].name
		elif e.get("weekly", "") != "":
			mode = " - weekly"
		var txt := "%s  %s%s  -  %d night%s, Take %d" % ["WON " if e.won else "LOST", wname, mode, e.nights, "" if e.nights == 1 else "s", e.take]
		var b = P.button(list, txt, func(): pass, Vector2(list_w - 12, 18), P.FONT_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.accent = P.GOOD if e.won else P.LINE.darkened(0.4)
		b.mouse_entered.connect(func():
			var lines := ["%s on the %s%s." % ["Won" if e.won else "Lost", wname, mode],
				"Nights cleared: %d.  Total Take: %d.  Best spin: +%d." % [e.nights, e.take, e.get("best_spin", 0)]]
			if e.get("kit", []).size() > 0:
				lines.append("Key chips: " + ", ".join(e.kit) + ".")
			if e.get("seed", 0) != 0:
				lines.append("Seed %d: type it on the wheel screen to play this run again." % e.seed)
			_show("RUN", "\n".join(lines)))
	var weekly: Array = prof.weekly_runs
	if not weekly.is_empty():
		_header("THIS WEEK'S CHALLENGE", "%d run%s" % [weekly.size(), "" if weekly.size() == 1 else "s"], 1.0, P.CYAN)
		for r in weekly:
			var b := P.button(list, "%s  %d nights, Take %d   %s" % ["WON " if r.won else "LOST", r.nights, r.take, r.code], func():
				DisplayServer.clipboard_set(r.code)
				_show("SHARE CODE COPIED", "%s\n\nPaste it to a friend; they can compare it in Weekly mode on the wheel screen." % r.code), Vector2(list_w - 12, 18), P.FONT_SMALL)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_lbl.text = "RUNS  %d runs played  -  %d won  -  best night %d  -  best Take %d" % [prof.runs, prof.wins, prof.best_night, prof.best_take]
	_show("YOUR RUNS", "Your last 10 runs, newest first. Hover one for its details and seed. Weekly results can be clicked to copy their share code.")


func _play(lines: Array) -> void:
	if lines.is_empty():
		return
	Sfx.play("click")
	main.say(lines)
