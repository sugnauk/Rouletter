extends RefCounted
## Wheel definitions: the starting "gamblers". Every wheel is fair (each pocket equally likely);
## they differ in pocket set, felt size and built-in rules. Zero pockets use ids 0, -1 ("00"), -2 ("000").

const RED_36 := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const RED_12 := [1, 3, 6, 8, 9, 12]

const EURO_ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const AMERICAN_ORDER := [0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1,
	-1, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2]
const TRIPLE_ORDER := [0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1,
	-1, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2, -2]
const NO_ZERO_ORDER := [32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const MINI_ORDER := [0, 1, 4, 8, 7, 3, 10, 12, 5, 6, 11, 9, 2]

## Classic French call bets (by number set; used on every 36-number wheel).
const VOISINS_36 := [22, 18, 29, 7, 28, 12, 35, 3, 26, 0, 32, 15, 19, 4, 21, 2, 25]
const TIERS_36 := [27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33]
const ORPHELINS_36 := [1, 20, 14, 31, 9, 17, 34, 6]
## Mini wheel call bets: arcs of its own wheel order.
const VOISINS_12 := [9, 2, 0, 1, 4]
const TIERS_12 := [10, 12, 5, 6]
const ORPHELINS_12 := [8, 7, 3, 11]

const WHEELS := {
	"french": {
		"felt": "#1d3f6e", "rail": "#5a3a1e",
		"name": "French Wheel", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": ["la_partage"], "cash": 0, "kit": [{"kind": "perm", "value": 2}, {"kind": "even_stevens", "value": 1}], "unlock": 0, "target": 0.85,
		"style": "SAFETY NET: outside bets that rarely sting",
		"desc": "Single zero, La Partage built in (even-money bets lose only half on zero). A Permanent x2 and an Even Stevens for a red/black box. Forgiving.",
	},
	"european": {
		"felt": "#0f5233", "rail": "#7a5a2a",
		"name": "European Wheel", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": [], "cash": 0, "kit": [{"kind": "box_office", "value": 1}, {"kind": "magnet", "value": 1}], "unlock": 0,
		"style": "NUMBERS: a few straight-ups that hit hard",
		"desc": "The classic single-zero wheel. A Box Office for a column or dozen and a Magnet: start steady, then pick your numbers.",
	},
	"american": {
		"felt": "#1d6b38", "rail": "#6b2a1e",
		"name": "Zero Wheel", "numbers": 36, "zeros": [0, -1, -2], "order": TRIPLE_ORDER, "red": RED_36,
		"rules": [], "cash": 2, "kit": [{"kind": "sentinel", "value": 1}, {"kind": "wildcard_zero", "value": 1}], "unlock": 3,
		"style": "ZERO ECONOMY: three green pockets, all yours",
		"desc": "0, 00 and 000: the worst odds in the house, but zero chips fire three times as often. A Sentinel, a Wildcard Zero and +$2.",
	},
	"mini": {
		"felt": "#4a2a6a", "rail": "#3a2a4a",
		"name": "Mini Wheel", "numbers": 12, "zeros": [0], "order": MINI_ORDER, "red": RED_12,
		"rules": [], "cash": 2, "kit": [{"kind": "bridge", "value": 1}], "unlock": 4, "target": 1.2,
		"style": "INSIDE BETS: splits, corners and streets",
		"desc": "Thirteen pockets on a 3x4 felt. Hits come often but pay small; a Bridge makes your splits and corners count.",
	},
	"twin": {
		"felt": "#0f4a5a", "rail": "#2a4a5a",
		"name": "Twin Ball", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": [], "cash": 0, "kit": [{"kind": "croupier", "value": 1}, {"kind": "bridge", "value": 1}], "unlock": 4,
		"twin": true, "spins": 4, "target": 1.5,
		"style": "TWO BALLS: cover more, combo harder",
		"desc": "Two balls drop every spin. A bet wins if either lands on it; a lost stake is only charged once. Both in one pocket: x3. Four spins a table, and payments 50% bigger.",
	},
	"crooked": {
		"felt": "#5a4a12", "rail": "#3a2a10",
		"name": "Crooked Wheel", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": [], "cash": 0, "kit": [{"kind": "magnet", "value": 1}, {"kind": "doorbell", "value": 1}], "unlock": 5,
		"crooked": true, "target": 1.0,
		"style": "CHASE THE FAT POCKETS: they move every table",
		"desc": "Four pockets are three times as wide (marked x3), so they come in far more often and pay less. They move to new numbers at every table.",
	},
	"carousel": {
		"felt": "#6a1f4a", "rail": "#8a5a2a",
		"name": "Carousel", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": ["momentum"], "cash": 0, "kit": [{"kind": "kingmaker", "value": 1}], "unlock": 6,
		"carousel": true, "target": 1.2,
		"style": "THE HOT ARC: bet where it's going",
		"desc": "A gold arc of seven pockets glows on the wheel and steps round after every spin. A ball inside it doubles the spin. Momentum built in, and a Kingmaker.",
	},
	"no_zero": {
		"felt": "#5a0f1e", "rail": "#2a1a14",
		"name": "Cheater's Wheel", "numbers": 36, "zeros": [], "order": NO_ZERO_ORDER, "red": RED_36,
		"rules": [], "cash": 0, "kit": [], "house": ["satin_gloves"], "unlock": 8, "target": 1.25,
		"style": "EVEN MONEY: red, black, odd, even at a fair price",
		"desc": "No zero at all: every bet is perfectly fair. Starts with Satin Gloves (even-money pays 1.5 to 1). Mr. Vance makes up for it with payments 25% bigger.",
	},
}

const ORDER := ["french", "european", "american", "mini", "twin", "crooked", "carousel", "no_zero"]
## Wheels retired in 0.0.44, and what saves that mention them become.
const RETIRED := {"triple_zero": "american", "sunrise": "carousel"}


static func get_def(id: String) -> Dictionary:
	return WHEELS[id]


static func label(p: int) -> String:
	return str(p) if p > 0 else "0".repeat(1 - p)


static func sectors(def: Dictionary) -> Dictionary:
	if def.numbers == 12:
		return {"VOI": VOISINS_12, "TIE": TIERS_12, "ORP": ORPHELINS_12}
	return {"VOI": VOISINS_36, "TIE": TIERS_36, "ORP": ORPHELINS_36}
