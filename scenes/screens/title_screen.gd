extends Control

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Version := preload("res://core/version.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")

var main
var debt_lbl: Label
var info_lbl: Label


func setup() -> void:
	var wheel = WheelView.new()
	wheel.board = Board.new("european")
	wheel.idle_spin = true
	P.place(wheel, Vector2(352, 44), Vector2(272, 272))
	add_child(wheel)
	P.place(P.label(self, "ROULETTER", P.FONT_HUGE, P.GOLD), Vector2(28, 54))
	P.place(P.label(self, "The Gilded Ace  -  1974", P.FONT, P.DIM), Vector2(32, 98))
	debt_lbl = P.label(self, "", P.FONT, P.DANGER)
	P.place(debt_lbl, Vector2(32, 122))
	info_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	P.place(info_lbl, Vector2(32, 138))
	var y := 170
	for b in [["New Run", func(): main.begin_flow()], ["Pawn Shop", func(): main.show_screen("pawn")],
			["Journal", func(): main.show_screen("journal")], ["Quit", func(): get_tree().quit()]]:
		P.place(P.button(self, b[0], b[1], Vector2(140, 22)), Vector2(32, y))
		y += 28
	P.place(P.label(self, "F2: CRT filter    F11: fullscreen", P.FONT_SMALL, P.DIM), Vector2(32, 340))
	var ver := P.label(self, Version.label(), P.FONT_SMALL, P.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	P.place(ver, Vector2(408, 340), Vector2(224, 10))


func refresh() -> void:
	var p = main.profile
	debt_lbl.text = "Marker owed to Mr. Vance: $%s" % P.money(p.debt)
	if p.act2_unlocked():
		debt_lbl.text += "   Floor Above: $%s" % P.money(p.debt2)
	info_lbl.text = "Markers %d    Runs %d    Wins %d    Best night %d" % [p.markers, p.runs, p.wins, p.best_night]
