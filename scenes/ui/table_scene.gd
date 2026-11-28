extends Control
## The home screen's live table: a roulette table seen over the shoulder, in chunky pixel 3D.
## Everything is drawn in code into a SubViewport at the game's own pixel size (one scene pixel
## per UI pixel) and shown with nearest filtering, so it reads as pixel art. It fills the whole
## window (main.gd hosts it behind the game frame), with no letterbox borders.
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
const WHEEL_C := Vector3(0.0, 0.05, 9.3)
const T_LAND := 3.7          ## the ball reaches the pockets
const T_SETTLE := 4.4        ## ...and has settled into one, riding the wheel
const RIM_R := 2.08
const POCKET_R := 1.6
const REST := Vector3(2.6, 0.5, 4.5)   ## the rake, held by the croupier's side between sweeps
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
var focus_y := 0.36           ## the horizon, down the picture (0..1)
var k := 1.0                  ## pixel sizes scale with the render (1 = a 320x180 picture)
var sway := 1.0               ## how far the camera drifts (less on a phone held upright)
var tall := false             ## laid out for a phone held upright (the title's logo sits up top)
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
	fill(Vector2(640, 360), Rect2(0, 0, 640, 360), 1.0, false)


## Fill `px` (the whole window, in window units). `frame` is where the game's play area sits in
## it and `scale` its zoom: the scene renders one pixel per game pixel, and frames the table to
## the play area (right of the menu in landscape; centred in the upper half on a phone held upright).
func fill(px: Vector2, frame: Rect2, scale: float, tall: bool) -> void:
	var rs: float = 1.0 / maxf(0.1, scale)
	var r := Vector2i(maxi(64, int(ceil(px.x * rs))), maxi(64, int(ceil(px.y * rs))))
	var fr := Rect2(frame.position * rs, frame.size * rs)   # the play area, in scene pixels
	res = r
	vp.size = r
	canvas.size = Vector2(r)
	size = px
	shown.size = px
	shown.position = Vector2.ZERO
	self.tall = tall
	if tall:
		focus_x = (fr.position.x + fr.size.x * 0.5) / r.x
		focus_y = (fr.position.y + fr.size.y * 0.17) / r.y
		sway = 0.35
		_f = fr.size.x * 0.8
		k = fr.size.x / 180.0
	else:
		focus_x = (fr.position.x + fr.size.x * 0.66) / r.x
		focus_y = (fr.position.y + fr.size.y * 0.36) / r.y
		sway = 1.0
		_f = fr.size.y * 1.05
		k = fr.size.y / 180.0


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
	_win = order[_land_index(rnd)]
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


# --- Motion: everything is a continuous function of time, so nothing ever jumps ---------

## The wheel's speed during a round: the croupier's push eases in, then it slows to a drift.
func _wheel_speed(x: float) -> float:
	var push := smoothstep(0.0, 0.5, x) * pow(maxf(0.0, 1.0 - x / 4.5), 2.0)
	return 0.35 + 1.4 * push


## The wheel's turn within a round (integrated speed). Rounds chain on, so the angle never resets.
func _wheel_turn(x: float) -> float:
	var steps := 36
	var dx := x / steps
	var sum := 0.0
	for i in range(steps):
		sum += _wheel_speed((i + 0.5) * dx) * dx
	return sum


var _loop_turn := -1.0
func _wheel_angle(rnd: int, ph: float) -> float:
	if _loop_turn < 0.0:
		_loop_turn = _wheel_turn(LOOP)
	return 0.7 + rnd * _loop_turn + _wheel_turn(ph)


## The ball's speed round the rim (against the wheel): fast off the croupier's hand, slowing.
func _ball_speed(x: float) -> float:
	return 0.9 + 3.6 * pow(maxf(0.0, 1.0 - x / T_LAND), 1.5)


## Where the ball is round the rim on its own (no wheel): integrated, always the same way.
func _ball_free(rnd: int, x: float) -> float:
	var steps := 36
	var dx := x / steps
	var sum := 0.0
	for i in range(steps):
		sum += _ball_speed((i + 0.5) * dx) * dx
	return rnd * 2.3 - sum


