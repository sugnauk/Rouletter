extends RefCounted
## Procedural pixel portraits for the cast: half-body busts on a 48x48 pixel grid (scaled to any
## size), shaded like proper pixel art: one key light from the top left, a warm rim light down the
## right edge, three tones per material and a dark outline round the silhouette.
## Each character is a recipe (CAST): suit, shirt, skin, hair and hair style, hat, extras, a
## backdrop colour and a `face` (warm, sly, stern, bored, grin) that sets the brows and mouth.
## Unknown speakers fall back to a tinted silhouette seeded from their name.

const P := preload("res://scenes/ui/palette.gd")

const SKIN := [Color("#f1c27d"), Color("#e0ac69"), Color("#c68642"), Color("#8d5524"), Color("#ffdbac")]
const OUTLINE := Color("#0c0810")
const RIM := Color(1.0, 0.82, 0.55)

## suit, shirt, skin index, hair colour, hair style, hat, extras, backdrop, face
const CAST := {
	"Mr. Vance": {"suit": "#14141c", "shirt": "#f4ead5", "skin": 4, "hair": "#9aa0a6", "hair_style": "slick",
		"extras": ["bowtie", "cigar", "lapels"], "bg": "#3b1020", "face": "sly"},
	"Rosa": {"suit": "#16141c", "shirt": "#f4ead5", "skin": 1, "hair": "#2a1610", "hair_style": "bob",
		"extras": ["visor", "vest", "bowtie", "chip_earring", "lips"], "bg": "#0f3a26", "face": "warm"},
	"Lucky Lou": {"suit": "#6b4426", "shirt": "#d6c38a", "skin": 1, "hair": "#3b2414", "hat": "fedora", "hat_col": "#3d3d4a",
		"extras": ["stubble", "loose_tie", "toothpick", "lapels"], "bg": "#1f2a1f", "face": "grin"},
	"Abe": {"suit": "#5a4a3a", "shirt": "#d9cbb0", "skin": 4, "hair": "#cfcfcf", "hair_style": "bald",
		"extras": ["glasses", "beard", "cardigan"], "bg": "#2b2418", "face": "warm"},
	"Big Sal": {"suit": "#2b2b36", "shirt": "#e9e9e9", "skin": 2, "hair": "#1a1a1a", "hat": "fedora", "hat_col": "#1a1a22",
		"extras": ["scar", "wide", "tie", "lapels"], "bg": "#2a1414", "face": "stern"},
	"Cashier": {"suit": "#e9e3d3", "shirt": "#e9e3d3", "skin": 0, "hair": "#5a3b1e", "hair_style": "short",
		"extras": ["visor", "armband", "bowtie"], "bg": "#1c2a1f", "face": "bored"},
	"Pit Boss": {"suit": "#1c1c28", "shirt": "#f4ead5", "skin": 1, "hair": "#20140c", "hair_style": "slick",
		"extras": ["moustache", "tie", "lapels"], "bg": "#2a1018", "face": "stern"},
	"Loan Shark": {"suit": "#2e5266", "shirt": "#1a1a22", "skin": 2, "hair": "#101010", "hair_style": "slick",
		"extras": ["shades", "chain", "lapels"], "bg": "#10262e", "face": "grin"},
	"Fence": {"suit": "#4a4a3a", "shirt": "#7a7a66", "skin": 1, "hair": "#4a3020", "hat": "cap", "hat_col": "#5a5a48",
		"extras": ["collar", "stubble"], "bg": "#202018", "face": "sly"},
	"Dealer": {"suit": "#141414", "shirt": "#f4ead5", "skin": 3, "hair": "#111111", "hair_style": "short",
		"extras": ["vest", "bowtie"], "bg": "#13241a", "face": "warm"},
	"The Accountant": {"suit": "#4a4f58", "shirt": "#f4ead5", "skin": 4, "hair": "#6b6b6b", "hair_style": "thin",
		"extras": ["glasses", "tie", "lapels"], "bg": "#1c1f26", "face": "bored"},
	"Madame Oro": {"suit": "#1e8a46", "shirt": "#1e8a46", "skin": 0, "hair": "#f2c14e", "hair_style": "big",
		"extras": ["lips", "pearls", "earrings"], "bg": "#0e2a1a", "face": "sly"},
	"Vic \"The Rake\"": {"suit": "#3a2a4a", "shirt": "#d6c38a", "skin": 1, "hair": "#2a1a10", "hat": "fedora", "hat_col": "#2a1a2a",
		"extras": ["pinstripe", "toothpick", "lapels"], "bg": "#1e1426", "face": "sly"},
	"The Inspector": {"suit": "#2c3e50", "shirt": "#f4ead5", "skin": 4, "hair": "#3b2a1a", "hat": "cap", "hat_col": "#1f2d3a",
		"extras": ["badge", "moustache", "lapels"], "bg": "#14202a", "face": "stern"},
	"Velvet": {"suit": "#6a1b9a", "shirt": "#6a1b9a", "skin": 0, "hair": "#101010", "hair_style": "long",
		"extras": ["lips", "earrings", "pearls"], "bg": "#25102e", "face": "sly"},
	"The Duchess": {"suit": "#7b2d4a", "shirt": "#f4ead5", "skin": 4, "hair": "#e8e0d0", "hair_style": "big",
		"extras": ["pearls", "lips", "earrings"], "bg": "#2a1020", "face": "bored"},
	"Miss Tempo": {"suit": "#c0392b", "shirt": "#141414", "skin": 3, "hair": "#141414", "hair_style": "waves",
		"extras": ["lips", "bowtie"], "bg": "#201014", "face": "grin"},
	"The Timekeeper": {"suit": "#3e3424", "shirt": "#d9cbb0", "skin": 4, "hair": "#cfcfcf", "hair_style": "bald",
		"extras": ["glasses", "chain", "moustache"], "bg": "#1e1a12", "face": "stern"},
	"Countess Ilsa": {"suit": "#14141c", "shirt": "#5a1a6a", "skin": 4, "hair": "#e8e8f0", "hair_style": "long",
		"extras": ["lips", "earrings"], "bg": "#140e1e", "face": "sly"},
	"The Auditor": {"suit": "#2f3a2f", "shirt": "#f4ead5", "skin": 4, "hair": "#4a4a4a", "hair_style": "thin",
		"extras": ["glasses", "tie", "badge", "lapels"], "bg": "#141c14", "face": "bored"},
	"Silk Montague": {"suit": "#c9a227", "shirt": "#1a1a22", "skin": 1, "hair": "#2a1a10", "hair_style": "slick",
		"extras": ["moustache", "chain", "bowtie", "lapels"], "bg": "#2a2010", "face": "grin"},
	"Mr. Winter": {"suit": "#d9e2ec", "shirt": "#14141c", "skin": 4, "hair": "#f4f4f8", "hair_style": "short",
		"extras": ["shades", "tie", "lapels"], "bg": "#10202e", "face": "stern"},
	"Mr. Kline": {"suit": "#3d3d3d", "shirt": "#f4ead5", "skin": 4, "hair": "#bdbdbd", "hair_style": "thin",
		"extras": ["glasses", "tie", "lapels"], "bg": "#1f1f1f", "face": "bored"},
	"The Twins": {"suit": "#3a1a2a", "shirt": "#f4ead5", "skin": 0, "hair": "#e8c070", "hair_style": "bob",
		"extras": ["twins", "lips", "pearls"], "bg": "#2a0f1e", "face": "sly", "hair2": "#1a1010"},
	"The Mechanic": {"suit": "#3a4a5a", "shirt": "#3a4a5a", "skin": 2, "hair": "#2a1a10", "hat": "cap", "hat_col": "#8a2a1a",
		"extras": ["grease", "wrench", "collar", "stubble"], "bg": "#1a2026", "face": "grin"},
	"The Ringmaster": {"suit": "#a01c24", "shirt": "#f4ead5", "skin": 4, "hair": "#3a2a1a", "hat": "top_hat", "hat_col": "#141418",
		"extras": ["moustache", "bowtie", "lapels", "braid"], "bg": "#2a0e10", "face": "grin"},
}

