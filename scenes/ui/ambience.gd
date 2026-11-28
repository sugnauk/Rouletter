extends RefCounted
## The casino around you, out of focus and quietly alive. Shared by the backdrop behind every
## screen (scenes/ui/backdrop.gd) and the home screen's live table (scenes/ui/table_scene.gd):
##   - bokeh: the lights of other tables and the bar, drifting slowly and breathing
##   - people passing: a soft dark silhouette walks by now and then, hiding lights as it goes
##   - smoke: thin wisps curling up from below
##   - far-table flashes: somewhere across the room a table's lights flare (someone won)
##   - glints: a brief four-point sparkle off brass
## `level` scales everything: 1 full (home), 0.5 calm (behind the table and Cage), 0 frozen.
## Fixed pools, no allocations per frame.

const MAX_PASSERS := 2
const MAX_WISPS := 6

var t := 0.0
var bokeh: Array = []      ## {x, y, r, c, ph, vx, flash}
var passers: Array = []    ## {on, x, dir, speed, h, hat, tray}
var wisps: Array = []      ## {on, x, age, life, sway}
var glint := {"on": false, "x": 0.0, "y": 0.0, "age": 0.0}
var _next_passer := 4.0
var _next_wisp := 1.0
var _next_flash := 3.0
var _next_glint := 2.0
var rng := RandomNumberGenerator.new()


func _init(seed_v: int = 7, count: int = 34, top: float = 0.04, bottom: float = 0.7) -> void:
	rng.seed = seed_v
	var cols := [Color("#ffb347"), Color("#ff6b8b"), Color("#ffd98a"), Color("#ffb347"), Color("#7fb8ff")]
	for i in range(count):
		bokeh.append({"x": rng.randf(), "y": rng.randf_range(top, bottom), "r": rng.randf_range(4.0, 16.0),
			"c": cols[rng.randi() % cols.size()], "ph": rng.randf() * TAU, "vx": rng.randf_range(-0.006, 0.006), "flash": 0.0})
	for i in range(MAX_PASSERS):
		passers.append({"on": false, "x": 0.0, "dir": 1.0, "speed": 0.04, "h": 0.3, "hat": false, "tray": false})
	for i in range(MAX_WISPS):
		wisps.append({"on": false, "x": 0.0, "age": 0.0, "life": 6.0, "sway": 1.0})


