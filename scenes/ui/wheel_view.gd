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


func _process(delta: float) -> void:
	if idle_spin and not animating:
		wheel_rot += delta * 0.4
		ball_angle -= delta * 0.9
	if idle_spin or animating:
		queue_redraw()


func pocket_angle(i: int) -> float:
	var n: int = board.order.size()
	return wheel_rot - PI / 2.0 + (i + 0.5) * TAU / n


func spin_to(pocket: int, duration: float = 1.9) -> void:
	result = -99
	var n: int = board.order.size()
	var idx: int = board.order.find(pocket)
	var end_rot := wheel_rot + TAU * 1.5 + randf() * TAU
	var end_ball_rel := -PI / 2.0 + (idx + 0.5) * TAU / n
	var end_ball := end_rot + end_ball_rel - TAU * 5.0
	while end_ball > ball_angle - TAU * 4.0:
		end_ball -= TAU
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "wheel_rot", end_rot, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "ball_angle", end_ball, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ball_radius_k = 0.95
	var drop := create_tween()
	drop.tween_interval(duration * 0.6)
	drop.tween_property(self, "ball_radius_k", 0.6,duration * 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	animating = true
	tw.chain().tween_callback(func():
		animating = false
		result = pocket
		queue_redraw()
		spin_done.emit())


func _draw() -> void:
	if board == null:
		return
	var c := (size / 2.0).floor()
	var r: float = floor(min(size.x, size.y) / 2.0) - 2.0
	var n: int = board.order.size()
	var seg := TAU / n
	draw_circle(c, r + 2.0, P.WOOD_DARK, true, -1.0, false)
	draw_circle(c, r, P.WOOD, true, -1.0, false)
	for i in range(n):
		var p: int = board.order[i]
		var a0 := pocket_angle(i) - seg / 2.0
		var col: Color = P.GREEN if p <= 0 else (P.RED if board.is_red(p) else P.BLACK)
		if p == result:
			col = col.lightened(0.5)
		_wedge(c, r * 0.56, r * 0.93, a0, a0 + seg, col)
	# Frets between pockets.
	for i in range(n):
		var a := pocket_angle(i) - seg / 2.0
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
