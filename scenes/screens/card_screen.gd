extends Control
## Opening title card: a dark street in 1974, the Gilded Ace's neon sign stuttering on, then
## "Mr. Vance presents ROULETTER". Any click or key skips straight to the title screen.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")

const LENGTH := 4.2
## Neon power pattern for the sign while it warms up: [start, end) windows where it's lit.
const FLICKER := [[0.9, 1.0], [1.08, 1.12], [1.3, 1.5], [1.56, 1.6]]
const STEADY := 1.7

var main
var t := 0.0
var done := false
var last_on := false
var show_skip := true   ## off when rendering the boot splash image


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh() -> void:
	t = 0.0
	done = false
	last_on = false


func _process(delta: float) -> void:
	if not visible or done:
		return
	t += delta
	var on := _sign_on()
	if on and not last_on:
		Sfx.play("click")
	last_on = on
	if t >= LENGTH:
		_finish()
	queue_redraw()


func _sign_on() -> bool:
	if t >= STEADY:
		return true
	for w in FLICKER:
		if t >= w[0] and t < w[1]:
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not done and event is InputEventKey and event.pressed:
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if done:
		return
	done = true
	main.go("title")


func _fade(start: float, dur: float = 0.5) -> float:
	return clampf((t - start) / dur, 0.0, 1.0)


func _draw() -> void:
	# Cover the whole window, not just the 640x360 frame.
	draw_rect(Rect2(-4000, -4000, 8640, 8360), Color("#07050a"))
	var c := Vector2(320, 150)
	# Wet asphalt: a few reflected streaks that pick up the sign's colour once it is lit.
	var on := _sign_on()
	var glow := 1.0 if on else 0.0
	for i in range(14):
		var y := 250.0 + i * 7.0
		var w := 60.0 + (i * 37) % 140
		var x := 320.0 - w / 2.0 + sin(i * 1.7) * 90.0
		draw_rect(Rect2(x, y, w, 1), Color(1.0, 0.31, 0.64, 0.05 + 0.10 * glow * (1.0 - i / 14.0)))
	Art.text(self, P.font(), Vector2(320, 92), "1974", 8, Color(P.DIM, _fade(0.1)), true)
	# The sign: a dark frame with the lettering inside.
	var frame := Rect2(c.x - 180, c.y - 34, 360, 56)
	draw_rect(frame, Color("#120a10"))
	draw_rect(frame, Color(P.GOLD.darkened(0.5), 0.9), false, 2.0)
	for i in range(18):
		var bx := frame.position.x + 10 + i * 20
		var lit := on and (int(t * 6.0) + i) % 3 != 0
		draw_rect(Rect2(bx, frame.position.y + 4, 2, 2), P.GOLD if lit else P.GOLD.darkened(0.7))
		draw_rect(Rect2(bx, frame.end.y - 6, 2, 2), P.GOLD if lit else P.GOLD.darkened(0.7))
	Art.neon(self, c, "THE GILDED ACE", 24, Color("#ff4fa3"), 1.0, 1.0 if on else 0.0)
	Art.text(self, P.font(), Vector2(320, 214), "MR. VANCE PRESENTS", 8, Color(P.CREAM, _fade(2.2)), true)
	Art.neon(self, Vector2(320, 238), "ROULETTER", 16, P.GOLD, _fade(2.8, 0.4))
	if show_skip:
		Art.text(self, P.font(), Vector2(320, 344), "CLICK TO SKIP", 8, Color(P.DIM, 0.6 * _fade(0.5)), true)
