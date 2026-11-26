extends Button
## A casino-marquee button: black lacquer face, gold trim and a border of light bulbs.
##   - at rest the bulbs glow warm and twinkle now and then
##   - on hover they chase round the border and the trim lights up
##   - on press every bulb flashes and the face dips a pixel
## Small buttons (under MIN_BULBS) get a lit trim without bulbs. Disabled buttons go dark.
## Used by every button made with Palette.button().

const P := preload("res://scenes/ui/palette.gd")

const MIN_BULBS := Vector2(60, 18)
const BULB_GAP := 6.0
const BULB_ON := Color("#ffe9a8")
const BULB_WARM := Color("#c98a2e")
const BULB_OFF := Color("#3a2a1a")

var accent: Color = P.GOLD     ## trim / lit-bulb colour (a "hero" button can use another)
var pulse := false             ## breathe gently even when not hovered (NEW RUN, DEAL ME IN)
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
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
	# Redraw while something is moving: hover chase, a press flash, a pulse, or a slow twinkle.
	if is_hovered() or _flash > 0.0 or pulse or int(_t * 8.0) % 4 == 0:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hot: bool = is_hovered() and not disabled
	var down: bool = button_pressed or _flash > 0.5
	# Trim: a bright inner line along the top, a dark one along the bottom.
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