static var _ci: CanvasItem
static var _o := Vector2.ZERO
static var _u := 1.0


static func has(who: String) -> bool:
	return CAST.has(who)


## One pixel-grid rectangle (48x48 grid coordinates).
static func _px(x: float, y: float, w: float, h: float, col: Color) -> void:
	var x0 := clampf(x, 0.0, 48.0)
	var y0 := clampf(y, 0.0, 48.0)
	var x1 := clampf(x + w, 0.0, 48.0)
	var y1 := clampf(y + h, 0.0, 48.0)
	if x1 <= x0 or y1 <= y0:
		return
	_ci.draw_rect(Rect2(_o + Vector2(x0, y0) * _u, Vector2(x1 - x0, y1 - y0) * _u), col)


## Shadow / base / light tones of a colour (light comes from the top left).
static func _tones(c: Color) -> Array:
	return [c.darkened(0.38), c, c.lightened(0.2)]


## Draw `who` into `r` (any size; square works best).
static func draw(ci: CanvasItem, who: String, r: Rect2) -> void:
	_ci = ci
	_o = r.position
	_u = r.size.x / 48.0
	if who == "Narrator":
		ci.draw_rect(r, P.BLACK)
		ci.draw_circle(r.get_center() - Vector2(0, _u * 3), 10 * _u, P.GOLD.darkened(0.4), true, -1.0, false)
		ci.draw_circle(r.get_center() - Vector2(0, _u * 3), 6.5 * _u, P.BLACK, true, -1.0, false)
		_px(21, 33, 6, 9, P.GOLD.darkened(0.5))
		ci.draw_rect(r, P.GOLD, false, 1.0)
		return
	var d: Dictionary = CAST.get(who, _fallback(who))
	var ex: Array = d.get("extras", [])
	_backdrop(Color(d.bg))
	if "twins" in ex:
		# Two of them in one frame: the dark-haired one behind, the fair one in front.
		var back := d.duplicate()
		back.hair = d.get("hair2", "#1a1010")
		_figure(back, 31, 1, true)
		_figure(d, 18, 0, false)
	else:
		_figure(d, 24, 0, false)
	# A thin gold frame.
	ci.draw_rect(r, P.GOLD.darkened(0.1), false, 1.0)


