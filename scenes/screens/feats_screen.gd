extends Control
## Feats: one-off achievements that pay Markers. Earned ones glow; the rest show what to do.
## The Almanac tab lists every chip, felt upgrade, House Rule and Dealer perk you've come across.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Feats := preload("res://core/feats.gd")
const Content := preload("res://core/content.gd")

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
		tab = "almanac" if tab == "feats" else "feats"
		Sfx.play("click")
		refresh(), Vector2(140, 22))
	P.place(tab_btn, Vector2(484, 326))


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	tab_btn.text = "ALMANAC >" if tab == "feats" else "< FEATS"
	head.text = "FEATS" if tab == "feats" else "ALMANAC"
	if tab == "almanac":
		_almanac()
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
	for group in [["CHIPS", Content.CHIPS], ["FELT UPGRADES", Content.UPGRADES], ["HOUSE RULES", Content.HOUSE_RULES],
			["FAVOURS", Content.FAVOURS], ["VOUCHERS", Content.VOUCHERS]]:
		P.label(list, group[0], P.FONT, P.GOLD)
		var table: Dictionary = group[1]
		for id in table:
			total += 1
			var known: bool = id in prof.seen_items
			var used: bool = id in prof.used_items
			if known:
				seen += 1
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
			var d := P.label(row, table[id].desc if known else "Not seen in the Cage yet.", P.FONT_SMALL, P.CREAM if known else P.DIM)
			d.clip_text = true
			P.place(d, Vector2(170, 5), Vector2(360, 12))
			var tag := P.label(row, "BOUGHT" if used else ("SEEN" if known else ""), P.FONT_SMALL, P.GOOD if used else P.DIM)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			P.place(tag, Vector2(530, 5), Vector2(60, 12))
	count_lbl.text = "Almanac: %d / %d seen    Feats earned: %d / %d" % [seen, total, prof.feats.size(), Feats.FEATS.size()]