## The pocket (index into the wheel order) the ball lands in this round: wherever it comes down.
func _land_index(rnd: int) -> int:
	var rel := posmod(_ball_free(rnd, T_LAND) - _wheel_angle(rnd, T_LAND), TAU)
	return int(rel / TAU * order.size()) % order.size()


## The ball in the world, and how visible it is (it fades out as the croupier picks it up at
## the end of a round, and fades in at the rim when it's launched again).
func _ball_at(rnd: int, ph: float) -> Array:
	var n := order.size()
	var free_a := _ball_free(rnd, ph)
	var r := RIM_R
	var y := 0.1
	var a := free_a
	if ph > T_LAND - 0.8:
		r = lerpf(RIM_R, POCKET_R, smoothstep(T_LAND - 0.8, T_LAND, ph))   # spiralling in
	if ph > T_LAND:
		# Ride the wheel in the pocket it fell into, blending smoothly off the free path.
		var land_rel := _ball_free(rnd, T_LAND) - _wheel_angle(rnd, T_LAND)
		var centre: float = (floor(posmod(land_rel, TAU) / TAU * n) + 0.5) * TAU / n
		var rel_unwrapped: float = land_rel + (centre - posmod(land_rel, TAU))
		var ride: float = _wheel_angle(rnd, ph) + rel_unwrapped
		var b := smoothstep(T_LAND, T_SETTLE, ph)
		a = lerpf(free_a, ride, b)
		var kk := clampf((ph - T_LAND) / (T_SETTLE - T_LAND), 0.0, 1.0)
		y = lerpf(0.1, 0.06, kk) + 0.12 * exp(-5.0 * kk) * absf(sin(kk * 3.0 * PI))   # three shrinking hops
	var vis := smoothstep(0.0, 0.3, ph) * (1.0 - smoothstep(8.4, 8.9, ph))
	return [WHEEL_C + Vector3(cos(a) * r, y, sin(a) * r), vis]


## The rake head: rests by the croupier's side, reaches in at the near end, sweeps to the wheel,
## then lifts back out. One continuous path.
func _rake_head(ph: float) -> Vector3:
	var start := Vector3(0.9, 0.04, 1.9)
	var finish := Vector3(0.2, 0.04, 7.4)
	if ph < 4.7 or ph > 8.4:
		return REST
	if ph < 5.5:
		return REST.lerp(start, smoothstep(4.7, 5.5, ph))
	if ph < 7.6:
		return start.lerp(finish, smoothstep(5.5, 7.6, ph))
	return finish.lerp(REST, smoothstep(7.6, 8.4, ph))


# --- Camera -------------------------------------------------------------------------------

## World to screen: x across the table, y up, z down its length (the wheel is far away).
func proj(p: Vector3) -> Vector2:
	var r := p - _cam
	var d := maxf(0.25, r.z)
	return Vector2(res.x * focus_x + _f * r.x / d, res.y * focus_y - _f * r.y / d)


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


## A thin ring lying on the table (the wheel's brass rims).
func _ring(c: Vector3, r: float, col: Color, segs: int = 40) -> void:
	var pts := PackedVector2Array()
	for i in range(segs + 1):
		var a := TAU * i / segs
		pts.append(proj(c + Vector3(cos(a) * r, 0, sin(a) * r)))
	canvas.draw_polyline(pts, col, maxf(1.0, k * 0.6))


# --- Drawing ------------------------------------------------------------------------------

func _draw_scene() -> void:
	var W := float(res.x)
	var H := float(res.y)
	_cam = Vector3(0.3 * sway * sin(t * 0.13), 2.25 + 0.08 * sin(t * 0.21), -0.6 + 0.25 * sway * sin(t * 0.09))
	var ph: float = fmod(t, LOOP)
	_draw_room(W, H)
	_draw_table(ph)
	_draw_lamps()
	_draw_wheel(ph)
	_draw_chips(ph)
	_draw_rake(ph)
	_draw_front(W, H)


