extends Button
## Every button made with Palette.button(). Two looks:
##   - everyday (the default): a warm lacquer face with a soft bevel and a thin brass trim that
##     warms to gold on hover, lifts a pixel with a small gold notch, and dips when pressed.
##   - marquee (`marquee = true`, the hero buttons only: NEW RUN, CONTINUE): a border of light
##     bulbs that glow warm, chase on hover and all flash when pressed.
## `pulse` makes the trim breathe slowly (the button you probably want next). Disabled buttons go dark.

const P := preload("res://scenes/ui/palette.gd")

const MIN_BULBS := Vector2(60, 18)
const BULB_GAP := 6.0
const BULB_ON := Color("#ffe9a8")
const BULB_WARM := Color("#c98a2e")
const BULB_OFF := Color("#3a2a1a")
const BRASS := Color("#8a6a3a")

var accent: Color = P.GOLD     ## trim / lit-bulb colour (a "hero" button can use another)
var pulse := false             ## the trim breathes gently even when not hovered
var marquee := false           ## light bulbs round the border (hero buttons only)
var link := false              ## a text link (the home menu): no face, a gold underline and chip on hover
var _t := 0.0
var _flash := 0.0


var _hover_at := 0.0


func _t_hover() -> float:
	return _t - _hover_at


func _ready() -> void:
	mouse_entered.connect(func(): _hover_at = _t)
	button_down.connect(func():
		_flash = 1.0
		queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
	# Redraw only while something moves: a press flash, a pulse, hover, or a marquee's twinkle.
	if _flash > 0.0 or pulse or (marquee and (is_hovered() or int(_t * 8.0) % 4 == 0)) or (link and is_hovered()):
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hot: bool = is_hovered() and not disabled
	var down: bool = button_pressed or _flash > 0.5
	if link:
		# Text link: on hover a chip slides up beside it and a gold underline draws across.
		if hot:
			var cy: float = floor(size.y / 2.0)
			var grow: float = clampf(_t_hover() * 6.0, 0.0, 1.0)
			draw_circle(Vector2(5, cy), 3.5, accent.darkened(0.5), true, -1.0, false)
			draw_circle(Vector2(5, cy - 1), 3.5, accent, true, -1.0, false)
			draw_circle(Vector2(5, cy - 1), 1.5, accent.darkened(0.35), true, -1.0, false)
			var tw: float = get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
			draw_rect(Rect2(14, size.y - 3, floor(tw * grow), 1), accent)
		return
	if marquee:
		var trim: Color = BULB_OFF if disabled else (accent if hot or pulse else accent.darkened(0.45))
		if pulse and not hot and not disabled:
			trim = accent.darkened(0.45).lerp(accent, 0.5 + 0.5 * sin(_t * 3.0))
		draw_rect(r, trim, false, 1.0)
		draw_rect(Rect2(1, 1, size.x - 2, 1), Color(1, 1, 1, 0.10 if not down else 0.0))
		draw_rect(Rect2(1, size.y - 2, size.x - 2, 1), Color(0, 0, 0, 0.35))
		if size.x >= MIN_BULBS.x and size.y >= MIN_BULBS.y:
			_draw_bulbs(r, hot)
		if _flash > 0.0 and not disabled:
			draw_rect(r.grow(-1), Color(BULB_ON, 0.18 * _flash))
		return
	# Everyday: soft bevel, brass trim warming to gold, a small notch when hovered.
	var trim2: Color = BULB_OFF if disabled else (accent if hot else BRASS)
	if pulse and not hot and not disabled:
		trim2 = BRASS.lerp(accent, 0.5 + 0.5 * sin(_t * 2.4))
	draw_rect(r, trim2, false, 1.0)
	if not disabled:
		draw_rect(Rect2(1, 1, size.x - 2, 1), Color(1, 0.9, 0.7, 0.0 if down else (0.14 if hot else 0.07)))
		draw_rect(Rect2(1, size.y - 2, size.x - 2, 1), Color(0, 0, 0, 0.45 if not down else 0.2))
	if hot and size.x >= 30.0:
		var cy: float = floor(size.y / 2.0)
		draw_rect(Rect2(3, cy - 2, 1, 5), accent)
		draw_rect(Rect2(4, cy - 1, 1, 3), accent)
		draw_rect(Rect2(5, cy, 1, 1), accent)
	if _flash > 0.0 and not disabled:
		draw_rect(r.grow(-1), Color(accent, 0.14 * _flash))


## Bulbs every few pixels round the border, chasing when hovered.
func _draw_bulbs(r: Rect2, hot: bool) -> void:
	var pts := []
	var inset := 2.0
	var x := inset + 1.0
	while x <= r.size.x - inset - 2.0:
		pts.append(Vector2(x, inset))
		x += BULB_GAP
	var y := inset + BULB_GAP
	while y <= r.size.y - inset - 2.0:
		pts.append(Vector2(r.size.x - inset - 1.0, y))
		y += BULB_GAP
	x = r.size.x - inset - 1.0 - BULB_GAP
	while x >= inset:
		pts.append(Vector2(x, r.size.y - inset - 1.0))
		x -= BULB_GAP
	y = r.size.y - inset - 1.0 - BULB_GAP
	while y >= inset + BULB_GAP:
		pts.append(Vector2(inset, y))
		y -= BULB_GAP
	var chase := int(_t * 14.0)
	var twinkle := int(_t * 2.0)
	for i in range(pts.size()):
		var col: Color
		if disabled:
			col = BULB_OFF
		elif _flash > 0.0:
			col = BULB_ON
		elif hot:
			col = BULB_ON if (i + chase) % 3 == 0 else BULB_WARM
		elif pulse:
			col = BULB_WARM.lerp(BULB_ON, 0.5 + 0.5 * sin(_t * 3.0 + i * 0.4))
		else:
			col = BULB_ON if (i * 7 + twinkle) % 23 == 0 else (BULB_WARM if i % 2 == 0 else BULB_WARM.darkened(0.45))
		draw_rect(Rect2(pts[i], Vector2(1, 1)), col)
		if col == BULB_ON:
			draw_rect(Rect2(pts[i] - Vector2(1, 1), Vector2(3, 3)), Color(col, 0.22))
