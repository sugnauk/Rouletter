extends Control
## Run summary: what the night paid toward the marker, Markers earned, then any story beats.

const P := preload("res://scenes/ui/palette.gd")
const Story := preload("res://core/story.gd")
const Content := preload("res://core/content.gd")

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
	title_lbl.text = "PAID IN FULL" if won else "THE HOUSE COLLECTS"
	title_lbl.add_theme_color_override("font_color", P.GOLD if won else P.DANGER)
	msg_lbl.text = main.run.message
	stats_lbl.text = "\n".join(["Wheel", "Nights cleared", "Total Take", "Paid on marker", "Markers earned", "Still owed"])
	values_lbl.text = "\n".join([
		main.run.felt.board.def.name,
		"%d / %d" % [s.get("nights", 0), Content.NIGHTS],
		str(int(s.get("take", 0.0))),
		"$" + P.money(s.get("paid", 0)),
		"%d   (now %d)" % [s.get("markers", 0), main.profile.markers],
		"$" + P.money(main.profile.debt),
	])


func _continue() -> void:
	var beats: Array = Story.beats_due(main.profile)
	var lines := []
	for b in beats:
		lines.append_array(b.lines)
		main.profile.seen_beats.append(b.id)
	main.save_profile()
	main.say(lines, func(): main.show_screen("title"))
