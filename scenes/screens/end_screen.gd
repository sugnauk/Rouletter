extends Control
## Run summary: how much of the run's marker was paid, Markers earned, then any story beats.

const P := preload("res://scenes/ui/palette.gd")
const Story := preload("res://core/story.gd")
const Content := preload("res://core/content.gd")
const Feats := preload("res://core/feats.gd")
const FeltView := preload("res://scenes/ui/felt_view.gd")
const Art := preload("res://scenes/ui/art.gd")

var main
var title_lbl: Label
var msg_lbl: Label
var stats_lbl: Label
var values_lbl: Label
var build_panel: Panel
var felt_view
var build_lbl: Label
var build_canvas: Control
var share_lbl: Label
var show_money := false
var tab_btn: Button


var btns := []   ## Continue, Save image, Copy report


func setup() -> void:
	title_lbl = P.label(self, "", P.FONT_HUGE, P.GOLD)
	P.place(title_lbl, Vector2(40, 50))
	msg_lbl = P.label(self, "", P.FONT, P.CREAM)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(msg_lbl, Vector2(42, 96), Vector2(556, 30))
	stats_lbl = P.label(self, "", P.FONT, P.DIM)
	P.place(stats_lbl, Vector2(42, 136))
	values_lbl = P.label(self, "", P.FONT, P.CREAM)
	P.place(values_lbl, Vector2(160, 136))
	btns.append(P.button(self, "Continue", _continue, Vector2(120, 24)))
	btns.append(P.button(self, "Save image", _save_image, Vector2(100, 24)))
	# Playtesting: the whole run as text, ready to paste to the developer.
	btns.append(P.button(self, "Copy report", func():
		DisplayServer.clipboard_set(main.run.run_report())
		share_lbl.text = "Run report copied: paste it with your playtest notes."
		Sfx.play("click"), Vector2(100, 24)))
	for i in range(3):
		P.place(btns[i], Vector2([42, 170, 278][i], 300))
	share_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	share_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(share_lbl, Vector2(42, 330), Vector2(330, 24))
	# Your build: the felt you finished with, your top chips and the best spin's breakdown.
	build_panel = Panel.new()
	build_panel.add_theme_stylebox_override("panel", P.box(Color("#120c08"), P.LINE, 1))
	P.place(build_panel, Vector2(392, 128), Vector2(240, 214))
	add_child(build_panel)
	var bt := P.label(build_panel, "YOUR BUILD", P.FONT_SMALL, P.GOLD)
	P.place(bt, Vector2(6, 4))
	tab_btn = P.button(build_panel, "MONEY >", func():
		show_money = not show_money
		bt.text = "WHERE THE MONEY CAME FROM" if show_money else "YOUR BUILD"
		tab_btn.text = "< BUILD" if show_money else "MONEY >"
		felt_view.visible = not show_money
		build_canvas.position.y = 16 if show_money else 96
		build_canvas.queue_redraw()
		Sfx.play("click"), Vector2(56, 12), P.FONT_SMALL)
	P.place(tab_btn, Vector2(180, 2))
	felt_view = FeltView.new()
	felt_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt_view.scale = Vector2(0.68, 0.68)
	P.place(felt_view, Vector2(6, 16))
	build_panel.add_child(felt_view)
	build_canvas = Control.new()
	build_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(build_canvas, Vector2(6, 96), Vector2(228, 112))
	build_canvas.draw.connect(_draw_build)
	build_panel.add_child(build_canvas)


