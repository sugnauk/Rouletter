extends Control
## Pause menu during a run (Esc, or the MENU button on the table and in the Cage):
## Resume, Options, Abandon run, Quit to title. The run is saved at every table and Cage
## visit, so quitting to the title keeps it for "Continue Run".

const P := preload("res://scenes/ui/palette.gd")

var main
var abandon_btn: Button
var fast_btn: Button
var confirm := false


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
	P.place(panel, Vector2(220, 80), Vector2(200, 204))
	add_child(panel)
	var t := P.label(panel, "PAUSED", P.FONT_BIG, P.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	P.place(t, Vector2(0, 10), Vector2(200, 20))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	P.place(box, Vector2(30, 40))
	panel.add_child(box)
	P.button(box, "Resume", close, Vector2(140, 22))
	P.button(box, "Options", func():
		close()
		main.open_options(true), Vector2(140, 22))
	fast_btn = P.button(box, "", func():
		main.set_option("fast_spins", not main.profile.settings.get("fast_spins", false))
		_label_fast(), Vector2(140, 22))
	abandon_btn = P.button(box, "Abandon run", _abandon, Vector2(140, 22))
	P.button(box, "Quit to title", func():
		close()
		main.quit_to_title(), Vector2(140, 22))


func _label_fast() -> void:
	fast_btn.text = "Fast spins: %s" % ("ON" if main.profile.settings.get("fast_spins", false) else "OFF")


func open() -> void:
	_label_fast()
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
