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
		"name": "French Wheel", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": ["la_partage"], "cash": 0, "kit": [{"kind": "perm", "value": 2}], "unlock": 0, "target": 0.85,
		"desc": "Single zero, La Partage built in (even-money bets lose only half on zero), and a Permanent x2 to start. Forgiving.",
	},
	"european": {
		"name": "European Wheel", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": [], "cash": 0, "kit": [{"kind": "magnet", "value": 1}], "unlock": 0,
		"desc": "The classic single-zero wheel. Starts with a Magnet chip.",
	},
	"american": {
		"name": "American Wheel", "numbers": 36, "zeros": [0, -1], "order": AMERICAN_ORDER, "red": RED_36,
		"rules": [], "cash": 4, "kit": [], "unlock": 3,
		"desc": "Two zeros: worse odds, but 00 is a second home for zero chips. +$4 to start.",
	},
	"mini": {
		"name": "Mini Wheel", "numbers": 12, "zeros": [0], "order": MINI_ORDER, "red": RED_12,
		"rules": [], "cash": 2, "kit": [], "unlock": 4, "target": 1.05,
		"desc": "Thirteen pockets on a 3x4 felt. Hits come often but pay small; every square counts.",
	},
	"triple_zero": {
		"name": "Triple Zero", "numbers": 36, "zeros": [0, -1, -2], "order": TRIPLE_ORDER, "red": RED_36,
		"rules": [], "cash": 0, "kit": [{"kind": "wildcard_zero", "value": 1}], "unlock": 6,
		"desc": "0, 00 and 000. The worst odds in the casino, but zero chips trigger three times as often.",
	},
	"sunrise": {
		"name": "Sunrise Wheel", "numbers": 36, "zeros": [0], "order": EURO_ORDER, "red": RED_36,
		"rules": ["momentum"], "cash": 0, "kit": [{"kind": "kingmaker", "value": 1}], "unlock": 5, "target": 1.15,
		"desc": "The last wheel before dawn. Momentum built in and a Kingmaker to start, but payments are 15% bigger.",
	},
	"no_zero": {
		"name": "Cheater's Wheel", "numbers": 36, "zeros": [], "order": NO_ZERO_ORDER, "red": RED_36,
		"rules": [], "cash": 0, "kit": [], "unlock": 8, "target": 1.25,
		"desc": "No zero at all: every bet is perfectly fair. Mr. Vance makes up for it with payments 25% bigger.",
	},
}

const ORDER := ["french", "european", "american", "mini", "triple_zero", "sunrise", "no_zero"]


static func get_def(id: String) -> Dictionary:
	return WHEELS[id]


static func label(p: int) -> String:
	return str(p) if p > 0 else "0".repeat(1 - p)


static func sectors(def: Dictionary) -> Dictionary:
	if def.numbers == 12:
		return {"VOI": VOISINS_12, "TIE": TIERS_12, "ORP": ORPHELINS_12}
	return {"VOI": VOISINS_36, "TIE": TIERS_36, "ORP": ORPHELINS_36}
