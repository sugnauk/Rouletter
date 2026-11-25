extends Control
## Pixel felt: draws every exposed bet area for the run's board, the chips on it, upgrades,
## hover and target highlights, and hit flashes. Emits clicks; it never changes run state itself.

signal bet_clicked(key: String, button: int)
signal bet_hovered(key: String)

const P := preload("res://scenes/ui/palette.gd")
const Board := preload("res://core/board.gd")
const Content := preload("res://core/content.gd")
const Art := preload("res://scenes/ui/art.gd")

const GRID_W := 288.0
const ROW_H := 22.0
const STRIP_H := 15.0
const ZERO_W := 20.0
const COL_W := 22.0

var run
var rects: Dictionary = {}
var hover_key: String = ""
var targets: Array = []          ## keys to highlight (upgrade placement)
var flashes: Dictionary = {}     ## key -> seconds left
var pops: Dictionary = {}        ## key -> seconds left (chip placed)
var floaters: Array = []         ## {text, pos, t, col}
var cell_w: float = 24.0


func layout() -> void:
	rects.clear()
	var B = run.felt.board
	cell_w = minf(40.0, floor(GRID_W / B.cols))
	var grid_w: float = cell_w * B.cols
	var nz: int = B.zeros.size()
	var zh: float = ROW_H * 3.0 / nz
	for i in range(nz):
		rects[Board.straight_key(B.zeros[i])] = Rect2(0, i * zh, ZERO_W, zh)
	for n in range(1, B.numbers + 1):
		var x: float = ZERO_W + Board.grid_col(n) * cell_w
		var y: float = (2 - Board.grid_row(n)) * ROW_H
		rects[Board.straight_key(n)] = Rect2(x, y, cell_w, ROW_H)
	for r in range(3):
		rects["COL%d" % (r + 1)] = Rect2(ZERO_W + grid_w, (2 - r) * ROW_H, COL_W, ROW_H)
	var y2 := ROW_H * 3.0
	for d in range(3):
		rects["DOZ%d" % (d + 1)] = Rect2(ZERO_W + d * grid_w / 3.0, y2, grid_w / 3.0, STRIP_H)
	var evens := ["LOW", "EVEN", "RED", "BLACK", "ODD", "HIGH"]
	for i in range(6):
		rects[evens[i]] = Rect2(ZERO_W + i * grid_w / 6.0, y2 + STRIP_H, grid_w / 6.0, STRIP_H)
	if run.has_feature("call_bets"):
		var calls := ["VOI", "TIE", "ORP"]
		for i in range(3):
			rects[calls[i]] = Rect2(ZERO_W + i * grid_w / 3.0, y2 + STRIP_H * 2.0, grid_w / 3.0, STRIP_H)
	var h: float = y2 + STRIP_H * (3.0 if run.has_feature("call_bets") else 2.0)
	custom_minimum_size = Vector2(ZERO_W + grid_w + COL_W, h).ceil()
	size = custom_minimum_size
	queue_redraw()


func flash(key: String, t: float = 0.8) -> void:
	flashes[key] = t


func pop(key: String) -> void:
	pops[key] = 0.25


func float_text(key: String, text: String, col: Color = P.GOLD) -> void:
	var r: Rect2 = rects.get(key, Rect2(size / 2.0, Vector2.ZERO))
	floaters.append({"text": text, "pos": r.get_center(), "t": 1.2, "col": col})


func _process(delta: float) -> void:
	var dirty := false
	for d in [flashes, pops]:
		for k in d.keys():
			d[k] -= delta
			dirty = true
			if d[k] <= 0.0:
				d.erase(k)
	for f in floaters:
		f.t -= delta
		f.pos.y -= delta * 14.0
		dirty = true
	floaters = floaters.filter(func(f): return f.t > 0.0)
	if dirty:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var k := key_at(event.position)
		if k != hover_key:
			hover_key = k
			bet_hovered.emit(k)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var k := key_at(event.position)
		if k != "":
			bet_clicked.emit(k, event.button_index)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover_key != "":
		hover_key = ""
		bet_hovered.emit("")
		queue_redraw()


func key_at(pos: Vector2) -> String:
	for k in rects:
		if rects[k].has_point(pos):
			return k
	return ""


func _draw() -> void:
	if run == null or rects.is_empty():
		return
	var B = run.felt.board
	var font := P.font()
	draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), P.WOOD_DARK)
	draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), P.WOOD)
	for k in rects:
		var r: Rect2 = rects[k]
		var bg: Color = P.FELT
		var text := ""
		var fsize := P.FONT_SMALL
		if Board.is_straight(k):
			var n := Board.straight_number(k)
			bg = P.GREEN if n <= 0 else (P.RED if B.is_red(n) else P.BLACK)
			text = B.label(n)
			fsize = P.FONT
		else:
			text = _outside_name(k)
			if not run.can_bet_on(k):
				bg = P.FELT_DARK
		if k == hover_key:
			bg = bg.lightened(0.18)
		if k in targets:
			bg = bg.lerp(P.CYAN, 0.45)
		if flashes.has(k):
			bg = bg.lerp(P.GOLD, clampf(flashes[k], 0.0, 0.7))
		var inner := r.grow(-1.0)
		draw_rect(inner, bg)
		# Felt nap: a sparse dither so the cloth doesn't read as flat UI.
		var seed := hash(k)
		for d in range(int(r.size.x * r.size.y / 40.0)):
			var px := r.position + Vector2(1 + (seed >> (d % 13)) % int(max(1.0, r.size.x - 2)), 1 + (seed * (d + 3) >> 4) % int(max(1.0, r.size.y - 2)))
			draw_rect(Rect2(px, Vector2(1, 1)), bg.darkened(0.12))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), bg.lightened(0.12))
		draw_rect(r, P.LINE.darkened(0.25), false, 1.0)
		# Upgrade markers.
		var up := ""
		if Board.is_straight(k):
			up = run.felt.square_upgrades.get(Board.straight_number(k), "")
		else:
			up = run.felt.bet_upgrades.get(k, "")
		if up != "":
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), _upgrade_color(up))
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var ty: float = r.position.y + (9.0 if Board.is_straight(k) else r.size.y - 4.0)
		var tcol: Color = P.CREAM if run.can_bet_on(k) or Board.is_straight(k) else P.DIM
		draw_string(font, Vector2(floor(r.get_center().x - tw / 2.0), floor(ty)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, tcol)
		_draw_chips(k, r, font)
	for f in floaters:
		var a: float = clampf(f.t, 0.0, 1.0)
		var w := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT).x
		var pos: Vector2 = (f.pos - Vector2(w / 2.0, 0)).floor()
		draw_string(font, pos + Vector2(1, 1), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT, Color(0, 0, 0, a))
		draw_string(font, pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT, Color(f.col, a))


