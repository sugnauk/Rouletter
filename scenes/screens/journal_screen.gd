extends Control
## Journal: every story scene you've seen, in order, ready to replay. Unseen ones stay sealed.

const P := preload("res://scenes/ui/palette.gd")
const Story := preload("res://core/story.gd")

var main
var count_lbl: Label
var list: VBoxContainer
var detail: Label


func setup() -> void:
	P.place(P.label(self, "JOURNAL", P.FONT_BIG, P.GOLD), Vector2(16, 8))
	count_lbl = P.label(self, "", P.FONT, P.CREAM)
	P.place(count_lbl, Vector2(16, 30))
	var scroll := ScrollContainer.new()
	P.place(scroll, Vector2(16, 50), Vector2(300, 268))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(288, 0)
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var panel := Panel.new()
	P.place(panel, Vector2(328, 50), Vector2(296, 268))
	add_child(panel)
	detail = P.label(panel, "Hover a page. Click to replay it.", P.FONT_SMALL, P.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail, Vector2(8, 8), Vector2(280, 250))
	P.place(P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 22)), Vector2(16, 326))


func refresh() -> void:
	var seen: Array = main.profile.seen_beats
	for c in list.get_children():
		c.queue_free()
	var scenes := Story.all_scenes()
	var n := 0
	for sc in scenes:
		var known: bool = sc.id in seen
		if known:
			n += 1
		var b := P.button(list, sc.title if known else "? ? ?", _play.bind(sc), Vector2(288, 18), P.FONT_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not known
		if known:
			b.mouse_entered.connect(func(): detail.text = "%s\n\n%s: \"%s\"" % [sc.title.to_upper(), sc.lines[0].speaker, sc.lines[0].text])
	count_lbl.text = "Pages found: %d / %d" % [n, scenes.size()]


func _play(sc: Dictionary) -> void:
	Sfx.play("click")
	main.say(sc.lines)
