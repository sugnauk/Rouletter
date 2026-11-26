extends Control
## Pixel felt: draws every exposed bet area for the run's board, the chips on it, upgrades,
## hover and target highlights, and hit flashes. Emits clicks; it never changes run state itself.

signal bet_clicked(key: String, button: int)
signal bet_hovered(key: String)
signal bet_held(key: String)        ## touch: a long press on a square

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
var line_rects: Dictionary = {}  ## splits, streets, corners, six-lines: small zones on the felt lines
var hover_key: String = ""
var targets: Array = []          ## keys to highlight (upgrade placement)
var flashes: Dictionary = {}     ## key -> seconds left
var pops: Dictionary = {}        ## key -> seconds left (chip placed)
var nears: Dictionary = {}       ## key -> seconds left (near miss shudder)
var floaters: Array = []         ## {text, pos, t, col}
var cell_w: float = 24.0
var preview: Dictionary = {}     ## key -> Color: squares lit by a hover preview (what fires / where a chip pays)
var ring_keys: Dictionary = {}
var pinned: Dictionary = {}      ## pinned bet keys (a small pin on their chips)   ## bet keys that could clear the table on a hit (gold ring on their chips)
var marks := false               ## colour-blind aid: a diamond on every red square


const ZONE := 8.0               ## width of the clickable strip on a felt line (mouse)
const ZONE_TOUCH := 12.0        ## ...and on touch screens, where fingers need more room
const HOLD_TIME := 0.45         ## touch: holding a square this long opens its edit menu

var zone := ZONE
var press_key := ""             ## touch: square under the finger, pending tap vs hold
var press_t := 0.0


func layout() -> void:
	rects.clear()
	line_rects.clear()
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
	_layout_lines(B, cell_w)
	var h: float = y2 + STRIP_H * (3.0 if run.has_feature("call_bets") else 2.0)
	custom_minimum_size = Vector2(ZERO_W + grid_w + COL_W, h).ceil()
	size = custom_minimum_size
	queue_redraw()


## Clickable zones on the lines between squares: corners where four squares meet, splits on an
## edge, streets / six-lines on the edge against the dozens strip, and zero splits.
func _layout_lines(B, cw: float) -> void:
	zone = ZONE_TOUCH if DisplayServer.is_touchscreen_available() else ZONE
	var hz := zone / 2.0
	var floor_y := ROW_H * 3.0
	for c in range(B.cols):
		var b := c * 3 + 1
		var x0: float = ZERO_W + c * cw
		var xr: float = x0 + cw
		_zone("ST%d" % b, Rect2(x0 + hz, floor_y - hz, cw - zone, zone))
		if c < B.cols - 1:
			_zone("LN%d" % b, Rect2(xr - hz, floor_y - hz, zone, zone))
			for r in range(3):
				var top: float = (2 - r) * ROW_H
				_zone("SP%d_%d" % [b + r, b + r + 3], Rect2(xr - hz, top + hz, zone, ROW_H - zone))
				if r < 2:
					_zone("CO%d" % (b + r), Rect2(xr - hz, top - hz, zone, zone))
		for r in range(2):
			var edge: float = (2 - r) * ROW_H
			_zone("SP%d_%d" % [b + r, b + r + 1], Rect2(x0 + hz, edge - hz, cw - zone, zone))
	# Zero splits sit on the boundary between the zeros and the first column, one slot per zero.
	var nz: int = B.zeros.size()
	for i in range(nz):
		for j in range(3):
			var top: float = (2 - j) * ROW_H
			var slot: float = ROW_H / nz
			_zone("SP%d_%d" % [B.zeros[i], j + 1], Rect2(ZERO_W - hz, top + i * slot + (hz if nz == 1 else 0.0), zone, slot - (zone if nz == 1 else 0.0)))


func _zone(key: String, r: Rect2) -> void:
	if run.felt.board.has_bet(key):
		line_rects[key] = r


func rect_of(k: String) -> Rect2:
	if line_rects.has(k):
		return line_rects[k]
	return rects.get(k, Rect2(size / 2.0, Vector2.ZERO))


func flash(key: String, t: float = 0.8) -> void:
	flashes[key] = t


func near(key: String) -> void:
	nears[key] = 0.5


func pop(key: String) -> void:
	pops[key] = 0.25


func float_text(key: String, text: String, col: Color = P.GOLD) -> void:
	var r: Rect2 = rect_of(key)
	floaters.append({"text": text, "pos": r.get_center(), "t": 1.2, "col": col})


