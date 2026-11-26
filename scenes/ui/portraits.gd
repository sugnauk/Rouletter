extends RefCounted
## Procedural pixel portraits for the cast. Each character is a recipe of layers drawn on a
## 32x32 pixel grid (scaled to any size): backdrop, suit, head, hair or hat, face, accessories.
## Unknown speakers fall back to a tinted silhouette seeded from their name.

const P := preload("res://scenes/ui/palette.gd")

const SKIN := [Color("#f1c27d"), Color("#e0ac69"), Color("#c68642"), Color("#8d5524"), Color("#ffdbac")]

## suit, shirt, skin index, hair colour, hair style, hat, extras, backdrop
const CAST := {
	"Mr. Vance": {"suit": "#14141c", "shirt": "#f4ead5", "skin": 4, "hair": "#9aa0a6", "hair_style": "slick",
		"extras": ["bowtie", "cigar", "brows"], "bg": "#3b1020"},
	"Dolores": {"suit": "#b8262d", "shirt": "#b8262d", "skin": 0, "hair": "#c0392b", "hair_style": "curls",
		"extras": ["lips", "earrings", "strap"], "bg": "#2a1a2e"},
	"Lucky Lou": {"suit": "#6b4426", "shirt": "#d6c38a", "skin": 1, "hair": "#3b2414", "hat": "fedora", "hat_col": "#3d3d4a",
		"extras": ["stubble", "loose_tie", "toothpick"], "bg": "#1f2a1f"},
	"Abe": {"suit": "#5a4a3a", "shirt": "#d9cbb0", "skin": 4, "hair": "#cfcfcf", "hair_style": "bald",
		"extras": ["glasses", "beard"], "bg": "#2b2418"},
	"Big Sal": {"suit": "#2b2b36", "shirt": "#e9e9e9", "skin": 2, "hair": "#1a1a1a", "hat": "fedora", "hat_col": "#1a1a22",
		"extras": ["scar", "wide", "tie"], "bg": "#2a1414"},
	"Cashier": {"suit": "#e9e3d3", "shirt": "#e9e3d3", "skin": 0, "hair": "#5a3b1e", "hair_style": "short",
		"extras": ["visor", "armband", "bowtie"], "bg": "#1c2a1f"},
	"Pit Boss": {"suit": "#1c1c28", "shirt": "#f4ead5", "skin": 1, "hair": "#20140c", "hair_style": "slick",
		"extras": ["moustache", "tie"], "bg": "#2a1018"},
	"Loan Shark": {"suit": "#2e5266", "shirt": "#1a1a22", "skin": 2, "hair": "#101010", "hair_style": "slick",
		"extras": ["shades", "chain"], "bg": "#10262e"},
	"Fence": {"suit": "#4a4a3a", "shirt": "#7a7a66", "skin": 1, "hair": "#4a3020", "hat": "cap", "hat_col": "#5a5a48",
		"extras": ["collar", "stubble"], "bg": "#202018"},
	"Dealer": {"suit": "#141414", "shirt": "#f4ead5", "skin": 3, "hair": "#111111", "hair_style": "short",
		"extras": ["vest", "bowtie"], "bg": "#13241a"},
	"The Accountant": {"suit": "#4a4f58", "shirt": "#f4ead5", "skin": 4, "hair": "#6b6b6b", "hair_style": "thin",
		"extras": ["glasses", "tie"], "bg": "#1c1f26"},
	"Madame Oro": {"suit": "#1e8a46", "shirt": "#1e8a46", "skin": 0, "hair": "#f2c14e", "hair_style": "big",
		"extras": ["lips", "pearls"], "bg": "#0e2a1a"},
	"Vic \"The Rake\"": {"suit": "#3a2a4a", "shirt": "#d6c38a", "skin": 1, "hair": "#2a1a10", "hat": "fedora", "hat_col": "#2a1a2a",
		"extras": ["pinstripe", "toothpick", "brows"], "bg": "#1e1426"},
	"The Inspector": {"suit": "#2c3e50", "shirt": "#f4ead5", "skin": 4, "hair": "#3b2a1a", "hat": "cap", "hat_col": "#1f2d3a",
		"extras": ["badge", "moustache"], "bg": "#14202a"},
	"Velvet": {"suit": "#6a1b9a", "shirt": "#6a1b9a", "skin": 0, "hair": "#101010", "hair_style": "long",
		"extras": ["lips", "earrings", "pearls"], "bg": "#25102e"},
	"Mr. Kline": {"suit": "#3d3d3d", "shirt": "#f4ead5", "skin": 4, "hair": "#bdbdbd", "hair_style": "thin",
		"extras": ["glasses", "tie", "brows"], "bg": "#1f1f1f"},
}


static func has(who: String) -> bool:
	return CAST.has(who)


