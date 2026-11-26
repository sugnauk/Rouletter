extends Control
## Options: display and comfort settings, saved in the profile.

const P := preload("res://scenes/ui/palette.gd")

const ITEMS := [
	["crt", "CRT filter", "Scanlines and a soft vignette over the whole screen (F2 toggles it anywhere)."],
	["cb_marks", "Colour-blind marks", "A small cross on every red square of the felt, so red and black don't rely on colour alone."],
	["cards", "Loading cards", "The themed cards between screens. Off switches screens instantly."],
	["shake", "Screen shake", "Shake on big wins and busts."],
]

var main
var buttons: Dictionary = {}
var detail: Label


func setup() -> void:
	P.place(P.label(self, "OPTIONS", P.FONT_BIG, P.GOLD), Vector2(16, 8))
	var y := 50
	for it in ITEMS:
		var b := P.button(self, "", _toggle.bind(it[0]), Vector2(260, 24))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(func(): detail.text = it[2])
		P.place(b, Vector2(16, y))
		buttons[it[0]] = [b, it[1]]
		y += 30
	var panel := Panel.new()
	P.place(panel, Vector2(292, 50), Vector2(332, 114))
	add_child(panel)
	detail = P.label(panel, "Hover an option.", P.FONT_SMALL, P.CREAM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(detail, Vector2(8, 8), Vector2(316, 100))
	P.place(P.label(self, "F11: fullscreen    Keys at the table: 1/2/3 chip size, Z undo, C clear, Space spin", P.FONT_SMALL, P.DIM), Vector2(16, 186))
	P.place(P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 22)), Vector2(16, 326))


func refresh() -> void:
	for k in buttons:
		var on: bool = main.profile.settings.get(k, false)
		buttons[k][0].text = "%s:  %s" % [buttons[k][1], "ON" if on else "OFF"]


func _toggle(key: String) -> void:
	Sfx.play("click")
	main.set_option(key, not main.profile.settings.get(key, false))