## The room behind: warm dark wall bands and out-of-focus lights (the logo names the place).
func _draw_room(W: float, H: float) -> void:
	# The same night as every other screen's backdrop: ink blue up top, burgundy low down.
	var nb := 12
	for i in range(nb):
		var col := Color("#0b0e18").lerp(Color("#1a0a10"), float(i) / (nb - 1))
		canvas.draw_rect(Rect2(0, floor(H * i / nb), W, ceil(H / nb) + 1), col)
	for b in _bokeh:
		var a := 0.16 + 0.08 * sin(t * 0.8 + b.ph)
		var c := Vector2(b.x * W, b.y * H)
		canvas.draw_circle(c, b.r * k, Color(b.c, a * 0.5), true, -1.0, false)
		canvas.draw_circle(c, b.r * k * 0.6, Color(b.c, a), true, -1.0, false)


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
		canvas.draw_line(top, s, Color("#0a0606"), maxf(1.0, k * 0.7))
		var w: float = _f * 0.55 / _depth(at)
		var h: float = maxf(3.0 * k, w * 0.45)
		canvas.draw_colored_polygon(PackedVector2Array([s + Vector2(-w * 0.35, 0), s + Vector2(w * 0.35, 0), s + Vector2(w * 0.6, h), s + Vector2(-w * 0.6, h)]), Color("#1f5a3a"))
		canvas.draw_rect(Rect2(s.x - w * 0.6, s.y + h - k, w * 1.2, k), Color("#3d8a5c"))
		canvas.draw_rect(Rect2(s.x - w * 0.45, s.y + h, w * 0.9, k), Color(1.0, 0.92, 0.65, 0.9))
		# The cone of light down to the felt.
		var f1 := proj(Vector3(sw - 1.3, 0.0, lz))
		var f2 := proj(Vector3(sw + 1.3, 0.0, lz))
		canvas.draw_colored_polygon(PackedVector2Array([s + Vector2(-w * 0.5, h), s + Vector2(w * 0.5, h), f2, f1]), Color(WARM, 0.045))


