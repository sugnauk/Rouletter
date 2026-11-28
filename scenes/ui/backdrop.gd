extends Control
## The Gilded Ace after midnight, out of focus: the same room as the home screen's live table,
## seen past the screen you're using. A deep night gradient (ink blue up top, burgundy low down),
## the room's life (scenes/ui/ambience.gd: drifting lights, people passing, smoke, far-table
## flashes), two lamp glows that breathe, motes that catch their light, and a vignette. It fills
## the whole window. Purely decorative; `level` (set by main) keeps it calm behind play.

const P := preload("res://scenes/ui/palette.gd")
const Ambience := preload("res://scenes/ui/ambience.gd")

const TOP := Color("#0b0e18")
const LOW := Color("#1a0a10")

var t := 0.0
var motes: Array = []
var lamps: Array = [Vector2(0.62, 0.12), Vector2(0.18, 0.2)]   ## as fractions of the window
var sign_on := true
var level := 1.0          ## how lively the room is: 1 full, 0.5 calm (behind play), 0 still (main sets it)
var amb = Ambience.new(7, 34, 0.04, 0.7)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(30):
		motes.append({"p": Vector2(rng.randf(), rng.randf()), "v": rng.randf_range(0.006, 0.02), "ph": rng.randf() * TAU})


func _process(delta: float) -> void:
	amb.update(delta, level)
	if level <= 0.0:
		return
	t += delta * (0.6 + 0.4 * level)
	for m in motes:
		m.p.y -= m.v * delta * level
		m.p.x += sin(t * 0.7 + m.ph) * delta * 0.004 * level
		if m.p.y < -0.01:
			m.p.y = 1.01
	sign_on = not (fmod(t, 7.3) > 6.9 and fmod(t * 20.0, 2.0) > 1.0)
	queue_redraw()


func _draw() -> void:
	var W := size.x
	var H := size.y
	# The night gradient, in bands so it stays pixel-crisp.
	var bands := 14
	for i in range(bands):
		var col := TOP.lerp(LOW, float(i) / (bands - 1))
		draw_rect(Rect2(0, floor(H * i / bands), W, ceil(H / bands) + 1), col)
	# Lamp glows overhead, breathing slowly.
	for li in range(lamps.size()):
		var l: Vector2 = lamps[li] * size
		var breathe := 1.0 + 0.2 * sin(t * 0.6 + li * 2.1)
		for i in range(5):
			draw_circle(l, 170.0 - i * 30.0, Color(1.0, 0.76, 0.45, (0.014 + i * 0.006) * breathe), true, -1.0, false)
	# The room: drifting lights, people passing, far tables flaring (scenes/ui/ambience.gd).
	amb.draw_back(self, size, level)
	# Smoke motes, brighter where the lamps catch them.
	for m in motes:
		var mp: Vector2 = m.p * size
		var near := 0.0
		for l in lamps:
			near = maxf(near, 1.0 - clampf(mp.distance_to(l * size) / 170.0, 0.0, 1.0))
		draw_rect(Rect2(mp.round(), Vector2(1, 1)), Color(1, 0.88, 0.65, 0.08 + 0.28 * near))
	amb.draw_front(self, size, level)
	# A soft vignette pulls the eye to the middle (banded, to stay pixel-crisp).
	for i in range(6):
		var a := 0.16 - i * 0.025
		draw_rect(Rect2(0, 0, W, (6 - i) * 5.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, H - (6 - i) * 5.0, W, (6 - i) * 5.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, (6 - i) * 6.0, H), Color(0, 0, 0, a))
		draw_rect(Rect2(W - (6 - i) * 6.0, 0, (6 - i) * 6.0, H), Color(0, 0, 0, a))


## Small neon sign, drawn by screens that have room for it.
static func neon(ci: CanvasItem, pos: Vector2, text: String, on: bool) -> void:
	var font := P.title_font()
	var col := Color("#ff4fa3") if on else Color("#4a2236")
	if on:
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			ci.draw_string(font, pos + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col, 0.35))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
