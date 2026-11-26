extends RefCounted
## Fixed pixel-art palette and the shared UI theme (640x360 base resolution, no anti-aliasing).

## The play area's size: 640x360 landscape, 360x640 on a phone held upright (main sets these).
static var W := 640.0
static var H := 360.0
static var portrait := false

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
const LACQUER := Color("#150c10")      ## marquee button face
const GOOD := Color("#7ee081")

const CHIP_COLORS := {
	"bet": Color("#ece6d6"), "perm": GOLD, "magnet": Color("#e63946"), "compounding": Color("#80ed99"),
	"croupier": Color("#adb5bd"), "wildcard_zero": Color("#2ec4b6"), "mint": Color("#57cc99"),
	"respin": CYAN, "ledger": Color("#f4a261"), "collector": VIOLET,
	"bridge": Color("#cdb4db"), "kingmaker": Color("#ffd166"),
	"mirror": Color("#90e0ef"), "porch_light": Color("#f6bd60"),
	"black_cat": Color("#4a4a5a"), "penny": Color("#d08a4a"), "snowball": Color("#e8f4ff"),
	"sentinel": Color("#2ec46a"), "crown": Color("#ffd166"),
	"street_light": Color("#e9c46a"), "red_herring": Color("#e76f51"), "jar": Color("#8ecae6"), "hedge": Color("#52b788"),
	"wheel_spoke": Color("#d4a373"), "echo": Color("#a2d2ff"), "ace": Color("#f8f9fa"), "tip_jar": Color("#90be6d"),
	"green_thumb": Color("#38b000"), "signpost": Color("#bc8a5f"),
	"odd_fellow": Color("#e9c46a"), "even_keel": Color("#90e0ef"), "low_roller": Color("#80ed99"), "penthouse": Color("#f4a261"),
	"dozen_watch": Color("#cdb4db"), "pillar": Color("#a8dadc"), "night_owl": Color("#b5838d"), "piggy_bank": Color("#ffafcc"),
	"clover": Color("#38b000"), "doorbell": Color("#ffd166"), "prime_time": Color("#e76f51"), "square_deal": Color("#4cc9f0"),
	"teen_idol": Color("#ff8fab"), "fibonacci": Color("#c77dff"), "nickel": Color("#adb5bd"), "seventh_heaven": Color("#ffe066"),
	"last_digit": Color("#8ecae6"), "far_side": Color("#f28482"), "seedling": Color("#95d5b2"), "golden_goose": Color("#fcbf49"),
	"heart_of_gold": Color("#ef476f"), "spare_key": Color("#2ec4b6"),
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
	# Buttons are casino marquees (scenes/ui/marquee_button.gd draws the bulbs and trim on top):
	# black lacquer with a deep-red sheen on hover, pressing dips into red velvet.
	t.set_stylebox("normal", "Button", box(LACQUER, LACQUER.lightened(0.18), 1, 4))
	t.set_stylebox("hover", "Button", box(Color("#2a1116"), GOLD.darkened(0.2), 1, 4))
	t.set_stylebox("pressed", "Button", box(Color("#4a0f18"), GOLD, 1, 4))
	t.set_stylebox("disabled", "Button", box(Color("#0e0a0c"), Color("#2a2024"), 1, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color("#ffe9a8"))
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
	t.set_color("font_outline_color", "Button", Color("#0a0608"))
	t.set_constant("outline_size", "Button", 0)
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
	var b: Button = load("res://scenes/ui/marquee_button.gd").new()
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
		c.custom_minimum_size = size   # first, so a control can also shrink (portrait re-layouts)
		c.size = size
	return c
