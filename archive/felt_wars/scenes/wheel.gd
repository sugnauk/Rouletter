extends Control
## Draws a European wheel (with an ownership ring) and an animated ball.

const Board := preload("res://core/board.gd")
const Chip := preload("res://core/chip.gd")

const N := 37
var felt = null
var highlight: int = -1

var ball_angle: float = 0.0:
	set(v):
		ball_angle = v
		queue_redraw()


## Angle of the centre of the pocket at wheel index i (0 at the top).
func angle_for(i: int) -> float:
	return -PI / 2.0 + (i + 0.5) * TAU / N


func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 4.0
	var seg := TAU / N
	var font := ThemeDB.fallback_font
	draw_circle(c, r + 3.0, Color(0.35, 0.22, 0.1))
	for i in range(N):
		var n: int = Board.WHEEL_ORDER[i]
		var a0 := -PI / 2.0 + i * seg
		var a1 := a0 + seg
		var col := Color(0.05, 0.45, 0.2) if n == 0 else (Color(0.72, 0.1, 0.1) if Board.is_red(n) else Color(0.1, 0.1, 0.1))
		if n == highlight:
			col = col.lightened(0.45)
		_wedge(c, r * 0.62, r, a0, a1, col)
		if felt != null:
			var o: int = felt.owner(n)
			if o != -1:
				var ring := Color(1.0, 0.8, 0.2) if o == Chip.Side.PLAYER else Color(0.7, 0.3, 1.0)
				_wedge(c, r * 0.96, r, a0, a1, ring)
		var mid := (a0 + a1) / 2.0
		var p := c + Vector2(cos(mid), sin(mid)) * r * 0.8
		draw_string(font, p + Vector2(-8, 4), str(n), HORIZONTAL_ALIGNMENT_CENTER, 16, 10, Color.WHITE)
	draw_circle(c, r * 0.6, Color(0.25, 0.16, 0.08))
	draw_circle(c, r * 0.18, Color(0.75, 0.6, 0.3))
	var bp := c + Vector2(cos(ball_angle), sin(ball_angle)) * r * 0.68
	draw_circle(bp, 6.0, Color(0.97, 0.97, 0.95))


func _wedge(c: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 4
	for s in range(steps + 1):
		var a: float = lerp(a0, a1, float(s) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r1)
	for s in range(steps, -1, -1):
		var a: float = lerp(a0, a1, float(s) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r0)
	draw_colored_polygon(pts, col)
