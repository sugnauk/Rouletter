extends Control
## Pixel wheel for any board: pockets in wheel order, a counter-rotating ball that skids and
## drops into its pocket. `spin_to(pocket)` animates and emits `spin_done`.

signal spin_done

const P := preload("res://scenes/ui/palette.gd")

var board = null
var result: int = -99
var idle_spin := false
var animating := false
var wheel_rot: float = 0.0
var ball_angle: float = -PI / 2.0
var ball_radius_k: float = 0.95   ## ball radius as a fraction of the outer rim
var weights: Dictionary = {}      ## Crooked Wheel: pocket -> width (wider wedges)
var arc: Array = []               ## Carousel: pockets in the hot arc (gold rim)...
var next_arc: Array = []          ## ...and where it goes after this spin (faint)
var twin := false                 ## Twin Ball: a second ball
var result2: int = -99
var ball2_angle: float = PI / 2.0
var ball2_radius_k: float = 0.95


func _process(delta: float) -> void:
	if idle_spin and not animating:
		wheel_rot += delta * 0.4
		ball_angle -= delta * 0.9
	if idle_spin or animating:
		queue_redraw()


func _w(p: int) -> float:
	return float(weights.get(p, 1))


func _total_w() -> float:
	var t := 0.0
	for p in board.order:
		t += _w(p)
	return t


## The centre angle of the i-th pocket in wheel order (wedges are as wide as their weight).
func pocket_angle(i: int) -> float:
	var before := 0.0
	for k in range(i):
		before += _w(board.order[k])
	return wheel_rot - PI / 2.0 + (before + _w(board.order[i]) / 2.0) * TAU / _total_w()


func _seg(i: int) -> float:
	return _w(board.order[i]) * TAU / _total_w()


## Where a ball must end up (absolute angle, spun back a few laps) to sit in `pocket`.
func _ball_end(pocket: int, end_rot: float, from: float, laps: float) -> float:
	var idx: int = board.order.find(pocket)
	var rel := pocket_angle(idx) - wheel_rot
	var e := end_rot + rel - TAU * laps
	while e > from - TAU * (laps - 1.0):
		e -= TAU
	return e