## Portrait: the verdict and stats on top, your build under them, the buttons at the bottom.
func relayout(tall: bool) -> void:
	title_lbl.add_theme_font_size_override("font_size", P.FONT_BIG if tall else P.FONT_HUGE)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if tall else TextServer.AUTOWRAP_OFF
	if tall:
		P.place(title_lbl, Vector2(16, 24), Vector2(328, 40))
		P.place(msg_lbl, Vector2(16, 70), Vector2(328, 44))
		P.place(stats_lbl, Vector2(16, 120))
		P.place(values_lbl, Vector2(134, 120))
		P.place(build_panel, Vector2(60, 330))
		for i in range(3):
			P.place(btns[i], Vector2([16, 142, 250][i], 556))
		P.place(share_lbl, Vector2(16, 588), Vector2(328, 40))
	else:
		P.place(title_lbl, Vector2(40, 50), Vector2(560, 30))
		P.place(msg_lbl, Vector2(42, 96), Vector2(556, 30))
		P.place(stats_lbl, Vector2(42, 136))
		P.place(values_lbl, Vector2(160, 136))
		P.place(build_panel, Vector2(392, 128))
		for i in range(3):
			P.place(btns[i], Vector2([42, 170, 278][i], 300))
		P.place(share_lbl, Vector2(42, 330), Vector2(330, 24))


func refresh() -> void:
	var s: Dictionary = main.last_summary
	var won: bool = s.get("won", false)
	title_lbl.text = ("THE OWNER FALLS" if main.run.acts == 2 else "PAID IN FULL") if won else "THE HOUSE COLLECTS"
	title_lbl.add_theme_color_override("font_color", P.GOLD if won else P.DANGER)
	msg_lbl.text = main.run.message
	# A clean read of a missed payment: how far short, and what was on the felt.
	var ll: Dictionary = main.last_layout
	if not won and not ll.is_empty():
		var bets := []
		for b in ll.layout:
			bets.append("%s x%d" % [_bet_label(b[0]), b[1]])
		msg_lbl.text += "  Short by %d Take (%d of %d).  Your layout: %s." % [ll.short, ll.take, ll.target, ", ".join(bets) if not bets.is_empty() else "no bets"]
	felt_view.run = main.run
	felt_view.layout()
	felt_view.queue_redraw()
	build_canvas.queue_redraw()
	show_money = false
	tab_btn.text = "MONEY >"
	felt_view.visible = true
	build_canvas.position.y = 96
	share_lbl.text = "Seed %d%s" % [main.run.run_seed, ("  -  " + Content.CHALLENGES[main.run.challenge].name) if main.run.challenge != "" else ("  -  weekly " + main.run.weekly if main.run.weekly != "" else "")]
	if main.run.weekly != "" and main.last_share_code != "":
		share_lbl.text = "Weekly code (copied): %s" % main.last_share_code
	stats_lbl.text = "\n".join(["Wheel", "Nights cleared", "Total Take", "Best spin", "Marker paid", "Left unpaid", "Enforcers beaten", "Markers earned", "Feats", "Next unlock"])
	values_lbl.text = "\n".join([
		main.run.felt.board.def.name,
		("%d (endless)" % s.get("nights", 0)) if main.run.endless() else "%d / %d" % [s.get("nights", 0), main.run.nights_total()],
		str(int(s.get("take", 0.0))),
		"+%d" % int(s.get("best_spin", 0.0)),
		"$%s of $%s" % [P.money(s.get("paid", 0)), P.money(s.get("marker", 0))],
		"$" + P.money(maxi(0, s.get("marker", 0) - s.get("paid", 0))),
		_names(s.get("beaten", []), func(e): return Content.ENFORCERS[e].name),
		"%d   (now %d)" % [s.get("markers", 0) + _feat_markers(s.get("feats", [])), main.profile.markers],
		_names(s.get("feats", []), func(f): return Feats.FEATS[f].name),
		_next_unlock(),
	])