func _draw_chips(k: String, r: Rect2, font: Font) -> void:
	var chips: Array = run.felt.chips_on(k)
	if chips.is_empty():
		return
	var bet_total := 0
	var perms := []
	for c in chips:
		if c.is_bet():
			bet_total += c.value
		else:
			perms.append(c)
	var base := Vector2(r.end.x - 7.0, r.end.y - 7.0).floor()
	var scale: float = 1.0 + (pops.get(k, 0.0) * 1.6)
	var i := 0
	for c in perms:
		var p := base - Vector2(i * 8, 0)
		Art.chip(self, p, 5.0 * scale, P.chip_color(c.kind), c.kind, 0, c.id == run.felt.frozen_id)
		if c.value > 1:
			_tiny(font, p + Vector2(-2, -6), str(c.value))
		i += 1
		if i >= 2:
			break
	if bet_total > 0:
		# A physical stack: one chip per denomination step, coloured like casino chips.
		var p2 := Vector2(r.position.x + 7.0, r.end.y - 7.0).floor()
		var layers := mini(4, 1 + bet_total / 5)
		for l in range(layers):
			Art.chip(self, p2 - Vector2(0, l * 2), 5.0 * scale, Art.denom_color(bet_total))
		_tiny(font, p2 + Vector2(5, -5 - layers * 2), str(bet_total))


func _coin(p: Vector2, rad: float, col: Color, frozen: bool) -> void:
	draw_circle(p + Vector2(0, 1), rad, col.darkened(0.5), true, -1.0, false)
	draw_circle(p, rad, col, true, -1.0, false)
	draw_circle(p, rad - 1.5, col.lightened(0.25), false, 1.0, false)
	if frozen:
		draw_line(p - Vector2(rad, rad), p + Vector2(rad, rad), P.CYAN, 1.0, false)
		draw_line(p + Vector2(-rad, rad), p + Vector2(rad, -rad), P.CYAN, 1.0, false)


func _tiny(font: Font, p: Vector2, s: String) -> void:
	draw_string(font, p.floor() + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT_SMALL, Color(0, 0, 0, 0.8))
	draw_string(font, p.floor(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT_SMALL, P.CREAM)


func _upgrade_color(up: String) -> Color:
	match up:
		"gilded":
			return P.GOLD
		"hot":
			return P.DANGER
		"link":
			return P.CYAN
		"double_felt":
			return P.GOOD
		"pinned":
			return P.VIOLET
	return P.CREAM


func _outside_name(k: String) -> String:
	var B = run.felt.board
	match k:
		"COL1", "COL2", "COL3":
			return "2:1"
		"DOZ1", "DOZ2", "DOZ3":
			var t: int = B.numbers / 3
			var d := int(k.substr(3)) - 1
			return "%d-%d" % [d * t + 1, (d + 1) * t]
		"LOW":
			return "1-%d" % (B.numbers / 2)
		"HIGH":
			return "%d-%d" % [B.numbers / 2 + 1, B.numbers]
		"VOI":
			return "Voisins"
		"TIE":
			return "Tiers"
		"ORP":
			return "Orphelins"
	return k.capitalize()


## Centre of a bet area in this control's coordinates (for FX).
func key_center(k: String) -> Vector2:
	return rects.get(k, Rect2(size / 2.0, Vector2.ZERO)).get_center()


## One-line description of a bet area for the status bar.
func describe(k: String) -> String:
	if k == "":
		return ""
	var B = run.felt.board
	var b: Dictionary = B.bet(k)
	var payout: float = b.payout
	var ptxt := str(int(payout)) if is_equal_approx(payout, round(payout)) else "%.2f" % payout
	var s := "%s  pays %s:1" % [B.label(Board.straight_number(k)) if Board.is_straight(k) else _outside_name(k), ptxt]
	var up := ""
	if Board.is_straight(k):
		up = run.felt.square_upgrades.get(Board.straight_number(k), "")
	else:
		up = run.felt.bet_upgrades.get(k, "")
	if up != "":
		s += "  |  " + Content.UPGRADES[up].name
	for c in run.felt.chips_on(k):
		s += "  |  %s x%d" % ["Bet" if c.is_bet() else Content.CHIPS[c.kind].name, c.value]
	if not Board.is_straight(k) and not run.can_bet_on(k):
		s += "  (closed)"
	return s
