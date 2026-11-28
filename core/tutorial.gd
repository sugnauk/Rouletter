extends RefCounted
## The guided first run: Rosa, the croupier, walks a brand-new player through one table and the Cage, one
## action at a time. Pure logic (no UI): the table and Cage screens ask `allows()` before acting,
## report actions with `did()`, and read `step()` for what to light up and say.
##
## The first spin is rigged so the lesson lands: the ball finds a red number in the column the
## player put their Box Office on, so the bet and the chip both pay.

const Board := preload("res://core/board.gd")

const DONE_ID := "tutorial_done"

## Each step: what to say, which action finishes it, and which felt spots to light (if any).
##   want: place_col | place_num | bet_red | spin | buy | leave
const STEPS := [
	{"want": "place_col", "status": "Put your Box Office on a column (a lit 2:1 box).",
		"say": ["Welcome to the Gilded Ace. I'm Rosa, I run this table. Let's get you through your first one.",
			"You start with two chips that stay on the felt all run. That ticket-shaped one is a Box Office: it pays every time its column comes in. Tap it in your rack, then tap a lit column."]},
	{"want": "place_num", "status": "Put your Magnet on any number.",
		"say": ["Now the Magnet: it goes on a single number, and if the ball lands right next to it, it slides on and pays. Pick any number you like."]},
	{"want": "bet_red", "status": "Tap RED to bet on it.",
		"say": ["Those chips are yours for keeps. Betting chips come off your stack each spin. Tap RED to bet on it: it comes in about half the time. I'd know."]},
	{"want": "spin", "status": "Press SPIN.",
		"say": ["That's a table. Press SPIN and I'll send the ball. Watch the bar at the top: your Take, and the payment you owe."]},
	{"want": "spin_free", "status": "",
		"say": ["See how it all pays at once? Keep going: reach the payment before the balls run out. Your bets go back down by themselves each spin."]},
	{"want": "buy", "status": "Drag an item off the counter onto the felt (or your rack) to buy it.",
		"say": ["This is the Cage, where you spend what you won. Drag anything off the counter: onto the felt to buy and place it, or onto the glowing box to keep it.",
			"Touch an item first to read its card. A chip you place here stays free to move until your next spin."]},
	{"want": "leave", "status": "Press NEXT TABLE when you're ready.",
		"say": ["That's all there is to it. The rest you learn at my table, the hard way. NEXT TABLE when you're ready."]},
]

var idx := 0
var active := true
var run_seed := -1       ## the run this tutorial guides (main.tutorial_on checks it still matches)
var wheel_id := ""
var col_key := ""        ## the column the Box Office went on (the rigged spin lands in it)


func step() -> Dictionary:
	return STEPS[idx] if active and idx < STEPS.size() else {}


func want() -> String:
	return step().get("want", "")


func finish() -> void:
	active = false


## May the player do this now? (Lets everything through once the tutorial is over.)
##   action: place | bet | spin | buy | leave ; key: the felt spot (or "")
func allows(action: String, key: String = "", kind: String = "") -> bool:
	match want():
		"":
			return true
		"place_col":
			return action == "place" and kind == "box_office" and key.begins_with("COL")
		"place_num":
			return action == "place" and Board.is_straight(key) and Board.straight_number(key) > 0
		"bet_red":
			return action == "bet" and key == "RED"
		"spin":   # (RED can go back on if it came off)
			return action == "spin" or (action == "bet" and key == "RED") or action == "take_back"
		"spin_free", "buy":
			return action in ["place", "bet", "spin", "buy", "take_back"]
		"leave":
			return true
	return true


## The player did something: move on if it was what this step wanted. Returns true on a new step.
func did(action: String, key: String = "") -> bool:
	var w := want()
	var hit := false
	match w:
		"place_col":
			hit = action == "place" and key.begins_with("COL")
			if hit:
				col_key = key
		"place_num":
			hit = action == "place" and Board.is_straight(key)
		"bet_red":
			hit = action == "bet" and key == "RED"
		"spin":
			hit = action == "spin"
		"spin_free":
			hit = action == "shop"   # reaching the Cage ends the table part
		"buy":
			hit = action == "buy"
		"leave":
			hit = action == "leave"
	if not hit:
		return false
	idx += 1
	if idx >= STEPS.size():
		active = false
	return true


## The rigged first spin: a red number in the Box Office's column (so the bet and the chip pay).
func rigged_pocket(board) -> int:
	var row := int(col_key.substr(3)) - 1 if col_key.begins_with("COL") else 0
	for n in range(1, board.numbers + 1):
		if board.is_red(n) and Board.grid_row(n) == row:
			return n
	return -99


## Felt spots to light for this step (the same lit/dim look as placing a chip).
func lit_keys(board) -> Array:
	match want():
		"place_col":
			return ["COL1", "COL2", "COL3"]
		"place_num":
			var out := []
			for n in range(1, board.numbers + 1):
				out.append(Board.straight_key(n))
			return out
		"bet_red":
			return ["RED"]
	return []