func _draw_build() -> void:
	var c := build_canvas
	var run = main.run
	var font := P.font()
	if show_money:
		var src: Array = run.cash_sources()
		var total := 0
		for x in src:
			total += x[1]
		Art.text(c, font, Vector2(0, 8), "EARNED $%d IN ALL" % total, 8, P.DIM)
		var top: float = maxf(1.0, src[0][1]) if not src.is_empty() else 1.0
		for i in range(mini(src.size(), 12)):
			var y := 14 + i * 14
			Art.text(c, font, Vector2(0, y + 9), src[i][0], 8, P.CREAM)
			c.draw_rect(Rect2(110, y + 3, 70.0 * src[i][1] / top, 5), P.GOOD.darkened(0.2))
			Art.text(c, font, Vector2(186, y + 9), "$%d" % src[i][1], 8, P.GOOD)
		return
	Art.text(c, font, Vector2(0, 8), "TOP CHIPS", 8, P.DIM)
	var top: Array = run.top_contributors(3)
	if top.is_empty():
		Art.text(c, font, Vector2(0, 20), "no chips scored", 8, P.DIM)
	var most: float = maxf(1.0, top[0][1]) if not top.is_empty() else 1.0
	for i in range(top.size()):
		var y := 14 + i * 14
		Art.icon(c, top[i][0], Vector2(6, y + 5), 1)
		Art.text(c, font, Vector2(16, y + 9), Content.CHIPS[top[i][0]].name, 8, P.CREAM)
		var w: float = 50.0 * top[i][1] / most
		c.draw_rect(Rect2(76, y + 3, w, 5), P.GOLD.darkened(0.2))
		Art.text(c, font, Vector2(130, y + 9), "+%d" % top[i][1], 8, P.GOLD)
	var b: Dictionary = run.best_spin_info
	Art.text(c, font, Vector2(0, 62), "BEST SPIN" + ("  +%d on %s" % [b.take, b.pocket] if not b.is_empty() else ""), 8, P.DIM)
	if not b.is_empty():
		var parts: Array = b.parts
		for i in range(mini(parts.size(), 6)):
			var x := (i % 2) * 114
			var y := 72 + (i / 2) * 12
			Art.text(c, font, Vector2(x, y + 8), parts[i][0], 8, P.CREAM)
			Art.text(c, font, Vector2(x + 104, y + 8), parts[i][1], 8, P.VIOLET if parts[i][1].begins_with("x") else P.GOLD)
			if x == 0:
				pass


## Save a picture of this summary to share: a download on the web, a PNG in the user folder elsewhere.
func _save_image() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var fname := "rouletter_run_%s.png" % stamp
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), fname, "image/png")
		share_lbl.text = "Saved %s (check your downloads)." % fname
	else:
		var path := "user://" + fname
		if img.save_png(path) == OK:
			share_lbl.text = "Saved to %s" % ProjectSettings.globalize_path(path)
		else:
			share_lbl.text = "Couldn't save the image."
	Sfx.play("click")


func _bet_label(key: String) -> String:
	if key.begins_with("S") and not key.begins_with("SP") and not key.begins_with("ST"):
		return main.run.felt.board.label(int(key.substr(1)))
	return key


func _names(ids: Array, name_of: Callable) -> String:
	if ids.is_empty():
		return "-"
	var out := []
	for i in ids:
		out.append(name_of.call(i))
	var txt := ", ".join(out)
	return txt if txt.length() <= 34 else txt.substr(0, 31) + "..."


func _next_unlock() -> String:
	var nu: Dictionary = main.profile.next_unlock()
	if nu.is_empty():
		return "everything owned"
	var m: int = main.profile.markers
	if m >= nu.cost:
		return "%s (ready at the Pawn Shop)" % nu.name
	var bar := ""
	for i in range(nu.cost):
		bar += "#" if i < m else "-"
	return "%s  [%s] %d/%d" % [nu.name, bar, m, nu.cost]


func _feat_markers(ids: Array) -> int:
	var t := 0
	for i in ids:
		t += Feats.FEATS[i].reward
	return t


func _continue() -> void:
	var beats: Array = Story.beats_due(main.profile)
	var lines := []
	for b in beats:
		lines.append_array(b.lines)
		main.profile.seen_beats.append(b.id)
	main.save_profile()
	var act_done := beats.any(func(b): return b.id == "free")
	var act2_done := beats.any(func(b): return b.id == "act2_free")
	main.say(lines, func():
		if act2_done:
			main.go("title", "END OF ACT II", "The house is yours", P.GOLD)
		elif act_done:
			main.go("title", "END OF ACT I", "The Floor Above is waiting", P.GOLD)
		else:
			main.show_screen("title"))
