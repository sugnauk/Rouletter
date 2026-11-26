extends Control
## A small card that pops up beside whatever you're pointing at (a chip on the felt, a chip in
## the rack, a House Rule, a voucher): its icon, name, a line of facts (level, stacked chips,
## refine, flaw, rarity) and what it does. One lives in Main, above the screens.
## Builders (for_chip, for_item, for_rule...) turn game objects into card data.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Content := preload("res://core/content.gd")

const W := 190.0
const PAD := 6.0

var data: Dictionary = {}
var _lines: PackedStringArray = []
var _h := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 50


## Show `d` ({icon, title, sub, body, col}) next to `at` (frame coordinates), kept on screen.
func show_at(at: Vector2, d: Dictionary) -> void:
	data = d
	var font := P.font()
	_lines = PackedStringArray()
	for para in str(d.get("body", "")).split("\n"):
		_wrap(para, font)
	_h = PAD * 2 + 26 + _lines.size() * 10
	size = Vector2(W, _h)
	var pos := at + Vector2(14, 10)
	if pos.x + W > 636:
		pos.x = at.x - W - 14
	if pos.y + _h > 356:
		pos.y = maxf(4.0, 356 - _h)
	position = pos.floor()
	visible = true
	queue_redraw()


func hide_card() -> void:
	visible = false


func _wrap(text: String, font: Font) -> void:
	var line := ""
	for word in text.split(" "):
		var t := word if line == "" else line + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > W - PAD * 2:
			_lines.append(line)
			line = word
		else:
			line = t
	_lines.append(line)


func _draw() -> void:
	if data.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	var col: Color = data.get("col", P.GOLD)
	draw_rect(r.grow(1), Color(0, 0, 0, 0.5))
	draw_rect(r, Color("#120c0a"))
	draw_rect(r, col, false, 1.0)
	draw_rect(Rect2(1, 1, size.x - 2, 1), Color(col, 0.35))
	var icon: String = data.get("icon", "")
	var tx := PAD
	if icon != "":
		draw_rect(Rect2(PAD, PAD, 22, 22), Color("#1c3a29"))
		Art.icon(self, icon, Vector2(PAD + 11, PAD + 11), 1)
		tx = PAD + 28
	var font := P.font()
	draw_string(font, Vector2(tx, PAD + 9), str(data.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, W - tx - PAD, 8, col)
	draw_string(font, Vector2(tx, PAD + 20), str(data.get("sub", "")), HORIZONTAL_ALIGNMENT_LEFT, W - tx - PAD, 8, P.CYAN)
	var y := PAD + 26 + 9
	for l in _lines:
		draw_string(font, Vector2(PAD, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, P.CREAM)
		y += 10


# --- Builders -------------------------------------------------------------------------------

## A permanent chip on the felt.
static func for_chip(c, run = null) -> Dictionary:
	var spec: Dictionary = Content.CHIPS[c.kind]
	var facts := ["LEVEL %d" % c.value]
	if c.copies > 1:
		facts.append("%d STACKED" % c.copies)
	if c.mod != "":
		facts.append(Content.REFINES[c.mod].name.to_upper())
	if c.flaw != "":
		facts.append(Content.FLAWS[c.flaw].name.to_upper())
	var body: String = spec.desc
	if c.mod != "":
		body += "\n%s: %s" % [Content.REFINES[c.mod].name, Content.REFINES[c.mod].desc]
	if c.flaw != "":
		body += "\n%s: %s" % [Content.FLAWS[c.flaw].name, Content.FLAWS[c.flaw].desc]
	if run != null and c.id == run.felt.frozen_id:
		body += "\nFrozen by the Enforcer: it pays nothing this table."
	return {"icon": c.kind, "title": spec.name, "sub": "  ".join(facts), "body": body, "col": _rar_col(c.kind)}


## A chip waiting in the rack ({kind, value, flaw?, mod?, copies?}).
static func for_item(item: Dictionary) -> Dictionary:
	var spec: Dictionary = Content.CHIPS[item.kind]
	var facts := ["IN YOUR RACK"]
	if item.value > 1:
		facts.append("LEVEL %d" % item.value)
	if item.get("flaw", "") != "":
		facts.append(Content.FLAWS[item.flaw].name.to_upper())
	var body: String = spec.desc + "\nClick it, then a spot on the felt (or drag it there). Put it on its twin to level up."
	if item.get("flaw", "") != "":
		body += "\n%s: %s" % [Content.FLAWS[item.flaw].name, Content.FLAWS[item.flaw].desc]
	return {"icon": item.kind, "title": spec.name, "sub": "  ".join(facts), "body": body, "col": _rar_col(item.kind)}


static func for_rule(id: String, built_in: bool = false) -> Dictionary:
	var r: Dictionary = Content.HOUSE_RULES[id]
	var sub := "BUILT INTO THE WHEEL" if built_in else ("TROPHY HOUSE RULE" if r.get("trophy", false) else "HOUSE RULE")
	return {"icon": id, "title": r.name, "sub": sub, "body": r.desc, "col": _rar_col(id)}


static func for_voucher(id: String) -> Dictionary:
	var v: Dictionary = Content.VOUCHERS[id]
	return {"icon": v.icon, "title": v.name, "sub": "VOUCHER (WHOLE RUN)", "body": v.desc, "col": P.VIOLET}


static func _rar_col(id: String) -> Color:
	match Content.rarity_of(id):
		"rare":
			return P.CYAN
		"legendary":
			return P.GOLD
	return P.LINE