## Draw `who` into `r` (any size; square works best).
static func draw(ci: CanvasItem, who: String, r: Rect2) -> void:
	var u := r.size.x / 32.0
	var o := r.position
	var R := func(x: float, y: float, w: float, h: float, col):
		ci.draw_rect(Rect2(o + Vector2(x, y) * u, Vector2(w, h) * u), col)
	if who == "Narrator":
		ci.draw_rect(r, P.BLACK)
		ci.draw_circle(r.get_center() - Vector2(0, u * 2), 7 * u, P.GOLD.darkened(0.4), true, -1.0, false)
		ci.draw_circle(r.get_center() - Vector2(0, u * 2), 4.5 * u, P.BLACK, true, -1.0, false)
		R.call(14, 22, 4, 6, P.GOLD.darkened(0.5))
		ci.draw_rect(r, P.GOLD, false, 1.0)
		return
	var d: Dictionary = CAST.get(who, _fallback(who))
	var bg := Color(d.bg)
	var suit := Color(d.suit)
	var shirt := Color(d.shirt)
	var skin: Color = SKIN[int(d.skin) % SKIN.size()]
	var hair := Color(d.hair)
	var ex: Array = d.get("extras", [])
	# Backdrop: a smoky gradient and a lamp glow behind the head.
	ci.draw_rect(r, bg.darkened(0.35))
	for i in range(4):
		R.call(0, 32 - (i + 1) * 4, 32, 4, bg.darkened(0.35 - i * 0.08))
	ci.draw_circle(o + Vector2(16, 13) * u, 11 * u, Color(bg.lightened(0.25), 0.35), true, -1.0, false)
	# Shoulders and suit.
	var sw := 26.0 if "wide" in ex else 22.0
	R.call(16 - sw / 2.0, 24, sw, 8, suit)
	R.call(16 - sw / 2.0 + 1, 23, sw - 2, 1, suit)
	if "pinstripe" in ex:
		for x in range(int(16 - sw / 2.0) + 1, int(16 + sw / 2.0), 3):
			R.call(x, 24, 1, 8, suit.lightened(0.25))
	if "vest" in ex:
		R.call(12, 24, 8, 8, Color("#7a1f2b"))
	if d.shirt != d.suit:
		R.call(13, 23, 6, 9, shirt)
	R.call(14, 22, 4, 3, skin.darkened(0.1))  # neck
	# Head.
	R.call(10, 8, 12, 14, skin)
	R.call(11, 7, 10, 1, skin)
	R.call(11, 22, 10, 1, skin.darkened(0.15))
	R.call(9, 13, 1, 4, skin.darkened(0.1))   # ears
	R.call(22, 13, 1, 4, skin.darkened(0.1))
	R.call(10, 19, 12, 3, skin.darkened(0.06))  # jaw shade
	# Hair.
	match d.get("hair_style", "short"):
		"slick":
			R.call(10, 6, 12, 3, hair)
			R.call(10, 9, 1, 3, hair)
			R.call(21, 9, 1, 3, hair)
			R.call(12, 6, 6, 1, hair.lightened(0.3))
		"short":
			R.call(10, 6, 12, 3, hair)
			R.call(10, 9, 2, 2, hair)
			R.call(20, 9, 2, 2, hair)
		"thin":
			R.call(10, 8, 2, 4, hair)
			R.call(20, 8, 2, 4, hair)
			R.call(13, 7, 6, 1, hair)
		"bald":
			R.call(10, 11, 1, 3, hair)
			R.call(21, 11, 1, 3, hair)
			R.call(13, 8, 3, 1, skin.lightened(0.3))
		"curls":
			for p in [[8, 6], [11, 4], [15, 3], [19, 4], [22, 6], [7, 10], [23, 10], [7, 15], [23, 15]]:
				R.call(p[0], p[1], 5, 5, hair)
				R.call(p[0] + 1, p[1], 2, 1, hair.lightened(0.3))
			R.call(10, 7, 12, 2, hair)
		"big":
			R.call(6, 3, 20, 7, hair)
			R.call(6, 10, 4, 12, hair)
			R.call(22, 10, 4, 12, hair)
			R.call(9, 4, 14, 1, hair.lightened(0.35))
		"long":
			R.call(9, 5, 14, 4, hair)
			R.call(8, 9, 3, 16, hair)
			R.call(21, 9, 3, 16, hair)
			R.call(11, 5, 6, 1, hair.lightened(0.3))
	# Hats.
	var hat_col := Color(d.get("hat_col", "#222222"))
	match d.get("hat", ""):
		"fedora":
			R.call(6, 7, 20, 2, hat_col)
			R.call(9, 2, 14, 5, hat_col)
			R.call(9, 5, 14, 1, Color("#7a1f2b"))   # band
			R.call(14, 2, 4, 1, hat_col.darkened(0.4))  # pinch
		"cap":
			R.call(9, 4, 14, 4, hat_col)
			R.call(8, 8, 17, 1, hat_col.darkened(0.3))
	# Face.
	var eye := Color("#1a1a22")
	if "shades" in ex:
		R.call(10, 12, 12, 3, Color("#0a0a0a"))
		R.call(11, 12, 2, 1, Color(1, 1, 1, 0.5))
		R.call(18, 12, 2, 1, Color(1, 1, 1, 0.5))
	else:
		R.call(12, 13, 2, 2, eye)
		R.call(18, 13, 2, 2, eye)
		R.call(12, 13, 1, 1, Color.WHITE)
		R.call(18, 13, 1, 1, Color.WHITE)
	if "brows" in ex:
		R.call(11, 11, 4, 1, hair.darkened(0.3))
		R.call(17, 11, 4, 1, hair.darkened(0.3))
	if "glasses" in ex:
		ci.draw_rect(Rect2(o + Vector2(11, 12) * u, Vector2(4, 4) * u), Color("#d6c38a"), false, maxf(1.0, u * 0.6))
		ci.draw_rect(Rect2(o + Vector2(17, 12) * u, Vector2(4, 4) * u), Color("#d6c38a"), false, maxf(1.0, u * 0.6))
		R.call(15, 13, 2, 1, Color("#d6c38a"))
	R.call(15, 15, 2, 3, skin.darkened(0.18))  # nose
	if "moustache" in ex:
		R.call(13, 18, 6, 1, hair.darkened(0.2))
	if "beard" in ex:
		R.call(11, 18, 10, 5, hair)
		R.call(14, 19, 4, 1, skin.darkened(0.3))
	elif "lips" in ex:
		R.call(14, 19, 4, 1, Color("#c0392b"))
	else:
		R.call(14, 19, 4, 1, skin.darkened(0.35))
	if "stubble" in ex:
		for p in [[11, 19], [13, 21], [17, 21], [20, 19], [12, 20], [19, 20], [15, 21]]:
			R.call(p[0], p[1], 1, 1, skin.darkened(0.3))
	if "scar" in ex:
		R.call(19, 11, 1, 6, Color("#a04040"))
	if "cigar" in ex:
		R.call(18, 19, 6, 1, Color("#6b4426"))
		R.call(24, 19, 1, 1, Color("#ff7b3a"))
		R.call(25, 16, 1, 2, Color(0.8, 0.8, 0.8, 0.5))
	if "toothpick" in ex:
		R.call(17, 19, 4, 1, Color("#e8d8a8"))
	if "earrings" in ex:
		R.call(9, 17, 1, 2, P.GOLD)
		R.call(22, 17, 1, 2, P.GOLD)
	if "visor" in ex:
		R.call(8, 9, 16, 2, Color("#1e8a46"))
		R.call(8, 9, 16, 1, Color("#2ec46a"))
	# Neckwear and chest details.
	if "bowtie" in ex:
		R.call(13, 23, 2, 2, Color("#b8262d") if d.shirt != "#141414" else P.BLACK)
		R.call(17, 23, 2, 2, Color("#b8262d"))
		R.call(15, 23, 2, 2, Color("#7a1f2b"))
	if "tie" in ex:
		R.call(15, 23, 2, 8, Color("#7a1f2b"))
	if "loose_tie" in ex:
		R.call(16, 24, 2, 7, Color("#a83232"))
	if "pearls" in ex:
		for x in range(11, 22, 2):
			R.call(x, 24 + (1 if x > 13 and x < 19 else 0), 1, 1, Color("#f4f4f4"))
	if "chain" in ex:
		for x in range(12, 21, 2):
			R.call(x, 25 + (1 if x > 13 and x < 19 else 0), 1, 1, P.GOLD)
	if "badge" in ex:
		R.call(20, 26, 3, 3, P.GOLD)
	if "armband" in ex:
		R.call(4, 27, 3, 2, Color("#b8262d"))
		R.call(25, 27, 3, 2, Color("#b8262d"))
	if "strap" in ex:
		for i in range(8):
			R.call(9 + i, 24 + i, 1, 1, Color("#3b2414"))
	if "collar" in ex:
		R.call(8, 22, 5, 3, suit.lightened(0.15))
		R.call(19, 22, 5, 3, suit.lightened(0.15))
	ci.draw_rect(r, P.GOLD, false, 1.0)


static func _fallback(who: String) -> Dictionary:
	var h := hash(who)
	var tint := Color.from_hsv(float(h % 360) / 360.0, 0.45, 0.45)
	return {"suit": tint.darkened(0.3).to_html(), "shirt": "#e9e3d3", "skin": h % 5, "hair": tint.darkened(0.6).to_html(),
		"hair_style": ["short", "slick", "thin", "long"][(h >> 4) % 4], "hat": "fedora" if (h >> 3) % 3 == 0 else "",
		"hat_col": tint.darkened(0.6).to_html(), "extras": [], "bg": tint.darkened(0.5).to_html()}
