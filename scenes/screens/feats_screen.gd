extends Control
## Feats: one-off achievements that pay Markers. Earned ones glow; the rest show what to do.
## The Almanac tab lists every chip, felt upgrade, House Rule and Dealer perk you've come across.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Feats := preload("res://core/feats.gd")
const Content := preload("res://core/content.gd")
const Wheels := preload("res://core/wheels.gd")

var main
var count_lbl: Label
var list: VBoxContainer
var tab := "feats"
var tab_btn: Button
var head: Label


func setup() -> void:
	head = P.label(self, "FEATS", P.FONT_BIG, P.GOLD)
	P.place(head, Vector2(16, 8))
	count_lbl = P.label(self, "", P.FONT, P.CREAM)
	P.place(count_lbl, Vector2(16, 30))
	var scroll := ScrollContainer.new()
	P.place(scroll, Vector2(16, 50), Vector2(608, 268))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(596, 0)
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	P.place(P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 22)), Vector2(16, 326))
	tab_btn = P.button(self, "", func():
		tab = {"feats": "almanac", "almanac": "history", "history": "feats"}[tab]
		Sfx.play("click")
		refresh(), Vector2(140, 22))
	P.place(tab_btn, Vector2(484, 326))


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	tab_btn.text = {"feats": "ALMANAC >", "almanac": "HISTORY >", "history": "FEATS >"}[tab]
	head.text = tab.to_upper()
	if tab == "almanac":
		_almanac()
		return
	if tab == "history":
		_history()
		return
	var earned: Array = main.profile.feats
	var n := 0
	var m := 0
	for id in Feats.FEATS:
		var f: Dictionary = Feats.FEATS[id]
		var got: bool = id in earned
		if got:
			n += 1
			m += f.reward
		var row := Panel.new()
		row.custom_minimum_size = Vector2(596, 22)
		row.add_theme_stylebox_override("panel", P.box(P.PANEL_HI if got else P.PANEL, P.GOLD if got else P.LINE.darkened(0.6), 1))
		list.add_child(row)
		var mark := Control.new()
		P.place(mark, Vector2(4, 3), Vector2(16, 16))
		mark.draw.connect(func():
			if got:
				Art.chip(mark, Vector2(8, 8), 6.0, P.GOLD)
			else:
				mark.draw_circle(Vector2(8, 8), 6.0, P.DIM.darkened(0.5), false, 1.0, false))
		row.add_child(mark)
		P.place(P.label(row, f.name.to_upper(), P.FONT, P.GOLD if got else P.CREAM), Vector2(26, 5))
		P.place(P.label(row, f.desc, P.FONT_SMALL, P.CREAM if got else P.DIM), Vector2(170, 5), Vector2(360, 12))
		var r := P.label(row, "+%d M" % f.reward, P.FONT_SMALL, P.GOOD if got else P.DIM)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		P.place(r, Vector2(530, 5), Vector2(60, 12))
	count_lbl.text = "Earned %d / %d    Markers from Feats: %d" % [n, Feats.FEATS.size(), m]