## The backdrop: a smoky vertical gradient, a soft spotlight behind the head and two bokeh dots.
static func _backdrop(bg: Color) -> void:
	for i in range(8):
		_px(0, i * 6, 48, 6, bg.darkened(0.45 - i * 0.04))
	for i in range(4):
		_ci.draw_circle(_o + Vector2(24, 18) * _u, (19 - i * 4) * _u, Color(bg.lightened(0.35), 0.10 + i * 0.05), true, -1.0, false)
	_ci.draw_circle(_o + Vector2(7, 9) * _u, 2.5 * _u, Color(1, 0.8, 0.5, 0.12), true, -1.0, false)
	_ci.draw_circle(_o + Vector2(41, 13) * _u, 3.5 * _u, Color(1, 0.6, 0.7, 0.08), true, -1.0, false)


## Head half-widths, row by row (y 9..33): a rounded crown, cheekbones, a tapering jaw.
const HEAD := {9: 4.0, 10: 6.0, 11: 7.5, 12: 8.5, 13: 9.0, 14: 9.0, 15: 9.0, 16: 9.0, 17: 9.0, 18: 9.0, 19: 9.0,
	20: 9.0, 21: 9.0, 22: 8.8, 23: 8.6, 24: 8.4, 25: 8.0, 26: 7.6, 27: 7.0, 28: 6.4, 29: 5.6, 30: 4.8, 31: 3.8, 32: 2.6}


