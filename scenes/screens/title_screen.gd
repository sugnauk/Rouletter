extends Control

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Version := preload("res://core/version.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")

var main
var debt_lbl: Label
var info_lbl: Label
var continue_btn: Button


func setup() -> void:
	var wheel = WheelView.new()
	wheel.board = Board.new("european")
	wheel.idle_spin = true
	P.place(wheel, Vector2(352, 44), Vector2(272, 272))
	add_child(wheel)
	P.place(P.label(self, "ROULETTER", P.FONT_HUGE, P.GOLD), Vector2(28, 54))
	P.place(P.label(self, "The Gilded Ace  -  1974", P.FONT, P.DIM), Vector2(32, 98))
	debt_lbl = P.label(self, "", P.FONT, P.GOLD)
	P.place(debt_lbl, Vector2(32, 122))
	info_lbl = P.label(self, "", P.FONT_SMALL, P.DIM)
	P.place(info_lbl, Vector2(32, 138))
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	P.place(menu, Vector2(32, 156))
	add_child(menu)
	continue_btn = P.button(menu, "Continue Run", func(): main.continue_run(), Vector2(140, 20))
	for b in [["New Run", func(): main.begin_flow()], ["Pawn Shop", func(): main.show_screen("pawn")],
			["Journal", func(): main.show_screen("journal")], ["Feats", func(): main.show_screen("feats")],
			["Options", func(): main.open_options()], ["Quit", func(): get_tree().quit()]]:
		P.button(menu, b[0], b[1], Vector2(140, 20))
	P.place(P.label(self, "F2: CRT filter    F11: fullscreen", P.FONT_SMALL, P.DIM), Vector2(32, 340))
	var ver := P.label(self, Version.label(), P.FONT_SMALL, P.CREAM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	P.place(ver, Vector2(408, 340), Vector2(224, 10))


func refresh() -> void:
	var p = main.profile
	continue_btn.visible = main.has_saved_run()
	var nu: Dictionary = p.next_unlock()
	debt_lbl.text = "Markers %d" % p.markers
	if not nu.is_empty():
		debt_lbl.text += ("   -   %s ready at the Pawn Shop!" % nu.name) if p.markers >= nu.cost else ("   -   next: %s at %d" % [nu.name, nu.cost])
	info_lbl.text = "Runs %d    Wins %d    Best night %d    Best Take %d    Paid to Vance $%s" % [p.runs, p.wins, p.best_night, p.best_take, P.money(p.total_paid)]
