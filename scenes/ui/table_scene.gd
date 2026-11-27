extends Control
## The home screen's live table: a roulette table seen over the shoulder, in chunky pixel 3D.
## Everything is drawn in code into a small SubViewport (320x180, or 180x150 on a phone held
## upright) and shown at 2x with nearest filtering, so it reads as low-res pixel art.
##
## A simple pinhole camera (proj) looks down the felt to the wheel at the far end. Every ~9s:
## the wheel spins and the ball drops into a pocket, a marker pops over the wheel, the winning
## square glows, the croupier's rake sweeps the losing stacks away, a payout slides onto the
## winner, and the chips are set out again. Pendant lamps, bokeh, smoke and a slow camera drift
## keep it alive in between.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Board := preload("res://core/board.gd")

const LOOP := 9.0
const RED := Color("#b8262d")
const BLACK := Color("#1b1a1f")
const GREEN := Color("#1f7a3e")
const FELT := Color("#155c36")
const WOOD := Color("#6b4423")
const WOOD_DARK := Color("#3a2414")
const WARM := Color(1.0, 0.82, 0.5)

var vp: SubViewport
var canvas: Control
var shown: TextureRect
var board
var order: Array = []
var t := 0.0
var res := Vector2i(320, 180)
var focus_x := 0.68           ## where the table sits across the picture (0..1)
var _cam := Vector3.ZERO
var _f := 150.0
var _bokeh: Array = []
var _motes: Array = []
var _stacks: Array = []       ## {x, z, n, col, win}: this round's chips
var _round := -1
var _win := 0                  ## the winning pocket this round


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board = Board.new("european")
	order = board.order
	vp = SubViewport.new()
	vp.size = res
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	canvas = Control.new()
	canvas.size = Vector2(res)
	canvas.draw.connect(_draw_scene)
	vp.add_child(canvas)
	shown = TextureRect.new()
	shown.texture = vp.get_texture()
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shown)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1974
	for i in range(26):
		_bokeh.append({"x": rng.randf(), "y": rng.randf_range(0.05, 0.42), "r": rng.randf_range(2.0, 7.0),
			"c": [Color("#ffb347"), Color("#ff6b6b"), Color("#ffd98a"), Color("#7fd1ff")][rng.randi() % 4], "ph": rng.randf() * TAU})
	for i in range(22):
		_motes.append({"x": rng.randf(), "y": rng.randf(), "v": rng.randf_range(0.01, 0.03), "ph": rng.randf() * TAU})
	set_size_px(Vector2(640, 360), Vector2i(320, 180), 0.68)


## Show the scene at `px` on screen, rendered at `r` pixels (2x upscale), table at `fx` across.
func set_size_px(px: Vector2, r: Vector2i, fx: float) -> void:
	res = r
	focus_x = fx
	vp.size = r
	canvas.size = Vector2(r)
	size = px
	shown.size = px
	shown.position = Vector2.ZERO
	_f = r.y * 1.05


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	for m in _motes:
		m.y -= m.v * delta
		if m.y < 0.0:
			m.y = 1.0
	var rnd := int(t / LOOP)
	if rnd != _round:
		_new_round(rnd)
	canvas.queue_redraw()


## Set out the chips for a round: three losing stacks and one on the number that will win.
func _new_round(rnd: int) -> void:
	_round = rnd
	_win = order[(rnd * 13 + 5) % order.size()]
	_stacks.clear()
	var spots := [[0, 1], [2, 4], [1, 7], [0, 10], [2, 2], [1, 9]]
	for i in range(3):
		var sp: Array = spots[(rnd + i * 2) % spots.size()]
		var n: int = sp[1] * 3 + sp[0] + 1
		if n == _win:
			continue
		_stacks.append({"n": n, "h": 2 + (rnd + i) % 4, "col": Art.denom_color([1, 5, 10, 25][(rnd + i) % 4]), "win": false})
	if _win > 0:
		_stacks.append({"n": _win, "h": 3, "col": Art.denom_color(5), "win": true})


# --- Camera -------------------------------------------------------------------------------