## The wheel at the far end: a wooden bowl, pockets turning, a chrome turret, and the ball.
func _draw_wheel(ph: float) -> void:
	var c := WHEEL_C
	var wa: float = _wheel_angle(_round, ph)
	_disc(c + Vector3(0, -0.02, 0), 2.35, WOOD_DARK, 40)
	_disc(c, 2.2, WOOD, 40)
	_disc(c + Vector3(0, 0.004, 0), 2.0, WOOD.darkened(0.3), 40)   # the ball track
	_ring(c + Vector3(0, 0.006, 0), 2.2, Color("#c9a050"))          # a brass rim
	var n := order.size()
	for i in range(n):
		var a0 := wa + TAU * i / n
		var a1 := wa + TAU * (i + 1) / n
		var p: int = order[i]
		var col: Color = GREEN if p <= 0 else (RED if board.is_red(p) else BLACK)
		_quad(c + Vector3(cos(a0) * 1.3, 0.01, sin(a0) * 1.3), c + Vector3(cos(a1) * 1.3, 0.01, sin(a1) * 1.3),
			c + Vector3(cos(a1) * 1.88, 0.01, sin(a1) * 1.88), c + Vector3(cos(a0) * 1.88, 0.01, sin(a0) * 1.88), col)
		# Frets: thin brass dividers between the pockets.
		canvas.draw_line(proj(c + Vector3(cos(a0) * 1.3, 0.02, sin(a0) * 1.3)), proj(c + Vector3(cos(a0) * 1.88, 0.02, sin(a0) * 1.88)), Color("#b8924a"), 1.0)
	_ring(c + Vector3(0, 0.015, 0), 1.88, Color("#c9a050"))
	_disc(c + Vector3(0, 0.02, 0), 1.3, Color("#4a2e18"), 32)
	_ring(c + Vector3(0, 0.025, 0), 1.3, Color("#8a6a3a"))
	_disc(c + Vector3(0, 0.03, 0), 0.7, Color("#6b4423"), 24)
	# The turret: a chrome post whose four arms turn with the wheel, catching the light.
	var tb := proj(c + Vector3(0, 0.03, 0))
	var tt := proj(c + Vector3(0, 0.6, 0))
	canvas.draw_line(tb, tt, Color("#c9ccd6"), maxf(2.0, 1.5 * k))
	for arm in range(4):
		var aa := wa + arm * TAU / 4.0
		var tip := proj(c + Vector3(cos(aa) * 0.55, 0.32, sin(aa) * 0.55))
		var mid := proj(c + Vector3(0, 0.36, 0))
		canvas.draw_line(mid, tip, Color("#e6e9f0") if sin(aa) < 0.0 else Color("#8d909a"), maxf(1.0, k * 0.8))
		canvas.draw_circle(tip, maxf(1.0, k * 0.9), Color("#f4f6fb"), true, -1.0, false)
	canvas.draw_circle(tt, maxf(1.0, k), Color.WHITE, true, -1.0, false)
	# The ball: round the rim against the spin, spiralling in, then riding its pocket.
	var ball: Array = _ball_at(_round, ph)
	var bs := proj(ball[0])
	var bv: float = ball[1]
	if bv > 0.01:
		var br: float = maxf(1.2, 1.3 * k)
		canvas.draw_circle(bs + Vector2(0, br * 0.6), br, Color(0, 0, 0, 0.45 * bv), true, -1.0, false)   # its shadow
		canvas.draw_circle(bs, br, Color(Color("#f4f1e8"), bv), true, -1.0, false)
		canvas.draw_rect(Rect2(bs - Vector2(br * 0.5, br * 0.6), Vector2(maxf(1.0, k * 0.6), maxf(1.0, k * 0.6))), Color(1, 1, 1, bv))
	# The result marker pops up over the wheel once the ball has settled.
	if ph > 4.2 and ph < 8.6:
		var up := proj(c + Vector3(0, 1.5 + 0.1 * sin(t * 4.0), 0))
		var mc: Color = GREEN if _win <= 0 else (RED if board.is_red(_win) else BLACK)
		var font := P.font()
		var lab := str(_win)
		var fs: int = 8 * maxi(1, int(round(k)))
		var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pad: float = 3.0 * k
		var box := Rect2(up.x - lw / 2.0 - pad, up.y - fs, lw + pad * 2.0, fs + pad)
		canvas.draw_rect(box.grow(maxf(1.0, k * 0.7)), P.GOLD)
		canvas.draw_rect(box, mc)
		canvas.draw_string(font, Vector2(box.position.x + pad, box.end.y - pad * 0.7), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, P.CREAM)


func _square_centre(n: int) -> Vector3:
	var row := (n - 1) / 3
	var c := (n - 1) % 3
	return Vector3(-0.8 + c * 0.8, 0.0, 1.6 + row * 0.45 + 0.22)


