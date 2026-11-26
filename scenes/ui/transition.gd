extends Control
## Themed loading card between screens: fades to black, shows a title, subtitle and a rotating
## tip or quote, swaps the screen underneath, then fades back in. Click / Space / Enter skips.
## Lives on its own CanvasLayer under the CRT so it covers the whole window.

const P := preload("res://scenes/ui/palette.gd")
const Art := preload("res://scenes/ui/art.gd")
const Portraits := preload("res://scenes/ui/portraits.gd")

const FADE := 0.18
const HOLD := 0.75
const HOLD_BOSS := 1.6     ## Enforcer cards linger for the entrance

const TIPS := [
	"The wheel is honest. The felt is where you win.",
	"A losing bet costs its value off the spin's Take.",
	"Permanent chips are never lost. They score every hit.",
	"Covering everything scores nothing. Pick your shots.",
	"Splits, corners and lines sit on the felt's edges.",
	"The Pit Boss takes his price in chips off your next stack.",
	"Clear takes every bet back. Your layout repeats each spin.",
	"\"The house edge is patience.\" - Mr. Vance",
	"\"Green is my favourite colour, darling.\" - Madame Oro",
	"\"Nobody comes back from upstairs.\" - Big Sal",
]

var title := ""
var subtitle := ""
var tip := ""
var accent: Color = P.GOLD
var who := ""           ## optional portrait on the card (Enforcers)
var alpha := 0.0
var t := 0.0
var stage := 0          ## 0 idle, 1 fading in, 2 holding, 3 fading out
var mid: Callable
var tip_i := 0
var elapsed := 0.0      ## since the card started (drives the Enforcer entrance)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_i = randi() % TIPS.size()


func busy() -> bool:
	return stage != 0


## Show a card; `swap` runs while the screen is fully covered.
func play(title_in: String, subtitle_in: String, swap: Callable, accent_in: Color = P.GOLD, who_in: String = "") -> void:
	who = who_in
	if stage != 0:
		# Already covering: run the swap now and just update the card text.
		swap.call()
		title = title_in
		subtitle = subtitle_in
		accent = accent_in
		return
	title = title_in
	subtitle = subtitle_in
	accent = accent_in
	tip_i = (tip_i + 1) % TIPS.size()
	tip = TIPS[tip_i]
	mid = swap
	stage = 1
	t = 0.0
	elapsed = 0.0
	if who != "":
		Sfx.play("enforcer:" + who)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if stage == 0:
		return
	t += delta
	elapsed += delta
	match stage:
		1:
			alpha = clampf(t / FADE, 0.0, 1.0)
			if t >= FADE:
				if mid.is_valid():
					mid.call()
				mid = Callable()
				stage = 2
				t = 0.0
		2:
			alpha = 1.0
			if t >= (HOLD_BOSS if who != "" else HOLD):
				_out()
		3:
			alpha = 1.0 - clampf(t / FADE, 0.0, 1.0)
			if t >= FADE:
				stage = 0
				alpha = 0.0
				mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _out() -> void:
	stage = 3
	t = 0.0


func _gui_input(event: InputEvent) -> void:
	if stage == 2 and event is InputEventMouseButton and event.pressed:
		_out()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if stage != 0 and event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		if stage == 2:
			_out()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if alpha <= 0.0:
		return
	var a := alpha
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.02, 0.025, a))
	var c := (size / 2.0).floor()
	# Thin gold rules framing the card, like a casino matchbook.
	var w := 300.0
	draw_rect(Rect2(c.x - w / 2.0, c.y - 46, w, 1), Color(accent, 0.8 * a))
	draw_rect(Rect2(c.x - w / 2.0, c.y + 34, w, 1), Color(accent, 0.8 * a))
	for x in [c.x - w / 2.0 - 6, c.x + w / 2.0 + 2]:
		draw_rect(Rect2(x, c.y - 49, 4, 4), Color(accent, a))
		draw_rect(Rect2(x, c.y + 32, 4, 4), Color(accent, a))
	Art.neon(self, Vector2(c.x, c.y - 12), title, 16, accent, a)
	if who != "" and a > 0.05:
		# The Enforcer's entrance: a spotlight snaps on, the portrait slides in from the dark,
		# and a red bar sweeps under the name.
		var k: float = clampf((elapsed - 0.1) / 0.35, 0.0, 1.0)
		var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
		var px: float = lerpf(-80.0, c.x - w / 2.0 - 70, ease_k)
		var pr := Rect2(px, c.y - 40, 64, 64)
		var spot: float = clampf(elapsed / 0.15, 0.0, 1.0) * a
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - w / 2.0 - 38 - 10, 0), Vector2(c.x - w / 2.0 - 38 + 10, 0),
			Vector2(pr.end.x + 10, pr.end.y + 6), Vector2(pr.position.x - 10, pr.end.y + 6)]), Color(1.0, 0.85, 0.6, 0.07 * spot))
		draw_rect(pr.grow(2), Color(accent, 0.9 * a), false, 2.0)
		Portraits.draw(self, who, pr)
		if a < 1.0:
			draw_rect(pr.grow(1), Color(0.035, 0.02, 0.025, 1.0 - a))
		var sweep: float = clampf((elapsed - 0.35) / 0.3, 0.0, 1.0)
		draw_rect(Rect2(c.x - w / 2.0, c.y + 22, w * sweep, 2), Color(P.DANGER, 0.9 * a))
	if subtitle != "":
		Art.text(self, P.font(), Vector2(c.x, c.y + 14), subtitle.to_upper(), 8, Color(P.CREAM, a), true)
	Art.text(self, P.font(), Vector2(c.x, c.y + 56), tip.to_upper(), 8, Color(P.DIM, a), true)