## One character, centred on `cx`, nudged down by `dy` (the second twin sits a little lower).
static func _figure(d: Dictionary, cx: float, dy: float, behind: bool) -> void:
	var ex: Array = d.get("extras", [])
	var skin: Color = SKIN[int(d.skin) % SKIN.size()]
	if behind:
		skin = skin.darkened(0.15)
	var st: Array = _tones(skin)
	var suit: Array = _tones(Color(d.suit))
	var shirt: Array = _tones(Color(d.shirt))
	var hair: Array = _tones(Color(d.hair))
	var face: String = d.get("face", "warm")
	var style: String = d.get("hair_style", "short") if d.get("hat", "") == "" else "under_hat"
	_hair_back(cx, dy, hair, style)
	_body(cx, dy, suit, shirt, ex, d)
	# The neck, shaded under the jaw.
	_px(cx - 4, 30 + dy, 8, 6, st[0])
	_px(cx - 4, 30 + dy, 3, 6, st[1])
	# Head: outline, then base, then the key light on the left and shadow on the right.
	for y in HEAD:
		var hw: float = HEAD[y]
		_px(cx - hw - 1, y + dy, (hw + 1) * 2, 1, OUTLINE)
	_px(cx - 3, 8 + dy, 6, 1, OUTLINE)
	_px(cx - 3, 33 + dy, 6, 1, OUTLINE)
	for y in HEAD:
		var hw: float = HEAD[y]
		_px(cx - hw, y + dy, hw * 2, 1, st[1])
		_px(cx - hw, y + dy, minf(3.0, hw), 1, st[2])
		_px(cx + hw - 2, y + dy, 2, 1, st[0])
	_px(cx + 7, 13 + dy, 1, 10, Color(RIM, 0.35))     # rim light down the cheek
	_px(cx - 3, 28 + dy, 7, 2, st[0].lerp(st[1], 0.5))   # under-chin shade
	# Ears.
	for side in [-1, 1]:
		var ex0: float = cx - 10.5 if side < 0 else cx + 9.0
		_px(ex0, 18 + dy, 1.5, 5, st[0] if side > 0 else st[1])
	_face(cx, dy, st, hair, face, ex, d)
	_hair(cx, dy, hair, style, ex)
	_hat(cx, dy, d)
	_extras_head(cx, dy, st, hair, ex)


## Shoulders and chest: a suit cut with lapels, a shirt V, folds and the rim light.
static func _body(cx: float, dy: float, suit: Array, shirt: Array, ex: Array, d: Dictionary) -> void:
	var wide: float = 3.0 if "wide" in ex else 0.0
	for y in range(34, 49):
		var hw: float = minf(21.0 + wide, 12.0 + (y - 34) * 1.6 + wide)
		_px(cx - hw - 1, y + dy, (hw + 1) * 2, 1, OUTLINE)
	for y in range(35, 49):
		var hw: float = minf(21.0 + wide, 12.0 + (y - 35) * 1.6 + wide)
		_px(cx - hw, y + dy, hw * 2, 1, suit[1])
		_px(cx - hw, y + dy, 4, 1, suit[2])
		_px(cx + hw - 4, y + dy, 4, 1, suit[0])
		_px(cx + hw - 1, y + dy, 1, 1, Color(RIM, 0.45))
	if "pinstripe" in ex:
		for x in range(int(cx - 18), int(cx + 18), 4):
			_px(x, 38 + dy, 1, 10, suit[2].lerp(suit[1], 0.4))
	if "cardigan" in ex:
		for y in range(38, 48, 3):
			_px(cx - 1, y + dy, 2, 1, suit[0])
	# Shirt V and collar points.
	if d.shirt != d.suit:
		for i in range(12):
			var w: float = maxf(1.0, 9.0 - i * 0.75)
			_px(cx - w, 34 + i + dy, w * 2, 1, shirt[1])
		_px(cx - 6, 34 + dy, 3, 3, shirt[2])
		_px(cx + 3, 34 + dy, 3, 3, shirt[0])
	if "vest" in ex:
		for i in range(10):
			var vw: float = 8.0 - i * 0.5
			_px(cx - vw - 3, 38 + i + dy, 3, 1, Color("#1a1a1f"))
			_px(cx + vw, 38 + i + dy, 3, 1, Color("#1a1a1f"))
		for y in [41, 44, 47]:
			_px(cx - 0.5, y + dy, 1, 1, P.GOLD)
	if "lapels" in ex:
		for i in range(9):
			_px(cx - 9 + i * 0.5, 36 + i + dy, 2, 1, suit[2])
			_px(cx + 7 - i * 0.5, 36 + i + dy, 2, 1, suit[0])
	if "collar" in ex:
		_px(cx - 10, 33 + dy, 6, 4, suit[2])
		_px(cx + 4, 33 + dy, 6, 4, suit[0])
	if "braid" in ex:   # the Ringmaster's gold frogging
		for y in [39, 42, 45]:
			_px(cx - 8, y + dy, 5, 1, P.GOLD)
			_px(cx + 3, y + dy, 5, 1, P.GOLD)
	# Neckwear and chest details.
	if "bowtie" in ex:
		var bt := Color("#b8262d")
		_px(cx - 4, 34 + dy, 3, 3, bt)
		_px(cx + 1, 34 + dy, 3, 3, bt.darkened(0.3))
		_px(cx - 1, 34.5 + dy, 2, 2, bt.darkened(0.45))
	if "tie" in ex:
		_px(cx - 1.5, 34 + dy, 3, 2, Color("#7a1f2b"))
		_px(cx - 1, 36 + dy, 2, 11, Color("#7a1f2b"))
		_px(cx - 1, 36 + dy, 1, 11, Color("#9a2f3b"))
	if "loose_tie" in ex:
		_px(cx, 36 + dy, 2, 10, Color("#a83232"))
		_px(cx - 2, 35 + dy, 3, 2, Color("#a83232"))
	if "pearls" in ex:
		for i in range(9):
			var px: float = cx - 8 + i * 2
			_px(px, 35 + (1 if absf(px - cx) < 5 else 0) + dy, 1, 1, Color("#f4f4f4"))
	if "chain" in ex:
		for i in range(8):
			var qx: float = cx - 7 + i * 2
			_px(qx, 37 + (1 if absf(qx - cx) < 4 else 0) + dy, 1, 1, P.GOLD)
	if "badge" in ex:
		_px(cx + 10, 40 + dy, 4, 4, P.GOLD)
		_px(cx + 11, 41 + dy, 2, 2, P.GOLD.darkened(0.3))
	if "armband" in ex:
		_px(cx - 21, 42 + dy, 5, 3, Color("#b8262d"))
		_px(cx + 16, 42 + dy, 5, 3, Color("#b8262d"))
	if "wrench" in ex:
		_px(cx + 14, 36 + dy, 2, 12, Color("#9aa0aa"))
		_px(cx + 12, 34 + dy, 6, 3, Color("#c0c6d0"))
		_px(cx + 14, 34 + dy, 2, 1, Color("#3a4048"))


