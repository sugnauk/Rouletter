extends Control
## Wheel select: one wheel at a time, shown in full, with < > to browse (or the arrow keys).
## The wheels are the starting "gamblers"; locked ones can be browsed but not dealt.

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Wheels := preload("res://core/wheels.gd")
const Content := preload("res://core/content.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")

var main
var selected := "french"
var wheel_view
var lock_lbl: Label
var index_lbl: Label
var dots: Control
var name_lbl: Label
var desc_lbl: Label
var stat_lbl: Label
var go_btn: Button
var act_btn: Button
var acts := 1
var grade := 0
var grade_box: HBoxContainer
var grade_lbl: Button


func setup() -> void:
	P.place(P.label(self, "CHOOSE YOUR WHEEL", P.FONT_BIG, P.GOLD), Vector2(16, 10))
	P.place(P.label(self, "Every wheel is honest. They just aren't the same wheel.", P.FONT_SMALL, P.DIM), Vector2(16, 30))
	# The wheel, big, between the browse arrows.
	wheel_view = WheelView.new()
	wheel_view.idle_spin = true
	wheel_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.place(wheel_view, Vector2(58, 48), Vector2(232, 232))
	add_child(wheel_view)
	var prev := P.button(self, "<", func(): _step(-1), Vector2(34, 64), P.FONT_BIG)
	P.place(prev, Vector2(16, 132))
	var next := P.button(self, ">", func(): _step(1), Vector2(34, 64), P.FONT_BIG)
	P.place(next, Vector2(298, 132))
	lock_lbl = P.label(self, "", P.FONT, P.DANGER)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	P.place(lock_lbl, Vector2(16, 286), Vector2(316, 14))
	dots = Control.new()
	P.place(dots, Vector2(16, 304), Vector2(316, 8))
	dots.draw.connect(_draw_dots)
	add_child(dots)
	# Details on the right.
	var panel := Panel.new()
	P.place(panel, Vector2(344, 48), Vector2(280, 264))
	add_child(panel)
	index_lbl = P.label(panel, "", P.FONT_SMALL, P.DIM)
	P.place(index_lbl, Vector2(8, 6))
	name_lbl = P.label(panel, "", P.FONT_BIG, P.GOLD)
	P.place(name_lbl, Vector2(8, 18))
	desc_lbl = P.label(panel, "", P.FONT, P.CREAM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(desc_lbl, Vector2(8, 44), Vector2(264, 110))
	stat_lbl = P.label(panel, "", P.FONT_SMALL, P.DIM)
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(stat_lbl, Vector2(8, 160), Vector2(264, 100))
	go_btn = P.button(self, "Deal me in", func(): main.start_run(selected, acts, grade), Vector2(120, 24))
	act_btn = P.button(self, "", _toggle_act, Vector2(166, 24))
	P.place(act_btn, Vector2(334, 322))
	# Marker grade (difficulty) picker, shown once you've won a run.
	grade_box = HBoxContainer.new()
	grade_box.add_theme_constant_override("separation", 2)
	P.place(grade_box, Vector2(102, 322))
	add_child(grade_box)
	P.button(grade_box, "<", func(): _grade(-1), Vector2(22, 24))
	grade_lbl = P.button(grade_box, "", func(): pass, Vector2(180, 24), P.FONT_SMALL)
	P.button(grade_box, ">", func(): _grade(1), Vector2(22, 24))
	P.place(go_btn, Vector2(504, 322))
	P.place(P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 24)), Vector2(16, 322))


func _grade(d: int) -> void:
	grade = clampi(grade + d, 0, main.profile.max_grade())
	Sfx.play("click")
	refresh()


func _toggle_act() -> void:
	var top: int = 3 if main.profile.act2_wins > 0 else 2
	acts = acts % top + 1
	Sfx.play("click")
	refresh()