## World to screen: x across the table, y up, z down its length (the wheel is far away).
func proj(p: Vector3) -> Vector2:
	var r := p - _cam
	var d := maxf(0.25, r.z)
	return Vector2(res.x * focus_x + _f * r.x / d, res.y * 0.36 - _f * r.y / d)


func _depth(p: Vector3) -> float:
	return maxf(0.25, (p - _cam).z)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([proj(a), proj(b), proj(c), proj(d)]), col)


## A flat disc lying on the table (chips, light pools): an ellipse from its projected size.
func _disc(c: Vector3, r: float, col: Color, segs: int = 12) -> void:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a := TAU * i / segs
		pts.append(proj(c + Vector3(cos(a) * r, 0, sin(a) * r)))
	canvas.draw_colored_polygon(pts, col)


# --- Drawing ------------------------------------------------------------------------------

func _draw_scene() -> void:
	var W := float(res.x)
	var H := float(res.y)
	_cam = Vector3(0.3 * sin(t * 0.13), 2.25 + 0.08 * sin(t * 0.21), -0.6 + 0.25 * sin(t * 0.09))
	var ph: float = fmod(t, LOOP)
	_draw_room(W, H)
	_draw_table(ph)
	_draw_lamps()
	_draw_wheel(ph)
	_draw_chips(ph)
	_draw_rake(ph)
	_draw_front(W, H)


## The room behind: warm dark wall bands, out-of-focus lights, a faint neon sign.
func _draw_room(W: float, H: float) -> void:
	var bands := [Color("#120a0a"), Color("#170d0c"), Color("#1c100d"), Color("#21130f"), Color("#1a0f0c")]
	for i in range(bands.size()):
		canvas.draw_rect(Rect2(0, H * i / bands.size(), W, H / bands.size() + 1), bands[i])
	for b in _bokeh:
		var a := 0.16 + 0.08 * sin(t * 0.8 + b.ph)
		var c := Vector2(b.x * W, b.y * H)
		canvas.draw_circle(c, b.r, Color(b.c, a * 0.5), true, -1.0, false)
		canvas.draw_circle(c, b.r * 0.6, Color(b.c, a), true, -1.0, false)
	var on: bool = not (fmod(t, 6.1) > 5.8 and fmod(t * 18.0, 2.0) > 1.0)
	var sx := W * focus_x
	var font := P.font()
	var txt := "GILDED ACE"
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var col := Color("#ff7aa8") if on else Color("#5a2a3a")
	if on:
		canvas.draw_rect(Rect2(sx - tw / 2.0 - 4, 6, tw + 8, 13), Color(col, 0.10))
	canvas.draw_string(font, Vector2(sx - tw / 2.0, 16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col, 0.75))


