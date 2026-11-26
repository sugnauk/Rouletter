extends Control
## Screen-space effects layer: pixel particles (coin bursts, chip confetti), banners and stamps.
## Sits above the screens and below the dialogue box; never takes input.

const P := preload("res://scenes/ui/palette.gd")

var parts: Array = []     ## {p, v, col, life, max, size}
var banners: Array = []   ## {text, col, t, dur, y, size}
var stamps: Array = []    ## {text, col, t, dur}
var flyers: Array = []    ## {from, to, mid, col, t, dur, size} chips arcing into a target
var texts: Array = []     ## {text, pos, col, t, dur} small floating labels anywhere
var tally: Dictionary = {}  ## {title, rows: [[label, value, col]], t, dur, shown}
var flash_a := 0.0


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


## Chips arcing from `from` to `to` (e.g. from a winning square into the Take meter).
func fly(from: Vector2, to: Vector2, col: Color, n: int = 4) -> void:
	for i in range(n):
		var mid := (from + to) / 2.0 + Vector2(randf_range(-40, 40), randf_range(-70, -30))
		flyers.append({"from": from, "to": to, "mid": mid, "col": col, "t": -i * 0.05, "dur": randf_range(0.4, 0.55), "size": 3})


## A small label that floats up from `pos`.
func pop_text(pos: Vector2, text: String, col: Color = P.GOLD, dur: float = 0.9) -> void:
	texts.append({"text": text, "pos": pos, "col": col, "t": 0.0, "dur": dur})


## A full-screen white flash (big moments).
func flash(alpha: float = 0.6) -> void:
	flash_a = maxf(flash_a, alpha)


## A centred reward card whose rows tick in one by one with a coin sound each.
func show_tally(title: String, rows: Array, dur: float = 2.6) -> void:
	tally = {"title": title, "rows": rows, "t": 0.0, "dur": dur, "shown": 0}


func busy() -> bool:
	return not parts.is_empty() or not banners.is_empty() or not stamps.is_empty() or not tally.is_empty()


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
	for f in flyers:
		f.t += delta
		if f.t >= f.dur and not f.has("done"):
			f.done = true
			burst(f.to, 3, [f.col, P.CREAM], 50.0)
	flyers = flyers.filter(func(f): return f.t < f.dur)
	for x in texts:
		x.t += delta
	texts = texts.filter(func(x): return x.t < x.dur)
	flash_a = maxf(0.0, flash_a - delta * 2.6)
	if not tally.is_empty():
		tally.t += delta
		var due := mini(tally.rows.size(), int((tally.t - 0.25) / 0.24) + 1) if tally.t > 0.25 else 0
		while tally.shown < due:
			tally.shown += 1
			Sfx.play("cash", 1.0 + 0.08 * tally.shown)
		if tally.t >= tally.dur:
			tally = {}
	queue_redraw()


func _draw() -> void:
	for f in flyers:
		if f.t < 0.0:
			continue
		var k: float = clampf(f.t / f.dur, 0.0, 1.0)
		k = k * k
		var p: Vector2 = f.from.lerp(f.mid, k).lerp(f.mid.lerp(f.to, k), k)
		_chip_dot(p, 3.0, f.col)
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
	var small := P.font()
	for x in texts:
		var k: float = x.t / x.dur
		var a := 1.0 if k < 0.7 else (1.0 - k) / 0.3
		var w := small.get_string_size(x.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var pos: Vector2 = (x.pos - Vector2(w / 2.0, k * 18.0)).round()
		draw_string(small, pos + Vector2(1, 1), x.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, a))
		draw_string(small, pos, x.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(x.col, a))
	if not tally.is_empty():
		_draw_tally(font, small)
	if flash_a > 0.0:
		draw_rect(Rect2(-4000, -4000, 8640, 8360), Color(1, 0.97, 0.88, flash_a))


func _draw_tally(font: Font, small: Font) -> void:
	var k: float = tally.t / tally.dur
	var a := clampf(tally.t / 0.15, 0.0, 1.0) * (1.0 if k < 0.85 else (1.0 - k) / 0.15)
	var h: float = 30.0 + tally.rows.size() * 13.0
	var box := Rect2(200, 200 - h / 2.0, 240, h).abs()
	box.position = box.position.round()
	draw_rect(box, Color(0.04, 0.03, 0.02, 0.92 * a))
	draw_rect(box, Color(P.GOLD, a), false, 2.0)
	var tw := font.get_string_size(tally.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(font, Vector2(320 - tw / 2.0, box.position.y + 16).round(), tally.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(P.GOLD, a))
	for i in range(tally.shown):
		var r: Array = tally.rows[i]
		var y: float = box.position.y + 32.0 + i * 13.0
		draw_string(small, Vector2(box.position.x + 10, y), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(P.DIM, a))
		var vw := small.get_string_size(r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(small, Vector2(box.end.x - 10 - vw, y), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(r[2], a))


func _chip_dot(p: Vector2, rad: float, col: Color) -> void:
	draw_circle(p.round() + Vector2(0, 1), rad, col.darkened(0.5), true, -1.0, false)
	draw_circle(p.round(), rad, col, true, -1.0, false)
	draw_circle(p.round(), rad * 0.5, col.lightened(0.3), true, -1.0, false)
