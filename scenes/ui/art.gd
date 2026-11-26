extends RefCounted
## Procedural pixel art: casino chips, item icons, plaques. Everything is drawn with integer
## rects/circles onto any CanvasItem, so it stays crisp at the 640x360 base resolution.

const P := preload("res://scenes/ui/palette.gd")


## A casino chip: rim with edge spots, inner inlay, optional icon or value.
static func chip(ci: CanvasItem, c: Vector2, rad: float, col: Color, kind: String = "", value: int = 0, frozen: bool = false) -> void:
	c = c.round()
	ci.draw_circle(c + Vector2(0, 1), rad, col.darkened(0.55), true, -1.0, false)
	ci.draw_circle(c, rad, col, true, -1.0, false)
	# Edge spots: the stripes every real chip has.
	var spots := 6 if rad >= 5.0 else 4
	for i in range(spots):
		var a := TAU * i / spots + PI / spots
		var p := (c + Vector2(cos(a), sin(a)) * (rad - 1.2)).round()
		ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), P.CREAM if col.get_luminance() < 0.75 else P.RED)
	ci.draw_circle(c, rad * 0.62, col.darkened(0.18), true, -1.0, false)
	ci.draw_circle(c, rad * 0.62, col.lightened(0.35), false, 1.0, false)
	if kind != "" and kind != "bet" and kind != "perm" and rad >= 5.0:
		icon(ci, kind, c, 1, true)
	if frozen:
		ci.draw_line(c - Vector2(rad, rad), c + Vector2(rad, rad), P.CYAN, 1.0, false)
		ci.draw_line(c + Vector2(-rad, rad), c + Vector2(rad, -rad), P.CYAN, 1.0, false)


## Denomination colours like a real casino.
static func denom_color(v: int) -> Color:
	if v >= 25:
		return Color("#2f9e44")
	if v >= 10:
		return Color("#1c7ed6")
	if v >= 5:
		return P.RED
	return P.CREAM