## Eyes, brows, nose and mouth, set by the character's mood.
static func _face(cx: float, dy: float, st: Array, hair: Array, face: String, ex: Array, d: Dictionary) -> void:
	var eye_y: float = 19.0 + dy
	var brow: Color = hair[0].darkened(0.2)
	if "shades" in ex:
		_px(cx - 8, eye_y - 1, 16, 4, Color("#0a0a0e"))
		_px(cx - 7, eye_y - 1, 3, 1, Color(1, 1, 1, 0.45))
		_px(cx + 2, eye_y - 1, 3, 1, Color(1, 1, 1, 0.45))
	else:
		for side in [-1, 1]:
			var ex0: float = cx - 6 if side < 0 else cx + 2
			_px(ex0, eye_y, 4, 2, Color("#f4efe6"))
			_px(ex0 + 1, eye_y, 2, 2, Color("#2a1e1a"))
			_px(ex0 + 1, eye_y, 1, 1, Color.WHITE)
			# Lids: heavy for sly and bored looks.
			var lid: float = 1.0 if face in ["sly", "bored"] else 0.0
			_px(ex0, eye_y - 1, 4, 1 + lid, st[0])
	# Brows.
	match face:
		"stern":
			_px(cx - 7, eye_y - 4, 2, 1, brow)
			_px(cx - 5, eye_y - 3, 3, 1, brow)
			_px(cx + 2, eye_y - 3, 3, 1, brow)
			_px(cx + 5, eye_y - 4, 2, 1, brow)
		"warm", "grin":
			_px(cx - 7, eye_y - 3, 2, 1, brow)
			_px(cx - 5, eye_y - 4, 3, 1, brow)
			_px(cx + 2, eye_y - 4, 3, 1, brow)
			_px(cx + 5, eye_y - 3, 2, 1, brow)
		"sly":
			_px(cx - 7, eye_y - 3, 5, 1, brow)
			_px(cx + 2, eye_y - 4, 3, 1, brow)
			_px(cx + 5, eye_y - 5, 2, 1, brow)
		_:
			_px(cx - 7, eye_y - 3, 5, 1, brow)
			_px(cx + 2, eye_y - 3, 5, 1, brow)
	if "glasses" in ex:
		var g := Color("#d6c38a")
		for side in [-1, 1]:
			var gx: float = cx - 7 if side < 0 else cx + 1
			_ci.draw_rect(Rect2(_o + Vector2(gx, eye_y - 1) * _u, Vector2(6, 4) * _u), g, false, maxf(1.0, _u * 0.7))
		_px(cx - 1, eye_y, 2, 1, g)
	# Nose: a light ridge and a shadow on the far side.
	_px(cx - 1, eye_y + 2, 1, 4, st[2])
	_px(cx, eye_y + 2, 1, 4, st[0])
	_px(cx - 2, eye_y + 6, 4, 1, st[0])
	# Cheeks, for the warm faces.
	if face in ["warm", "grin"]:
		_px(cx - 8, eye_y + 4, 3, 1, Color(0.85, 0.35, 0.35, 0.35))
		_px(cx + 5, eye_y + 4, 3, 1, Color(0.85, 0.35, 0.35, 0.35))
	# Mouth.
	var my: float = 27.0 + dy
	var lipc: Color = Color("#b8262d") if "lips" in ex else st[0].darkened(0.25)
	match face:
		"grin":
			_px(cx - 4, my, 8, 2, Color("#2a1416"))
			_px(cx - 3, my, 6, 1, Color("#f4efe6"))
			_px(cx - 5, my - 1, 1, 1, lipc)
			_px(cx + 4, my - 1, 1, 1, lipc)
		"warm":
			_px(cx - 3, my, 6, 1, lipc)
			_px(cx - 4, my - 1, 1, 1, lipc)
			_px(cx + 3, my - 1, 1, 1, lipc)
		"sly":
			_px(cx - 3, my, 6, 1, lipc)
			_px(cx + 3, my - 1, 2, 1, lipc)
		"stern":
			_px(cx - 3, my, 6, 1, lipc.darkened(0.2))
			_px(cx - 4, my + 1, 1, 1, lipc.darkened(0.2))
			_px(cx + 3, my + 1, 1, 1, lipc.darkened(0.2))
		_:
			_px(cx - 3, my, 6, 1, lipc)
	if "lips" in ex:
		_px(cx - 2, my + 1, 4, 1, lipc.darkened(0.3))
	if "moustache" in ex:
		_px(cx - 4, my - 2, 8, 1, hair[0])
		_px(cx - 5, my - 1, 2, 1, hair[0])
		_px(cx + 3, my - 1, 2, 1, hair[0])
	if "beard" in ex:
		for y in range(25, 33):
			var bw: float = HEAD.get(y, 3.0) - 0.5
			_px(cx - bw, y + dy, bw * 2, 1, hair[1] if y % 2 == 0 else hair[0])
		_px(cx - 3, my, 6, 1, st[0].darkened(0.3))
	if "stubble" in ex:
		for p in [[-6, 26], [-4, 29], [3, 29], [5, 26], [-2, 30], [1, 30], [-7, 24], [6, 24], [0, 31]]:
			_px(cx + p[0], p[1] + dy, 1, 1, st[0].darkened(0.2))
	if "scar" in ex:
		_px(cx + 4, eye_y - 3, 1, 8, Color("#a04848"))
		_px(cx + 3, eye_y - 1, 3, 1, Color("#a04848"))
	if "grease" in ex:
		_px(cx - 7, eye_y + 5, 3, 2, Color(0.1, 0.08, 0.06, 0.6))
	if "cigar" in ex:
		_px(cx + 3, my, 8, 2, Color("#6b4426"))
		_px(cx + 3, my, 8, 1, Color("#8a5a32"))
		_px(cx + 11, my, 1, 2, Color("#ff7b3a"))
		for i in range(4):
			_ci.draw_circle(_o + Vector2(cx + 12 + i, my - 3 - i * 3) * _u, (1.0 + i * 0.6) * _u, Color(0.85, 0.85, 0.85, 0.22 - i * 0.04), true, -1.0, false)
	if "toothpick" in ex:
		_px(cx + 2, my, 6, 1, Color("#e8d8a8"))


