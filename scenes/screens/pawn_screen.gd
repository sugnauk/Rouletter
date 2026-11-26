extends Control
## Pawn Shop: spend Markers (earned per night cleared) to unlock wheels and content for future runs.

const P := preload("res://scenes/ui/palette.gd")
const Profile := preload("res://core/profile.gd")

var main
var markers_lbl: Label
var list: VBoxContainer
var detail: Label


func setup() -> void:
	P.place(P.label(self, "PAWN SHOP  -  Fifth Street", P.FONT_BIG, P.GOLD), Vector2(16, 8))
	markers_lbl = P.label(self, "", P.FONT, P.CREAM)
	P.place(markers_lbl, Vector2(16, 30))
	var scroll := ScrollContainer.new()
	P.place(scroll, Vector2(16, 50), Vector2(380, 268))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(368, 0)
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var panel := Panel.new()
	P.place(panel, Vector2(408, 50), Vector2(216, 268))
	add_child(panel)
	detail = P.label(panel, "Hover an item.", P.FONT_SMALL, P.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail, Vector2(8, 8), Vector2(200, 250))
	P.place(P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 22)), Vector2(16, 326))


func refresh() -> void:
	var prof = main.profile
	markers_lbl.text = "Markers: %d   (earned by clearing nights)" % prof.markers
	for c in list.get_children():
		c.queue_free()
	for e in Profile.catalogue():
		var owned: bool = prof.is_unlocked(e.id)
		var txt := "[%s] %s   %s" % [e.category.to_upper(), e.name, "OWNED" if owned else "%d M" % e.cost]
		var b := P.button(list, txt, _buy.bind(e.id), Vector2(368, 18), P.FONT_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = owned or prof.markers < e.cost
		b.mouse_entered.connect(func(): detail.text = "%s\n\n%s" % [e.name, e.desc])


func _buy(id: String) -> void:
	if main.profile.buy_unlock(id):
		main.save_profile()
		Sfx.play("unlock")
		main.fx.stamp("UNLOCKED", P.GOLD, 1.0)
		main.fx.burst(main.fx.get_local_mouse_position(), 30, [P.GOLD, P.CREAM, P.GOOD], 150.0)
		refresh()