## A small pixel icon (12x12 at scale 1). `tiny` = draw a 6x6 glyph for inside chips.
static func icon(ci: CanvasItem, id: String, c: Vector2, s: int = 1, tiny: bool = false) -> void:
	c = c.round()
	if tiny:
		_tiny(ci, id, c)
		return
	var o := c - Vector2(6, 6) * s
	var R := func(x: int, y: int, w: int, h: int, col: Color):
		ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), col)
	match id:
		"perm":
			chip(ci, c, 5.5 * s, P.GOLD)
			R.call(5, 4, 2, 4, P.WOOD_DARK)
			R.call(4, 5, 4, 2, P.WOOD_DARK)
		"bet":
			chip(ci, c, 5.5 * s, P.CREAM)
		"magnet":
			R.call(2, 2, 3, 7, P.RED)
			R.call(7, 2, 3, 7, P.RED)
			R.call(2, 8, 8, 3, P.RED)
			R.call(2, 2, 3, 2, P.CREAM)
			R.call(7, 2, 3, 2, P.CREAM)
		"compounding":
			R.call(5, 3, 2, 8, P.GOOD)
			R.call(3, 5, 6, 2, P.GOOD)
			R.call(4, 4, 4, 1, P.GOOD)
			R.call(5, 2, 2, 1, P.GOOD)
			R.call(2, 10, 8, 1, P.GOOD.darkened(0.3))
		"croupier":
			R.call(6, 1, 1, 8, P.WOOD)
			R.call(2, 8, 9, 2, P.LINE)
			for x in [2, 4, 6, 8, 10]:
				R.call(x, 10, 1, 2, P.LINE)
		"wildcard_zero":
			ci.draw_circle(c, 5 * s, Color("#2ec4b6"), false, 2.0 * s, false)
			R.call(5, 0, 2, 2, P.GOLD)
			R.call(5, 10, 2, 2, P.GOLD)
		"mint":
			ci.draw_circle(c, 5.5 * s, P.GOLD, true, -1.0, false)
			ci.draw_circle(c, 4.0 * s, P.GOLD.darkened(0.25), false, 1.0, false)
			R.call(5, 3, 2, 6, P.WOOD_DARK)
			R.call(4, 4, 4, 1, P.WOOD_DARK)
			R.call(4, 7, 4, 1, P.WOOD_DARK)
		"respin":
			ci.draw_arc(c, 4.5 * s, 0.6, TAU - 0.3, 14, P.CYAN, 2.0 * s, false)
			R.call(8, 1, 3, 3, P.CYAN)
		"ledger":
			R.call(2, 1, 8, 10, Color("#8a5a2b"))
			R.call(3, 2, 6, 8, P.CREAM)
			for y in [3, 5, 7]:
				R.call(4, y, 4, 1, P.DIM)
		"collector":
			for i in range(3):
				R.call(2, 8 - i * 3, 8, 2, [P.RED, P.CREAM, P.GOLD][i])
				R.call(2, 10 - i * 3, 8, 1, Color(0, 0, 0, 0.4))
		"gilded":
			R.call(1, 5, 10, 5, P.GOLD)
			R.call(3, 3, 6, 2, P.GOLD.lightened(0.3))
			R.call(2, 6, 2, 1, P.CREAM)
		"hot":
			R.call(4, 2, 4, 9, P.DANGER)
			R.call(2, 5, 8, 6, P.DANGER)
			R.call(4, 6, 4, 5, P.GOLD)
			R.call(5, 8, 2, 3, P.CREAM)
		"link":
			ci.draw_arc(c - Vector2(2.5, 0) * s, 3 * s, 0, TAU, 12, P.CYAN, 1.5 * s, false)
			ci.draw_arc(c + Vector2(2.5, 0) * s, 3 * s, 0, TAU, 12, P.CYAN, 1.5 * s, false)
		"double_felt":
			R.call(1, 4, 6, 6, P.FELT.lightened(0.3))
			R.call(5, 2, 6, 6, P.GOOD)
		"pinned":
			ci.draw_circle(c - Vector2(0, 2) * s, 3.5 * s, P.VIOLET, true, -1.0, false)
			R.call(5, 6, 2, 6, P.LINE)
		"la_partage":
			ci.draw_circle(c, 5 * s, P.CREAM, true, -1.0, false)
			R.call(6, 1, 5, 10, P.PANEL)
			R.call(6, 1, 1, 10, P.GOLD)
		"red_streak":
			for i in range(3):
				R.call(1 + i * 4, 8 - i * 3, 3, 3 + i * 3, P.RED.lightened(0.1 * i))
		"rent_control":
			R.call(2, 5, 8, 6, P.WOOD)
			R.call(3, 3, 6, 2, P.WOOD.lightened(0.2))
			R.call(5, 1, 2, 2, P.WOOD.lightened(0.2))
			R.call(5, 7, 2, 4, P.BLACK)
		"thirteen":
			ci.draw_circle(c, 5.5 * s, P.BLACK, true, -1.0, false)
			R.call(3, 4, 1, 4, P.GOLD)
			R.call(5, 4, 3, 1, P.GOLD)
			R.call(7, 5, 1, 1, P.GOLD)
			R.call(6, 6, 2, 1, P.GOLD)
			R.call(7, 7, 1, 1, P.GOLD)
			R.call(5, 8, 3, 1, P.GOLD)
		"en_prison":
			R.call(1, 1, 10, 10, P.PANEL_HI)
			for x in [2, 5, 8]:
				R.call(x, 1, 2, 10, P.DIM)
		"hot_hand":
			R.call(3, 4, 6, 7, Color("#d9a47a"))
			for x in [3, 5, 7]:
				R.call(x, 1, 2, 4, Color("#d9a47a"))
			R.call(9, 5, 2, 3, Color("#d9a47a"))
			R.call(2, 10, 8, 1, P.DANGER)
		"dealer_signature":
			R.call(2, 9, 9, 1, P.CREAM)
			for i in range(5):
				R.call(2 + i * 2, 6 - (i % 2) * 2, 2, 2, P.CREAM)
			R.call(9, 1, 2, 6, P.GOLD)
		"call_bets":
			ci.draw_arc(c, 5 * s, -PI, 0, 10, P.GOLD, 2.0 * s, false)
			R.call(5, 5, 2, 6, P.GOLD)
		"reroll":
			# Refresh symbol: an open circular arrow, arrowhead at the top right.
			ci.draw_arc(c, 4 * s, -PI * 0.1, PI * 1.5, 16, P.CREAM, 2.0 * s, false)
			var e := c + Vector2(0, -4) * s
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(0, -3) * s, e + Vector2(0, 3) * s, e + Vector2(3.5, 0) * s]), P.CREAM)
		"stack":
			for i in range(4):
				R.call(2, 9 - i * 2, 8, 2, [P.CREAM, P.RED, P.CREAM, P.RED][i])
		"cash":
			ci.draw_circle(c, 5.5 * s, P.GOLD, true, -1.0, false)
			R.call(5, 3, 2, 6, P.WOOD_DARK)
		"spin":
			ci.draw_circle(c, 4 * s, P.CREAM, true, -1.0, false)
			ci.draw_circle(c - Vector2(1, 1) * s, 1.5 * s, Color.WHITE, true, -1.0, false)
		_:
			ci.draw_circle(c, 5 * s, P.CREAM, true, -1.0, false)


