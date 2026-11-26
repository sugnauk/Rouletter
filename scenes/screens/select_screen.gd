extends Control
## Wheel select: one wheel at a time, shown in full, with < > to browse (or the arrow keys).
## The wheels are the starting "gamblers"; locked ones can be browsed but not dealt.

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Wheels := preload("res://core/wheels.gd")
const Content := preload("res://core/content.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")
const RunState := preload("res://core/run_state.gd")

var main
var selected := "french"
var wheel_view
var lock_lbl: Label
var index_lbl: Label
var dots: Control
var name_lbl: Label
var desc_lbl: Label
var style_lbl: Label
var stat_lbl: Label
var go_btn: Button
var act_btn: Button
var acts := 1
var grade := 0
var grade_box: HBoxContainer
var grade_lbl: Button
var mode := ""             ## "" standard, "weekly", or a Content.CHALLENGES id
var kit := ""              ## "" the wheel's kit, or a Content.STARTERS id
var mode_btn: Button
var kit_btn: Button
var seed_edit: LineEdit
var seed_lbl: Label
var browse: Array = []     ## the < > buttons (hidden when a mode fixes the wheel)


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
	browse = [prev, next]
	# Run mode (standard / weekly / named challenges), starting kit, and an optional seed.
	mode_btn = P.button(self, "", func(): _cycle_mode(1), Vector2(138, 16), P.FONT_SMALL)
	P.place(mode_btn, Vector2(344, 4))
	kit_btn = P.button(self, "", func(): _cycle_kit(1), Vector2(138, 16), P.FONT_SMALL)
	P.place(kit_btn, Vector2(486, 4))
	seed_lbl = P.label(self, "SEED", P.FONT_SMALL, P.DIM)
	P.place(seed_lbl, Vector2(344, 28))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "random"
	seed_edit.max_length = 24
	seed_edit.add_theme_font_override("font", P.font())
	seed_edit.add_theme_font_size_override("font_size", P.FONT_SMALL)
	for st in ["normal", "focus", "read_only"]:
		var sb: StyleBoxFlat = P.box(Color("#120c08"), P.GOLD if st == "focus" else P.LINE, 1)
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		sb.content_margin_left = 4
		seed_edit.add_theme_stylebox_override(st, sb)
	seed_edit.add_theme_color_override("font_color", P.CREAM)
	seed_edit.add_theme_color_override("font_placeholder_color", P.DIM)
	P.place(seed_edit, Vector2(374, 23), Vector2(110, 14))
	add_child(seed_edit)
	lock_lbl = P.label(self, "", P.FONT, P.DANGER)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	P.place(lock_lbl, Vector2(16, 286), Vector2(316, 14))
	dots = Control.new()
	P.place(dots, Vector2(16, 304), Vector2(316, 8))
	dots.draw.connect(_draw_dots)
	add_child(dots)
	# Details on the right.
	var panel := Panel.new()
	P.place(panel, Vector2(344, 50), Vector2(280, 262))
	add_child(panel)
	index_lbl = P.label(panel, "", P.FONT_SMALL, P.DIM)
	P.place(index_lbl, Vector2(8, 6))
	name_lbl = P.label(panel, "", P.FONT_BIG, P.GOLD)
	P.place(name_lbl, Vector2(8, 18))
	style_lbl = P.label(panel, "", P.FONT_SMALL, P.CYAN)
	style_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(style_lbl, Vector2(8, 42), Vector2(264, 12))
	desc_lbl = P.label(panel, "", P.FONT, P.CREAM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(desc_lbl, Vector2(8, 56), Vector2(264, 100))
	stat_lbl = P.label(panel, "", P.FONT_SMALL, P.DIM)
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(stat_lbl, Vector2(8, 160), Vector2(264, 100))
	go_btn = P.button(self, "Deal me in", _deal, Vector2(120, 24))
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


func _deal() -> void:
	var opts := {"seed": RunState.parse_seed(seed_edit.text), "starter": kit}
	if mode == "weekly":
		var w: Dictionary = RunState.weekly_preset(int(Time.get_unix_time_from_system()))
		opts = {"seed": w.seed, "weekly": w.id}
		main.start_run(w.wheel, 1, w.grade, opts)
	elif mode != "":
		opts.challenge = mode
		main.start_run(selected, 1, 0, opts)
	else:
		main.start_run(selected, acts, grade, opts)


func _modes() -> Array:
	return [""] + ["weekly"] + Content.CHALLENGES.keys()


func _cycle_mode(d: int) -> void:
	var ms := _modes()
	mode = ms[(ms.find(mode) + d + ms.size()) % ms.size()]
	if mode == "weekly":
		selected = RunState.weekly_preset(int(Time.get_unix_time_from_system())).wheel
	elif mode != "":
		selected = Content.CHALLENGES[mode].wheel
	Sfx.play("click")
	refresh()


func _cycle_kit(d: int) -> void:
	var ks := [""]
	for k in Content.STARTERS:
		if main.profile.is_unlocked(k):
			ks.append(k)
	kit = ks[(ks.find(kit) + d + ks.size()) % ks.size()]
	Sfx.play("click")
	refresh()


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
	if mode != "":
		return
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
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not go_btn.disabled and not seed_edit.has_focus():
			_deal()
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
	var fixed: bool = mode != ""
	if not main.profile.is_unlocked(kit):
		kit = ""
	mode_btn.text = "MODE: " + ("STANDARD" if mode == "" else ("WEEKLY" if mode == "weekly" else Content.CHALLENGES[mode].name.to_upper()))
	kit_btn.text = "KIT: " + ("WHEEL'S OWN" if kit == "" else Content.STARTERS[kit].name.to_upper())
	kit_btn.visible = mode in ["", "no_outside", "gauntlet", "shoestring"] and Content.STARTERS.keys().any(func(k): return prof.is_unlocked(k))
	seed_edit.visible = mode != "weekly"
	seed_lbl.visible = seed_edit.visible
	for b in browse:
		b.visible = not fixed
	grade_box.visible = grade_box.visible and not fixed
	act_btn.visible = act_btn.visible and not fixed
	var unlocked: bool = prof.is_unlocked(selected) or fixed
	wheel_view.board = Board.new(selected)
	wheel_view.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.35)
	wheel_view.queue_redraw()
	lock_lbl.text = "" if unlocked else "LOCKED  -  %d Markers at the Pawn Shop" % Wheels.get_def(selected).unlock
	index_lbl.text = "WHEEL %d OF %d" % [Wheels.ORDER.find(selected) + 1, Wheels.ORDER.size()]
	dots.queue_redraw()
	var d: Dictionary = Wheels.get_def(selected)
	var b = Board.new(selected)
	name_lbl.text = d.name
	style_lbl.text = d.get("style", "")
	desc_lbl.text = d.desc
	var kit_names := []
	for k in d.kit:
		kit_names.append("%s x%d" % [Content.CHIPS[k.kind].name, k.value])
	if kit != "" and mode != "fence_run" and mode != "weekly":
		kit_names = [Content.STARTERS[kit].name]
	elif mode == "fence_run":
		kit_names = ["Magnet x1", "Permanent x1", "+$%d" % Content.FENCE_RUN_CASH]
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
	if mode == "weekly":
		var w: Dictionary = RunState.weekly_preset(int(Time.get_unix_time_from_system()))
		var wb: Dictionary = prof.weekly_best
		desc_lbl.text = "WEEKLY CHALLENGE, week of %s. Same wheel, same seed, same Grade 2 marker for everyone this week." % w.monday
		if wb.get("id", "") == w.id:
			desc_lbl.text += "  Your best: %s." % ("PAID IN FULL" if wb.won else "%d night%s" % [wb.nights, "" if wb.nights == 1 else "s"])
	elif mode != "":
		desc_lbl.text = "CHALLENGE: %s  %s" % [Content.CHALLENGES[mode].desc, "(Won)" if ("ch_" + mode) in prof.feats else ""]
	var edge_txt := "%.1f%%" % edge + (" (%.1f%% even-money)" % (edge / 2.0) if "la_partage" in d.rules else "")
	var zeros := []
	for z in b.zeros:
		zeros.append(b.label(z))
	var rules := []
	for r in d.rules + d.get("house", []):
		rules.append(Content.HOUSE_RULES[r].name)
	stat_lbl.text = "\n".join([
		"POCKETS  %d  (%d numbers%s)" % [b.pockets.size(), b.numbers, (" + zeros " + ", ".join(zeros)) if not zeros.is_empty() else ", no zero"],
		"HOUSE EDGE  " + edge_txt,
		"PAYMENTS  x%.2f" % d.get("target", 1.0),
		"STARTING CASH  $%d" % (Content.START_CASH + d.cash),
		"STARTING KIT  " + (", ".join(kit_names) if not kit_names.is_empty() else "none"),
		"BUILT-IN RULES  " + (", ".join(rules) if not rules.is_empty() else "none"),
	])
	go_btn.disabled = not unlocked