## Browse to the previous/next wheel.
func _step(d: int) -> void:
	var i: int = Wheels.ORDER.find(selected)
	selected = Wheels.ORDER[(i + d + Wheels.ORDER.size()) % Wheels.ORDER.size()]
	Sfx.play("click")
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialogue.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			_step(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			_step(1)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not go_btn.disabled:
			main.start_run(selected, acts, grade)
			get_viewport().set_input_as_handled()


## One dot per wheel; the current one is gold, locked ones are dim.
func _draw_dots() -> void:
	var n: int = Wheels.ORDER.size()
	var x0: float = dots.size.x / 2.0 - (n - 1) * 6.0
	for i in range(n):
		var id: String = Wheels.ORDER[i]
		var col: Color = P.GOLD if id == selected else (P.CREAM if main.profile.is_unlocked(id) else P.DIM.darkened(0.4))
		dots.draw_circle(Vector2(x0 + i * 12.0, 4), 3.0 if id == selected else 2.0, col, true, -1.0, false)


func refresh() -> void:
	var prof = main.profile
	grade = clampi(grade, 0, prof.max_grade())
	grade_box.visible = prof.max_grade() > 0
	grade_lbl.text = "GRADE %d: %s" % [grade + 1, Content.GRADES[grade].name.to_upper()]
	if not prof.act2_unlocked():
		acts = 1
	act_btn.visible = prof.act2_unlocked()
	if acts == 3 and prof.act2_wins <= 0:
		acts = 1
	act_btn.text = ["ACT I: THE FLOOR", "ACT II: FLOOR ABOVE", "ENDLESS"][acts - 1]
	var unlocked: bool = prof.is_unlocked(selected)
	wheel_view.board = Board.new(selected)
	wheel_view.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.35)
	wheel_view.queue_redraw()
	lock_lbl.text = "" if unlocked else "LOCKED  -  %d Markers at the Pawn Shop" % Wheels.get_def(selected).unlock
	index_lbl.text = "WHEEL %d OF %d" % [Wheels.ORDER.find(selected) + 1, Wheels.ORDER.size()]
	dots.queue_redraw()
	var d: Dictionary = Wheels.get_def(selected)
	var b = Board.new(selected)
	name_lbl.text = d.name
	desc_lbl.text = d.desc
	var kit := []
	for k in d.kit:
		kit.append("%s x%d" % [Content.CHIPS[k.kind].name, k.value])
	var edge: float = float(b.zeros.size()) / b.pockets.size() * 100.0
	if acts == 2:
		desc_lbl.text = d.desc + "  ACT II: eight nights, ending at the Owner's table."
	elif acts == 3:
		desc_lbl.text = d.desc + "  ENDLESS: the nights never stop; payments grow 30% a night past the eighth."
	if grade > 0:
		var tw := []
		for g in range(1, grade + 1):
			tw.append(Content.GRADES[g].name)
		desc_lbl.text += "  GRADE %d marker ($%s): %s." % [grade + 1, P.money(int(round(Content.MARKER_ACT1 * (1.0 + Content.MARKER_GRADE_STEP * grade)))), ", ".join(tw)]
	var edge_txt := "%.1f%%" % edge + (" (%.1f%% even-money)" % (edge / 2.0) if "la_partage" in d.rules else "")
	var zeros := []
	for z in b.zeros:
		zeros.append(b.label(z))
	var rules := []
	for r in d.rules:
		rules.append(Content.HOUSE_RULES[r].name)
	stat_lbl.text = "\n".join([
		"POCKETS  %d  (%d numbers%s)" % [b.pockets.size(), b.numbers, (" + zeros " + ", ".join(zeros)) if not zeros.is_empty() else ", no zero"],
		"HOUSE EDGE  " + edge_txt,
		"PAYMENTS  x%.2f" % d.get("target", 1.0),
		"STARTING CASH  $%d" % (Content.START_CASH + d.cash),
		"STARTING KIT  " + (", ".join(kit) if not kit.is_empty() else "none"),
		"BUILT-IN RULES  " + (", ".join(rules) if not rules.is_empty() else "none"),
	])
	go_btn.disabled = not prof.is_unlocked(selected)