## Hair, styled, with a highlight where the key light catches it.
static func _hair(cx: float, dy: float, h: Array, style: String, ex: Array) -> void:
	match style:
		"under_hat":
			_px(cx - 9, 14 + dy, 2, 4, h[0])
			_px(cx + 7, 14 + dy, 2, 4, h[0])
		"slick":
			for y in range(8, 15):
				var hw: float = HEAD.get(y, 4.0) + 0.5
				_px(cx - hw, y + dy, hw * 2, 1, h[1])
			_px(cx - 9.5, 15 + dy, 2, 4, h[1])
			_px(cx + 7.5, 15 + dy, 2, 4, h[0])
			for i in range(5):
				_px(cx - 6 + i * 2, 9 + i * 0.6 + dy, 3, 1, h[2])   # the comb lines
		"short":
			for y in range(9, 14):
				var hw2: float = HEAD.get(y, 4.0) + 0.5
				_px(cx - hw2, y + dy, hw2 * 2, 1, h[1])
			for x in range(int(cx - 8), int(cx + 8), 3):
				_px(x, 14 + dy, 2, 1, h[1])
			_px(cx - 6, 10 + dy, 5, 1, h[2])
		"thin":
			_px(cx - 9.5, 13 + dy, 2, 6, h[1])
			_px(cx + 7.5, 13 + dy, 2, 6, h[0])
			for x in [-4, -1, 2]:
				_px(cx + x, 9 + dy, 2, 1, h[1])
		"bald":
			_px(cx - 9.5, 16 + dy, 2, 5, h[1])
			_px(cx + 7.5, 16 + dy, 2, 5, h[0])
			_px(cx - 4, 11 + dy, 4, 1, Color(1, 1, 1, 0.35))   # the shine
		"bob":
			# A sleek bob: a full cap, a straight fringe, sides down to the jaw.
			for y in range(7, 15):
				var hw3: float = HEAD.get(y, 3.0) + 1.5
				_px(cx - hw3, y + dy, hw3 * 2, 1, h[1])
			_px(cx - 8, 14 + dy, 16, 2, h[1])                 # the fringe
			_px(cx - 11, 14 + dy, 4, 16, h[1])
			_px(cx + 7, 14 + dy, 4, 16, h[0])
			_px(cx - 11, 29 + dy, 5, 2, h[1])                 # the bob turns under at the jaw
			_px(cx + 6, 29 + dy, 5, 2, h[0])
			_px(cx - 7, 9 + dy, 7, 1, h[2])
			_px(cx - 10, 16 + dy, 1, 10, h[2])
		"curls":
			for p in [[-11, 9], [-7, 6], [-2, 5], [3, 5], [8, 7], [-12, 14], [9, 13], [-12, 20], [9, 20], [-11, 26], [8, 26]]:
				_ci.draw_circle(_o + Vector2(cx + p[0] + 2, p[1] + dy + 2) * _u, 3.2 * _u, h[1], true, -1.0, false)
				_px(cx + p[0] + 1, p[1] + dy, 2, 1, h[2])
		"waves":
			for y in range(8, 16):
				var hw4: float = HEAD.get(y, 3.0) + 1.0
				_px(cx - hw4, y + dy, hw4 * 2, 1, h[1])
			for i in range(3):
				_px(cx - 8 + i * 5, 10 + (i % 2) * 2 + dy, 4, 1, h[2])
			_px(cx - 10, 15 + dy, 3, 8, h[1])
			_px(cx + 7, 15 + dy, 3, 8, h[0])
		"long":
			for y in range(7, 15):
				var hw5: float = HEAD.get(y, 3.0) + 1.5
				_px(cx - hw5, y + dy, hw5 * 2, 1, h[1])
			_px(cx - 11, 13 + dy, 3, 14, h[1])
			_px(cx + 8, 13 + dy, 3, 14, h[0])
			_px(cx - 6, 9 + dy, 6, 1, h[2])
		"big":
			# The bouffant's front: a full crown down to the brow, swept to one side.
			for y in range(5, 15):
				var hw6: float = HEAD.get(y, 3.0) + 2.5 + (2.0 if y < 9 else 0.0)
				_px(cx - hw6, y + dy, hw6 * 2, 1, h[1])
			_px(cx - 8, 5 + dy, 10, 2, h[2])
			_px(cx - 11, 8 + dy, 2, 6, h[2])
			_px(cx + 1, 13 + dy, 8, 2, h[0])


