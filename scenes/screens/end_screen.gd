extends Control
## Run summary: how much of the run's marker was paid, Markers earned, then any story beats.

const P := preload("res://scenes/ui/palette.gd")
const Story := preload("res://core/story.gd")
const Content := preload("res://core/content.gd")
const Feats := preload("res://core/feats.gd")

var main
var title_lbl: Label
var msg_lbl: Label
var stats_lbl: Label
var values_lbl: Label


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
	P.place(P.button(self, "Continue", _continue, Vector2(120, 24)), Vector2(42, 300))


func refresh() -> void:
	var s: Dictionary = main.last_summary
	var won: bool = s.get("won", false)
	title_lbl.text = ("THE OWNER FALLS" if main.run.acts == 2 else "PAID IN FULL") if won else "THE HOUSE COLLECTS"
	title_lbl.add_theme_color_override("font_color", P.GOLD if won else P.DANGER)
	msg_lbl.text = main.run.message
	stats_lbl.text = "\n".join(["Wheel", "Nights cleared", "Total Take", "Best spin", "Marker paid", "Left unpaid", "Enforcers beaten", "Markers earned", "Feats"])
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
	])


func _names(ids: Array, name_of: Callable) -> String:
	if ids.is_empty():
		return "-"
	var out := []
	for i in ids:
		out.append(name_of.call(i))
	var txt := ", ".join(out)
	return txt if txt.length() <= 60 else txt.substr(0, 57) + "..."


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
