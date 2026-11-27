extends Control
## The Pawn Shop: where Markers are earned and spent, in one place.
##   - the top bar: your Markers, progress to the next unlock you can buy, and the Feats that
##     would get you there
##   - UNLOCKS: the tree (lanes of unlocks, cheapest at the top; each needs the one above it)
##   - GOALS: every Feat, grouped, with what each pays and which unlock it would bring in reach

const P := preload("res://scenes/ui/palette.gd")
const InfoCard := preload("res://scenes/ui/info_card.gd")
const Art := preload("res://scenes/ui/art.gd")
const Profile := preload("res://core/profile.gd")
const Feats := preload("res://core/feats.gd")
const Token := preload("res://scenes/ui/token_button.gd")

const LANE_W := 86.0
const ROW_H := 44.0
const TOP := 70.0
const NODE := Vector2(30, 30)
var portrait := false
var lane_w := LANE_W
var row_h := ROW_H
var top := TOP
var sub_lbl: Label
var panel: Panel
var back_btn
## Icons for unlocks that aren't items (wheels, the feature, vendors, kits).
const ICON_FOR := {"call_bets": "call_bets", "fence": "hot", "banker_kit": "cash", "collector_kit": "perm",
	"high_roller_kit": "kingmaker"}

var main
var tab := "unlocks"
var tab_btns := {}
var bar_view: Control
var detail: Label
var unlocks_view: Control
var lines_view: Control
var nodes: Control
var goals_scroll: ScrollContainer
var goals_list: VBoxContainer
var catalogue := {}


func setup() -> void:
	P.place(P.label(self, "PAWN SHOP", P.FONT_BIG, P.GOLD), Vector2(16, 6))
	sub_lbl = P.label(self, "Markers buy what the house won't sell.", P.FONT_SMALL, P.DIM)
	P.place(sub_lbl, Vector2(176, 12))
	for t in [["unlocks", "UNLOCKS"], ["goals", "GOALS"]]:
		var b := P.button(self, t[1], func():
			tab = t[0]
			Sfx.play("click")
			refresh(), Vector2(86, 16), P.FONT_SMALL)
		P.place(b, Vector2(448 + (0 if t[0] == "unlocks" else 92), 6))
		tab_btns[t[0]] = b
	bar_view = Control.new()
	bar_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(bar_view, Vector2(16, 28), Vector2(608, 22))
	bar_view.draw.connect(_draw_bar)
	add_child(bar_view)
	# UNLOCKS: the tree.
	unlocks_view = Control.new()
	unlocks_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(unlocks_view, Vector2.ZERO, Vector2(640, 296))
	add_child(unlocks_view)
	lines_view = Control.new()
	lines_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(lines_view, Vector2.ZERO, Vector2(640, 296))
	lines_view.draw.connect(_draw_lines)
	unlocks_view.add_child(lines_view)
	nodes = Control.new()
	nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(nodes, Vector2.ZERO, Vector2(640, 296))
	unlocks_view.add_child(nodes)
	# GOALS: the Feats, grouped.
	goals_scroll = ScrollContainer.new()
	P.place(goals_scroll, Vector2(16, 56), Vector2(608, 236))
	goals_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(goals_scroll)
	goals_list = VBoxContainer.new()
	goals_list.custom_minimum_size = Vector2(596, 0)
	goals_list.add_theme_constant_override("separation", 2)
	goals_scroll.add_child(goals_list)
	panel = Panel.new()
	P.place(panel, Vector2(104, 296), Vector2(520, 56))
	add_child(panel)
	detail = P.label(panel, "", P.FONT_SMALL, P.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail, Vector2(6, 4), Vector2(508, 48))
	back_btn = P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 22))
	P.place(back_btn, Vector2(16, 326))