## Hair that sits behind the head and shoulders: the bouffant's volume, long hair's fall.
static func _hair_back(cx: float, dy: float, h: Array, style: String) -> void:
	match style:
		"big":
			_ci.draw_circle(_o + Vector2(cx, 13 + dy) * _u, 15.0 * _u, OUTLINE, true, -1.0, false)
			_ci.draw_circle(_o + Vector2(cx, 13 + dy) * _u, 14.0 * _u, h[1], true, -1.0, false)
			_px(cx - 15, 14 + dy, 6, 16, h[1])
			_px(cx + 9, 14 + dy, 6, 16, h[0])
			_px(cx - 14, 10 + dy, 2, 12, h[2])
		"long":
			_px(cx - 13, 12 + dy, 26, 32, OUTLINE)
			_px(cx - 12, 12 + dy, 24, 32, h[1])
			_px(cx + 6, 12 + dy, 6, 32, h[0])
			_px(cx - 11, 16 + dy, 1, 24, h[2])


## Hats: fedora, cap, top hat, or the croupier's green visor.
static func _hat(cx: float, dy: float, d: Dictionary) -> void:
	var hc: Array = _tones(Color(d.get("hat_col", "#222222")))
	match d.get("hat", ""):
		"fedora":
			_px(cx - 15, 11 + dy, 30, 3, OUTLINE)
			_px(cx - 14, 11 + dy, 28, 2, hc[1])
			_px(cx - 14, 11 + dy, 28, 1, hc[2])
			# A fedora: a low, pinched crown over a wide brim that dips at the front.
			_px(cx - 9, 4 + dy, 18, 8, OUTLINE)
			_px(cx - 8, 5 + dy, 16, 7, hc[1])
			_px(cx - 8, 5 + dy, 4, 7, hc[2])
			_px(cx + 5, 5 + dy, 3, 7, hc[0])
			_px(cx - 2, 4 + dy, 4, 2, OUTLINE)             # the pinch at the crown
			_px(cx - 8, 9 + dy, 16, 2, Color("#7a1f2b"))   # band
			_px(cx - 6, 13 + dy, 12, 1, hc[0])             # brim dipping over the eyes
		"cap":
			_px(cx - 10, 6 + dy, 20, 7, OUTLINE)
			_px(cx - 9, 6 + dy, 18, 6, hc[1])
			_px(cx - 9, 6 + dy, 5, 6, hc[2])
			_px(cx - 12, 12 + dy, 21, 2, hc[0])            # the peak
		"top_hat":
			_px(cx - 14, 10 + dy, 28, 3, OUTLINE)
			_px(cx - 13, 10 + dy, 26, 2, hc[1])
			_px(cx - 8, 0 + dy, 16, 11, OUTLINE)
			_px(cx - 7, 0 + dy, 14, 10, hc[1])
			_px(cx - 7, 0 + dy, 3, 10, hc[2])
			_px(cx - 7, 7 + dy, 14, 2, Color("#a01c24"))   # band
	var ex: Array = d.get("extras", [])
	if "visor" in ex:
		# A green celluloid croupier's visor, light glowing through it.
		_px(cx - 11, 12 + dy, 22, 2, Color("#0e5a2e"))
		_px(cx - 12, 14 + dy, 24, 2, Color(0.18, 0.75, 0.4, 0.75))
		_px(cx - 12, 14 + dy, 24, 1, Color(0.45, 0.95, 0.6, 0.8))
		_px(cx - 9, 16 + dy, 18, 1, Color(0.1, 0.4, 0.2, 0.35))   # its green shade on the brow


