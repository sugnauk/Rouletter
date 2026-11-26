extends Control
## The Gilded Ace after midnight: damask wallpaper, a wainscot rail, pools of lamplight,
## drifting smoke motes and a neon sign that occasionally buzzes. Purely decorative.

const P := preload("res://scenes/ui/palette.gd")

var t := 0.0
var motes: Array = []
var lamps: Array = [Vector2(352, 70), Vector2(92, 110)]
var sign_on := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(28):
		motes.append({"p": Vector2(rng.randf() * 640, rng.randf() * 360), "v": rng.randf_range(2, 7), "ph": rng.randf() * TAU})


func _process(delta: float) -> void:
	t += delta
	for m in motes:
		m.p.y -= m.v * delta
		m.p.x += sin(t * 0.7 + m.ph) * delta * 3.0
		if m.p.y < -2:
			m.p.y = 362
	sign_on = not (fmod(t, 7.3) > 6.9 and fmod(t * 20.0, 2.0) > 1.0)
	queue_redraw()


func _draw() -> void:
	# The 640x360 design is centred; the wall and floor run on past it to fill any extra window space.
	var off := ((size - Vector2(640, 360)) / 2.0).floor()
	draw_set_transform(off)
	var ex := off.x + 16.0
	var ey := off.y + 16.0
	var wall := Color("#140d0f")
	draw_rect(Rect2(-off.x, -off.y, size.x, 300 + off.y), wall)
	# Damask diamonds.
	var pat := wall.lightened(0.05)
	for y in range(-int(ceil(ey / 16.0)) * 16, 300, 16):
		for x in range(-int(ceil(ex / 16.0)) * 16, 640 + int(ex), 16):
			var o := 8 if posmod(y / 16, 2) == 1 else 0
			var c := Vector2(x + o, y + 8)
			draw_rect(Rect2(c - Vector2(1, 3), Vector2(2, 6)), pat)
			draw_rect(Rect2(c - Vector2(3, 1), Vector2(6, 2)), pat)
	# Wainscot and floor.
	draw_rect(Rect2(-off.x, 300, size.x, 60 + off.y), Color("#1d120c"))
	draw_rect(Rect2(-off.x, 300, size.x, 2), P.WOOD)
	for x in range(-int(ceil(off.x / 40.0)) * 40, 640 + int(off.x), 40):
		draw_rect(Rect2(x + 4, 308, 32, 46 + off.y), Color("#24170f"))
	# Lamplight pools (banded, like dithered 16-bit lighting).
	for l in lamps:
		for i in range(5):
			var rr := 150.0 - i * 26.0
			draw_circle(l, rr, Color(1.0, 0.8, 0.45, 0.018 + i * 0.006), true, -1.0, false)
	# Smoke motes.
	for m in motes:
		draw_rect(Rect2(m.p.round(), Vector2(1, 1)), Color(1, 0.9, 0.7, 0.18))


## Small neon sign, drawn by screens that have room for it.
static func neon(ci: CanvasItem, pos: Vector2, text: String, on: bool) -> void:
	var font := P.title_font()
	var col := Color("#ff4fa3") if on else Color("#4a2236")
	if on:
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			ci.draw_string(font, pos + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col, 0.35))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
