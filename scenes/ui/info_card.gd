extends Control
## A small card that pops up beside whatever you're pointing at (a chip on the felt, a chip in
## the rack, a House Rule, a voucher): its icon, name, a line of facts (level, stacked chips,
## refine, flaw, rarity) and what it does. One lives in Main, above the screens.
## Builders (for_chip, for_item, for_rule...) turn game objects into card data.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Content := preload("res://core/content.gd")
const Preview := preload("res://core/preview.gd")

const W := 190.0
const PAD := 6.0

var data: Dictionary = {}
var _lines: Array = []  ## [text, colour]
var _h := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 50


## Show `d` ({icon, title, sub, body, col}) next to `at` (frame coordinates), kept on screen.
func show_at(at: Vector2, d: Dictionary) -> void:
	data = d
	var font := P.font()
	_lines = []
	for para in str(d.get("body", "")).split("\n"):
		_wrap(para, font, P.CREAM)
	for para in str(d.get("detail", "")).split("\n"):
		if para != "":
			_wrap(para, font, P.DIM)
	if str(d.get("foot", "")) != "":
		_wrap(str(d.foot), font, d.get("foot_col", P.GOLD))
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


func _wrap(text: String, font: Font, col: Color) -> void:
	var line := ""
	for word in text.split(" "):
		var t := word if line == "" else line + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > W - PAD * 2:
			_lines.append([line, col])
			line = word
		else:
			line = t
	_lines.append([line, col])


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
		draw_string(font, Vector2(PAD, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, l[1])
		y += 10


# --- Builders -------------------------------------------------------------------------------

## The dim rules lines under a chip's one-line description: where it goes, how it scales, the fine print.
static func chip_detail(kind: String) -> String:
	var spec: Dictionary = Content.CHIPS.get(kind, Content.UPGRADES.get(kind, {}))
	var out := []
	for t in [Content.place_hint(kind), Content.scale_hint(kind), str(spec.get("more", ""))]:
		if t != "":
			out.append(t)
	return "\n".join(out)


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
	var d := {"icon": c.kind, "title": spec.name, "sub": "  ".join(facts), "body": body, "col": _rar_col(c.kind),
		"detail": chip_detail(c.kind)}
	if run != null:
		var hc := hit_chance(run.felt, c)
		if hc != "":
			d.detail = hc + ("\n" + d.detail if d.detail != "" else "")
	if run != null and c.id == run.felt.frozen_id:
		d.foot = "Frozen by the Enforcer: pays nothing this table."
		d.foot_col = P.DANGER
	elif run != null and run.is_fresh(c.id):
		d.foot = "Placed this turn: free to pick up until the spin."
		d.foot_col = P.CYAN
		facts.append("NEW")
		d.sub = "  ".join(facts)
	return d


## "Pays on 18 of 37 spins (49%)": how often a chip on the felt scores anything.
static func hit_chance(felt, c) -> String:
	var n: int = Preview.chip_pays_on(felt, c.id).size()
	var total: int = felt.board.pockets.size()
	if n <= 0 or total <= 0:
		return ""
	return "Pays on %d of %d spins (%d%%)." % [n, total, int(round(100.0 * n / total))]


## A chip waiting in the rack ({kind, value, flaw?, mod?, copies?}).
static func for_item(item: Dictionary) -> Dictionary:
	var spec: Dictionary = Content.CHIPS[item.kind]
	var facts := ["IN YOUR RACK"]
	if item.value > 1:
		facts.append("LEVEL %d" % item.value)
	if item.get("flaw", "") != "":
		facts.append(Content.FLAWS[item.flaw].name.to_upper())
	var body: String = spec.desc
	if item.get("flaw", "") != "":
		body += "\n%s: %s" % [Content.FLAWS[item.flaw].name, Content.FLAWS[item.flaw].desc]
	return {"icon": item.kind, "title": spec.name, "sub": "  ".join(facts), "body": body, "col": _rar_col(item.kind),
		"detail": chip_detail(item.kind), "foot": "Click, then a lit spot (or drag it). Same chip = level up.", "foot_col": P.CYAN}


## A chip on offer somewhere that isn't the counter: a free chip, the stash, an opening pick.
static func for_offer(kind: String, label: String, foot: String = "") -> Dictionary:
	var spec: Dictionary = Content.CHIPS[kind]
	return {"icon": kind, "title": spec.name, "sub": label, "body": spec.desc, "col": _rar_col(kind),
		"detail": chip_detail(kind), "foot": foot, "foot_col": P.CYAN}


## Anything on the Cage counter (chip, felt upgrade, House Rule, favour, voucher, loan).
static func for_stock(run, i: int) -> Dictionary:
	var item: Dictionary = run.shop.stock[i]
	var icon: String = item.id
	var sub := Content.rarity_of(item.id).to_upper() if item.type in ["chip", "rule", "upgrade"] else ""
	var detail := ""
	match item.type:
		"chip":
			detail = chip_detail(item.id)
			sub += "  CHIP"
		"upgrade":
			detail = chip_detail(item.id)
			sub += "  FELT UPGRADE"
		"rule":
			detail = str(Content.HOUSE_RULES[item.id].get("more", ""))
			sub += "  HOUSE RULE"
		"favour":
			icon = Content.FAVOURS[item.id].icon
			sub = "FAVOUR (NEXT TABLE)"
		"voucher":
			icon = Content.VOUCHERS[item.id].icon
			detail = str(Content.VOUCHERS[item.id].get("more", ""))
			sub = "VOUCHER (WHOLE RUN)"
		"loan":
			icon = "loan"
			sub = "LOAN"
	var hints: Array = run.item_hints(item)
	if not hints.is_empty():
		detail += ("\n" if detail != "" else "") + "\n".join(hints)
	var block: String = run.buy_block(i)
	var foot := ""
	var fcol := P.GOLD
	if block != "":
		foot = block
		fcol = P.DANGER if block != "Sold." else P.DIM
	elif item.type == "chip" or item.type == "upgrade":
		foot = "%s  Drag it onto the felt to buy and place." % run.price_text(item)
	else:
		foot = "%s  Drag it to your rack to buy." % run.price_text(item)
	return {"icon": icon, "title": run.item_name(item), "sub": sub.strip_edges(), "body": run.item_desc(item),
		"col": _rar_col(item.id) if item.type in ["chip", "rule", "upgrade"] else P.VIOLET,
		"detail": detail, "foot": foot, "foot_col": fcol}


## A plain titled card for choices that aren't items (routes, refine paths, bonuses).
static func for_text(title: String, sub: String, body: String, icon: String = "", detail: String = "") -> Dictionary:
	return {"icon": icon, "title": title, "sub": sub, "body": body, "col": P.GOLD, "detail": detail}


## Any item by id (chip, House Rule, felt upgrade, voucher), for the Pawn Shop and the Casebook.
static func for_id(id: String, sub: String = "") -> Dictionary:
	if Content.CHIPS.has(id):
		return for_offer(id, sub if sub != "" else Content.rarity_of(id).to_upper() + "  CHIP")
	if Content.HOUSE_RULES.has(id):
		var d := for_rule(id)
		if sub != "":
			d.sub = sub
		return d
	if Content.UPGRADES.has(id):
		return {"icon": id, "title": Content.UPGRADES[id].name, "sub": sub if sub != "" else "FELT UPGRADE",
			"body": Content.UPGRADES[id].desc, "col": _rar_col(id), "detail": chip_detail(id)}
	if Content.VOUCHERS.has(id):
		return for_voucher(id)
	return {}


static func for_rule(id: String, built_in: bool = false) -> Dictionary:
	var r: Dictionary = Content.HOUSE_RULES[id]
	var sub := "BUILT INTO THE WHEEL" if built_in else ("TROPHY HOUSE RULE" if r.get("trophy", false) else "HOUSE RULE")
	return {"icon": id, "title": r.name, "sub": sub, "body": r.desc, "col": _rar_col(id), "detail": str(r.get("more", ""))}


static func for_voucher(id: String) -> Dictionary:
	var v: Dictionary = Content.VOUCHERS[id]
	return {"icon": v.icon, "title": v.name, "sub": "VOUCHER (WHOLE RUN)", "body": v.desc, "col": P.VIOLET, "detail": str(v.get("more", ""))}


static func _rar_col(id: String) -> Color:
	match Content.rarity_of(id):
		"rare":
			return P.CYAN
		"legendary":
			return P.GOLD
	return P.LINE