## Move everything on by `delta` seconds at `level` (0 = frozen).
func update(delta: float, level: float) -> void:
	if level <= 0.0:
		return
	var d := delta * (0.6 + 0.4 * level)   # calm also moves a little slower
	t += d
	for b in bokeh:
		b.x = fposmod(b.x + b.vx * d, 1.0)
		b.flash = maxf(0.0, b.flash - d * 0.8)
	# People walking past, out of focus.
	_next_passer -= d
	if _next_passer <= 0.0:
		_next_passer = rng.randf_range(6.0, 14.0) / maxf(0.35, level)
		for p in passers:
			if not p.on:
				p.on = true
				p.dir = 1.0 if rng.randf() < 0.5 else -1.0
				p.x = -0.12 if p.dir > 0.0 else 1.12
				p.speed = rng.randf_range(0.03, 0.055)
				p.h = rng.randf_range(0.26, 0.36)
				p.hat = rng.randf() < 0.45
				p.tray = rng.randf() < 0.3
				break
	for p in passers:
		if p.on:
			p.x += p.dir * p.speed * d
			if p.x < -0.2 or p.x > 1.2:
				p.on = false
	# Smoke rising from below.
	_next_wisp -= d
	if _next_wisp <= 0.0:
		_next_wisp = rng.randf_range(1.5, 3.5) / maxf(0.35, level)
		for w in wisps:
			if not w.on:
				w.on = true
				w.x = rng.randf_range(0.05, 0.95)
				w.age = 0.0
				w.life = rng.randf_range(5.0, 8.0)
				w.sway = rng.randf_range(0.6, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
				break
	for w in wisps:
		if w.on:
			w.age += d
			if w.age > w.life:
				w.on = false
	# A far table's lights flare: someone over there just won.
	_next_flash -= d
	if _next_flash <= 0.0:
		_next_flash = rng.randf_range(4.0, 9.0) / maxf(0.35, level)
		var b0: Dictionary = bokeh[rng.randi() % bokeh.size()]
		b0.flash = 1.0
		for b in bokeh:
			if b != b0 and absf(b.x - b0.x) < 0.06 and absf(b.y - b0.y) < 0.08:
				b.flash = 0.7
	# A glint off brass.
	_next_glint -= d
	if _next_glint <= 0.0:
		_next_glint = rng.randf_range(2.0, 5.0) / maxf(0.35, level)
		glint.on = true
		glint.x = rng.randf()
		glint.y = rng.randf_range(0.1, 0.6)
		glint.age = 0.0
	if glint.on:
		glint.age += d
		if glint.age > 0.6:
			glint.on = false


## Draw into `ci` over a `size` area. `s` scales pixel sizes (the home table renders bigger).
func draw_back(ci: CanvasItem, size: Vector2, level: float, s: float = 1.0) -> void:
	var a_mul: float = 0.55 + 0.45 * clampf(level, 0.0, 1.0)
	for b in bokeh:
		var breathe := 1.0 + 0.12 * sin(t * 0.9 + b.ph)
		var a: float = (0.07 + 0.04 * sin(t * 1.1 + b.ph) + 0.25 * b.flash) * a_mul
		var c := Vector2(b.x * size.x, b.y * size.y)
		var r: float = b.r * s * breathe * (1.0 + 0.4 * b.flash)
		ci.draw_circle(c, r, Color(b.c, a * 0.6), true, -1.0, false)
		ci.draw_circle(c, r * 0.72, Color(b.c, a), true, -1.0, false)
		ci.draw_circle(c, r * 0.4, Color(b.c.lightened(0.2), a * 0.8), true, -1.0, false)
	# Silhouettes walk in front of the lights (out of focus: soft layered edges).
	for p in passers:
		if p.on:
			_passer(ci, size, p, a_mul, s)


func draw_front(ci: CanvasItem, size: Vector2, level: float, s: float = 1.0) -> void:
	var a_mul: float = 0.5 + 0.5 * clampf(level, 0.0, 1.0)
	for w in wisps:
		if not w.on:
			continue
		var k: float = w.age / w.life
		for i in range(7):
			var kk := clampf(k - i * 0.035, 0.0, 1.0)
			if kk <= 0.0:
				continue
			var y: float = size.y * (1.02 - kk * 0.75)
			var x: float = w.x * size.x + sin(kk * 7.0 + t * 0.6) * 14.0 * s * w.sway * kk
			var fade: float = sin(kk * PI) * (1.0 - i / 7.0)
			ci.draw_circle(Vector2(x, y), (2.0 + kk * 6.0) * s, Color(0.85, 0.82, 0.78, 0.045 * fade * a_mul), true, -1.0, false)
	if glint.on:
		var g: float = sin(glint.age / 0.6 * PI)
		var c := Vector2(glint.x * size.x, glint.y * size.y).round()
		var col := Color(1.0, 0.92, 0.7, 0.8 * g * a_mul)
		var arm: float = maxf(1.0, round(3.0 * g * s))
		ci.draw_rect(Rect2(c - Vector2(arm, 0), Vector2(arm * 2 + 1, 1)), col)
		ci.draw_rect(Rect2(c - Vector2(0, arm), Vector2(1, arm * 2 + 1)), col)


## A passer-by: shoulders, head and maybe a hat or a waiter's tray, drawn soft (three layers).
func _passer(ci: CanvasItem, size: Vector2, p: Dictionary, a_mul: float, s: float) -> void:
	var h: float = p.h * size.y
	var x: float = p.x * size.x
	var base := size.y * 0.78
	var bob: float = absf(sin(t * 5.0 + p.x * 20.0)) * 2.0 * s   # a walking bob
	var col := Color(0.015, 0.01, 0.025)
	for layer in range(3):
		var grow: float = (2 - layer) * 3.0 * s
		var a: float = (0.12 + layer * 0.1) * a_mul
		var top := base - h - bob
		# Body: a rounded capsule.
		var bw: float = h * 0.34 + grow
		ci.draw_rect(Rect2(x - bw / 2.0, top + h * 0.3, bw, h * 0.7 + grow), Color(col, a))
		ci.draw_circle(Vector2(x, top + h * 0.32), bw / 2.0, Color(col, a), true, -1.0, false)
		# Head.
		ci.draw_circle(Vector2(x, top + h * 0.12), h * 0.1 + grow * 0.5, Color(col, a), true, -1.0, false)
		if p.hat:
			ci.draw_rect(Rect2(x - h * 0.15 - grow * 0.5, top + h * 0.04, h * 0.3 + grow, h * 0.03 + 1), Color(col, a))
			ci.draw_rect(Rect2(x - h * 0.09, top - h * 0.04, h * 0.18, h * 0.09), Color(col, a))
		if p.tray:
			var tx: float = x + p.dir * h * 0.22
			ci.draw_rect(Rect2(tx - h * 0.12, top + h * 0.3, h * 0.24 + grow, h * 0.025 + 1), Color(col, a))