func spin_to(pocket: int, duration: float = 1.9, pocket2: int = -99) -> void:
	result = -99
	result2 = -99
	var end_rot := wheel_rot + TAU * 1.5 + randf() * TAU
	var end_ball := _ball_end(pocket, end_rot, ball_angle, 5.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "wheel_rot", end_rot, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "ball_angle", end_ball, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ball_radius_k = 0.95
	var drop := create_tween()
	drop.tween_interval(duration * 0.6)
	drop.tween_property(self, "ball_radius_k", 0.6,duration * 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if pocket2 != -99:
		twin = true
		ball2_angle = ball_angle + PI
		var end2 := _ball_end(pocket2, end_rot, ball2_angle, 4.0)
		tw.tween_property(self, "ball2_angle", end2, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ball2_radius_k = 0.95
		var drop2 := create_tween()
		drop2.tween_interval(duration * 0.7)
		drop2.tween_property(self, "ball2_radius_k", 0.6, duration * 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	animating = true
	tw.chain().tween_callback(func():
		animating = false
		result = pocket
		result2 = pocket2
		queue_redraw()
		spin_done.emit())


func _draw() -> void:
	if board == null:
		return
	var c := (size / 2.0).floor()
	var r: float = floor(min(size.x, size.y) / 2.0) - 2.0
	var n: int = board.order.size()
	draw_circle(c, r + 2.0, P.WOOD_DARK, true, -1.0, false)
	draw_circle(c, r, P.WOOD, true, -1.0, false)
	var glow := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 180.0)
	for i in range(n):
		var p: int = board.order[i]
		var seg := _seg(i)
		var a0 := pocket_angle(i) - seg / 2.0
		var col: Color = P.GREEN if p <= 0 else (P.RED if board.is_red(p) else P.BLACK)
		if p == result or p == result2:
			col = col.lightened(0.5)
		_wedge(c, r * 0.56, r * 0.93, a0, a0 + seg, col)
		if p in arc:   # the Carousel's hot arc: a glowing gold rim
			_wedge(c, r * 0.93, r * 1.0, a0, a0 + seg, Color(P.GOLD, glow))
		elif p in next_arc:
			_wedge(c, r * 0.95, r * 0.99, a0, a0 + seg, Color(P.GOLD, 0.3))
		if _w(p) > 1.0:   # a crooked pocket: a gold band across its wide wedge
			_wedge(c, r * 0.56, r * 0.61, a0, a0 + seg, P.GOLD)
	# Frets between pockets.
	for i in range(n):
		var a := pocket_angle(i) - _seg(i) / 2.0
		draw_line((c + Vector2(cos(a), sin(a)) * r * 0.56).floor(), (c + Vector2(cos(a), sin(a)) * r * 0.93).floor(), P.LINE.darkened(0.3), 1.0, false)
	if r >= 70.0:
		_draw_numbers(c, r)
	draw_circle(c, r * 0.54, P.WOOD_DARK, true, -1.0, false)
	draw_circle(c, r * 0.42, P.WOOD, true, -1.0, false)
	# Turret: spokes that turn with the wheel.
	for k in range(4):
		var a := wheel_rot + k * PI / 2.0
		draw_line(c, (c + Vector2(cos(a), sin(a)) * r * 0.4).floor(), P.GOLD.darkened(0.2), 2.0, false)
	draw_circle(c, 4.0, P.GOLD, true, -1.0, false)
	if result != -99:
		var font := P.title_font()
		var txt: String = board.label(result)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var box := Rect2((c - Vector2(w / 2.0 + 3, 7)).floor(), Vector2(w + 6, 13))
		draw_rect(box, P.BLACK if result > 0 and not board.is_red(result) else (P.RED if result > 0 else P.GREEN))
		draw_rect(box, P.GOLD, false, 1.0)
		draw_string(font, (c + Vector2(-w / 2.0, 4)).floor(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, P.CREAM)
	var bp := (c + Vector2(cos(ball_angle), sin(ball_angle)) * r * ball_radius_k).floor()
	draw_circle(bp + Vector2(1, 1), 3.0, Color(0, 0, 0, 0.5), true, -1.0, false)
	draw_circle(bp, 3.0, P.CREAM, true, -1.0, false)
	if twin:   # the second ball is gold, so you can tell them apart
		var bp2 := (c + Vector2(cos(ball2_angle), sin(ball2_angle)) * r * ball2_radius_k).floor()
		draw_circle(bp2 + Vector2(1, 1), 3.0, Color(0, 0, 0, 0.5), true, -1.0, false)
		draw_circle(bp2, 3.0, P.GOLD, true, -1.0, false)
	if result2 != -99 and result2 != result:
		var font2 := P.title_font()
		var t2: String = board.label(result2)
		var w2 := font2.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var box2 := Rect2((c + Vector2(-w2 / 2.0 - 3, 9)).floor(), Vector2(w2 + 6, 13))
		draw_rect(box2, P.BLACK if result2 > 0 and not board.is_red(result2) else (P.RED if result2 > 0 else P.GREEN))
		draw_rect(box2, P.GOLD.lightened(0.3), false, 1.0)
		draw_string(font2, (c + Vector2(-w2 / 2.0, 20)).floor(), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, P.GOLD)


## Pocket numbers. They ride with their pocket but stay upright: rotating 1px pixel-font strokes
## with nearest sampling garbles them, so upright text is the only way they stay crisp.
## Only drawn when the wheel is big enough for each number to fit inside its pocket.
func _draw_numbers(c: Vector2, r: float) -> void:
	var font := P.font()
	var fs := P.FONT_SMALL
	for i in range(board.order.size()):
		var p: int = board.order[i]
		var a := pocket_angle(i)
		var txt: String = board.label(p)
		var mid := c + Vector2(cos(a), sin(a)) * r * 0.82
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := (mid + Vector2(-w / 2.0, 3.0)).round()
		draw_string(font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, P.CREAM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _wedge(c: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 3
	for s in range(steps + 1):
		var a: float = lerp(a0, a1, float(s) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r1)
	for s in range(steps, -1, -1):
		var a: float = lerp(a0, a1, float(s) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r0)
	draw_colored_polygon(pts, col)