## Portrait: narrower lanes with more room between rows, the Feats list two lines a row, and
## the detail panel above Back.
func relayout(tall: bool) -> void:
	portrait = tall
	var lanes: int = Profile.tree().size()
	lane_w = minf(LANE_W, floor((P.W - 8.0) / maxf(1.0, lanes))) if tall else LANE_W
	row_h = 58.0 if tall else ROW_H
	top = 100.0 if tall else TOP
	for i in range(2):
		var b = tab_btns.values()[i]
		P.place(b, Vector2((176 if tall else 448) + i * 92, 6))
	P.place(sub_lbl, Vector2(16, 26) if tall else Vector2(176, 12))
	P.place(bar_view, Vector2(16, 40) if tall else Vector2(16, 28), Vector2(328, 36) if tall else Vector2(608, 22))
	for v in [unlocks_view, lines_view, nodes]:
		P.place(v, Vector2.ZERO, Vector2(P.W, 520 if tall else 296))
	P.place(goals_scroll, Vector2(16, 82) if tall else Vector2(16, 56), Vector2(328, 436) if tall else Vector2(608, 236))
	goals_list.custom_minimum_size.x = 316 if tall else 596
	P.place(panel, Vector2(16, 524) if tall else Vector2(104, 296), Vector2(328, 80) if tall else Vector2(520, 56))
	P.place(detail, Vector2(6, 4), Vector2(316, 72) if tall else Vector2(508, 48))
	P.place(back_btn, Vector2(16, 612) if tall else Vector2(16, 326))
	if main != null and visible:
		refresh()


func _lane_x(i: int, n: int) -> float:
	var total: float = n * lane_w
	return (P.W - total) / 2.0 + i * lane_w + lane_w / 2.0


func _node_pos(lane: int, row: int, n: int) -> Vector2:
	return Vector2(_lane_x(lane, n), top + 14 + row * row_h)


## Feats not yet earned whose Markers would cover `need`, easiest first.
func _feats_for(need: int) -> Array:
	var out := []
	var sum := 0
	for id in Feats.FEATS:
		if id in main.profile.feats:
			continue
		out.append(id)
		sum += Feats.FEATS[id].reward
		if sum >= need or out.size() >= 3:
			break
	return out


func _feat_list(ids: Array) -> String:
	return ", ".join(ids.map(func(id): return "%s (+%d)" % [Feats.FEATS[id].name, Feats.FEATS[id].reward]))


func refresh() -> void:
	catalogue = {}
	for e in Profile.catalogue():
		catalogue[e.id] = e
	for k in tab_btns:
		tab_btns[k].accent = P.GOLD if k == tab else P.LINE.darkened(0.4)
		tab_btns[k].pulse = k == tab
	unlocks_view.visible = tab == "unlocks"
	goals_scroll.visible = tab == "goals"
	if tab == "unlocks":
		_refresh_unlocks()
		detail.text = "Hover an unlock. Each one needs the one above it in its lane. Short of Markers? The GOALS tab shows how to earn them."
	else:
		_refresh_goals()
		detail.text = "Feats pay Markers the first time you pull them off. A gold arrow marks a Feat that would bring an unlock within reach."
	bar_view.queue_redraw()


## Markers, progress to the next unlock, and the Feats that would pay for it.
func _draw_bar() -> void:
	if main == null:
		return
	var c := bar_view
	var prof = main.profile
	var r := Rect2(Vector2.ZERO, bar_view.size)
	c.draw_rect(r, Color("#0e1a12"))
	c.draw_rect(r, P.LINE.darkened(0.4), false, 1.0)
	Art.icon(c, "cash", Vector2(12, 11), 1)
	Art.text(c, P.font(), Vector2(24, 15), "MARKERS  %d" % prof.markers, 8, P.GOLD)
	var nu: Dictionary = prof.next_unlock()
	var k := 1.0
	var line := "Everything here is yours."
	if not nu.is_empty():
		k = clampf(float(prof.markers) / nu.cost, 0.0, 1.0)
		if prof.markers >= nu.cost:
			line = "%s is ready to buy (%d M)!" % [nu.name, nu.cost]
		else:
			var need: int = nu.cost - prof.markers
			line = "Next: %s. Earn %d more: %s" % [nu.name, need, _feat_list(_feats_for(need))]
	var bar := Rect2(110, 8, 90, 6)
	c.draw_rect(bar, Color("#05100a"))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), P.GOLD.lerp(P.GOOD, k))
	c.draw_rect(bar, P.LINE.darkened(0.5), false, 1.0)
	var room: int = 50 if portrait else 72
	var shown := line if line.length() <= room else line.substr(0, room - 2) + ".."
	c.draw_string(P.font(), Vector2(8, 30) if portrait else Vector2(210, 15), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, P.CREAM)


