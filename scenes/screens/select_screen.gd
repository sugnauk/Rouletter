extends Control
## Wheel select: the wheels are the starting "gamblers".

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Wheels := preload("res://core/wheels.gd")
const Content := preload("res://core/content.gd")
const WheelView := preload("res://scenes/ui/wheel_view.gd")

var main
var selected := "french"
var cards: Dictionary = {}
var name_lbl: Label
var desc_lbl: Label
var stat_lbl: Label
var go_btn: Button


func setup() -> void:
	P.place(P.label(self, "CHOOSE YOUR WHEEL", P.FONT_BIG, P.GOLD), Vector2(16, 10))
	P.place(P.label(self, "Every wheel is honest. They just aren't the same wheel.", P.FONT_SMALL, P.DIM), Vector2(16, 30))
	var x := 16
	for id in Wheels.ORDER:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		P.place(b, Vector2(x, 48), Vector2(114, 150))
		b.pressed.connect(_pick.bind(id))
		add_child(b)
		var w = WheelView.new()
		w.board = Board.new(id)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		P.place(w, Vector2(17, 8), Vector2(80, 80))
		b.add_child(w)
		var n := P.label(b, Wheels.get_def(id).name, P.FONT, P.CREAM)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		P.place(n, Vector2(0, 96), Vector2(114, 14))
		var s := P.label(b, "", P.FONT_SMALL, P.DIM)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		P.place(s, Vector2(0, 116), Vector2(114, 28))
		cards[id] = {"button": b, "status": s, "wheel": w}
		x += 122
	var panel := Panel.new()
	P.place(panel, Vector2(16, 208), Vector2(608, 104))
	add_child(panel)
	name_lbl = P.label(panel, "", P.FONT_BIG, P.GOLD)
	P.place(name_lbl, Vector2(8, 4))
	desc_lbl = P.label(panel, "", P.FONT, P.CREAM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	P.place(desc_lbl, Vector2(8, 26), Vector2(592, 40))
	stat_lbl = P.label(panel, "", P.FONT_SMALL, P.DIM)
	P.place(stat_lbl, Vector2(8, 80))
	go_btn = P.button(self, "Deal me in", func(): main.start_run(selected), Vector2(120, 24))
	P.place(go_btn, Vector2(504, 322))
	P.place(P.button(self, "Back", func(): main.show_screen("title"), Vector2(80, 24)), Vector2(16, 322))


func _pick(id: String) -> void:
	selected = id
	Sfx.play("click")
	refresh()


func refresh() -> void:
	var prof = main.profile
	if not prof.is_unlocked(selected):
		selected = "french"
	for id in cards:
		var c: Dictionary = cards[id]
		var unlocked: bool = prof.is_unlocked(id)
		c.status.text = ("" if unlocked else "LOCKED\nPawn Shop: %d M" % Wheels.get_def(id).unlock)
		c.wheel.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.35)
		c.button.add_theme_stylebox_override("normal", P.box(P.PANEL_HI, P.GOLD if id == selected else P.LINE.darkened(0.5), 2 if id == selected else 1))
	var d: Dictionary = Wheels.get_def(selected)
	var b = Board.new(selected)
	name_lbl.text = d.name
	desc_lbl.text = d.desc
	var kit := []
	for k in d.kit:
		kit.append("%s x%d" % [Content.CHIPS[k.kind].name, k.value])
	var edge: float = float(b.zeros.size()) / b.pockets.size() * 100.0
	var edge_txt := "%.1f%%" % edge + (" (%.1f%% even-money)" % (edge / 2.0) if "la_partage" in d.rules else "")
	stat_lbl.text = "%d pockets   house edge %s   payments x%.1f   start: $%d%s" % [
		b.pockets.size(), edge_txt, d.get("target", 1.0),
		Content.START_CASH + d.cash, ("   kit: " + ", ".join(kit)) if not kit.is_empty() else ""]
	go_btn.disabled = not prof.is_unlocked(selected)