## The table: rail, felt, the betting grid with its numbers' colours, and lamplight on the felt.
func _draw_table(ph: float) -> void:
	# Rail (wood) under the felt, then the felt.
	_quad(Vector3(-2.7, 0.0, 0.4), Vector3(2.7, 0.0, 0.4), Vector3(2.7, 0.0, 12.2), Vector3(-2.7, 0.0, 12.2), WOOD)
	_quad(Vector3(-2.7, -0.4, 0.4), Vector3(2.7, -0.4, 0.4), Vector3(2.7, 0.0, 0.4), Vector3(-2.7, 0.0, 0.4), WOOD_DARK)
	_quad(Vector3(-2.35, 0.0, 0.8), Vector3(2.35, 0.0, 0.8), Vector3(2.35, 0.0, 11.6), Vector3(-2.35, 0.0, 11.6), FELT)
	# Lamplight pools, banded like dithered light.
	for lz in [5.0, 8.4]:
		for i in range(3):
			_disc(Vector3(0, 0.001, lz), 2.2 - i * 0.6, Color(WARM, 0.05 + i * 0.03), 16)
	# The grid: 12 rows of 3 along the table, the zero at the far end, a dozens strip beside it.
	for row in range(12):
		for c in range(3):
			var n: int = row * 3 + c + 1
			var x0 := -1.2 + c * 0.8
			var z0 := 1.6 + row * 0.45
			var col: Color = RED if board.is_red(n) else BLACK
			if n == _win and ph > 4.2:
				col = col.lerp(P.GOLD, 0.5 + 0.4 * sin(t * 10.0))
			_quad(Vector3(x0 + 0.04, 0.002, z0 + 0.03), Vector3(x0 + 0.76, 0.002, z0 + 0.03),
				Vector3(x0 + 0.76, 0.002, z0 + 0.42), Vector3(x0 + 0.04, 0.002, z0 + 0.42), col)
	_quad(Vector3(-1.16, 0.002, 7.03), Vector3(1.16, 0.002, 7.03), Vector3(1.16, 0.002, 7.5), Vector3(-1.16, 0.002, 7.5), GREEN)
	for d in range(3):
		var z0 := 1.6 + d * 1.8
		_quad(Vector3(1.28, 0.002, z0 + 0.04), Vector3(1.9, 0.002, z0 + 0.04), Vector3(1.9, 0.002, z0 + 1.74), Vector3(1.28, 0.002, z0 + 1.74), FELT.lightened(0.08))
	# A gold line round the grid.
	var gl := Color(P.GOLD, 0.5)
	for e in [[Vector3(-1.2, 0.003, 1.6), Vector3(-1.2, 0.003, 7.5)], [Vector3(1.2, 0.003, 1.6), Vector3(1.2, 0.003, 7.5)],
			[Vector3(-1.2, 0.003, 1.6), Vector3(1.9, 0.003, 1.6)]]:
		canvas.draw_line(proj(e[0]), proj(e[1]), gl, 1.0)


## Pendant lamps over the table: a cord, a green glass shade, a warm glow under it.
func _draw_lamps() -> void:
	for lz in [5.0, 8.4]:
		var sw := 0.05 * sin(t * 0.9 + lz)
		var top := proj(Vector3(sw, 6.0, lz))
		var at := Vector3(sw, 3.4, lz)
		var s := proj(at)
		canvas.draw_line(top, s, Color("#0a0606"), 1.0)
		var w: float = _f * 0.55 / _depth(at)
		var h: float = maxf(3.0, w * 0.45)
		canvas.draw_colored_polygon(PackedVector2Array([s + Vector2(-w * 0.35, 0), s + Vector2(w * 0.35, 0), s + Vector2(w * 0.6, h), s + Vector2(-w * 0.6, h)]), Color("#1f5a3a"))
		canvas.draw_rect(Rect2(s.x - w * 0.6, s.y + h - 1, w * 1.2, 1), Color("#3d8a5c"))
		canvas.draw_rect(Rect2(s.x - w * 0.45, s.y + h, w * 0.9, 1), Color(1.0, 0.92, 0.65, 0.9))
		# The cone of light down to the felt.
		var f1 := proj(Vector3(sw - 1.3, 0.0, lz))
		var f2 := proj(Vector3(sw + 1.3, 0.0, lz))
		canvas.draw_colored_polygon(PackedVector2Array([s + Vector2(-w * 0.5, h), s + Vector2(w * 0.5, h), f2, f1]), Color(WARM, 0.045))


