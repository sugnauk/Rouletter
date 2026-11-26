extends Control

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Version := preload("res://core/version.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")
const RunState := preload("res://core/run_state.gd")
const Wheels := preload("res://core/wheels.gd")
const Content := preload("res://core/content.gd")

var main
var debt_lbl: Label
var info_lbl: Label
var continue_btn: Button
var continue_info: Label


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
	continue_info = P.label(self, "", P.FONT_SMALL, P.CREAM)
	continue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continue_info.add_theme_constant_override("line_spacing", -1)
	P.place(continue_info, Vector2(180, 158), Vector2(170, 90))
	# On the web, phones get the tip that matters: home-screen play is truly full screen.
	var hint := "On a phone: Share > Add to Home Screen plays full screen. Options > Screen fit if it's cut off." if OS.has_feature("web") \
		else "F2: CRT filter    F11: fullscreen"
	P.place(P.label(self, hint, P.FONT_SMALL, P.DIM), Vector2(32, 340))
	var ver := P.label(self, Version.label(), P.FONT_SMALL, P.CREAM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	P.place(ver, Vector2(408, 340), Vector2(224, 10))


func refresh() -> void:
	var p = main.profile
	continue_btn.visible = main.has_saved_run()
	continue_info.text = ""
	if continue_btn.visible:
		var r = RunState.new()
		if r.load_from(main.run_save_path()):
			var lines := ["%s  -  NIGHT %d" % [Wheels.get_def(r.wheel_id).name.to_upper(), r.night + 1]]
			lines.append("%s  -  marker $%s left" % ["In the Cage" if r.phase == RunState.Phase.SHOP else r.table_name() + " table", P.money(r.marker_left())])
			if r.challenge != "":
				lines.append("Challenge: " + Content.CHALLENGES[r.challenge].name)
			elif r.weekly != "":
				lines.append("Weekly challenge")
			elif r.grade > 0:
				lines.append("Grade %d marker" % (r.grade + 1))
			var ks: Array = main.kit_summary(r)
			if not ks.is_empty():
				lines.append(", ".join(ks))
			lines.append("$%d  -  seed %d" % [r.cash, r.run_seed])
			continue_info.text = "\n".join(lines)
	var nu: Dictionary = p.next_unlock()
	debt_lbl.text = "Markers %d" % p.markers
	if not nu.is_empty():
		debt_lbl.text += ("   -   %s ready at the Pawn Shop!" % nu.name) if p.markers >= nu.cost else ("   -   next: %s at %d" % [nu.name, nu.cost])
	info_lbl.text = "Runs %d    Wins %d    Best night %d    Best Take %d" % [p.runs, p.wins, p.best_night, p.best_take]