func _refresh_unlocks() -> void:
	var prof = main.profile
	for c in nodes.get_children():
		c.queue_free()
	var lanes := Profile.tree()
	for li in range(lanes.size()):
		var lane: Dictionary = lanes[li]
		var head := P.label(nodes, lane.title, P.FONT_SMALL, P.DIM)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		P.place(head, Vector2(_lane_x(li, lanes.size()) - lane_w / 2.0, top - 12), Vector2(lane_w, 10))
		head.clip_text = true
		for ri in range(lane.ids.size()):
			var id: String = lane.ids[ri]
			var e: Dictionary = catalogue[id]
			var owned: bool = prof.is_unlocked(id)
			var open: bool = prof.can_unlock(id)
			var tok = Token.new(ICON_FOR.get(id, "spin" if e.category == "wheel" else id), NODE)
			tok.selected = owned
			tok.dim = not owned and not open
			tok.badge = "" if owned else "%dM" % e.cost
			var at: Vector2 = _node_pos(li, ri, lanes.size()) - NODE / 2.0
			P.place(tok, at)
			nodes.add_child(tok)
			var max_chars: int = 13 if lane_w >= 80.0 else 7
			var nm := P.label(nodes, e.name if e.name.length() <= max_chars else e.name.substr(0, max_chars - 1) + ".", P.FONT_SMALL, P.CREAM if owned else (P.GOLD if open else P.DIM))
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			P.place(nm, Vector2(at.x + NODE.x / 2.0 - lane_w / 2.0, at.y + NODE.y + 1), Vector2(lane_w, 9))
			tok.hover_target = func(_s):
				var req := Profile.requires(id)
				var state := "OWNED" if owned else ("%d Markers" % e.cost if open else "Needs %s first" % catalogue[req].name)
				var txt := "%s  [%s]  -  %s\n%s" % [e.name, e.category.to_upper(), state, e.desc]
				if not owned and prof.markers < e.cost:
					txt += "\nEarn %d more Markers: %s" % [e.cost - prof.markers, _feat_list(_feats_for(e.cost - prof.markers))]
				detail.text = txt
				var cd: Dictionary = InfoCard.for_id(id, state.to_upper())
				if not cd.is_empty():
					main.card_near(tok, cd)
			tok.hover_exit = main.hide_card
			tok.pressed.connect(_buy.bind(id))
	lines_view.queue_redraw()


