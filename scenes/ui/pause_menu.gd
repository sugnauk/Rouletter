extends Control
## Pause menu during a run (Esc, or the MENU button on the table and in the Cage):
## Resume, Options, Abandon run, Quit to title. The run is saved at every table and Cage
## visit, so quitting to the title keeps it for "Continue Run".

const P := preload("res://scenes/ui/palette.gd")
const Content := preload("res://core/content.gd")

var main
var abandon_btn: Button
var fast_btn: Button
var confirm := false
var info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.02, 0.8)
	shade.position = Vector2(-4000, -4000)
	shade.size = Vector2(8640, 8360)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", P.box(P.PANEL, P.GOLD, 2))
	P.place(panel, Vector2(200, 66), Vector2(240, 228))
	add_child(panel)
	var t := P.label(panel, "PAUSED", P.FONT_BIG, P.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	P.place(t, Vector2(0, 10), Vector2(240, 20))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	P.place(box, Vector2(50, 40))
	info = P.label(panel, "", P.FONT_SMALL, P.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_constant_override("line_spacing", -1)
	P.place(info, Vector2(10, 182), Vector2(220, 44))
	panel.add_child(box)
	P.button(box, "Resume", close, Vector2(140, 22))
	P.button(box, "Options", func():
		close()
		main.open_options(true), Vector2(140, 22))
	fast_btn = P.button(box, "", func():
		main.cycle_speed()
		_label_fast(), Vector2(140, 22))
	abandon_btn = P.button(box, "Abandon run", _abandon, Vector2(140, 22))
	P.button(box, "Quit to title", func():
		close()
		main.quit_to_title(), Vector2(140, 22))


func _label_fast() -> void:
	var sp: Dictionary = preload("res://core/profile.gd").SPEEDS[main.speed()]
	fast_btn.text = "Speed: %s  %s" % [sp.name.to_upper(), sp.label]


func open() -> void:
	_label_fast()
	var r = main.run
	var lines := ["SEED %d" % r.run_seed]
	if r.challenge != "":
		lines[0] += "  -  " + Content.CHALLENGES[r.challenge].name.to_upper()
	elif r.weekly != "":
		lines[0] += "  -  WEEKLY CHALLENGE"
	if r.grade > 0:
		var mods := []
		for g in range(1, r.grade + 1):
			mods.append(Content.GRADES[g].name)
		lines.append("GRADE %d: %s" % [r.grade + 1, ", ".join(mods)])
	var src: Array = r.cash_sources()
	if not src.is_empty():
		var bits := []
		for x in src.slice(0, 3):
			bits.append("%s $%d" % [x[0], x[1]])
		lines.append("MONEY: " + ", ".join(bits))
	info.text = "\n".join(lines)
	confirm = false
	abandon_btn.text = "Abandon run"
	visible = true
	Sfx.play("click")


func close() -> void:
	visible = false


func _abandon() -> void:
	if not confirm:
		confirm = true
		abandon_btn.text = "Really? Click again"
		Sfx.play("lose")
		return
	close()
	main.abandon_run()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