## Chip stacks: discs piled up, each with a light rim. Losers get raked away; the winner is paid.
func _draw_chips(ph: float) -> void:
	var head := _rake_head(ph)
	for s in _stacks:
		var fade: float = 1.0 - smoothstep(8.4, 8.9, ph)
		var p := _square_centre(s.n)
		var h: int = s.h
		if not s.win:
			# Losing stacks are pushed along in front of the rake once it reaches them...
			if ph > 5.5 and p.z <= head.z - 0.25:
				p.z = maxf(p.z, head.z - 0.25)
				p.x = lerpf(p.x, head.x, smoothstep(5.5, 7.6, ph) * 0.8)
			if ph > 7.6:
				p.z = 7.15
			# ...and taken off at the wheel end.
			fade = 1.0 - smoothstep(7.4, 7.9, ph)
			if fade <= 0.01:
				continue
		elif ph > 7.7:
			h += int(clampf((ph - 7.7) / 0.1, 0.0, 6.0))   # the payout piles on once the rake is clear
		for i in range(h):
			var q := p + Vector3(0, 0.07 * i, 0)
			_disc(q + Vector3(0, -0.02, 0), 0.2, Color(s.col.darkened(0.55), fade), 16)
			_disc(q, 0.2, Color(s.col, fade), 16)
			# Edge spots: the white inserts every casino chip has.
			for sp in [-0.2, 0.2, 0.0]:
				var e1 := proj(q + Vector3(sp, 0, -0.19 if sp == 0.0 else 0.0))
				canvas.draw_rect(Rect2(e1 - Vector2(0, k * 0.5), Vector2(maxf(1.0, k), maxf(1.0, k * 0.6))), Color(1, 1, 1, 0.55 * fade))
		var top := p + Vector3(0, 0.07 * h, 0)
		_disc(top, 0.12, Color(s.col.lightened(0.3), fade), 12)
		if s.win and ph > 4.2 and ph < 8.5:
			var ts := proj(top + Vector3(0, 0.15, 0))
			var g := 0.5 + 0.5 * sin(t * 8.0)
			canvas.draw_rect(Rect2(ts - Vector2(0, (2 + g * 2) * k), Vector2(maxf(1.0, k), maxf(1.0, k))), Color(P.GOLD, 0.8))


## The croupier's arm and rake, reaching in from the right.
func _draw_rake(ph: float) -> void:
	var head := _rake_head(ph)
	var hand := head + Vector3(2.0, 0.9, -1.4)   # the handle's end, in the croupier's hand
	var hs := proj(head)
	var hn := proj(hand)
	canvas.draw_line(hs, hn, Color("#c8a46a"), maxf(1.0, k * 0.8))
	var a := proj(head + Vector3(-0.45, 0, 0))
	var b := proj(head + Vector3(0.45, 0, 0))
	canvas.draw_line(a, b, Color("#d8b47a"), maxf(2.0, k * 1.4))
	# Sleeve: a black dinner jacket with a white cuff, coming in off the right edge.
	var elbow := Vector2(res.x - 14 * k, hn.y + 18 * k)
	var jacket := Color("#14111a")
	canvas.draw_colored_polygon(PackedVector2Array([hn + Vector2(1, -3) * k, hn + Vector2(5, 3) * k, elbow + Vector2(6, 8) * k, elbow + Vector2(-5, -2) * k]), jacket)
	canvas.draw_colored_polygon(PackedVector2Array([elbow + Vector2(-5, -2) * k, elbow + Vector2(6, 8) * k, Vector2(res.x + 2, res.y * 0.9), Vector2(res.x + 2, elbow.y - 10 * k)]), jacket)
	canvas.draw_line(hn + Vector2(1, -3) * k, elbow + Vector2(-5, -2) * k, Color("#2a2433"), maxf(1.0, k * 0.6))
	canvas.draw_rect(Rect2(hn - Vector2(2, 3) * k, Vector2(5, 5) * k), Color("#e8e0d0"))
	canvas.draw_rect(Rect2(hn - Vector2(3, 1) * k, Vector2(3, 3) * k), Color("#d9a47a"))


## Foreground: the near rail out of focus, smoke, and a soft vignette.
func _draw_front(W: float, H: float) -> void:
	for m in _motes:
		var a := 0.10 + 0.08 * sin(t * 1.3 + m.ph)
		canvas.draw_rect(Rect2(m.x * W + sin(t * 0.5 + m.ph) * 3.0 * k, m.y * H, maxf(1.0, k * 0.7), maxf(1.0, k * 0.7)), Color(WARM, a))
	for i in range(6):
		var a := 0.32 - i * 0.05
		canvas.draw_rect(Rect2(0, i * 2 * k, W, 2 * k), Color(0, 0, 0, a))
		canvas.draw_rect(Rect2(0, H - (i + 1) * 3 * k, W, 3 * k), Color(0, 0, 0, a))
		canvas.draw_rect(Rect2(W - (i + 1) * 3 * k, 0, 3 * k, H), Color(0, 0, 0, a * 0.7))