## The wheel at the far end: a wooden bowl, pockets turning, a chrome turret, and the ball.
func _draw_wheel(ph: float) -> void:
	var c := Vector3(0.0, 0.05, 9.3)
	# Wheel angle: fast then slowing, and a slow drift while it rests.
	var wa: float
	if ph < 4.0:
		wa = 2.4 * ph - 0.25 * ph * ph
	else:
		wa = 2.4 * 4.0 - 0.25 * 16.0 + (ph - 4.0) * 0.25
	wa += _round * 1.3
	_disc(c + Vector3(0, -0.02, 0), 2.35, WOOD_DARK, 24)
	_disc(c, 2.2, WOOD, 28)
	var n := order.size()
	for i in range(n):
		var a0 := wa + TAU * i / n
		var a1 := wa + TAU * (i + 1) / n
		var p: int = order[i]
		var col: Color = GREEN if p <= 0 else (RED if board.is_red(p) else BLACK)
		_quad(c + Vector3(cos(a0) * 1.3, 0.01, sin(a0) * 1.3), c + Vector3(cos(a1) * 1.3, 0.01, sin(a1) * 1.3),
			c + Vector3(cos(a1) * 1.88, 0.01, sin(a1) * 1.88), c + Vector3(cos(a0) * 1.88, 0.01, sin(a0) * 1.88), col)
	_disc(c + Vector3(0, 0.02, 0), 1.3, Color("#4a2e18"), 20)
	_disc(c + Vector3(0, 0.03, 0), 0.7, Color("#6b4423"), 14)
	# The turret: a chrome post with a glint that turns with the wheel.
	var tb := proj(c + Vector3(0, 0.03, 0))
	var tt := proj(c + Vector3(0, 0.6, 0))
	canvas.draw_line(tb, tt, Color("#c9ccd6"), 2.0)
	var g := proj(c + Vector3(cos(wa) * 0.3, 0.3, sin(wa) * 0.3))
	canvas.draw_line(tt, g, Color("#e6e9f0"), 1.0)
	canvas.draw_rect(Rect2(tt - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
	# The ball: round the rim against the spin, spiralling in, then riding its pocket.
	var bp: Vector3
	var win_i: int = order.find(_win)
	if ph < 3.0:
		var ba := -3.6 * ph + 0.3 * ph * ph
		bp = c + Vector3(cos(ba) * 2.08, 0.1, sin(ba) * 2.08)
	elif ph < 4.0:
		var k := ph - 3.0
		var ba2 := -3.6 * 3.0 + 0.3 * 9.0 - 2.0 * k
		var target := wa + TAU * (win_i + 0.5) / n
		var a := lerp_angle(ba2, target, k * k)
		var rr := lerpf(2.08, 1.6, k)
		bp = c + Vector3(cos(a) * rr, 0.08 + absf(sin(k * 18.0)) * 0.12 * (1.0 - k), sin(a) * rr)
	else:
		var a2 := wa + TAU * (win_i + 0.5) / n
		bp = c + Vector3(cos(a2) * 1.6, 0.06, sin(a2) * 1.6)
	var bs := proj(bp)
	canvas.draw_rect(Rect2(bs - Vector2(1, 1), Vector2(3, 2)), Color("#f4f1e8"))
	canvas.draw_rect(Rect2(bs - Vector2(1, 1), Vector2(1, 1)), Color.WHITE)
	# The result marker pops up over the wheel once the ball has settled.
	if ph > 4.2 and ph < 8.6:
		var up := proj(c + Vector3(0, 1.5 + 0.1 * sin(t * 4.0), 0))
		var mc: Color = GREEN if _win <= 0 else (RED if board.is_red(_win) else BLACK)
		var font := P.font()
		var lab := str(_win)
		var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var box := Rect2(up.x - lw / 2.0 - 3, up.y - 7, lw + 6, 11)
		canvas.draw_rect(box.grow(1), P.GOLD)
		canvas.draw_rect(box, mc)
		canvas.draw_string(font, Vector2(box.position.x + 3, box.position.y + 9), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, P.CREAM)


func _square_centre(n: int) -> Vector3:
	var row := (n - 1) / 3
	var c := (n - 1) % 3
	return Vector3(-0.8 + c * 0.8, 0.0, 1.6 + row * 0.45 + 0.22)


## Chip stacks: discs piled up, each with a light rim. Losers get raked away; the winner is paid.
func _draw_chips(ph: float) -> void:
	var rake_z := _rake_z(ph)
	var fade: float = 1.0 - clampf((ph - 8.5) / 0.5, 0.0, 1.0)
	for s in _stacks:
		var p := _square_centre(s.n)
		var h: int = s.h
		if not s.win and ph > 5.4 and rake_z < 99.0 and p.z <= rake_z:
			p.z = rake_z   # swept along in front of the rake
			p.x = lerpf(p.x, 0.0, clampf((ph - 5.4) / 2.0, 0.0, 1.0))
		if not s.win and ph > 7.5:
			continue
		if s.win and ph > 6.8:
			h += int(clampf((ph - 6.8) / 0.12, 0.0, 6.0))   # the payout piles on
		for i in range(h):
			var q := p + Vector3(0, 0.07 * i, 0)
			_disc(q + Vector3(0, -0.02, 0), 0.2, Color(s.col.darkened(0.55), fade), 10)
			_disc(q, 0.2, Color(s.col, fade), 10)
			var e1 := proj(q + Vector3(-0.2, 0, 0))
			canvas.draw_rect(Rect2(e1 + Vector2(1, 0), Vector2(1, 1)), Color(1, 1, 1, 0.6 * fade))
		var top := p + Vector3(0, 0.07 * h, 0)
		_disc(top, 0.12, Color(s.col.lightened(0.3), fade), 8)
		if s.win and ph > 4.2 and ph < 8.5:
			var ts := proj(top + Vector3(0, 0.15, 0))
			var g := 0.5 + 0.5 * sin(t * 8.0)
			canvas.draw_rect(Rect2(ts - Vector2(0, 2 + g * 2), Vector2(1, 1)), Color(P.GOLD, 0.8))


## Where the rake head is along the table (99 = not out).
func _rake_z(ph: float) -> float:
	if ph < 5.0 or ph > 7.8:
		return 99.0
	var k := clampf((ph - 5.0) / 2.4, 0.0, 1.0)
	return lerpf(1.2, 7.4, k * k * (3.0 - 2.0 * k))


## The croupier's arm and rake, reaching in from the right.
func _draw_rake(ph: float) -> void:
	var rz := _rake_z(ph)
	var head_z: float = rz if rz < 99.0 else 8.6
	var reach: float = 1.0 if rz < 99.0 else 0.0
	var head := Vector3(lerpf(1.4, 0.2, reach), 0.04, head_z)
	var hand := Vector3(2.9, 1.0, head_z - 1.6 + (1.0 - reach) * 0.8)
	var hs := proj(head)
	var hn := proj(hand)
	canvas.draw_line(hs, hn, Color("#c8a46a"), 1.0)
	var a := proj(head + Vector3(-0.45, 0, 0))
	var b := proj(head + Vector3(0.45, 0, 0))
	canvas.draw_line(a, b, Color("#d8b47a"), 2.0)
	# Sleeve: a black dinner jacket with a white cuff, coming in off the right edge.
	var elbow := Vector2(res.x - 14, hn.y + 18)
	var jacket := Color("#14111a")
	canvas.draw_colored_polygon(PackedVector2Array([hn + Vector2(1, -3), hn + Vector2(5, 3), elbow + Vector2(6, 8), elbow + Vector2(-5, -2)]), jacket)
	canvas.draw_colored_polygon(PackedVector2Array([elbow + Vector2(-5, -2), elbow + Vector2(6, 8), Vector2(res.x + 2, res.y * 0.9), Vector2(res.x + 2, elbow.y - 10)]), jacket)
	canvas.draw_line(hn + Vector2(1, -3), elbow + Vector2(-5, -2), Color("#2a2433"), 1.0)
	canvas.draw_rect(Rect2(hn - Vector2(2, 3), Vector2(5, 5)), Color("#e8e0d0"))
	canvas.draw_rect(Rect2(hn - Vector2(3, 1), Vector2(3, 3)), Color("#d9a47a"))


## Foreground: the near rail out of focus, smoke, and a soft vignette.
func _draw_front(W: float, H: float) -> void:
	for m in _motes:
		var a := 0.10 + 0.08 * sin(t * 1.3 + m.ph)
		canvas.draw_rect(Rect2(m.x * W + sin(t * 0.5 + m.ph) * 3.0, m.y * H, 1, 1), Color(WARM, a))
	for i in range(6):
		var a := 0.32 - i * 0.05
		canvas.draw_rect(Rect2(0, i * 2, W, 2), Color(0, 0, 0, a))
		canvas.draw_rect(Rect2(0, H - (i + 1) * 3, W, 3), Color(0, 0, 0, a))
		canvas.draw_rect(Rect2(W - (i + 1) * 3, 0, 3, H), Color(0, 0, 0, a * 0.7))
