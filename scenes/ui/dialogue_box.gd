extends Control
## Story overlay: a procedural pixel portrait, the speaker's name and typewriter text.
## `say(lines, on_done)`; click, Space or Enter advances (or completes the current line).

const P := preload("res://scenes/ui/palette.gd")
const Portraits := preload("res://scenes/ui/portraits.gd")

var lines: Array = []
var idx := 0
var shown := 0.0
var on_done: Callable
var panel: Panel
var portrait: Control
var name_lbl: Label
var text_lbl: Label
var hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	# Huge so it also covers the extra space around the 640x360 frame on wide/tall windows.
	shade.position = Vector2(-4000, -4000)
	shade.size = Vector2(8640, 8360)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_gui_input)
	add_child(shade)
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", P.box(P.PANEL, P.GOLD, 2))
	P.place(panel, Vector2(12, 266), Vector2(616, 84))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	portrait = Control.new()
	P.place(portrait, Vector2(8, 8), Vector2(64, 64))
	portrait.draw.connect(_draw_portrait)
	panel.add_child(portrait)
	name_lbl = P.label(panel, "", P.FONT, P.GOLD)
	P.place(name_lbl, Vector2(82, 6))
	text_lbl = P.label(panel, "", P.FONT, P.CREAM)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(text_lbl, Vector2(82, 22), Vector2(522, 50))
	hint = P.label(panel, "click / space", P.FONT_SMALL, P.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	P.place(hint, Vector2(456, 68), Vector2(152, 10))


func say(new_lines: Array, done: Callable = Callable()) -> void:
	if new_lines.is_empty():
		if done.is_valid():
			done.call()
		return
	lines = new_lines
	idx = 0
	on_done = done
	_show_line()
	visible = true


func is_open() -> bool:
	return visible


func _show_line() -> void:
	shown = 0.0
	var l: Dictionary = lines[idx]
	name_lbl.text = l.speaker
	text_lbl.text = l.text
	text_lbl.visible_characters = 0
	portrait.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	shown += delta * 45.0
	text_lbl.visible_characters = int(shown)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		advance()
		get_viewport().set_input_as_handled()


func advance() -> void:
	if shown < text_lbl.text.length():
		shown = 9999.0
		text_lbl.visible_characters = -1
		return
	idx += 1
	if idx >= lines.size():
		visible = false
		var cb := on_done
		on_done = Callable()
		if cb.is_valid():
			cb.call()
		return
	_show_line()


## Pixel portrait of whoever is speaking (scenes/ui/portraits.gd).
func _draw_portrait() -> void:
	if lines.is_empty():
		return
	Portraits.draw(portrait, lines[idx].speaker, Rect2(0, 0, 64, 64))