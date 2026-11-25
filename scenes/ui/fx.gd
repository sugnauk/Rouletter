extends Control
## Screen-space effects layer: pixel particles (coin bursts, chip confetti), banners and stamps.
## Sits above the screens and below the dialogue box; never takes input.

const P := preload("res://scenes/ui/palette.gd")

var parts: Array = []     ## {p, v, col, life, max, size}
var banners: Array = []   ## {text, col, t, dur, y, size}
var stamps: Array = []    ## {text, col, t, dur}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func burst(pos: Vector2, n: int, cols: Array = [P.GOLD, P.CREAM], speed: float = 110.0) -> void:
	for i in range(n):
		var a := randf() * TAU
		var sp := randf_range(0.35, 1.0) * speed
		parts.append({"p": pos, "v": Vector2(cos(a), sin(a) - 0.9) * sp, "col": cols[i % cols.size()],
			"life": randf_range(0.6, 1.1), "max": 1.1, "size": 2 if randf() < 0.7 else 3})


func coin_rain(n: int) -> void:
	for i in range(n):
		parts.append({"p": Vector2(randf() * 640, randf_range(-60, -4)), "v": Vector2(randf_range(-15, 15), randf_range(40, 120)),
			"col": [P.GOLD, P.GOLD.lightened(0.3), P.CREAM][i % 3], "life": 2.4, "max": 2.4, "size": 3})


func banner(text: String, col: Color, dur: float = 1.1, y: float = 120.0, size: int = 16) -> void:
	banners.append({"text": text, "col": col, "t": 0.0, "dur": dur, "y": y, "size": size})


func stamp(text: String, col: Color, dur: float = 1.4) -> void:
	stamps.append({"text": text, "col": col, "t": 0.0, "dur": dur})


func busy() -> bool:
	return not parts.is_empty() or not banners.is_empty() or not stamps.is_empty()


func _process(delta: float) -> void:
	for p in parts:
		p.v.y += 260.0 * delta
		p.p += p.v * delta
		p.life -= delta
	parts = parts.filter(func(p): return p.life > 0.0 and p.p.y < 380.0)
	for b in banners:
		b.t += delta
	banners = banners.filter(func(b): return b.t < b.dur)
	for s in stamps:
		s.t += delta
	stamps = stamps.filter(func(s): return s.t < s.dur)
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var a: float = clampf(p.life / 0.4, 0.0, 1.0)
		draw_rect(Rect2(p.p.round(), Vector2(p.size, p.size)), Color(p.col, a))
	var font := P.title_font()
	for b in banners:
		var k: float = b.t / b.dur
		var a := 1.0 if k < 0.75 else (1.0 - k) / 0.25
		var size: int = b.size * (2 if b.t < 0.08 else 1)
		var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := Vector2(320 - w / 2.0, b.y - k * 10.0).round()
		draw_rect(Rect2(pos + Vector2(-6, -size - 3), Vector2(w + 12, size + 9)), Color(0, 0, 0, 0.55 * a))
		draw_string(font, pos + Vector2(2, 2), b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, a))
		draw_string(font, pos, b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(b.col, a))
	for s in stamps:
		var k: float = s.t / s.dur
		var a := 1.0 if k < 0.8 else (1.0 - k) / 0.2
		var size := 48 if s.t < 0.06 else (32 if s.t < 0.12 else 24)
		var w := font.get_string_size(s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var box := Rect2(Vector2(320 - w / 2.0 - 12, 180 - size / 2.0 - 10), Vector2(w + 24, size + 20)).abs()
		box.position = box.position.round()
		draw_rect(box, Color(0, 0, 0, 0.7 * a))
		draw_rect(box, Color(s.col, a), false, 3.0)
		draw_rect(box.grow(-5), Color(s.col, a * 0.6), false, 1.0)
		draw_string(font, Vector2(320 - w / 2.0, 180 + size / 2.0 - 2).round(), s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(s.col, a))
