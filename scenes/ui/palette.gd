extends RefCounted
## Fixed pixel-art palette and the shared UI theme (640x360 base resolution, no anti-aliasing).

const BG := Color("#08140e")
const PANEL := Color("#11251a")
const PANEL_HI := Color("#1c3a29")
const FELT := Color("#0f5233")
const FELT_DARK := Color("#0a3a24")
const LINE := Color("#d6c38a")
const RED := Color("#b8262d")
const BLACK := Color("#1a1a22")
const GREEN := Color("#1e8a46")
const GOLD := Color("#f2c14e")
const CREAM := Color("#f4ead5")
const DIM := Color("#7f9688")
const VIOLET := Color("#a061e8")
const CYAN := Color("#4cc9f0")
const WOOD := Color("#6b4426")
const WOOD_DARK := Color("#3b2414")
const DANGER := Color("#ff5d5d")
const GOOD := Color("#7ee081")

const CHIP_COLORS := {
	"bet": Color("#ece6d6"), "perm": GOLD, "magnet": Color("#e63946"), "compounding": Color("#80ed99"),
	"croupier": Color("#adb5bd"), "wildcard_zero": Color("#2ec4b6"), "mint": Color("#57cc99"),
	"respin": CYAN, "ledger": Color("#f4a261"), "collector": VIOLET,
}

## Fonts (SIL Open Font License, see fonts/*-OFL.txt):
##   Silkscreen     - body text, pixel-exact at multiples of 8px
##   Press Start 2P - titles, pixel-exact at multiples of 8px
const FONT_PATH := "res://fonts/Silkscreen-Regular.ttf"
const TITLE_FONT_PATH := "res://fonts/PressStart2P-Regular.ttf"
const FONT_SMALL := 8
const FONT := 8
const FONT_BIG := 16
const FONT_HUGE := 24

static var _font: FontFile
static var _title_font: FontFile


static func font() -> Font:
	if _font == null:
		_font = _pixel(FONT_PATH)
	return _font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = _pixel(TITLE_FONT_PATH)
	return _title_font


static func _pixel(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f


static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func chip_color(kind: String) -> Color:
	return CHIP_COLORS.get(kind, CREAM)


static func box(bg: Color, border: Color, width: int = 1, margin: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(0)
	s.content_margin_left = margin + 1
	s.content_margin_right = margin + 1
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	s.anti_aliasing = false
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font())
	t.set_stylebox("normal", "Button", box(PANEL_HI, LINE.darkened(0.35)))
	t.set_stylebox("hover", "Button", box(PANEL_HI.lightened(0.12), GOLD))
	t.set_stylebox("pressed", "Button", box(PANEL.darkened(0.2), GOLD))
	t.set_stylebox("disabled", "Button", box(PANEL, PANEL_HI))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_color", "Label", CREAM)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE.darkened(0.5)))
	t.set_stylebox("panel", "Panel", box(PANEL, LINE.darkened(0.5)))
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_font_size("normal_font_size", "RichTextLabel", FONT_SMALL)
	t.set_font_size("bold_font_size", "RichTextLabel", FONT_SMALL)
	t.set_stylebox("background", "ProgressBar", box(BLACK, LINE.darkened(0.4)))
	t.set_stylebox("fill", "ProgressBar", box(GOLD, GOLD, 0, 0))
	return t


static func label(parent: Node, text: String, size: int = FONT, col: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	if size >= FONT_BIG:
		l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if parent != null:
		parent.add_child(l)
	return l


static func button(parent: Node, text: String, cb: Callable, size: Vector2 = Vector2(0, 0), font: int = FONT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font)
	b.pressed.connect(cb)
	if parent != null:
		parent.add_child(b)
	return b


static func place(c: Control, pos: Vector2, size: Vector2 = Vector2.ZERO) -> Control:
	c.position = pos
	if size != Vector2.ZERO:
		c.size = size
		c.custom_minimum_size = size
	return c