func _almanac() -> void:
	var prof = main.profile
	var seen := 0
	var total := 0
	var summary := []
	for group in Content.ALMANAC:
		var table: Dictionary = Content.almanac_table(group[1])
		var ids: Array = group[2]
		var found: int = ids.filter(func(i): return i in prof.seen_items).size()
		var bought: int = ids.filter(func(i): return i in prof.used_items).size()
		seen += found
		total += ids.size()
		# Category header: "MODIFIER CHIPS   2 / 3 found   1 bought" with a little progress bar.
		var head_row := Control.new()
		head_row.custom_minimum_size = Vector2(596, 18)
		list.add_child(head_row)
		P.place(P.label(head_row, group[0], P.FONT, P.GOLD if found == ids.size() else P.CREAM), Vector2(0, 4))
		var cnt := P.label(head_row, "%d / %d found   %d bought" % [found, ids.size(), bought], P.FONT_SMALL, P.GOOD if found == ids.size() else P.DIM)
		P.place(cnt, Vector2(200, 5))
		var bar := Control.new()
		P.place(bar, Vector2(420, 8), Vector2(170, 5))
		var k: float = float(found) / ids.size()
		bar.draw.connect(func():
			bar.draw_rect(Rect2(0, 0, 170, 5), P.BLACK)
			bar.draw_rect(Rect2(0, 0, floor(170 * k), 5), P.GOLD if k >= 1.0 else P.GOOD.darkened(0.2)))
		head_row.add_child(bar)
		summary.append("%d/%d" % [found, ids.size()])
		for id in ids:
			var known: bool = id in prof.seen_items
			var used: bool = id in prof.used_items
			var locked: bool = not prof.is_unlocked(id) and table[id].get("unlock", 0) > 0
			var row := Panel.new()
			row.custom_minimum_size = Vector2(596, 22)
			row.add_theme_stylebox_override("panel", P.box(P.PANEL_HI if used else P.PANEL, P.LINE.darkened(0.3 if known else 0.6), 1))
			list.add_child(row)
			var icon := Control.new()
			P.place(icon, Vector2(4, 3), Vector2(16, 16))
			var icon_id: String = table[id].get("icon", id)
			icon.draw.connect(func():
				if known:
					Art.icon(icon, icon_id, Vector2(8, 8), 1)
				else:
					icon.draw_rect(Rect2(2, 2, 12, 12), P.DIM.darkened(0.5), false, 1.0))
			row.add_child(icon)
			P.place(P.label(row, table[id].name.to_upper() if known else "? ? ?", P.FONT, P.CREAM if known else P.DIM), Vector2(26, 5))
			var hint := "Not seen in the Cage yet."
			if locked and not known:
				hint = "Locked: %d Markers at the Pawn Shop." % table[id].unlock
			var d := P.label(row, table[id].desc if known else hint, P.FONT_SMALL, P.CREAM if known else P.DIM)
			d.clip_text = true
			P.place(d, Vector2(170, 5), Vector2(360, 12))
			var rar: String = Content.rarity_of(id)
			var tag := P.label(row, "BOUGHT" if used else ("SEEN" if known else ("" if rar == "common" else rar.to_upper())), P.FONT_SMALL,
				P.GOOD if used else (P.DIM if known else (P.CYAN if rar == "rare" else P.GOLD)))
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			P.place(tag, Vector2(530, 5), Vector2(60, 12))
	count_lbl.text = "Almanac: %d / %d found    Feats earned: %d / %d" % [seen, total, prof.feats.size(), Feats.FEATS.size()]


func _history() -> void:
	var h: Array = main.profile.history
	if h.is_empty():
		P.label(list, "No runs yet. Your last 10 runs will be listed here.", P.FONT, P.DIM)
	for e in h:
		var row := Panel.new()
		row.custom_minimum_size = Vector2(596, 22)
		row.add_theme_stylebox_override("panel", P.box(P.PANEL_HI if e.won else P.PANEL, P.GOLD if e.won else P.LINE.darkened(0.6), 1))
		list.add_child(row)
		P.place(P.label(row, "WON" if e.won else "LOST", P.FONT, P.GOOD if e.won else P.DANGER), Vector2(8, 5))
		var wname: String = Wheels.get_def(e.wheel).name if Wheels.WHEELS.has(e.wheel) else e.wheel
		var mode: String = ["", "", "  (Act II)", "  (endless)"][clampi(int(e.acts), 0, 3)]
		P.place(P.label(row, wname + mode, P.FONT, P.CREAM), Vector2(60, 5))
		P.place(P.label(row, "%d night%s   Take %d   best spin +%d" % [e.nights, "" if e.nights == 1 else "s", e.take, e.best_spin], P.FONT_SMALL, P.DIM), Vector2(300, 6))
	var wins := h.filter(func(e): return e.won).size()
	count_lbl.text = "Last %d runs: %d won" % [h.size(), wins]