func _process(delta: float) -> void:
	if run != null and (not ring_keys.is_empty() or run.felt.perm_chips().any(func(c): return Content.rarity_of(c.kind) == "legendary")):
		queue_redraw()
	if press_key != "":
		press_t += delta
		if press_t >= HOLD_TIME:
			bet_held.emit(press_key)
			press_key = ""
	var dirty := false
	for d in [flashes, pops, nears]:
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
	elif event is InputEventMouseButton and DisplayServer.is_touchscreen_available() and event.button_index == MOUSE_BUTTON_LEFT:
		# Touch: a tap bets, a long hold opens the bet's edit menu (there's no right button or Shift).
		var k := key_at(event.position)
		if event.pressed:
			press_key = k
			press_t = 0.0
		elif press_key != "":
			if k == press_key:
				bet_clicked.emit(k, MOUSE_BUTTON_LEFT)
			press_key = ""
		accept_event()
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
	for k in line_rects:
		if line_rects[k].has_point(pos):
			return k
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
	var covered := {}
	if hover_key != "" and B.has_bet(hover_key) and B.is_line_bet(hover_key):
		for n in B.bet(hover_key).numbers:
			covered[Board.straight_key(n)] = true
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
		elif covered.has(k):
			bg = bg.lightened(0.14)
		if k in targets:
			bg = bg.lerp(P.CYAN, 0.45)
		if preview.has(k):
			bg = bg.lerp(preview[k], 0.42)
		if flashes.has(k):
			bg = bg.lerp(P.GOLD, clampf(flashes[k], 0.0, 0.7))
		if nears.has(k):
			bg = bg.lerp(P.DANGER, 0.5 * nears[k] / 0.5)
			r.position.x += round(sin(nears[k] * 60.0) * 1.5)
		var inner := r.grow(-1.0)
		draw_rect(inner, bg)
		# Felt nap: a sparse dither so the cloth doesn't read as flat UI.
		var seed := hash(k)
		for d in range(int(r.size.x * r.size.y / 40.0)):
			var px := r.position + Vector2(1 + (seed >> (d % 13)) % int(max(1.0, r.size.x - 2)), 1 + (seed * (d + 3) >> 4) % int(max(1.0, r.size.y - 2)))
			draw_rect(Rect2(px, Vector2(1, 1)), bg.darkened(0.12))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), bg.lightened(0.12))
		draw_rect(r, P.LINE.darkened(0.25), false, 1.0)
		if marks and Board.is_straight(k) and B.is_red(Board.straight_number(k)):
			var m := (r.position + Vector2(3, r.size.y - 4)).floor()
			draw_rect(Rect2(m + Vector2(1, 0), Vector2(1, 3)), P.CREAM)
			draw_rect(Rect2(m + Vector2(0, 1), Vector2(3, 1)), P.CREAM)
		# Upgrade markers.
		var up := ""
		if Board.is_straight(k):
			up = run.felt.square_upgrades.get(Board.straight_number(k), "")
		else:
			up = run.felt.bet_upgrades.get(k, "")
		if up != "":
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), _upgrade_color(up))
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var ty: float = r.position.y + (8.0 if Board.is_straight(k) else r.size.y - 4.0)
		var tcol: Color = P.CREAM if run.can_bet_on(k) or Board.is_straight(k) else P.DIM
		var tx: float = floor(r.get_center().x - tw / 2.0)
		if not Board.is_straight(k) and r.size.y <= STRIP_H + 1.0 and not run.felt.chips_on(k).is_empty():
			tx = r.position.x + 3.0  # make room for the chips on the right of a strip
		draw_string(font, Vector2(tx, floor(ty)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, tcol)
		_draw_chips(k, r, font)
	_draw_line_zones(font)
	for f in floaters:
		var a: float = clampf(f.t, 0.0, 1.0)
		var w := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT).x
		var pos: Vector2 = (f.pos - Vector2(w / 2.0, 0)).floor()
		draw_string(font, pos + Vector2(1, 1), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT, Color(0, 0, 0, a))
		draw_string(font, pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT, Color(f.col, a))


func _draw_line_zones(font: Font) -> void:
	for k in line_rects:
		var r: Rect2 = line_rects[k]
		if k == hover_key:
			draw_rect(r, Color(P.GOLD, 0.45))
			draw_rect(r, P.GOLD, false, 1.0)
		elif preview.has(k):
			draw_rect(r, Color(preview[k], 0.55))
		elif run.felt.chips_on(k).is_empty():
			draw_rect(Rect2(r.get_center().floor() - Vector2(1, 1), Vector2(2, 2)), Color(P.CREAM, 0.3))
		if flashes.has(k):
			draw_rect(r, Color(P.GOLD, clampf(flashes[k], 0.0, 0.7)))
	for k in line_rects:
		_draw_chips(k, line_rects[k], font)