## Earrings and other head details.
static func _extras_head(cx: float, dy: float, st: Array, h: Array, ex: Array) -> void:
	if "earrings" in ex:
		_px(cx - 10.5, 23 + dy, 1.5, 3, P.GOLD)
		_px(cx + 9, 23 + dy, 1.5, 3, P.GOLD)
	if "chip_earring" in ex:
		# A tiny casino chip on a gold hoop.
		_px(cx + 9, 23 + dy, 1, 2, P.GOLD)
		_ci.draw_circle(_o + Vector2(cx + 9.5, 27 + dy) * _u, 1.8 * _u, Color("#b8262d"), true, -1.0, false)
		_px(cx + 9, 26 + dy, 1, 1, Color("#f4efe6"))


static func _fallback(who: String) -> Dictionary:
	var h := hash(who)
	var tint := Color.from_hsv(float(h % 360) / 360.0, 0.45, 0.45)
	return {"suit": tint.darkened(0.3).to_html(), "shirt": "#e9e3d3", "skin": h % 5, "hair": tint.darkened(0.6).to_html(),
		"hair_style": ["short", "slick", "thin", "long"][(h >> 4) % 4], "hat": "fedora" if (h >> 3) % 3 == 0 else "",
		"hat_col": tint.darkened(0.6).to_html(), "extras": ["lapels"], "bg": tint.darkened(0.5).to_html(), "face": "stern"}