static func _tiny(ci: CanvasItem, id: String, c: Vector2) -> void:
	var o := c - Vector2(2, 2)
	var col := P.BLACK
	match id:
		"magnet":
			ci.draw_rect(Rect2(o, Vector2(1, 4)), col)
			ci.draw_rect(Rect2(o + Vector2(3, 0), Vector2(1, 4)), col)
			ci.draw_rect(Rect2(o + Vector2(0, 3), Vector2(4, 1)), col)
		"compounding":
			ci.draw_rect(Rect2(o + Vector2(1, 0), Vector2(2, 4)), col)
			ci.draw_rect(Rect2(o + Vector2(0, 1), Vector2(4, 1)), col)
		"mint":
			ci.draw_rect(Rect2(o + Vector2(1, 0), Vector2(2, 4)), col)
		"respin":
			ci.draw_rect(Rect2(o, Vector2(4, 1)), col)
			ci.draw_rect(Rect2(o + Vector2(0, 3), Vector2(4, 1)), col)
			ci.draw_rect(Rect2(o + Vector2(3, 0), Vector2(1, 4)), col)
		"wildcard_zero":
			ci.draw_rect(Rect2(o, Vector2(4, 4)), col, false, 1.0)
		_:
			ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(2, 2)), col)


## A brass plaque background.
static func plaque(ci: CanvasItem, r: Rect2, dark: bool = false) -> void:
	var base := P.WOOD_DARK if dark else Color("#7a5a2a")
	ci.draw_rect(r, P.BLACK)
	ci.draw_rect(r.grow(-1), base)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), base.lightened(0.35))
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), base.darkened(0.4))
	for p in [r.position + Vector2(2, 2), Vector2(r.end.x - 4, r.position.y + 2),
			Vector2(r.position.x + 2, r.end.y - 4), r.end - Vector2(4, 4)]:
		ci.draw_rect(Rect2(p, Vector2(2, 2)), P.GOLD.darkened(0.2))


## Text with a 1px drop shadow.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, centered: bool = false) -> void:
	var p := pos
	if centered:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	p = p.round()
	ci.draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * col.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Centred neon lettering in the title font with a soft glow. `on` < 1 dims it (flicker).
static func neon(ci: CanvasItem, centre: Vector2, s: String, size: int, col: Color, alpha: float = 1.0, on: float = 1.0) -> void:
	var font := P.title_font()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := (centre - Vector2(w / 2.0, -size / 2.0)).round()
	var lit: Color = col.lerp(col.darkened(0.7), 1.0 - on)
	if on > 0.5:
		for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			ci.draw_string(font, p + d, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, 0.18 * alpha * on))
	ci.draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * alpha))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(lit, alpha))