## Chips on a bet area: a bet stack (count printed on the chip) and up to two permanent chips,
## fanned out so counts never fight the square's own label.
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
	var entries := []
	if bet_total > 0:
		entries.append({"col": Art.denom_color(bet_total), "kind": "bet", "value": bet_total, "frozen": false})
	for c in perms.slice(0, 2):
		entries.append({"col": P.chip_color(c.kind), "kind": c.kind, "value": c.value, "frozen": c.id == run.felt.frozen_id, "mod": c.mod})
	var is_line := line_rects.has(k)
	var rad := 5.0 if (is_line or r.size.y <= STRIP_H + 1.0 or not Board.is_straight(k)) else 6.0
	var scale: float = 1.0 + (pops.get(k, 0.0) * 1.6)
	var n := entries.size()
	var spacing := minf(2.0 * rad - 1.0, (r.size.x - 2.0 * rad - 2.0) / maxf(1.0, n - 1.0)) if not is_line else 6.0
	spacing = maxf(spacing, 5.0)
	var first: Vector2   # centre of the first chip; the rest fan out to the right
	if is_line:
		first = r.get_center() - Vector2((n - 1) * spacing / 2.0, 0)
	elif Board.is_straight(k):
		first = Vector2(r.get_center().x - (n - 1) * spacing / 2.0, r.end.y - 7.0)
	elif r.size.y <= STRIP_H + 1.0:
		first = Vector2(r.end.x - 7.0 - (n - 1) * spacing, r.get_center().y)  # strips: chips hug the right edge
	else:
		first = Vector2(r.get_center().x - (n - 1) * spacing / 2.0, r.position.y + 7.0)  # columns: chips above the label
	var fp := first.floor()
	if ring_keys.has(k):
		var g := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		draw_arc(fp, rad + 2.5, 0, TAU, 18, Color(P.GOLD, 0.5 + 0.5 * g), 1.0, false)
	if pinned.has(k):
		draw_rect(Rect2(fp + Vector2(rad - 2, -rad - 5), Vector2(1, 4)), P.CREAM)
		draw_circle(fp + Vector2(rad - 1.5, -rad - 5), 1.8, P.RED, true, -1.0, false)
	for i in range(n):
		var e: Dictionary = entries[i]
		var p := (first + Vector2(i * spacing, 0)).floor()
		Art.chip(self, p, rad * scale, e.col, e.kind, 0, e.frozen)
		if e.get("mod", "") != "":
			# A refined chip: a small diamond on its rim (cyan Focused, green Steady).
			var mc: Color = P.CYAN if e.mod == "focused" else P.GOOD
			var mp := p + Vector2(-rad, -rad + 1)
			draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -2), mp + Vector2(2, 0), mp + Vector2(0, 2), mp + Vector2(-2, 0)]), mc)
		# Shine, and a slow gold halo on legendary chips.
		draw_rect(Rect2(p + Vector2(-rad * 0.5, -rad * 0.6), Vector2(2, 1)), Color(1, 1, 1, 0.55))
		if e.kind != "bet" and Content.rarity_of(e.kind) == "legendary":
			var g := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			draw_arc(p, rad + 1.5, 0, TAU, 16, Color(P.GOLD, 0.35 + 0.45 * g), 1.0, false)
		var v: int = e.value
		if v > 1 or e.kind == "bet":
			var txt := str(v) if v < 100 else "99+"
			var dark: bool = Color(e.col).get_luminance() > 0.45
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT_SMALL).x
			draw_string(font, p + Vector2(-floor(tw / 2.0), 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FONT_SMALL, P.BLACK if dark else P.CREAM)


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
		"diamond":
			return Color("#9ad7ff")
		"magnetized":
			return P.RED
		"twin_square", "spoke":
			return P.CYAN.darkened(0.2)
		"gold_trim", "lamp", "sweet_spot":
			return P.GOLD
		"fat_box", "repeat_box", "silk":
			return Color("#c08ad8")
		"lucky_colour":
			return P.GOOD
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
	if B.has_bet(k) and B.is_line_bet(k):
		var names := []
		for n in B.bet(k).numbers:
			names.append(B.label(n))
		var kind: String = {"split": "Split", "street": "Street", "corner": "Corner", "line": "Line"}[B.bet(k).type]
		return "%s %s" % [kind, "/".join(names)]
	return k.capitalize()


## Centre of a bet area in global coordinates (respects zoom and the centred frame).
func key_global(k: String) -> Vector2:
	return get_global_transform() * key_center(k)


## Centre of a bet area in this control's coordinates (for FX).
func key_center(k: String) -> Vector2:
	return rect_of(k).get_center()


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
		s += "  |  %s%s x%d%s" % ["" if c.flaw == "" else Content.FLAWS[c.flaw].name + " ", "Bet" if c.is_bet() else Content.CHIPS[c.kind].name, c.value,
			(" (%d stacked)" % c.copies) if c.copies > 1 else ""]
	if not Board.is_straight(k) and not B.is_line_bet(k) and not run.can_bet_on(k):
		s += "  (closed)"
	return s