func _refresh_goals() -> void:
	var prof = main.profile
	for c in goals_list.get_children():
		c.queue_free()
	var nu: Dictionary = prof.next_unlock()
	var need: int = maxi(0, nu.cost - prof.markers) if not nu.is_empty() else 0
	for g in Feats.GROUPS:
		var ids: Array = Feats.FEATS.keys().filter(func(id): return Feats.group_of(id) == g)
		if ids.is_empty():
			continue
		var got: int = ids.filter(func(id): return id in prof.feats).size()
		var pays := 0
		for id in ids:
			if not id in prof.feats:
				pays += Feats.FEATS[id].reward
		# Group header: name, progress bar, Markers still on offer.
		var head := Control.new()
		var gw: float = 316.0 if portrait else 596.0
		head.custom_minimum_size = Vector2(gw, 18)
		goals_list.add_child(head)
		P.place(P.label(head, g.to_upper(), P.FONT, P.GOLD if got == ids.size() else P.CREAM), Vector2(0, 5))
		P.place(P.label(head, "%d / %d" % [got, ids.size()], P.FONT_SMALL, P.GOOD if got == ids.size() else P.DIM), Vector2(110, 6))
		var bar := Control.new()
		var bw: float = 60.0 if portrait else 200.0
		P.place(bar, Vector2(160, 9), Vector2(bw, 5))
		var k: float = float(got) / ids.size()
		bar.draw.connect(func():
			bar.draw_rect(Rect2(0, 0, bw, 5), P.BLACK)
			bar.draw_rect(Rect2(0, 0, floor(bw * k), 5), P.GOLD if k >= 1.0 else P.GOOD.darkened(0.2)))
		head.add_child(bar)
		var left := P.label(head, ("%d Markers left to earn" % pays) if pays > 0 else "ALL EARNED", P.FONT_SMALL, P.GOLD if pays > 0 else P.GOOD)
		left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		P.place(left, Vector2(gw - 106, 6) if portrait else Vector2(400, 6), Vector2(106, 10) if portrait else Vector2(190, 10))
		left.clip_text = true
		for id in ids:
			var f: Dictionary = Feats.FEATS[id]
			var earned: bool = id in prof.feats
			var row := Panel.new()
			row.custom_minimum_size = Vector2(gw, 30 if portrait else 20)
			row.add_theme_stylebox_override("panel", P.box(P.PANEL_HI if earned else P.PANEL, P.GOLD if earned else P.LINE.darkened(0.6), 1))
			goals_list.add_child(row)
			var mark := Control.new()
			P.place(mark, Vector2(4, 2), Vector2(16, 16))
			mark.draw.connect(func():
				if earned:
					Art.chip(mark, Vector2(8, 8), 6.0, P.GOLD)
				else:
					mark.draw_circle(Vector2(8, 8), 6.0, P.DIM.darkened(0.5), false, 1.0, false))
			row.add_child(mark)
			P.place(P.label(row, f.name.to_upper(), P.FONT_SMALL, P.GOLD if earned else P.CREAM), Vector2(24, 5))
			var d := P.label(row, f.desc, P.FONT_SMALL, P.CREAM if earned else P.DIM)
			d.clip_text = true
			P.place(d, Vector2(24, 17) if portrait else Vector2(176, 5), Vector2(gw - 30, 10) if portrait else Vector2(300, 10))
			var tag := ""
			var tag_col: Color = P.DIM
			if earned:
				tag = "EARNED"
				tag_col = P.GOOD
			elif need > 0 and f.reward >= need:
				tag = "> %s" % nu.name.to_upper()
				tag_col = P.GOLD
			var tl := P.label(row, tag, P.FONT_SMALL, tag_col)
			tl.clip_text = true
			P.place(tl, Vector2(gw - 126, 4) if portrait else Vector2(480, 5), Vector2(80, 10))
			var rw := P.label(row, "+%dM" % f.reward, P.FONT_SMALL, P.GOOD if earned else P.GOLD)
			rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			P.place(rw, Vector2(gw - 44, 4) if portrait else Vector2(552, 5), Vector2(38, 10))
			row.mouse_entered.connect(func():
				detail.text = "%s  (+%d Markers)%s\n%s" % [f.name, f.reward, "  -  earned" if earned else "", f.desc])


func _draw_lines() -> void:
	if main == null:
		return
	var lanes := Profile.tree()
	for li in range(lanes.size()):
		var ids: Array = lanes[li].ids
		for ri in range(1, ids.size()):
			var a := _node_pos(li, ri - 1, lanes.size()) + Vector2(0, NODE.y / 2.0 + 10)
			var b := _node_pos(li, ri, lanes.size()) - Vector2(0, NODE.y / 2.0)
			var lit: bool = main.profile.is_unlocked(ids[ri - 1])
			lines_view.draw_line(a, b, P.GOLD if lit else P.LINE.darkened(0.4), 1.0)


func _buy(id: String) -> void:
	var prof = main.profile
	if prof.buy_unlock(id):
		main.save_profile()
		Sfx.play("unlock")
		main.fx.stamp("UNLOCKED", P.GOLD, 1.0)
		main.fx.burst(main.fx.get_local_mouse_position(), 30, [P.GOLD, P.CREAM, P.GOOD], 150.0)
		refresh()
	elif prof.is_unlocked(id):
		detail.text = "Already yours."
	elif not prof.can_unlock(id):
		detail.text = "Unlock %s first: it's the one above this in the lane." % catalogue[Profile.requires(id)].name
	else:
		var need: int = catalogue[id].cost - prof.markers
		detail.text = "Not enough Markers yet: %d more. %s" % [need, _feat_list(_feats_for(need))]
		Sfx.play("click")
